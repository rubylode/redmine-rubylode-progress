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

class QueryCountTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  CLOSED_STATUS_ID = 5

  # What a project page costs once the preloads are in, whatever the issue count: 49 statements, measured on 2026-11-19 (45 before the edit and add controls, 48 before the author preload).
  # Redmine's own request: the session user and their preferences, the settings (read a few times each), the project, its
  # modules, memberships and roles, the menu's module and tracker checks (wiki, boards, repositories). The plugin's:
  # the project's setting row, the viewer's group ids, the project tree, the versions (own and shared), the issues, then
  # one preload each for statuses, priorities, assignees (users and groups), versions, relations, parents, custom values
  # and their fields, and one for the latest notes. The edit and add controls added three, none per issue: the project's
  # trackers, one query for required custom fields and one for workflow-required fields across all the trackers (the
  # issues' projects load in one preload with the rest). The owner's revisions added one, the issues' authors, again one
  # preload for all of them.
  PROJECT_PAGE_QUERY_CEILING = 49

  setup do
    @manager = User.find(2)
    Role.find(1).add_permission!(:view_rubylode_progress)
    @group = Group.generate!
    @group.users << User.find(3)
    Setting.issue_group_assignment = "1"
  end

  def build_project(issue_count, name: "Counted")
    project = Project.generate!(name: name, is_public: false)
    project.enable_module!(:rubylode_progress)
    project.enable_module!(:issue_tracking)
    User.add_to_project(@manager, project, Role.find(1))
    Member.create!(project: project, principal: @group, roles: [Role.find(2)])
    versions = [Version.generate!(project: project, name: "One", effective_date: Date.new(2026, 1, 1)),
                Version.generate!(project: project, name: "Two", effective_date: Date.new(2026, 2, 1))]
    issues = Array.new(issue_count) do |index|
      Issue.generate!(project: project, fixed_version: versions[index % 2], author: @manager,
                      assigned_to: (index.even? ? @group : @manager),
                      status_id: (index % 3 == 0 ? CLOSED_STATUS_ID : 1))
    end
    issues.each_cons(2) { |first, second| IssueRelation.create!(issue_from: first, issue_to: second, relation_type: "blocks") }
    issues.each { |issue| issue.init_journal(@manager, "A note"); issue.save! }
    project
  end

  def queries_for_all_projects_page
    get "/progress"
    assert_response :success
    QueryCounter.count { get "/progress" }
  end

  def queries_for_progress_page(project)
    get "/projects/#{project.identifier}/progress"
    assert_response :success
    QueryCounter.count { get "/projects/#{project.identifier}/progress" }
  end

  test "the project page runs the same number of queries for 5 issues as for 50" do
    log_user("jsmith", "jsmith")
    few = queries_for_progress_page(build_project(5, name: "Few"))
    many = queries_for_progress_page(build_project(50, name: "Many"))

    assert_equal few, many
    assert_select ".rubylode-progress-step", count: 50
    assert_operator many, :<=, PROJECT_PAGE_QUERY_CEILING
  end

  test "the cross-project page runs the same number of queries per project whatever the issue count" do
    log_user("jsmith", "jsmith")
    small_projects = [build_project(5, name: "Small one"), build_project(5, name: "Small two")]
    few = queries_for_all_projects_page
    small_projects.each { |project| Member.where(project_id: project.id).delete_all }
    build_project(50, name: "Large one")
    build_project(50, name: "Large two")
    many = queries_for_all_projects_page

    assert_equal few, many
    assert_select ".rubylode-progress-compact-tracker", count: 2
  end
end
