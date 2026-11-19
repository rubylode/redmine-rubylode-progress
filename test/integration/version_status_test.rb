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

class VersionStatusTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  DEVELOPER_ROLE_ID = 2
  MANAGER_ROLE_ID = 1

  setup do
    @manager = User.find(2)
    @developer = User.find(3)
    @project = Project.generate!(is_public: false)
    @project.enable_module!(:rubylode_progress)
    @project.enable_module!(:issue_tracking)
    Role.find(MANAGER_ROLE_ID).add_permission!(:view_rubylode_progress, :manage_versions)
    Role.find(DEVELOPER_ROLE_ID).add_permission!(:view_rubylode_progress)
    Role.find(DEVELOPER_ROLE_ID).remove_permission!(:manage_versions)
    User.add_to_project(@manager, @project, Role.find(MANAGER_ROLE_ID))
    User.add_to_project(@developer, @project, Role.find(DEVELOPER_ROLE_ID))
    @open_version = Version.generate!(project: @project, name: "Framing", effective_date: Date.new(2026, 1, 1))
    @locked_version = Version.generate!(project: @project, name: "Lighting", effective_date: Date.new(2026, 2, 1))
    @closed_version = Version.generate!(project: @project, name: "Shipped", effective_date: Date.new(2025, 12, 1))
    Issue.generate!(project: @project, fixed_version: @open_version, author: @manager)
    Issue.generate!(project: @project, fixed_version: @locked_version, author: @manager)
    Issue.generate!(project: @project, fixed_version: @closed_version, author: @manager, status_id: 5)
    @locked_version.update!(status: "locked")
    @closed_version.update!(status: "closed")
  end

  def progress_path(query = "")
    "/projects/#{@project.identifier}/progress#{query}"
  end

  def status_path(version = @open_version, query = "")
    "/projects/#{@project.identifier}/progress/versions/#{version.id}/status#{query}"
  end

  def sign_in_as(login)
    log_user(login, login == "dlopper" ? "foo" : login)
  end

  test "the status tag is a button only for a viewer who may manage the version's project; others see a plain tag on closed and locked stages and nothing on open ones" do
    sign_in_as("jsmith")
    get progress_path
    assert_response :success
    assert_select "a.rubylode-progress-status-button", count: 3
    assert_select "a.rubylode-progress-status-button[href=?]", status_path(@open_version), text: "open"
    assert_select "a.rubylode-progress-status-button[href=?]", status_path(@locked_version), text: "locked"
    assert_select "a.rubylode-progress-status-button[href=?]", status_path(@closed_version), text: "closed"
    assert_select "a.rubylode-progress-status-button[title=?][aria-label][data-remote=true]",
                  "Change the status of Framing", count: 1
    assert_select "a.rubylode-progress-status-button[aria-label*=Framing][aria-label*=open]", count: 1

    post "/logout"
    sign_in_as("dlopper")
    get progress_path
    assert_response :success
    assert_select "a.rubylode-progress-status-button", count: 0
    assert_select "span.rubylode-progress-stage__tag", count: 2
    assert_select "span.rubylode-progress-stage__tag", text: "closed", count: 1
    assert_select "span.rubylode-progress-stage__tag", text: "locked", count: 1
  end

  test "the status modal answers for a stage and refuses a viewer without manage_versions (403) and a version that is not a stage (404)" do
    other_project = Project.generate!(is_public: true)
    foreign_version = Version.generate!(project: other_project, name: "Elsewhere")

    sign_in_as("jsmith")
    get status_path(@open_version), xhr: true
    assert_response :success
    assert_includes response.body, "#ajax-modal"
    assert_includes response.body, "showModal('ajax-modal', '600px')"
    assert_includes response.body, ".ui-widget-overlay"
    get status_path(@closed_version)
    assert_response :success
    get status_path(foreign_version)
    assert_response :not_found
    get "/projects/#{@project.identifier}/progress/versions/0/status"
    assert_response :not_found

    post "/logout"
    sign_in_as("dlopper")
    get status_path(@open_version), xhr: true
    assert_response :forbidden
    get status_path(@open_version)
    assert_response :forbidden
    get status_path(foreign_version)
    assert_response :not_found
  end

  test "the modal offers the three statuses with the current one selected and posts to Redmine's version update with a back_url to the Progress page" do
    sign_in_as("jsmith")
    get status_path(@locked_version, "?filter=all"), params: { back_url: "https://evil.example/steal" }
    assert_response :success

    assert_select "form[action=?][method=post]", "/versions/#{@locked_version.id}"
    assert_select "input[name=_method][value=put]"
    assert_select "input[type=radio][name='version[status]']", count: 3
    assert_select "input[type=radio][name='version[status]'][checked]", count: 1
    assert_select "input[type=radio][name='version[status]'][value=locked][checked]", count: 1
    %w[open locked closed].each do |status|
      assert_select "input[type=radio][name='version[status]'][value=?]", status
    end
    assert_select "h3.title", text: /Lighting/
    assert_equal progress_path("?filter=all"), css_select("input[name=back_url]").first["value"]
  end

  test "an unknown filter or grouping is replaced, never copied into the return address" do
    sign_in_as("jsmith")
    get status_path(@open_version, "?filter=javascript:alert(1)&group=bogus")

    assert_equal progress_path("?filter=open"), css_select("input[name=back_url]").first["value"]
  end

  test "after Redmine's update the stage shows its new status, and a reopened stage becomes a drop target" do
    sign_in_as("jsmith")
    get progress_path
    assert_select ".rubylode-progress-stage[data-version-id=?]", @closed_version.id.to_s, count: 0

    get status_path(@closed_version, "?filter=all")
    back_url = css_select("input[name=back_url]").first["value"]
    put "/versions/#{@closed_version.id}", params: { version: { status: "open" }, back_url: back_url }
    assert_redirected_to progress_path("?filter=all")
    assert_equal "open", @closed_version.reload.status

    follow_redirect!
    assert_select ".rubylode-progress-stage[data-version-id=?]", @closed_version.id.to_s, count: 1
    assert_select "a.rubylode-progress-status-button[href=?]", status_path(@closed_version), text: "open"
  end

  test "a viewer without manage_versions cannot change the status through the plugin's form either" do
    sign_in_as("dlopper")
    put "/versions/#{@open_version.id}", params: { version: { status: "closed" } }

    assert_response :forbidden
    assert_equal "open", @open_version.reload.status
  end

  test "the button follows the viewer's right with the rail cached" do
    original_caching = ActionController::Base.perform_caching
    original_store = ActionController::Base.cache_store
    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new

    sign_in_as("jsmith")
    get progress_path
    assert_select "a.rubylode-progress-status-button", count: 3

    Role.find(MANAGER_ROLE_ID).remove_permission!(:manage_versions)
    get progress_path
    assert_select "a.rubylode-progress-status-button", count: 0
  ensure
    ActionController::Base.perform_caching = original_caching
    ActionController::Base.cache_store = original_store
  end
end
