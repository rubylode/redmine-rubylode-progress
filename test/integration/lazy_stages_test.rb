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

# Slice 20: a folded stage renders its summary only, and its issues load when it is opened.
class LazyStagesTest < Redmine::IntegrationTest
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

  # Two finished stages, a current one (one closed, one open issue) and an upcoming one.
  def build_project(name: "Lazy", upcoming_issues: 3)
    @project = Project.generate!(name: name, is_public: false)
    @project.enable_module!(:rubylode_progress)
    @project.enable_module!(:issue_tracking)
    User.add_to_project(@manager, @project, Role.find(1))
    User.add_to_project(@developer, @project, Role.find(2))
    @finished = Array.new(2) do |index|
      version = Version.generate!(project: @project, name: "Finished #{index + 1}", effective_date: Date.new(2025, 1, 1) >> index)
      2.times { |count| Issue.generate!(project: @project, fixed_version: version, author: @manager, status_id: CLOSED_STATUS_ID, subject: "Finished #{index + 1} issue #{count + 1}") }
      version.update!(status: "closed")
      version
    end
    @current = Version.generate!(project: @project, name: "Current stage", effective_date: Date.new(2031, 1, 1))
    Issue.generate!(project: @project, fixed_version: @current, author: @manager, status_id: CLOSED_STATUS_ID, subject: "Current closed issue")
    @current_open_issue = Issue.generate!(project: @project, fixed_version: @current, author: @manager, subject: "Current open issue")
    @upcoming = Version.generate!(project: @project, name: "Upcoming stage", effective_date: Date.new(2031, 2, 1))
    upcoming_issues.times do |count|
      Issue.generate!(project: @project, fixed_version: @upcoming, author: @developer, subject: "Upcoming issue #{count + 1}")
    end
    @project
  end

  def progress_path = "/projects/#{@project.identifier}/progress"

  def stage_issues_path(version) = "#{progress_path}/stages/#{version.id}/issues"

  def open_stage_link_query(version)
    link = css_select("details[data-lazy-issues-path='#{stage_issues_path(version)}'] a.rubylode-progress-stage__lazy-link").first
    assert link
    Rack::Utils.parse_query(URI.parse(link["href"]).query)
  end

  test "the first response holds the issues of the current stage and none of the folded stages" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path

    assert_response :success
    assert_select ".rubylode-progress-stage .rubylode-progress-steps a.rubylode-progress-item-link", text: "Current open issue"
    assert_select ".rubylode-progress-stage .rubylode-progress-steps a.rubylode-progress-item-link", text: /Upcoming issue/, count: 0
    assert_select ".rubylode-progress-stage .rubylode-progress-steps a.rubylode-progress-item-link", text: /Finished/, count: 0
    assert_select "details.rubylode-progress-stage[data-lazy-issues-path]", count: 3
    assert_select "details.rubylode-progress-stage[data-lazy-issues-path][open]", count: 0
  end

  test "each folded stage carries its lazy path and a plain link that opens it without a script" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path

    assert_select "details.rubylode-progress-stage[data-lazy-issues-path=?]", stage_issues_path(@upcoming), count: 1
    assert_select "details[data-lazy-issues-path=?] a[href^=?]", stage_issues_path(@upcoming), "#{progress_path}?", text: "Show the 3 issues"
    assert_equal @upcoming.id.to_s, open_stage_link_query(@upcoming)["open_stage"]
    assert_select "details[data-lazy-issues-path=?] a", stage_issues_path(@finished.first), text: "Show the 2 issues"
    assert_select "details.rubylode-progress-stage[data-lazy-issues-path=?]", stage_issues_path(@current), count: 0
  end

  test "a folded stage's summary stays complete without its issues" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path

    assert_select "details[data-lazy-issues-path=?] > summary .rubylode-progress-stage__name", stage_issues_path(@upcoming), text: "Upcoming stage"
    assert_select "details[data-lazy-issues-path=?] > summary .rubylode-progress-meter", stage_issues_path(@upcoming), count: 1
    assert_select "details[data-lazy-issues-path=?] > summary .rubylode-progress-stage__summary", stage_issues_path(@upcoming), text: /3/
  end

  test "the link keeps the filter and the grouping, and drops anything else" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { filter: "all", group: "status", stranger: "x" }

    query = open_stage_link_query(@upcoming)
    assert_equal "all", query["filter"]
    assert_equal @upcoming.id.to_s, query["open_stage"]
    assert_nil query["stranger"]
  end

  test "the issues route answers a stage's list without the page around it" do
    build_project
    log_user("jsmith", "jsmith")

    get stage_issues_path(@upcoming)

    assert_response :success
    assert_not_includes response.body, "<html"
    assert_select "ul.rubylode-progress-steps li.rubylode-progress-step", count: 3
    assert_select "a.rubylode-progress-item-link", text: "Upcoming issue 1"
  end

  test "the route renders the rows exactly as the eager stage does" do
    build_project
    log_user("jsmith", "jsmith")
    get progress_path
    eager_rows = css_select("details.rubylode-progress-stage[open] ul.rubylode-progress-steps li").map(&:to_s)
    assert_not_empty eager_rows

    get stage_issues_path(@current)

    assert_equal eager_rows, css_select("ul.rubylode-progress-steps li").map(&:to_s)
  end

  test "the route shows only the issues the viewer may see" do
    build_project
    Role.find(2).update!(issues_visibility: "own")
    @project.issues.where(fixed_version_id: @upcoming.id).first.update_columns(author_id: @manager.id)
    log_user("dlopper", "foo")

    get stage_issues_path(@upcoming)

    assert_response :success
    assert_select "li.rubylode-progress-step", count: 2
  end

  test "the route answers 404 for a version that is not a stage of the page" do
    build_project
    other_project = Project.generate!(is_public: false)
    stranger = Version.generate!(project: other_project, name: "Elsewhere")
    log_user("jsmith", "jsmith")

    get "#{progress_path}/stages/#{stranger.id}/issues"
    assert_response :not_found
    get "#{progress_path}/stages/0/issues"
    assert_response :not_found
  end

  test "the route answers 403 to a viewer without the plugin permission" do
    build_project
    Role.find(2).remove_permission!(:view_rubylode_progress)
    log_user("dlopper", "foo")

    get stage_issues_path(@upcoming)

    assert_response :forbidden
  end

  test "open_stage renders that stage open with its issues" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { open_stage: @upcoming.id }

    assert_response :success
    assert_select "details.rubylode-progress-stage[open]", count: 2
    assert_select "details[open] a.rubylode-progress-item-link", text: "Upcoming issue 1"
    assert_select "details[data-lazy-issues-path=?]", stage_issues_path(@upcoming), count: 0
    assert_select "details.rubylode-progress-stage[data-lazy-issues-path]", count: 2
  end

  test "open_stage for a stage inside the finished fold opens the fold too" do
    build_project
    RubylodeProgress::ProjectSetting.create!(project: @project, finished_stages_kept: 0)
    log_user("jsmith", "jsmith")

    get progress_path, params: { open_stage: @finished.first.id }

    assert_select "details.rubylode-progress-finished-fold[open]", count: 1
    assert_select "a.rubylode-progress-item-link", text: "Finished 1 issue 1"
  end

  test "an unknown, foreign or malformed open_stage changes nothing" do
    build_project
    log_user("jsmith", "jsmith")
    get progress_path
    expected = css_select("details.rubylode-progress-stage[open]").size

    ["0", "99999999", "abc", ""].each do |value|
      get progress_path, params: { open_stage: value }
      assert_response :success
      assert_select "details.rubylode-progress-stage[open]", count: expected
    end
    get "#{progress_path}?open_stage[]=1"
    assert_response :success
    assert_select "details.rubylode-progress-stage[open]", count: expected
  end

  test "the closed fold of the current stage holds no rows in the first response and carries its own lazy path" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path

    closed_path = "#{progress_path}/stages/#{@current.id}/closed_issues"
    assert_select "details.rubylode-progress-closed-fold[data-lazy-issues-path=?]", closed_path, count: 1
    assert_select "details.rubylode-progress-closed-fold a.rubylode-progress-item-link", count: 0
    assert_select "a.rubylode-progress-item-link", text: "Current closed issue", count: 0
  end

  test "the closed issues route answers the closed rows of a stage, and refuses what the page does not show" do
    build_project
    log_user("jsmith", "jsmith")

    get "#{progress_path}/stages/#{@current.id}/closed_issues"
    assert_response :success
    assert_not_includes response.body, "<html"
    assert_select "li.rubylode-progress-step", count: 1
    assert_select "a.rubylode-progress-item-link", text: "Current closed issue"

    other_project = Project.generate!(is_public: false)
    stranger = Version.generate!(project: other_project, name: "Elsewhere")
    get "#{progress_path}/stages/#{stranger.id}/closed_issues"
    assert_response :not_found

    Role.find(2).remove_permission!(:view_rubylode_progress)
    post "/logout"
    log_user("dlopper", "foo")
    get "#{progress_path}/stages/#{@current.id}/closed_issues"
    assert_response :forbidden
  end

  test "open_stage on the current stage lists its closed rows in the page too" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { open_stage: @current.id }

    assert_select "details.rubylode-progress-closed-fold[data-lazy-issues-path]", count: 0
    assert_select "details.rubylode-progress-closed-fold a.rubylode-progress-item-link", text: "Current closed issue"
  end

  test "the stage list does not grow with the issues in folded stages" do
    build_project(name: "Few lazy", upcoming_issues: 40)
    log_user("jsmith", "jsmith")
    get progress_path
    few = response.body.bytesize

    build_project(name: "Many lazy", upcoming_issues: 120)
    get progress_path
    many = response.body.bytesize

    assert_select "li.rubylode-progress-step", maximum: 12
    assert_operator many - few, :<, 400
  end
end
