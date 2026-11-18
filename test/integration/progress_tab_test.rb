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

class ProgressTabTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses

  def setup
    @project = Project.find(1)
    @project.enable_module!(:rubylode_progress)
    @member_role = Role.find(1)
    @member_role.add_permission!(:view_rubylode_progress)
  end

  def progress_path
    "/projects/#{@project.identifier}/progress"
  end

  test "a member with View progress sees the tab" do
    log_user("jsmith", "jsmith")
    get progress_path
    assert_response :success
    assert_select "#main-menu a.selected", text: "Progress"
    assert_select "h2", text: @project.name
  end

  test "a signed-in non-member of a private project gets 403" do
    private_project = Project.find(5)
    private_project.enable_module!(:rubylode_progress)
    assert_not private_project.is_public?
    log_user("dlopper", "foo")
    get "/projects/#{private_project.identifier}/progress"
    assert_response :forbidden
  end

  test "with the module disabled the tab is gone and the page answers 403" do
    @project.disable_module!(:rubylode_progress)
    log_user("jsmith", "jsmith")
    get "/projects/#{@project.identifier}"
    assert_response :success
    assert_select "#main-menu a", text: "Progress", count: 0
    get progress_path
    assert_response :forbidden
  end

  test "an anonymous visitor follows Redmine's rules" do
    assert @project.is_public?
    Role.anonymous.remove_permission!(:view_rubylode_progress)
    get progress_path
    assert_redirected_to %r{/login}

    Role.anonymous.add_permission!(:view_rubylode_progress)
    get progress_path
    assert_response :success
  end
end
