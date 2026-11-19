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

    attr_reader :settings

    def initialize(project:, viewer:, settings: EffectiveSettings.for(project))
      @viewer = viewer
      @settings = settings
      @scope = IssueScope.new(project: project, viewer: viewer, settings: settings)
    end

    def stage_list
      @stage_list ||= StageList.new(versions: @scope.versions, issues: @scope.issues,
                                    in_progress_status_ids: settings.in_progress_status_ids)
    end

    def stages = stage_list.stages

    def current_stage = stage_list.current_stage

    def percent = PercentRule.percent_for(stages)

    def items
      @items ||= stages.flat_map do |stage|
        stage.steps.map { |step| Item.new(issue: step.issue, status: status_for(step.issue), step_number: step.number) }
      end
    end

    def status_for(issue)
      status_rule.status_for(issue)
    end

    # Taken over every counted issue, so it does not move when the checklist is filtered.
    def last_change_on
      @scope.issues.filter_map(&:updated_on).max
    end

    private

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
