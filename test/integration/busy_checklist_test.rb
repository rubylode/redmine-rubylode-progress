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

# Slice 19, steps 4 to 7: the checklist lists a few issues per section with "Show more", the assignee, tracker and category
# selects, shorter notes, and the Behind notice that names at most three stages.
class BusyChecklistTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  CLOSED_STATUS_ID = 5
  PROJECT_PAGE_QUERY_CEILING = 51 # the same ceiling as QueryCountTest

  setup do
    @manager = User.find(2)
    @colleague = User.find(3)
    Role.find(1).add_permission!(:view_rubylode_progress)
    Role.find(2).add_permission!(:view_rubylode_progress)
    log_user("jsmith", "jsmith")
  end

  # One current version holding issue_count issues, spread over two people, two trackers and a category.
  def build_project(issue_count, name: "Wide")
    project = Project.generate!(name: name, is_public: false)
    project.enable_module!(:rubylode_progress)
    project.enable_module!(:issue_tracking)
    project.trackers = Tracker.where(id: [1, 2])
    User.add_to_project(@manager, project, Role.find(1))
    User.add_to_project(@colleague, project, Role.find(2))
    @category = IssueCategory.create!(project: project, name: "Plumbing")
    @version = Version.generate!(project: project, name: "Only stage", effective_date: Date.new(2031, 1, 1))
    @issues = Array.new(issue_count) do |index|
      Issue.generate!(project: project, fixed_version: @version, author: @manager, subject: format("Row %03d", index + 1),
                      tracker_id: index.even? ? 1 : 2, assigned_to: index % 3 == 0 ? @colleague : nil,
                      category: index % 5 == 0 ? @category : nil)
    end
    project
  end

  def progress_path(project) = "/projects/#{project.identifier}/progress"

  def row_subjects = css_select(".rubylode-progress-row__title").map { |node| node.text.strip }

  test "a section lists its first 10 issues, counts all of them and offers Show more" do
    project = build_project(25)

    get progress_path(project)

    assert_response :success
    assert_equal 10, css_select(".rubylode-progress-row").size
    assert_select ".rubylode-progress-section__tally", text: "25 open"
    assert_select "a.rubylode-progress-show-more", text: "Show 15 more"
    assert_select ".rubylode-progress-row__title", text: /Row 011/, count: 0
    assert_select "a.rubylode-progress-show-more[href=?]", "#{progress_path(project)}?expand=#{@version.id}&filter=open"
    assert_select "a.rubylode-progress-show-more[data-checklist-path=?]", "#{progress_path(project)}/checklist?expand=#{@version.id}&filter=open"
  end

  test "expand lists that section in full without a script, and an unknown key shows nothing extra" do
    project = build_project(25)

    get progress_path(project), params: { expand: @version.id.to_s }
    assert_equal 25, css_select(".rubylode-progress-row").size
    assert_select "a.rubylode-progress-show-more", count: 0

    ["999999", "none", "../etc", ""].each do |unknown|
      get progress_path(project), params: { expand: unknown }
      assert_response :success
      assert_equal 10, css_select(".rubylode-progress-row").size, unknown
    end
    get progress_path(project), params: { expand: ["x"] }
    assert_response :success
    assert_equal 10, css_select(".rubylode-progress-row").size
  end

  test "the checklist route swaps one panel and honours expand" do
    project = build_project(25)

    get "#{progress_path(project)}/checklist", params: { expand: @version.id.to_s }

    assert_response :success
    assert_equal 25, css_select(".rubylode-progress-row").size
    assert_select "details.rubylode-progress-section[data-section-key=?]", @version.id.to_s
  end

  test "the rows per section are a project setting with a plugin-wide default, and the first response drops the rest" do
    project = build_project(25)
    get progress_path(project)
    full_size = response.body.bytesize

    RubylodeProgress::ProjectSetting.create!(project: project, checklist_rows_per_section: 5)
    get progress_path(project)
    assert_equal 5, css_select(".rubylode-progress-row").size
    assert_select "a.rubylode-progress-show-more", text: "Show 20 more"
    assert_operator response.body.bytesize, :<, full_size

    RubylodeProgress::ProjectSetting.where(project_id: project.id).update_all(checklist_rows_per_section: nil)
    with_settings(plugin_redmine_rubylode_progress: RubylodeProgress::Settings::DEFAULTS.merge("checklist_rows_per_section" => "30")) do
      get progress_path(project)
      assert_equal 25, css_select(".rubylode-progress-row").size
      assert_select "a.rubylode-progress-show-more", count: 0
    end
  end

  test "the project tab saves the rows per section and refuses a number out of range" do
    project = build_project(2)
    Role.find(1).add_permission!(:edit_project)

    patch "/projects/#{project.identifier}/progress/settings", params: { rubylode_progress_project_setting: { checklist_rows_per_section: "7" } }
    assert_equal 7, RubylodeProgress::ProjectSetting.for(project).checklist_rows_per_section

    patch "/projects/#{project.identifier}/progress/settings", params: { rubylode_progress_project_setting: { checklist_rows_per_section: "500" } }
    assert_equal 7, RubylodeProgress::ProjectSetting.for(project).checklist_rows_per_section

    get "/projects/#{project.identifier}/settings/rubylode_progress"
    assert_select "input[name=?][value=?]", "rubylode_progress_project_setting[checklist_rows_per_section]", "7"
  end

  test "the three selects offer any first, then the values that occur, with counts" do
    project = build_project(10)

    get progress_path(project)

    assert_select "select[name=assignee] option:first-child[value=any]", text: "Any assignee"
    assert_select "select[name=assignee] option", text: "Dave Lopper (4)"
    assert_select "select[name=assignee] option[value=none]", text: "Unassigned (6)"
    assert_select "select[name=tracker] option", count: 3
    assert_select "select[name=category] option[value=?]", @category.id.to_s, text: "Plumbing (2)"
    assert_select "select[name=category] option[value=none]"
  end

  test "choosing one narrows the checklist and the pill counts together, and not the stage list or the track" do
    project = build_project(10)
    get progress_path(project)
    stages_before = css_select(".rubylode-progress-stage").size
    track_before = css_select(".rubylode-progress-track__stage").size

    get progress_path(project), params: { assignee: @colleague.id.to_s, tracker: "1" }

    assert_response :success
    assert_equal ["Row 001", "Row 007"], row_subjects
    assert_select ".rubylode-progress-filter[data-filter-name=open] .rubylode-progress-filter__count", text: "2"
    assert_select ".rubylode-progress-filter[data-filter-name=all] .rubylode-progress-filter__count", text: "2"
    assert_select ".rubylode-progress-checklist__count", text: "2 issues"
    assert_select "select[name=assignee] option[selected][value=?]", @colleague.id.to_s
    assert_equal stages_before, css_select(".rubylode-progress-stage").size
    assert_equal track_before, css_select(".rubylode-progress-track__stage").size
  end

  test "a stale or unknown value falls back to any, never an error" do
    project = build_project(6)

    get progress_path(project), params: { assignee: "99999", tracker: "abc", category: ["1"] }

    assert_response :success
    assert_equal 6, css_select(".rubylode-progress-row").size
    assert_select "select[name=assignee] option[selected][value=any]"
  end

  test "the chosen values stay in the filter and grouping links and the issue query link, and none means Redmine's none" do
    project = build_project(10)

    get progress_path(project), params: { assignee: "none", tracker: "2" }

    assert_select ".rubylode-progress-filter[data-filter-name=done][href*=?]", "assignee=none"
    assert_select ".rubylode-progress-filter[data-filter-name=done][href*=?]", "tracker=2"
    assert_select ".rubylode-progress-group__button[data-checklist-path*=?]", "tracker=2"
    href = css_select("a.rubylode-progress-issue-query").first["href"]
    assert_includes href, "tracker_id"
    assert_includes href, "assigned_to_id"
    assert_includes CGI.unescape(href), "op[assigned_to_id]=!*"
  end

  test "the assignees offered come only from issues the viewer may see" do
    project = build_project(3)
    Member.where(project_id: project.id, user_id: @manager.id).first.update!(role_ids: [Role.find(2).id])
    hidden = Issue.generate!(project: project, fixed_version: @version, author: @colleague, assigned_to: @colleague, is_private: true)
    Issue.where(id: @issues.map(&:id)).update_all(assigned_to_id: nil)

    get progress_path(project)

    assert_response :success
    assert_select "select[name=assignee] option", text: /Dave Lopper/, count: 0
    assert_select ".rubylode-progress-row__title", text: /#{Regexp.escape(hidden.subject)}/, count: 0
  end

  test "a long note is cut with a show note details; a short one is not" do
    project = build_project(2)
    long_text = "word " * 60
    @issues[0].init_journal(@manager, long_text)
    @issues[0].save!
    @issues[1].init_journal(@manager, "Short note")
    @issues[1].save!

    get progress_path(project)

    assert_select ".rubylode-progress-row__note-more", count: 1
    assert_select ".rubylode-progress-row__note-more summary", text: "show note"
    assert_select ".rubylode-progress-row__note-full", text: long_text[0, RubylodeProgress::ItemNotes::NOTE_LENGTH].strip
    assert_select ".rubylode-progress-row__note", text: "Short note"
  end

  test "the Behind notice names at most three stages" do
    project = Project.generate!(name: "Late", is_public: false)
    project.enable_module!(:rubylode_progress)
    project.enable_module!(:issue_tracking)
    User.add_to_project(@manager, project, Role.find(1))
    5.times do |index|
      version = Version.generate!(project: project, name: "Late #{index + 1}", effective_date: Date.new(2024, 1 + index, 1))
      Issue.generate!(project: project, fixed_version: version, author: @manager, status_id: CLOSED_STATUS_ID)
      Issue.generate!(project: project, fixed_version: version, author: @manager)
      version.update!(status: "closed")
    end

    get progress_path(project)

    text = css_select(".rubylode-progress-notice--behind").first.text.squish
    assert_includes text, "Late 1 is"
    assert_includes text, "Also behind: Late 2, Late 3, and 2 more"
    assert_not_includes text, "Late 4"
  end

  test "the query count does not grow with the issues, narrowed or not" do
    small = build_project(30, name: "Small")
    get progress_path(small)
    small_count = QueryCounter.count { get progress_path(small), params: { tracker: "1" } }
    large = build_project(150, name: "Large")
    get progress_path(large)
    large_count = QueryCounter.count { get progress_path(large), params: { tracker: "1" } }

    assert_operator large_count, :<=, PROJECT_PAGE_QUERY_CEILING
    assert_equal small_count, large_count
  end
end
