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

class FiltersTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers, :user_preferences

  CLOSED_STATUS_ID = 5
  DEVELOPER_ROLE_ID = 2
  MANAGER_ROLE_ID = 1

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
    version = Version.generate!(project: @project, name: "Build", effective_date: Date.new(2026, 2, 15))
    Issue.generate!(project: @project, fixed_version: version, author: @manager, subject: "Finished thing",
                    status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: @project, fixed_version: version, author: @manager, subject: "Mine to do",
                    assigned_to: @manager)
    Issue.generate!(project: @project, fixed_version: version, author: @manager, subject: "Someone else's thing",
                    assigned_to: @developer)
  end

  def progress_path(query = "")
    "/projects/#{@project.identifier}/progress#{query}"
  end

  def sign_in(login)
    log_user(login, login == "jsmith" ? login : "foo")
  end

  def stored_filter(user)
    User.find(user.id).pref[RubylodeProgress::ChecklistFilter::PREFERENCE_KEY]
  end

  test "?filter=done shows only done rows and presses Done" do
    sign_in("jsmith")
    get progress_path("?filter=done")

    assert_response :success
    assert_select ".rubylode-progress-row", count: 1
    assert_select ".rubylode-progress-row", text: /Finished thing/
    assert_select "[data-filter-name=done][aria-pressed=true]"
    assert_select ".rubylode-progress-filter[aria-pressed=true]", count: 1
  end

  test "an unknown filter in the address shows Open" do
    sign_in("jsmith")
    get progress_path("?filter=nonsense")

    assert_select "[data-filter-name=open][aria-pressed=true]"
    assert_select ".rubylode-progress-row", text: /Finished thing/, count: 0
    assert_select ".rubylode-progress-row", text: /Mine to do/
  end

  test "choosing a filter is remembered for the next visit without a parameter" do
    sign_in("jsmith")
    get progress_path("?filter=needs_you")
    get progress_path

    assert_select "[data-filter-name=needs_you][aria-pressed=true]"
    assert_select ".rubylode-progress-row", count: 1
    assert_select ".rubylode-progress-row", text: /Mine to do/
  end

  test "two people keep their own filters" do
    sign_in("jsmith")
    get progress_path("?filter=done")
    assert_equal "done", stored_filter(@manager)
    assert_nil stored_filter(@developer)

    post "/logout"
    sign_in("dlopper")
    get progress_path("?filter=all")

    assert_equal "all", stored_filter(@developer)
    assert_equal "done", stored_filter(@manager)
  end

  test "an anonymous visitor can filter and nothing is stored" do
    @project.update!(is_public: true)
    Role.anonymous.add_permission!(:view_rubylode_progress)
    Role.anonymous.add_permission!(:view_issues)
    preference_count = UserPreference.count

    get progress_path("?filter=all")

    assert_response :success
    assert_select "[data-filter-name=all][aria-pressed=true]"
    assert_equal preference_count, UserPreference.count
  end

  test "a remembered filter that no longer exists falls back to Open" do
    pref = @manager.pref
    pref[RubylodeProgress::ChecklistFilter::PREFERENCE_KEY] = "waiting"
    pref.save!

    sign_in("jsmith")
    get progress_path

    assert_select "[data-filter-name=open][aria-pressed=true]"
    assert_equal "waiting", stored_filter(@manager)
  end

  test "the checklist route returns the checklist alone, without the layout, and checks the permission" do
    sign_in("jsmith")
    get progress_path("/checklist?filter=done")

    assert_response :success
    assert_no_match(/<html|<head|id="main"/, response.body)
    assert_select ".rubylode-progress-checklist .rubylode-progress-row", count: 1

    post "/logout"
    sign_in("rhill")
    get progress_path("/checklist?filter=done")
    assert_response :forbidden
  end

  test "the page loads the filter script as a module and the import map names what it imports" do
    sign_in("jsmith")
    get progress_path

    assert_select "script[type=module][src*=progress_filters]"
    assert_select "script[type=importmap]" do |maps|
      assert_includes maps.first.text, "@hotwired/stimulus"
      assert_includes maps.first.text, "controllers/application"
    end
  end
end
