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

# The owner's second pass over the demo (slice 17).
class SecondPassTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  CLOSED_STATUS_ID = 5
  IN_PROGRESS_STATUS_ID = 2
  WAITING_STATUS_ID = 4
  MANAGER_ROLE_ID = 1
  DEVELOPER_ROLE_ID = 2

  setup do
    @today = User.find(2).today
    @manager = User.find(2)
    @developer = User.find(3)
    @project = Project.generate!(is_public: false)
    @project.enable_module!(:rubylode_progress)
    @project.enable_module!(:issue_tracking)
    Role.find(MANAGER_ROLE_ID).add_permission!(:view_rubylode_progress)
    Role.find(DEVELOPER_ROLE_ID).add_permission!(:view_rubylode_progress)
    User.add_to_project(@manager, @project, Role.find(MANAGER_ROLE_ID))
    User.add_to_project(@developer, @project, Role.find(DEVELOPER_ROLE_ID))
    build_stages
    log_user("jsmith", "jsmith")
  end

  # Foundations done and closed, Framing left behind with one open issue (closed), Decking current, Lighting upcoming and
  # locked. Decking holds one issue per status the viewer (jsmith, the manager) can see.
  def build_stages
    @foundations = Version.generate!(project: @project, name: "Foundations", effective_date: @today - 60)
    @framing = Version.generate!(project: @project, name: "Framing", effective_date: @today - 30)
    @decking = Version.generate!(project: @project, name: "Decking", effective_date: @today + 14)
    @lighting = Version.generate!(project: @project, name: "Lighting", effective_date: @today + 40)
    2.times { Issue.generate!(project: @project, fixed_version: @foundations, author: @manager, status_id: CLOSED_STATUS_ID) }
    @framing_closed = Issue.generate!(project: @project, fixed_version: @framing, author: @manager, status_id: CLOSED_STATUS_ID)
    @framing_open = Issue.generate!(project: @project, fixed_version: @framing, author: @manager, subject: "Repair the post")
    @decking_closed = Issue.generate!(project: @project, fixed_version: @decking, author: @manager, status_id: CLOSED_STATUS_ID)
    @decking_mine = Issue.generate!(project: @project, fixed_version: @decking, author: @manager, assigned_to: @manager,
                                    subject: "Mine to do")
    @decking_started = Issue.generate!(project: @project, fixed_version: @decking, author: @manager,
                                       status_id: IN_PROGRESS_STATUS_ID, assigned_to: @developer, subject: "Started")
    @decking_waiting = Issue.generate!(project: @project, fixed_version: @decking, author: @manager,
                                       status_id: WAITING_STATUS_ID, subject: "Waiting on someone")
    @decking_next = Issue.generate!(project: @project, fixed_version: @decking, author: @manager, subject: "Do next")
    @lighting_issue = Issue.generate!(project: @project, fixed_version: @lighting, author: @manager, subject: "Light it")
    @foundations.update!(status: "closed")
    @framing.update!(status: "closed")
    @lighting.update!(status: "locked")
  end

  def with_status_settings(&block)
    settings = RubylodeProgress::Settings::DEFAULTS.merge(
      "in_progress_status_ids" => [IN_PROGRESS_STATUS_ID.to_s], "waiting_status_ids" => [WAITING_STATUS_ID.to_s],
      "next_issue_limit" => "1"
    )
    with_settings({ plugin_redmine_rubylode_progress: settings }, &block)
  end

  def progress_path(query = "")
    "/projects/#{@project.identifier}/progress#{query}"
  end

  def open_progress(query = "")
    get progress_path(query)
    assert_response :success
  end

  def row_selector(issue)
    "#rubylode-progress-item-#{issue.id}"
  end

  # Step 1 is the contrast test in the stylesheet test.

  test "step 2: done and upcoming stages start folded, current and partial open" do
    open_progress

    assert_select "details.rubylode-progress-stage[open]", count: 2
    assert_select "details.rubylode-progress-stage:not([open])", count: 2
    assert_select "details.rubylode-progress-stage:not([open]) .rubylode-progress-stage__name", text: "Foundations"
    assert_select "details.rubylode-progress-stage:not([open]) .rubylode-progress-stage__name", text: "Lighting"
    assert_select "details.rubylode-progress-stage[open] .rubylode-progress-stage__name", text: "Framing"
    assert_select "details.rubylode-progress-stage[open] .rubylode-progress-stage__name", text: "Decking"
  end

  test "step 2: in an open stage the closed issues are not listed until the toggle is opened" do
    open_progress

    assert_select "details.rubylode-progress-stage[open] > ul.rubylode-progress-steps .rubylode-progress-step--done", count: 0
    assert_select "details.rubylode-progress-stage[open] > details.rubylode-progress-closed-fold:not([open]) .rubylode-progress-step--done", count: 0
    assert_select "details.rubylode-progress-stage[open] > details.rubylode-progress-closed-fold:not([open])[data-lazy-issues-path]", count: 2
    assert_select "details.rubylode-progress-stage:not([open]) details.rubylode-progress-closed-fold", count: 0
  end

  test "step 2: the toggle is a details summary with a chevron and a label for each state" do
    open_progress

    assert_select "details.rubylode-progress-closed-fold:not([open]) > summary", count: 2
    assert_select "details.rubylode-progress-closed-fold > summary > .rubylode-progress-chevron[aria-hidden=true]", count: 2
    assert_select "details.rubylode-progress-closed-fold > summary > .rubylode-progress-closed-fold__show", text: "Show 1 closed", count: 2
    assert_select "details.rubylode-progress-closed-fold > summary > .rubylode-progress-closed-fold__hide", text: "Hide 1 closed", count: 2
  end

  test "step 3: a checklist row's mark has its own shape class for each status" do
    with_status_settings do
      open_progress("?filter=all")
    end

    assert_select "#{row_selector(@decking_closed)} .rubylode-progress-row__mark--done"
    assert_select "#{row_selector(@decking_mine)} .rubylode-progress-row__mark--needs-you"
    assert_select "#{row_selector(@decking_started)} .rubylode-progress-row__mark--in-progress"
    assert_select "#{row_selector(@decking_waiting)} .rubylode-progress-row__mark--waiting"
    assert_select "#{row_selector(@decking_next)} .rubylode-progress-row__mark--next"
    assert_select "#{row_selector(@lighting_issue)} .rubylode-progress-row__mark--to-do"
    assert_select ".rubylode-progress-row__mark[aria-hidden=true]", count: 10
    assert_select "#{row_selector(@decking_next)} .rubylode-progress-pill", text: "Next"
    assert_select "#{row_selector(@decking_waiting)} .rubylode-progress-pill", text: "Waiting"
  end

  test "step 3: the stage list's steps keep done, in progress and open only" do
    with_status_settings do
      open_progress
    end

    assert_select ".rubylode-progress-step--in-progress", count: 1
    assert_select ".rubylode-progress-step--open", minimum: 1
    assert_select ".rubylode-progress-step--next, .rubylode-progress-step--waiting, .rubylode-progress-step--needs-you, .rubylode-progress-step--to-do", count: 0
  end

  test "step 4: rows show the assignee only, not the viewer, not an empty one, and never the author" do
    open_progress("?filter=all")

    assert_select "#{row_selector(@decking_started)} .rubylode-progress-row__assignee", text: @developer.name
    assert_select "#{row_selector(@decking_mine)} .rubylode-progress-row__assignee", count: 0
    assert_select "#{row_selector(@decking_next)} .rubylode-progress-row__assignee", count: 0
    assert_select ".rubylode-progress-row__author, .rubylode-progress-step__author", count: 0
    assert_select ".rubylode-progress-step__assignee", text: @developer.name, count: 1
    assert_select ".rubylode-progress-step__assignee", count: 1
  end

  test "owner A: every issue row reads mark, title, number, assignee, and the stage list gets the number" do
    open_progress("?filter=all")

    assert_select "details.rubylode-progress-stage[open] li.rubylode-progress-step" do |steps|
      started = steps.find { |step| step.text.include?("Started") }
      classes = started.css("span, a").map { |element| element["class"].to_s.split.first }
      assert_operator classes.index("rubylode-progress-step__mark"), :<, classes.index("rubylode-progress-item-link")
      assert_operator classes.index("rubylode-progress-item-link"), :<, classes.index("rubylode-progress-step__number")
      assert_operator classes.index("rubylode-progress-step__number"), :<, classes.index("rubylode-progress-step__assignee")
    end
    assert_select "li.rubylode-progress-step a.rubylode-progress-step__number[href=?]", "/issues/#{@decking_started.id}",
                  text: "##{@decking_started.id}"
    assert_select "#{row_selector(@decking_started)} a.rubylode-progress-row__number", text: "##{@decking_started.id}", count: 1
    assert_select "#{row_selector(@decking_started)} .rubylode-progress-row__main", text: /##{@decking_started.id}/, count: 0
  end

  test "step 5: the Open heading leads with the open count the rows show; Done keeps N of M closed" do
    open_progress("?filter=open")

    assert_select ".rubylode-progress-section" do |sections|
      sections.each do |section|
        shown = section.css(".rubylode-progress-row").size
        assert_equal "#{shown} open", section.at_css(".rubylode-progress-section__tally").text.strip
      end
    end
    assert_select ".rubylode-progress-section__tally", text: "4 open"

    get progress_path("?filter=done")
    assert_select ".rubylode-progress-section__tally", text: "1 of 5 closed"
  end

  test "step 6: the date column drops this year's year and shortens another year's" do
    version = Version.generate!(project: @project, name: "Later", effective_date: @today + 400)
    near = Issue.generate!(project: @project, fixed_version: version, author: @manager, due_date: @today + 20)
    far = Issue.generate!(project: @project, fixed_version: version, author: @manager, due_date: Date.new(@today.year + 1, 3, 5))
    soon = Issue.generate!(project: @project, fixed_version: version, author: @manager, due_date: @today + 3)
    late = Issue.generate!(project: @project, fixed_version: version, author: @manager, due_date: @today - 45)

    with_settings date_format: "%m/%d/%Y" do
      open_progress("?filter=all")
    end

    expected_near = (@today + 20).year == @today.year ? (@today + 20).strftime("%m/%d") : (@today + 20).strftime("%m/%d/%y")
    assert_select "#{row_selector(near)} .rubylode-progress-row__date", text: expected_near
    assert_select "#{row_selector(far)} .rubylode-progress-row__date", text: Date.new(@today.year + 1, 3, 5).strftime("%m/%d/%y")
    assert_select "#{row_selector(soon)} .rubylode-progress-row__date--soon", text: "#{(@today + 3).strftime("%a %m/%d")}, 3d"
    assert_select "#{row_selector(late)} .rubylode-progress-row__date--overdue", text: "Overdue 45d"
  end

  test "step 6: a pattern that is not plain day-month-year leaves Redmine's format" do
    version = Version.generate!(project: @project, name: "Later", effective_date: @today + 400)
    far = Issue.generate!(project: @project, fixed_version: version, author: @manager, due_date: @today + 30)

    with_settings date_format: "%d %b %Y" do
      open_progress("?filter=all")
      assert_select "#{row_selector(far)} .rubylode-progress-row__date", text: (@today + 30).strftime("%d %b %Y")
    end
  end

  test "step 7 and 8: the project name is a hidden heading, Updated sits beside the percent, which explains itself" do
    open_progress

    assert_select "h2.rubylode-progress-visually-hidden", text: @project.name
    assert_select ".rubylode-progress-title", count: 0
    assert_select ".rubylode-progress-title__last-change", count: 0
    assert_select ".rubylode-progress-tracker__figure .rubylode-progress-tracker__percent", count: 1
    assert_select ".rubylode-progress-tracker__figure .rubylode-progress-tracker__updated", text: /\AUpdated \d\d\/\d\d/
    assert_select ".rubylode-progress-tracker__figure .rubylode-progress-tracker__percent-note", text: "Average of stage progress"
    assert_select ".rubylode-progress-tracker__closed", text: /issues closed/
  end

  test "step 9: the top tracker's name line carries the percent and the date line comes second" do
    open_progress

    assert_select ".rubylode-progress-track__stage--current .rubylode-progress-track__heading" do |headings|
      assert_match(/\ADecking\s+\d+%\z/, headings.first.text.squish)
    end
    assert_select ".rubylode-progress-track__label > .rubylode-progress-track__heading + .rubylode-progress-track__date", minimum: 1
    assert_select ".rubylode-progress-track__label > .rubylode-progress-visually-hidden", minimum: 4
  end

  test "step 10: the rules disclosure has an info icon, is folded, and stays beside Group by" do
    open_progress

    assert_select ".rubylode-progress-checklist__controls > .rubylode-progress-group"
    assert_select ".rubylode-progress-checklist__controls > details.rubylode-progress-rules:not([open]) > summary .rubylode-progress-rules__icon[aria-hidden=true]"
    assert_select "details.rubylode-progress-rules > summary", text: /How statuses are decided/
  end

  test "owner B: a stage that takes issues is a drop target; closed, locked and unshared ones carry a reason instead" do
    open_progress("?group=version&filter=all")

    assert_select ".rubylode-progress-stage[data-version-id=?]", @decking.id.to_s, count: 1
    assert_select ".rubylode-progress-stage[data-version-id=?][data-refuse-reason]", @decking.id.to_s, count: 0
    assert_select ".rubylode-progress-stage[data-refuse-reason=?]:not([data-version-id])", "Foundations is closed, so it takes no new issues. Use its status button to reopen it.", count: 1
    assert_select ".rubylode-progress-stage[data-refuse-reason=?]:not([data-version-id])", "Framing is closed, so it takes no new issues. Use its status button to reopen it.", count: 1
    assert_select ".rubylode-progress-stage[data-refuse-reason=?]:not([data-version-id])", "Lighting is locked, so it takes no new issues. Use its status button to open it again.", count: 1
    assert_select ".rubylode-progress-section[data-refuse-reason=?]:not([data-version-id])", "Lighting is locked, so it takes no new issues. Use its status button to open it again.", count: 1
    assert_select ".rubylode-progress-section[data-version-id=?]", @decking.id.to_s, count: 1
  end

  test "owner B: closed and locked stages carry a small tag, open ones none, and the hint says open stage" do
    open_progress

    assert_select ".rubylode-progress-stage[data-refuse-reason*=Foundations] .rubylode-progress-stage__tag", text: "closed"
    assert_select ".rubylode-progress-stage[data-refuse-reason*=Lighting] .rubylode-progress-stage__tag", text: "locked"
    assert_select ".rubylode-progress-stage[data-version-id] .rubylode-progress-stage__tag", count: 0
    assert_select ".rubylode-progress-hint", text: "Drag an issue to another open stage to move it."
  end

  test "owner B: a version that is open but not shared with the project says so" do
    other_project = Project.generate!(is_public: false)
    foreign = Version.generate!(project: other_project, name: "Elsewhere", sharing: "none")
    helper = ApplicationController.helpers
    helper.extend(RubylodeProgressHelper)

    assert_equal "Elsewhere is not shared with this project, so it takes no new issues.", helper.rubylode_progress_refuse_reason(foreign)
  end
end
