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

# Saves one project's Progress overrides, from the Progress tab of its Settings. Redmine has no "Manage project"
# permission, so the gate is the one its own settings tabs use: Edit project, with the module enabled.
class RubylodeProgressProjectSettingsController < ApplicationController
  before_action :find_project
  before_action :require_edit_project

  STRING_FIELDS = %w[counted_versions version_name_prefix checklist_grouping note_source].freeze
  STATUS_LIST_FIELDS = %w[in_progress_status_ids waiting_status_ids].freeze

  def update
    setting = RubylodeProgress::ProjectSetting.for(@project)
    setting.assign_attributes(override_attributes)
    if setting.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = setting.errors.full_messages.join(", ")
    end
    redirect_to settings_project_path(@project, tab: "rubylode_progress")
  end

  private

  def require_edit_project
    return if User.current.allowed_to?(:edit_project, @project) && @project.module_enabled?(:rubylode_progress)

    deny_access
  end

  def submitted
    params.fetch(:rubylode_progress_project_setting, {}).permit(
      *STRING_FIELDS, :next_issue_limit, :finished_stages_kept, :checklist_rows_per_section, { counted_version_ids: [] }, *STATUS_LIST_FIELDS.map { |name| { name => [] } },
      *STATUS_LIST_FIELDS.map { |name| :"use_default_#{name}" }
    )
  end

  # A blank field, or a status list with "use the default" ticked, is NULL; everything else is the chosen value. A field
  # the form did not send is left as it is.
  def override_attributes
    values = submitted
    attributes = {}
    (STRING_FIELDS + %w[next_issue_limit finished_stages_kept checklist_rows_per_section]).each do |name|
      attributes[name] = values[name].presence if values.key?(name)
    end
    STATUS_LIST_FIELDS.each do |name|
      next unless values.key?(name) || values.key?("use_default_#{name}")

      use_default = values["use_default_#{name}"] == "1"
      attributes[name] = use_default ? nil : Array(values[name]).compact_blank.map(&:to_i)
    end
    attributes["excluded_version_ids"] = excluded_version_ids(values[:counted_version_ids]) if values.key?(:counted_version_ids)
    attributes
  end

  # The versions the tab listed that were left unticked. Only the project's own listed versions count, so a posted id
  # that is not one of them (another project's, a deleted one) is ignored. Nothing unticked is NULL: every version counts.
  def excluded_version_ids(ticked_ids)
    ticked = Array(ticked_ids).compact_blank.map(&:to_i)
    scope = RubylodeProgress::IssueScope.new(project: @project, viewer: User.current,
                                              settings: RubylodeProgress::EffectiveSettings.for(@project))
    unticked = scope.listable_versions.map(&:id) - ticked
    unticked.presence
  end
end
