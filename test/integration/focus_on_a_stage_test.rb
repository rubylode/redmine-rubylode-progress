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

# Slice 22: ?stage=<version id> narrows the page and its fragment routes to one stage.
class FocusOnAStageTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  CLOSED_STATUS_ID = 5

  setup do
    @manager = User.find(2)
    @developer = User.find(3)
    Role.find(1).add_permission!(:view_rubylode_progress)
    Role.find(2).add_permission!(:view_rubylode_progress)
    Role.find(2).remove_permission!(:edit_project)
  end

  # A current stage (one closed, one open issue) and an upcoming one (three open issues).
  def build_project
    @project = Project.generate!(name: "Focus", is_public: false)
    @project.enable_module!(:rubylode_progress)
    @project.enable_module!(:issue_tracking)
    User.add_to_project(@manager, @project, Role.find(1))
    User.add_to_project(@developer, @project, Role.find(2))
    @current = Version.generate!(project: @project, name: "Current stage", effective_date: Date.new(2031, 1, 1))
    Issue.generate!(project: @project, fixed_version: @current, author: @manager, status_id: CLOSED_STATUS_ID, subject: "Current closed issue")
    @current_open_issue = Issue.generate!(project: @project, fixed_version: @current, author: @manager, subject: "Current open issue")
    @upcoming = Version.generate!(project: @project, name: "Upcoming stage", effective_date: Date.new(2031, 2, 1))
    @upcoming_issues = Array.new(3) do |count|
      Issue.generate!(project: @project, fixed_version: @upcoming, author: @developer, subject: "Upcoming issue #{count + 1}")
    end
    @project
  end

  def progress_path = "/projects/#{@project.identifier}/progress"

  def checklist_path = "#{progress_path}/checklist"

  def checklist_row_ids = css_select("li.rubylode-progress-row").map { |row| row["id"] }

  test "the stage parameter narrows the checklist to that stage" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id }

    assert_response :success
    assert_equal @upcoming_issues.map { |issue| "rubylode-progress-item-#{issue.id}" }.sort, checklist_row_ids.sort
    assert_select ".rubylode-progress-checklist a.rubylode-progress-item-link", text: "Current open issue", count: 0
    assert_select ".rubylode-progress-checklist__count", text: /3/
  end

  test "the checklist route keeps the focus" do
    build_project
    log_user("jsmith", "jsmith")

    get checklist_path, params: { stage: @current.id, filter: "all" }

    assert_response :success
    assert_not_includes response.body, "<html"
    assert_select "a.rubylode-progress-item-link", text: "Current open issue"
    assert_select "a.rubylode-progress-item-link", text: "Current closed issue"
    assert_select "a.rubylode-progress-item-link", text: /Upcoming issue/, count: 0
  end

  test "a stage that is unknown, malformed or another project's is a 404 on the page and the checklist" do
    build_project
    stranger = Version.generate!(project: Project.generate!(is_public: false), name: "Elsewhere")
    log_user("jsmith", "jsmith")

    [progress_path, checklist_path].each do |path|
      ["999999", "abc", "12abc", "-1", stranger.id.to_s].each do |value|
        get path, params: { stage: value }
        assert_response :not_found, "#{path} stage=#{value}"
      end
      get "#{path}?stage[]=#{@upcoming.id}"
      assert_response :not_found, "#{path} stage[]"
      get "#{path}?stage[a]=#{@upcoming.id}"
      assert_response :not_found, "#{path} stage[a]"
    end
  end

  # A project's own version stays a stage for a viewer who sees none of its issues, so it is focusable and empty.
  test "a stage whose issues the viewer cannot see focuses on an empty checklist" do
    build_project
    Role.find(2).update!(issues_visibility: "own")
    @project.issues.where(fixed_version_id: @upcoming.id).update_all(author_id: @manager.id)
    log_user("dlopper", "foo")

    get progress_path, params: { stage: @upcoming.id }

    assert_response :success
    assert_equal [], checklist_row_ids
    assert_select "p.rubylode-progress-checklist__empty"
  end

  test "an empty stage parameter means no focus" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: "", filter: "all" }

    assert_response :success
    assert_select "a.rubylode-progress-item-link", text: "Current open issue"
    assert_select "a.rubylode-progress-item-link", text: "Current closed issue"
    assert_equal 5, checklist_row_ids.size
  end

  test "focus does not touch the remembered filter or the project's grouping" do
    build_project
    RubylodeProgress::ProjectSetting.create!(project: @project, checklist_grouping: "category")
    user = User.find(2)
    user.pref[RubylodeProgress::ChecklistFilter::PREFERENCE_KEY] = "open"
    user.pref.save
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id, group: "version" }
    get checklist_path, params: { stage: @upcoming.id, group: "parent" }

    assert_response :success
    assert_equal "open", User.find(2).pref[RubylodeProgress::ChecklistFilter::PREFERENCE_KEY]
    assert_equal "category", RubylodeProgress::ProjectSetting.find_by(project_id: @project.id).checklist_grouping
    assert_equal 1, css_select("ul.rubylode-progress-rows").size
  end

  test "a rejected focus does not write the remembered filter" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: "abc", filter: "done" }

    assert_response :not_found
    assert_nil User.find(2).pref[RubylodeProgress::ChecklistFilter::PREFERENCE_KEY]
  end

  test "focus with a filter that matches nothing shows the empty message" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id, filter: "done" }

    assert_response :success
    assert_select "p.rubylode-progress-checklist__empty", text: "No issues match this filter"
    assert_equal [], checklist_row_ids
  end
end
