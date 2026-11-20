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

class DragToMoveTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  DEVELOPER_ROLE_ID = 2
  MANAGER_ROLE_ID = 1
  EDIT_PERMISSIONS = [:edit_issues, :edit_own_issues, :add_issue_notes].freeze

  setup do
    @manager = User.find(2)
    @developer = User.find(3)
    @project = Project.generate!(is_public: false)
    @project.enable_module!(:rubylode_progress)
    @project.enable_module!(:issue_tracking)
    Role.find(MANAGER_ROLE_ID).add_permission!(:view_rubylode_progress)
    Role.find(DEVELOPER_ROLE_ID).add_permission!(:view_rubylode_progress)
    User.add_to_project(@manager, @project, Role.find(MANAGER_ROLE_ID))
    User.add_to_project(@developer, @project, Role.find(DEVELOPER_ROLE_ID))
    @first_version = Version.generate!(project: @project, name: "Framing", effective_date: Date.new(2026, 1, 1))
    @second_version = Version.generate!(project: @project, name: "Foundations", effective_date: Date.new(2026, 2, 1))
    @closed_version = Version.generate!(project: @project, name: "Shipped", effective_date: Date.new(2025, 12, 1))
    @issue = Issue.generate!(project: @project, fixed_version: @first_version, author: @manager, subject: "Pour it")
    Issue.generate!(project: @project, fixed_version: @closed_version, author: @manager, subject: "Old work",
                    status_id: 5)
    @closed_version.update!(status: "closed")
  end

  def progress_path(query = "")
    "/projects/#{@project.identifier}/progress#{query}"
  end

  def quick_edit_path(issue = @issue)
    "/projects/#{@project.identifier}/progress/issues/#{issue.id}/quick_edit"
  end

  def sign_in_as(login)
    log_user(login, login == "dlopper" ? "foo" : login)
  end

  test "only an issue the viewer may edit is draggable, and none when the checklist is grouped by category" do
    Role.find(DEVELOPER_ROLE_ID).remove_permission!(*EDIT_PERMISSIONS)

    sign_in_as("jsmith")
    get progress_path("?group=version")
    assert_select ".rubylode-progress-step[draggable=true][data-issue-id=?]", @issue.id.to_s, count: 1
    assert_select ".rubylode-progress-row[draggable=true][data-issue-id=?]", @issue.id.to_s, count: 1
    assert_select ".rubylode-progress-hint", count: 1

    get progress_path("?group=category&open_stage=#{@closed_version.id}")
    assert_select ".rubylode-progress-step[draggable=true]", count: 2
    assert_select ".rubylode-progress-row[draggable]", count: 0
    assert_select ".rubylode-progress-section[data-version-id]", count: 0

    post "/logout"
    sign_in_as("dlopper")
    get progress_path("?group=version")
    assert_response :success
    assert_select "[draggable]", count: 0
    assert_select ".rubylode-progress-hint", count: 0
  end

  test "only a version that accepts issues is a drop target, in the stage list and in the version sections" do
    sign_in_as("jsmith")
    get progress_path("?group=version&filter=all")

    assert_select ".rubylode-progress-stage[data-version-id=?]", @first_version.id.to_s, count: 1
    assert_select ".rubylode-progress-stage[data-version-id=?]", @second_version.id.to_s, count: 1
    assert_select ".rubylode-progress-stage[data-version-id=?]", @closed_version.id.to_s, count: 0
    assert_select ".rubylode-progress-section[data-version-id=?]", @first_version.id.to_s, count: 1
    assert_select ".rubylode-progress-section[data-version-id=?]", @closed_version.id.to_s, count: 0
    assert_select ".rubylode-progress-row[data-current-version-id=?]", @first_version.id.to_s
  end

  test "the page names no drop target for a version the viewer cannot assign to" do
    sign_in_as("jsmith")
    get progress_path("?group=version&filter=all")

    assert_response :success
    assert_select "[data-version-id=?]", @closed_version.id.to_s, count: 0
  end

  test "the quick-edit form offers the assignable versions and saving it moves the issue to that version" do
    sign_in_as("jsmith")
    get quick_edit_path
    assert_response :success

    offered = css_select("select[name='issue[fixed_version_id]'] option").map { |option| option["value"].to_i }
    assert_includes offered, @first_version.id
    assert_includes offered, @second_version.id
    assert_not_includes offered, @closed_version.id
    assert_select "select[name='issue[fixed_version_id]'] option[selected][value=?]", @first_version.id.to_s
    back_url = css_select("input[name=back_url]").first["value"]

    patch "/issues/#{@issue.id}", params: { issue: { fixed_version_id: @second_version.id }, back_url: back_url }
    assert_redirected_to back_url
    assert_equal @second_version.id, @issue.reload.fixed_version_id
  end

  test "the quick-edit form has no Target version for a viewer who may not change it" do
    WorkflowPermission.create!(role_id: DEVELOPER_ROLE_ID, tracker_id: @issue.tracker_id, old_status_id: @issue.status_id,
                               field_name: "fixed_version_id", rule: "readonly")

    sign_in_as("dlopper")
    get quick_edit_path
    assert_response :success
    assert_select "select[name='issue[status_id]']"
    assert_select "select[name='issue[fixed_version_id]']", count: 0
  end

  test "the move request goes to Redmine's own issue update" do
    sign_in_as("jsmith")
    # The test environment turns forgery protection off, which also leaves out the meta tag.
    original_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get progress_path("?group=version")

    assert_select "meta[name=csrf-token][content]", count: 1
    assert_select ".rubylode-progress-step[data-update-path=?]", "/issues/#{@issue.id}"
    assert_select ".rubylode-progress-row[data-update-path=?]", "/issues/#{@issue.id}"
    assert_select "[data-controller~=rubylode-progress-move]", count: 1
    assert_select "[data-rubylode-progress-move-target=message][aria-live]", count: 1
    assert_select "script[src*=progress_move]", count: 1
    assert_select "[data-action~='dragenter->rubylode-progress-move#over'][data-action~='dragover->rubylode-progress-move#over'][data-action~='drop->rubylode-progress-move#drop']", count: 1
  ensure
    ActionController::Base.allow_forgery_protection = original_protection
  end
end
