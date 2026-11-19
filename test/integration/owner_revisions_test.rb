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

class OwnerRevisionsTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  CLOSED_STATUS_ID = 5
  IN_PROGRESS_STATUS_ID = 2
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
    User.add_to_project(@manager, @project, Role.find(MANAGER_ROLE_ID))
    User.add_to_project(@developer, @project, Role.find(DEVELOPER_ROLE_ID))
    @version = Version.generate!(project: @project, name: "Build", effective_date: Date.new(2026, 3, 15))
    @done_issue = Issue.generate!(project: @project, fixed_version: @version, author: @manager, subject: "Finished",
                                  status_id: CLOSED_STATUS_ID)
    @started_issue = Issue.generate!(project: @project, fixed_version: @version, author: @developer, subject: "Started",
                                     status_id: IN_PROGRESS_STATUS_ID)
    @waiting_issue = Issue.generate!(project: @project, fixed_version: @version, author: @manager, subject: "Not started")
  end

  def progress_path(filter = "all")
    "/projects/#{@project.identifier}/progress?filter=#{filter}"
  end

  def item_modal_path(issue = @started_issue)
    "/projects/#{@project.identifier}/progress/issues/#{issue.id}/item"
  end

  def open_progress(login = "jsmith")
    log_user(login, login == "dlopper" ? "foo" : login)
    get progress_path
    assert_response :success
  end

  test "in-progress steps and rows get the half-filled mark, open ones the empty mark, done ones the tick" do
    with_settings plugin_redmine_rubylode_progress: { "in_progress_status_ids" => [IN_PROGRESS_STATUS_ID.to_s] } do
      open_progress

      assert_select ".rubylode-progress-step--in-progress", count: 1
      assert_select ".rubylode-progress-step--open", count: 1
      assert_select ".rubylode-progress-step--done", count: 1
      assert_select ".rubylode-progress-row--in-progress .rubylode-progress-row__mark", count: 1
      assert_select ".rubylode-progress-row--done .rubylode-progress-row__mark", count: 1
      assert_select ".rubylode-progress-row__mark--next", count: 1
    end
  end

  test "a checklist row carries a new-tab link that opens the issue, and no author" do
    open_progress

    assert_select ".rubylode-progress-row__author", count: 0
    assert_select "#rubylode-progress-item-#{@started_issue.id} a[href=?][target=_blank][rel~=noopener][title][aria-label]",
                  "/issues/#{@started_issue.id}"
    assert_select ".rubylode-progress-step a[href=?][target=_blank][rel~=noopener]", "/issues/#{@started_issue.id}"
    assert_select ".rubylode-progress-step__author", count: 0
  end

  test "the item title links to the issue and the modal action answers for a visible issue and refuses one the viewer cannot see" do
    open_progress
    assert_select "a.rubylode-progress-item-link[href=?][data-remote=true]", item_modal_path, minimum: 1

    get item_modal_path, xhr: true
    assert_response :success
    assert_includes response.body, "#ajax-modal"
    assert_includes response.body, "showModal("
    assert_includes response.body, ".ui-widget-overlay", "a click outside the modal closes it"
    assert_includes response.body, "center top", "the modal hangs from the top, so loaded content cannot push it down"
    assert_not_includes response.body, "iframe", "only the issue's own content goes in the modal, not the whole site"
    assert_includes response.body, "/issues/#{@started_issue.id}"
    assert_includes response.body, "#content"
    assert_includes response.body, CGI.escape("/projects/#{@project.identifier}/progress"),
                    "saving in the modal comes back to the Progress page"

    get item_modal_path
    assert_redirected_to "/issues/#{@started_issue.id}"

    get "/projects/#{@project.identifier}/progress/issues/0/item", xhr: true
    assert_response :not_found

    hidden = Issue.generate!(project: @project, fixed_version: @version, author: @manager, is_private: true)
    Role.find(DEVELOPER_ROLE_ID).update!(issues_visibility: "default")
    post "/logout"
    log_user("dlopper", "foo")
    get item_modal_path(hidden), xhr: true
    assert_response :not_found

    Role.find(DEVELOPER_ROLE_ID).remove_permission!(:view_rubylode_progress)
    get item_modal_path, xhr: true
    assert_response :forbidden
  end

  test "the item modal refuses an issue of another project" do
    other_project = Project.generate!(is_public: true)
    other_project.enable_module!(:issue_tracking)
    foreign_issue = Issue.generate!(project: other_project, author: @manager)

    log_user("jsmith", "jsmith")
    get item_modal_path(foreign_issue), xhr: true

    assert_response :not_found
  end

  test "each stage and section shows a progress percentage that matches its closed share" do
    open_progress

    assert_select "details.rubylode-progress-stage .rubylode-progress-meter__percent", text: "33%"
    assert_select "details.rubylode-progress-stage .rubylode-progress-meter__fill[style*=?]", "33%"
    assert_select "details.rubylode-progress-section .rubylode-progress-meter__percent", text: "33%"

    get progress_path("done")
    assert_select "details.rubylode-progress-section .rubylode-progress-meter__percent", text: "33%"
  end

  test "the stage date is labelled Due and absent without a date" do
    @version.update!(effective_date: nil)
    dated = Version.generate!(project: @project, name: "Launch", effective_date: Date.new(2026, 4, 1))
    Issue.generate!(project: @project, fixed_version: dated, author: @manager)

    open_progress

    assert_select ".rubylode-progress-stage__date", count: 1
    assert_select ".rubylode-progress-stage__date", text: "Due #{format_date_for_test(Date.new(2026, 4, 1))}"
  end

  test "the top tracker carries the overall percent and a mark per stage" do
    second = Version.generate!(project: @project, name: "Launch", effective_date: Date.new(2026, 4, 1))
    Issue.generate!(project: @project, fixed_version: second, author: @manager)

    open_progress

    assert_select ".rubylode-progress-tracker .rubylode-progress-tracker__percent", text: /\d+%/
    assert_select ".rubylode-progress-tracker ol.rubylode-progress-track[aria-label] li.rubylode-progress-track__stage", count: 2
    assert_select ".rubylode-progress-tracker .rubylode-progress-track__label", count: 2
    assert_select ".rubylode-progress-track__stage--current", count: 1

    get "/progress"
    assert_select ".rubylode-progress-compact-tracker .rubylode-progress-track__segment"
    assert_select ".rubylode-progress-compact-tracker .rubylode-progress-track__label", count: 0
  end

  def format_date_for_test(date)
    ApplicationController.new.helpers.format_date(date)
  end
end
