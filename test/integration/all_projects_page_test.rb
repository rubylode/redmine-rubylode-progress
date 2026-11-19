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

class AllProjectsPageTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses

  CLOSED_STATUS_ID = 5

  setup do
    Role.find(1).add_permission!(:view_rubylode_progress)
    Role.find(2).add_permission!(:view_rubylode_progress)
    @manager = User.find(2)
    @developer = User.find(3)
    @project = Project.generate!(name: "Tracked project", is_public: false)
    @project.enable_module!(:rubylode_progress)
    User.add_to_project(@manager, @project, Role.find(1))
    User.add_to_project(@developer, @project, Role.find(2))
    @first_stage = Version.generate!(project: @project, name: "Alpha stage", effective_date: Date.today + 10)
    @second_stage = Version.generate!(project: @project, name: "Beta stage", effective_date: Date.today + 40)
  end

  test "each tracker links to the project's Progress tab and shows the percent and the current stage's name" do
    Issue.generate!(project: @project, fixed_version: @first_stage, status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: @project, fixed_version: @first_stage)
    Issue.generate!(project: @project, fixed_version: @second_stage)

    log_user("jsmith", "jsmith")
    get "/progress"

    assert_response :success
    assert_select ".rubylode-progress-compact-tracker" do
      assert_select "a[href=?]", "/projects/#{@project.identifier}/progress", text: "Tracked project"
      assert_select ".rubylode-progress-track__dot", count: 2
      assert_select ".rubylode-progress-tracker__percent", text: "25%"
      assert_select ".rubylode-progress-compact-tracker__stage", text: "Alpha stage"
    end
    assert_select "#top-menu a", text: "Progress"
  end

  test "a private project the viewer is not a member of is not listed" do
    other_project = Project.generate!(name: "Hidden project", is_public: false)
    other_project.enable_module!(:rubylode_progress)

    log_user("jsmith", "jsmith")
    get "/progress"

    assert_response :success
    assert_select "a", text: "Hidden project", count: 0
    assert_select "a", text: "Tracked project"
  end

  test "a private issue does not move another viewer's percent" do
    @second_stage.destroy
    Issue.generate!(project: @project, fixed_version: @first_stage, status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: @project, fixed_version: @first_stage, is_private: true, author: @manager)

    log_user("dlopper", "foo")
    get "/progress"
    assert_select ".rubylode-progress-tracker__percent", text: "100%"

    post "/logout"
    log_user("jsmith", "jsmith")
    get "/progress"
    assert_select ".rubylode-progress-tracker__percent", text: "50%"
  end

  test "someone with no such project gets 403 and sees no Progress link in the top menu" do
    Role.all.each { |role| role.remove_permission!(:view_rubylode_progress) }

    log_user("jsmith", "jsmith")
    get "/projects/#{Project.find(1).identifier}"
    assert_select "#top-menu a", text: "Progress", count: 0
    get "/progress"
    assert_response :forbidden
  end

  test "an anonymous visitor with no such project is sent to sign in" do
    Role.anonymous.remove_permission!(:view_rubylode_progress)
    Role.non_member.remove_permission!(:view_rubylode_progress)

    get "/progress"

    assert_redirected_to %r{/login}
  end

  test "a project with the module but no counted versions says nothing to track yet" do
    log_user("jsmith", "jsmith")
    @first_stage.destroy
    @second_stage.destroy
    get "/progress"

    assert_response :success
    assert_select ".rubylode-progress-compact-tracker", text: /Tracked project/ do
      assert_select ".rubylode-progress-compact-tracker__empty", text: /nothing to track yet/i
    end
  end
end
