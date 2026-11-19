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

class QuickEditAndAddTest < Redmine::IntegrationTest
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
    @open_version = Version.generate!(project: @project, name: "Build", effective_date: Date.new(2026, 2, 1))
    @issue = Issue.generate!(project: @project, fixed_version: @open_version, author: @manager, subject: "Wire it up")
  end

  def progress_path(filter = nil)
    "/projects/#{@project.identifier}/progress#{"?filter=#{filter}" if filter}"
  end

  def quick_edit_path(issue = @issue, filter: nil)
    "/projects/#{@project.identifier}/progress/issues/#{issue.id}/quick_edit#{"?filter=#{filter}" if filter}"
  end

  def new_issue_path(version = @open_version)
    "/projects/#{@project.identifier}/progress/versions/#{version.id}/new_issue"
  end

  def sign_in_as(login)
    log_user(login, login == "dlopper" ? "foo" : login)
  end

  def revoke_editing_from_developers
    Role.find(DEVELOPER_ROLE_ID).remove_permission!(*EDIT_PERMISSIONS)
  end

  def revoke_adding_from_developers
    Role.find(DEVELOPER_ROLE_ID).remove_permission!(:add_issues)
  end

  test "the pencil shows only for a viewer who may edit the issue" do
    revoke_editing_from_developers

    sign_in_as("jsmith")
    get progress_path
    assert_select ".rubylode-progress-step a[href=?]", quick_edit_path, count: 1
    assert_select ".rubylode-progress-row a.rubylode-progress-edit", count: 1
    assert_select ".rubylode-progress-step a[aria-label][title][data-remote=true]", count: 1

    post "/logout"
    sign_in_as("dlopper")
    get progress_path
    assert_response :success
    assert_select ".rubylode-progress-step", count: 1
    assert_select "a.rubylode-progress-edit", count: 0
  end

  test "the pencil disappears once the viewer's role loses the right, even with the rail cached" do
    original_caching = ActionController::Base.perform_caching
    original_store = ActionController::Base.cache_store
    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new

    sign_in_as("jsmith")
    get progress_path
    assert_select ".rubylode-progress-step a[href=?]", quick_edit_path, count: 1

    Role.find(MANAGER_ROLE_ID).remove_permission!(*EDIT_PERMISSIONS)
    get progress_path
    assert_select "a.rubylode-progress-edit", count: 0
  ensure
    ActionController::Base.perform_caching = original_caching
    ActionController::Base.cache_store = original_store
  end

  test "two viewers with different edit rights never share a cached stage" do
    original_caching = ActionController::Base.perform_caching
    original_store = ActionController::Base.cache_store
    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
    revoke_editing_from_developers

    sign_in_as("dlopper")
    get progress_path
    assert_select "a.rubylode-progress-edit", count: 0
    post "/logout"
    sign_in_as("jsmith")
    get progress_path
    assert_select ".rubylode-progress-step a[href=?]", quick_edit_path, count: 1
    post "/logout"
    sign_in_as("dlopper")
    get progress_path
    assert_select "a.rubylode-progress-edit", count: 0
  ensure
    ActionController::Base.perform_caching = original_caching
    ActionController::Base.cache_store = original_store
  end

  test "quick edit offers only the statuses the workflow allows this viewer" do
    WorkflowTransition.where(role_id: DEVELOPER_ROLE_ID).delete_all
    WorkflowTransition.create!(role_id: DEVELOPER_ROLE_ID, tracker_id: @issue.tracker_id, old_status_id: 1,
                               new_status_id: 2)

    sign_in_as("dlopper")
    get quick_edit_path
    assert_response :success

    offered = css_select("select[name='issue[status_id]'] option").map { |option| option["value"].to_i }
    assert_equal [1, 2], offered.sort
    assert_select "select[name='issue[assigned_to_id]']"
    assert_select "select[name='issue[done_ratio]']"
    assert_select "textarea[name='issue[notes]']"
    assert_select "a[href^=?]", "/issues/#{@issue.id}/edit", text: "Full edit"
  end

  test "quick edit shows only the notes to a viewer who may add notes but not edit the issue" do
    Role.find(DEVELOPER_ROLE_ID).remove_permission!(:edit_issues, :edit_own_issues)

    sign_in_as("dlopper")
    get quick_edit_path
    assert_response :success

    assert_select "select[name='issue[status_id]']", count: 0
    assert_select "select[name='issue[assigned_to_id]']", count: 0
    assert_select "textarea[name='issue[notes]']"
  end

  test "saving a quick edit returns to the Progress page with the same filter" do
    sign_in_as("jsmith")
    get quick_edit_path(filter: "all"), params: { back_url: "https://evil.example/steal" }
    assert_response :success

    assert_select "form[action=?][method=post]", "/issues/#{@issue.id}"
    assert_select "input[name=_method][value=patch]"
    back_url = css_select("input[name=back_url]").first["value"]
    assert_equal progress_path("all"), back_url

    patch "/issues/#{@issue.id}", params: { issue: { status_id: 2, notes: "Started" }, back_url: back_url }
    assert_redirected_to progress_path("all")
    assert_equal 2, @issue.reload.status_id
    assert_equal "Started", @issue.journals.last.notes
  end

  test "an unknown filter is replaced, never copied into the return address" do
    sign_in_as("jsmith")
    get quick_edit_path(filter: "javascript:alert(1)")

    assert_equal progress_path("open"), css_select("input[name=back_url]").first["value"]
  end

  test "the quick edit answers a script request with the modal" do
    sign_in_as("jsmith")
    get quick_edit_path, xhr: true

    assert_response :success
    assert_includes response.body, "#ajax-modal"
    assert_includes response.body, "showModal('ajax-modal', '600px')"
    assert_includes response.body, ".ui-widget-overlay", "a click outside the modal closes it"
  end

  test "quick edit refuses a viewer who may not edit, and an issue that does not exist or is hidden" do
    revoke_editing_from_developers
    hidden = Issue.generate!(project: @project, fixed_version: @open_version, author: @manager, is_private: true)
    Role.find(DEVELOPER_ROLE_ID).update!(issues_visibility: "default")

    sign_in_as("dlopper")
    get quick_edit_path
    assert_response :forbidden
    get quick_edit_path(hidden)
    assert_response :not_found
    get "/projects/#{@project.identifier}/progress/issues/0/quick_edit"
    assert_response :not_found
  end

  test "quick edit refuses an issue of another project" do
    other_issue = Issue.generate!(project: Project.find(1))

    sign_in_as("jsmith")
    get quick_edit_path(other_issue)
    assert_response :not_found
  end

  test "the plus shows only on open stages and only for a viewer who may add issues" do
    closed_version = Version.generate!(project: @project, name: "Shipped", effective_date: Date.new(2026, 1, 1))
    Issue.generate!(project: @project, fixed_version: closed_version, author: @manager)
    closed_version.update!(status: "closed")
    revoke_adding_from_developers

    sign_in_as("jsmith")
    get progress_path
    assert_select "a.rubylode-progress-add[href=?]", new_issue_path, count: 1
    assert_select "a.rubylode-progress-add[href=?]", new_issue_path(closed_version), count: 0
    assert_select "a.rubylode-progress-add[title][aria-label][data-remote=true]", count: 1

    post "/logout"
    sign_in_as("dlopper")
    get progress_path
    assert_response :success
    assert_select "a.rubylode-progress-add", count: 0
  end

  test "the plus disappears for a locked version too" do
    @open_version.update!(status: "locked")

    sign_in_as("jsmith")
    get progress_path
    assert_select "a.rubylode-progress-add", count: 0
  end

  test "a new issue from a stage lands in that version and returns to the Progress page" do
    sign_in_as("jsmith")
    get new_issue_path, params: { filter: "needs_you" }
    assert_response :success

    assert_select "form[action=?][method=post]", "/projects/#{@project.identifier}/issues"
    assert_select "input[name='issue[fixed_version_id]'][type=hidden][value=?]", @open_version.id.to_s
    assert_select "select[name='issue[tracker_id]'] option"
    assert_select "input[name='issue[subject]']"
    assert_select "textarea[name='issue[description]']"
    assert_select "select[name='issue[assigned_to_id]']"
    back_url = css_select("input[name=back_url]").first["value"]
    assert_equal progress_path("needs_you"), back_url

    assert_difference "Issue.count", 1 do
      post "/projects/#{@project.identifier}/issues",
           params: { issue: { tracker_id: 1, subject: "Added from the stage", fixed_version_id: @open_version.id },
                     back_url: back_url }
    end
    assert_redirected_to progress_path("needs_you")
    assert_equal @open_version, Issue.order(:id).last.fixed_version
  end

  test "the new issue modal answers a script request" do
    sign_in_as("jsmith")
    get new_issue_path, xhr: true

    assert_response :success
    assert_includes response.body, "showModal('ajax-modal', '600px')"
    assert_includes response.body, ".ui-widget-overlay", "a click outside the modal closes it"
  end

  test "a required custom field sends the plus to Redmine's full new-issue form" do
    IssueCustomField.generate!(name: "Customer code", field_format: "string", is_required: true,
                               is_for_all: true, tracker_ids: Tracker.pluck(:id))

    sign_in_as("jsmith")
    get progress_path
    assert_select "a.rubylode-progress-add" do |links|
      uri = URI.parse(links.first["href"])
      assert_equal "/projects/#{@project.identifier}/issues/new", uri.path
      query = Rack::Utils.parse_nested_query(uri.query)
      assert_equal @open_version.id.to_s, query["issue"]["fixed_version_id"]
      assert_equal progress_path, query["back_url"]
      assert_nil links.first["data-remote"]
    end

    get new_issue_path
    assert_response :redirect
    assert_match %r{/projects/#{@project.identifier}/issues/new}, response.location
  end

  test "a field the workflow requires on a new issue sends the plus to Redmine's full new-issue form" do
    Tracker.find_each do |tracker|
      WorkflowPermission.create!(role_id: MANAGER_ROLE_ID, tracker_id: tracker.id, old_status_id: tracker.default_status_id,
                                 field_name: "category_id", rule: "required")
    end

    sign_in_as("jsmith")
    get progress_path
    assert_select "a.rubylode-progress-add[href^=?]", "/projects/#{@project.identifier}/issues/new"
  end

  test "a required custom field with a default does not send the plus away" do
    IssueCustomField.generate!(name: "Customer code", field_format: "string", is_required: true, is_for_all: true,
                               default_value: "internal", tracker_ids: Tracker.pluck(:id))

    sign_in_as("jsmith")
    get progress_path
    assert_select "a.rubylode-progress-add[href=?]", new_issue_path
  end

  test "the new issue modal refuses a closed version, a viewer who may not add, and a version that is not a stage" do
    closed_version = Version.generate!(project: @project, name: "Shipped", effective_date: Date.new(2026, 1, 1))
    Issue.generate!(project: @project, fixed_version: closed_version, author: @manager)
    closed_version.update!(status: "closed")
    foreign_version = Version.generate!(project: Project.find(1), name: "Elsewhere")
    revoke_adding_from_developers

    sign_in_as("jsmith")
    get new_issue_path(closed_version)
    assert_response :forbidden
    get new_issue_path(foreign_version)
    assert_response :not_found

    post "/logout"
    sign_in_as("dlopper")
    get new_issue_path
    assert_response :forbidden
  end

  test "a viewer without the plugin's permission cannot open either modal" do
    Role.find(DEVELOPER_ROLE_ID).remove_permission!(:view_rubylode_progress)

    sign_in_as("dlopper")
    get quick_edit_path
    assert_response :forbidden
    get quick_edit_path, xhr: true
    assert_response :forbidden
    get new_issue_path
    assert_response :forbidden
    get new_issue_path, xhr: true
    assert_response :forbidden
  end
end
