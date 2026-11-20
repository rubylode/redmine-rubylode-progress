# Rubylode Progress: a progress page for Redmine projects
# Copyright (C) 2026  Nick Gorbikoff
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module RubylodeProgress
  # One project's progress as one viewer sees it. The stages, the percent and every item's status all come from the
  # same IssueScope, so the rail, the percent, the tiles and the checklist always agree.
  class ProjectProgress
    Item = Struct.new(:issue, :status, :step_number, keyword_init: true)

    # What the new-issue modal shows. Anything beyond these needs Redmine's full form.
    NEW_ISSUE_MODAL_ATTRIBUTES = %w[tracker_id subject description assigned_to_id fixed_version_id].freeze

    attr_reader :settings

    # focused_stage_id narrows the items to one of the viewer's stages; the stages themselves stay whole.
    def initialize(project:, viewer:, settings: EffectiveSettings.for(project), focused_stage_id: nil)
      @project = project
      @viewer = viewer
      @settings = settings
      @focused_stage_id = focused_stage_id
      @scope = IssueScope.new(project: project, viewer: viewer, settings: settings)
    end

    def stage_list
      @stage_list ||= StageList.new(versions: @scope.versions, issues: @scope.issues,
                                    in_progress_status_ids: settings.in_progress_status_ids)
    end

    def stages = stage_list.stages

    # The older finished stages the stage list and the track fold; the fold is drawn outside the stage cache.
    def finished_stage_fold
      @finished_stage_fold ||= FinishedStageFold.new(stages, settings.finished_stages_kept)
    end

    def current_stage = stage_list.current_stage

    def percent = PercentRule.percent_for(stages)

    def finished_stage_count = stage_list.finished_stage_count

    def all_done? = stage_list.all_done?

    # Whether a focus was asked for, found or not.
    def focus_requested? = !@focused_stage_id.nil?

    # The viewer's stage the focus names; nil without a focus, or when the id is not one of the viewer's stages.
    def focused_stage
      return nil unless focus_requested?

      @focused_stage ||= stages.find { |stage| stage.version.id == @focused_stage_id }
    end

    # Every counted item, or only the focused stage's when a focus names one of the viewer's stages.
    def items
      @items ||= (focus_requested? ? [focused_stage].compact : stages).flat_map do |stage|
        stage.steps.map { |step| Item.new(issue: step.issue, status: status_for(step.issue), step_number: step.number) }
      end
    end

    def status_for(issue)
      status_rule.status_for(issue)
    end

    # The ids of the counted issues this viewer may edit, found for all of them at once from the issues already loaded.
    def editable_issue_ids
      @editable_issue_ids ||= items.map(&:issue).select { |issue| issue.editable?(@viewer) }.to_set(&:id)
    end

    # What the plus on a stage does for this viewer: :none (no plus), :modal (Redmine's modal), or :full_form (the
    # project needs fields the modal does not show, so the plus links to Redmine's own new-issue form). Redmine files
    # an issue only in an open version shared with the project, and only for a viewer who may add issues.
    def new_issue_mode_for(version)
      return :none unless accepts_issues?(version)

      new_issue_mode
    end

    # Whether an issue may be filed in, or moved into, this version: it is open and shared with the project, which is
    # what Redmine's own Target version list holds. It is only a convenience for the page: Redmine's update decides.
    def accepts_issues?(version)
      version.open? && @scope.shared_version_ids.include?(version.id)
    end

    # Whether anything on the page can be dragged: an issue the viewer may edit and a stage that takes it.
    def draggable_issues?
      editable_issue_ids.any? && stages.any? { |stage| accepts_issues?(stage.version) }
    end

# Whether this viewer may change the version's status: Redmine's manage_versions on the version's own project (a
# version shared from another project is that project's). Asked once per project, whatever the number of stages.
def can_manage_version?(version)
  @manage_versions_by_project_id ||= {}
  @manage_versions_by_project_id.fetch(version.project_id) do
    project = version.project_id == @project.id ? @project : version.project
    @manage_versions_by_project_id[version.project_id] = @viewer.allowed_to?(:manage_versions, project)
  end
end

    # Taken over every counted issue, so it does not move when the checklist is filtered.
    def last_change_on
      @scope.issues.filter_map(&:updated_on).max
    end

    private

    def new_issue_mode
      @new_issue_mode ||= begin
        trackers = @viewer.allowed_to?(:add_issues, @project) ? Issue.allowed_target_trackers(@project, @viewer).to_a : []
        if trackers.empty?
          :none
        elsif hidden_required_fields?(trackers)
          :full_form
        else
          :modal
        end
      end
    end

    # Whether a new issue of any of these trackers needs a field the modal does not show and that has no default: a
    # required custom field, or a field the workflow makes required for one of the viewer's roles on a new issue. Two
    # queries for all the trackers together, and deliberately on the safe side: a doubt sends the viewer to Redmine's form.
    def hidden_required_fields?(trackers)
      tracker_ids = trackers.map(&:id)
      required_custom_field = IssueCustomField.where(is_required: true, default_value: [nil, ""])
                                              .where("is_for_all = ? OR custom_fields.id IN (SELECT custom_field_id FROM custom_fields_projects WHERE project_id = ?)", true, @project.id)
                                              .joins(:trackers).where(custom_fields_trackers: { tracker_id: tracker_ids })
      return true if required_custom_field.exists?

      role_ids = @viewer.admin? ? Role.pluck(:id) : @viewer.roles_for_project(@project).map(&:id)
      WorkflowPermission.where(tracker_id: tracker_ids, old_status_id: trackers.map(&:default_status_id), role_id: role_ids,
                               rule: "required")
                        .where.not(field_name: NEW_ISSUE_MODAL_ATTRIBUTES).exists?
    end

    def status_rule
      @status_rule ||= begin
        without_next = build_status_rule(next_issue_ids: [])
        next_issue_ids = NextLimit.issue_ids_for(current_stage&.steps&.map(&:issue), limit: settings.next_issue_limit,
                                                                                     status_rule_without_next: without_next)
        build_status_rule(next_issue_ids: next_issue_ids)
      end
    end

    def build_status_rule(next_issue_ids:)
      ItemStatusRule.new(viewer_id: @viewer.logged? ? @viewer.id : nil, viewer_group_ids: @scope.viewer_group_ids,
                         in_progress_status_ids: settings.in_progress_status_ids,
                         waiting_status_ids: settings.waiting_status_ids, next_issue_ids: next_issue_ids)
    end
  end
end
