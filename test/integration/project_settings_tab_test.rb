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

require File.expand_path("../test_helper", __dir__)

class ProjectSettingsTabTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  MANAGER_ROLE_ID = 1
  DEVELOPER_ROLE_ID = 2

  setup do
    @manager = User.find(2)
    @developer = User.find(3)
    @project = Project.generate!(is_public: false)
    @project.enable_module!(:rubylode_progress)
    @project.enable_module!(:issue_tracking)
    Role.find(MANAGER_ROLE_ID).add_permission!(:view_rubylode_progress)
    Role.find(DEVELOPER_ROLE_ID).add_permission!(:view_rubylode_progress)
    Role.find(DEVELOPER_ROLE_ID).remove_permission!(:edit_project)
    User.add_to_project(@manager, @project, Role.find(MANAGER_ROLE_ID))
    User.add_to_project(@developer, @project, Role.find(DEVELOPER_ROLE_ID))
  end

  def settings_path(tab = "rubylode_progress")
    "/projects/#{@project.identifier}/settings/#{tab}"
  end

  def save_path
    "/projects/#{@project.identifier}/progress/settings"
  end

  def save_override(**fields)
    patch save_path, params: { rubylode_progress_project_setting: fields }
  end

  test "the number fields are wide enough to show their 'Use the default' hint" do
    log_user("jsmith", "jsmith")

    get settings_path

    assert_response :success
    %w[next_issue_limit finished_stages_kept checklist_rows_per_section].each do |name|
      assert_select "input[type=number][name$='[#{name}]'][placeholder^='Use the default'][style*='width: 14em']", count: 1
    end
  end

  test "someone with Edit project sees the Progress tab and saves an override" do
    category = IssueCategory.create!(project: @project, name: "Backend")
    version = Version.generate!(project: @project, effective_date: Date.new(2026, 2, 15))
    Issue.generate!(project: @project, fixed_version: version, category: category, author: @manager)
    log_user("jsmith", "jsmith")

    get settings_path
    assert_response :success
    assert_select "#tab-content-rubylode_progress form[action=?]", save_path

    save_override(checklist_grouping: "category", next_issue_limit: "5")
    assert_redirected_to "/projects/#{@project.identifier}/settings/rubylode_progress"
    follow_redirect!
    assert_select "#flash_notice"

    row = RubylodeProgress::ProjectSetting.find_by!(project_id: @project.id)
    assert_equal "category", row.checklist_grouping
    assert_equal 5, row.next_issue_limit

    get "/projects/#{@project.identifier}/progress"
    assert_select ".rubylode-progress-section__title", text: /Backend/
  end

  test "someone with View progress only gets 403 and nothing is saved" do
    log_user("dlopper", "foo")

    save_override(checklist_grouping: "category")

    assert_response :forbidden
    assert_nil RubylodeProgress::ProjectSetting.find_by(project_id: @project.id)
  end

  test "the tab is hidden while the module is disabled and saving is refused" do
    @project.disable_module!(:rubylode_progress)
    log_user("jsmith", "jsmith")

    get "/projects/#{@project.identifier}/settings"
    assert_response :success
    assert_select "#tab-rubylode_progress", count: 0

    save_override(checklist_grouping: "category")
    assert_response :forbidden
    assert_nil RubylodeProgress::ProjectSetting.find_by(project_id: @project.id)
  end

  test "clearing a field brings back the plugin-wide default" do
    RubylodeProgress::ProjectSetting.create!(project: @project, checklist_grouping: "category", next_issue_limit: 9,
                                             in_progress_status_ids: [2])
    log_user("jsmith", "jsmith")

    save_override(checklist_grouping: "", next_issue_limit: "", use_default_in_progress_status_ids: "1",
                  in_progress_status_ids: [""])

    row = RubylodeProgress::ProjectSetting.find_by!(project_id: @project.id)
    assert_nil row.checklist_grouping
    assert_nil row.next_issue_limit
    assert_nil row.in_progress_status_ids
    assert_empty row.overrides
  end

  test "a status list without the use-the-default box saves the chosen statuses" do
    log_user("jsmith", "jsmith")

    save_override(waiting_status_ids: ["", "3", "4"])

    assert_equal [3, 4], RubylodeProgress::ProjectSetting.find_by!(project_id: @project.id).waiting_status_ids
  end

  test "an invalid value is refused with a message and nothing is saved" do
    log_user("jsmith", "jsmith")

    save_override(next_issue_limit: "21")

    assert_redirected_to "/projects/#{@project.identifier}/settings/rubylode_progress"
    follow_redirect!
    assert_select "#flash_error"
    assert_nil RubylodeProgress::ProjectSetting.find_by(project_id: @project.id)
  end

  test "deleting a project deletes its settings row, and a subproject's with it" do
    subproject = Project.generate_with_parent!(@project)
    RubylodeProgress::ProjectSetting.create!(project: @project, next_issue_limit: 4)
    RubylodeProgress::ProjectSetting.create!(project: subproject, next_issue_limit: 6)

    assert_difference "RubylodeProgress::ProjectSetting.count", -2 do
      @project.reload.destroy
    end
  end
end
