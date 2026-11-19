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

class ProjectPageTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

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
  end

  def build_three_stages
    first = Version.generate!(project: @project, name: "Foundations", effective_date: Date.new(2026, 1, 15))
    second = Version.generate!(project: @project, name: "Build", effective_date: Date.new(2026, 2, 15),
                               description: "The build stage")
    third = Version.generate!(project: @project, name: "Launch", effective_date: Date.new(2026, 3, 15))
    Issue.generate!(project: @project, fixed_version: first, author: @manager, status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: @project, fixed_version: second, author: @manager, status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: @project, fixed_version: second, author: @manager)
    Issue.generate!(project: @project, fixed_version: third, author: @manager)
    first.update!(status: "closed")
    [first, second, third]
  end

  def progress_path
    "/projects/#{@project.identifier}/progress"
  end

  def open_progress_as(login)
    log_user(login, login == "dlopper" ? "foo" : login)
    get progress_path
    assert_response :success
  end

  test "a member sees the hidden title, Updated, Stage N of M and the track's label" do
    build_three_stages

    open_progress_as("jsmith")

    assert_select "h2", text: @project.name
    assert_select ".rubylode-progress-tracker__updated", text: /\AUpdated /
    assert_select ".rubylode-progress-tracker__position", text: "Stage 2 of 3"
    assert_select ".rubylode-progress-tracker__headline", text: "Build"
    assert_select "ol.rubylode-progress-track[aria-label=?]", "50% done, 1 of 3 stages finished"
  end

  test "the current stage is open with N of M closed; the others are folded" do
    build_three_stages

    open_progress_as("jsmith")

    assert_select "details.rubylode-progress-stage[open]", count: 1
    assert_select "details.rubylode-progress-stage[open] .rubylode-progress-stage__summary", text: "1 of 2 closed"
    assert_select "details.rubylode-progress-stage:not([open]) .rubylode-progress-stage__summary", text: "1 issue closed"
    assert_select "details.rubylode-progress-stage:not([open]) .rubylode-progress-stage__summary", text: "1 issue planned"
  end

  test "the pills carry the counts of the scope, and no tiles are drawn" do
    build_three_stages

    open_progress_as("jsmith")

    assert_select ".rubylode-progress-tile", count: 0
    assert_select "[data-filter-name=done] .rubylode-progress-filter__count", text: "2"
    assert_select "[data-filter-name=next] .rubylode-progress-filter__count", text: "1"
    assert_select "[data-filter-name=needs_you] .rubylode-progress-filter__count", text: "0"
    assert_select "[data-filter-name=open] .rubylode-progress-filter__count", text: "2"
    assert_select "[data-filter-name=all] .rubylode-progress-filter__count", text: "4"
  end

  test "a project without counted versions says there is nothing to track yet and shows no track" do
    open_progress_as("jsmith")

    assert_select ".rubylode-progress-empty", text: /nothing to track yet/i
    assert_select "ol.rubylode-progress-track", count: 0
  end

  test "the row date is the plain due date, a weekday and days when within a week, or Overdue with the days" do
    today = User.current.today
    version = Version.generate!(project: @project, effective_date: today + 90)
    far = Issue.generate!(project: @project, fixed_version: version, author: @manager, due_date: today + 30)
    soon = Issue.generate!(project: @project, fixed_version: version, author: @manager, due_date: today + 3)
    late = Issue.generate!(project: @project, fixed_version: version, author: @manager, due_date: today - 45)
    inherited = Issue.generate!(project: @project, fixed_version: Version.generate!(project: @project, effective_date: today - 10),
                                author: @manager)
    undated = Issue.generate!(project: @project, fixed_version: Version.generate!(project: @project), author: @manager)

    open_progress_as("jsmith")

    assert_select "#rubylode-progress-item-#{far.id} .rubylode-progress-row__date", text: expected_plain_row_date(today + 30, today)
    assert_select "#rubylode-progress-item-#{soon.id} .rubylode-progress-row__date--soon", text: "#{(today + 3).strftime("%a %m/%d")}, 3d"
    assert_select "#rubylode-progress-item-#{late.id} .rubylode-progress-row__date--overdue", text: "Overdue 45d"
    assert_select "#rubylode-progress-item-#{inherited.id} .rubylode-progress-row__date--overdue", text: "Overdue 10d"
    assert_select "#rubylode-progress-item-#{undated.id} .rubylode-progress-row__date", text: "-"
  end

  test "a done issue shows Closed and its date" do
    version = Version.generate!(project: @project, effective_date: Date.new(2026, 2, 15))
    done_issue = Issue.generate!(project: @project, fixed_version: version, author: @manager, status_id: CLOSED_STATUS_ID)
    done_issue.update_column(:closed_on, Time.utc(2026, 3, 5, 12))

    log_user("jsmith", "jsmith")
    get "#{progress_path}?filter=all"
    assert_response :success

    assert_select "#rubylode-progress-item-#{done_issue.id} .rubylode-progress-row__date", text: "Closed 03/05"
    get "#{progress_path}?filter=open"
    assert_select "#rubylode-progress-item-#{done_issue.id}", count: 0
  end

  test "the open issues of a closed version still show under Open" do
    version = Version.generate!(project: @project, effective_date: Date.new(2026, 1, 15))
    left_behind = Issue.generate!(project: @project, fixed_version: version, author: @manager)
    version.update!(status: "closed")

    open_progress_as("jsmith")

    assert_select "#rubylode-progress-item-#{left_behind.id}"
  end

  test "an issue assigned to a group the viewer is in shows as Needs you and counts on the pill" do
    version = Version.generate!(project: @project, effective_date: Date.new(2026, 2, 15))
    group = Group.generate!
    group.users << @developer
    User.add_to_project(group, @project, Role.find(DEVELOPER_ROLE_ID))
    issue = with_settings(issue_group_assignment: "1") do
      Issue.generate!(project: @project, fixed_version: version, author: @manager, assigned_to: group)
    end

    open_progress_as("dlopper")

    assert_select "#rubylode-progress-item-#{issue.id} .rubylode-progress-pill", text: "Needs you"
    assert_select "[data-filter-name=needs_you] .rubylode-progress-filter__count", text: "1"
  end

  test "a private note is never the item note for a viewer without View private notes" do
    version = Version.generate!(project: @project, effective_date: Date.new(2026, 2, 15))
    issue = Issue.generate!(project: @project, fixed_version: version, author: @manager)
    Journal.create!(journalized: issue, user: @manager, notes: "The public note", private_notes: false)
    Journal.create!(journalized: issue, user: @manager, notes: "The private note", private_notes: true)
    Role.find(MANAGER_ROLE_ID).add_permission!(:view_private_notes)
    Role.find(DEVELOPER_ROLE_ID).remove_permission!(:view_private_notes)

    open_progress_as("dlopper")
    assert_select "#rubylode-progress-item-#{issue.id} .rubylode-progress-row__note", text: "The public note"
    post "/logout"

    open_progress_as("jsmith")
    assert_select "#rubylode-progress-item-#{issue.id} .rubylode-progress-row__note", text: "The private note"
  end

  test "a custom field note shows only where the field is visible to the viewer" do
    version = Version.generate!(project: @project, effective_date: Date.new(2026, 2, 15))
    field = IssueCustomField.generate!(field_format: "string", is_for_all: true, tracker_ids: Tracker.pluck(:id),
                                       visible: false, role_ids: [MANAGER_ROLE_ID])
    issue = Issue.generate!(project: @project, fixed_version: version, author: @manager)
    issue.custom_field_values = { field.id.to_s => "Field note text" }
    issue.save!
    with_settings(plugin_redmine_rubylode_progress: RubylodeProgress::Settings::DEFAULTS.merge(
      "note_source" => "custom_field_#{field.id}"
    )) do
      open_progress_as("jsmith")
      assert_select "#rubylode-progress-item-#{issue.id} .rubylode-progress-row__note", text: "Field note text"
      post "/logout"

      open_progress_as("dlopper")
      assert_select "#rubylode-progress-item-#{issue.id}"
      assert_select "#rubylode-progress-item-#{issue.id} .rubylode-progress-row__note", count: 0
    end
  end

  # The default pattern is month/day/year: the year is dropped for this year and two digits for another.
  def expected_plain_row_date(date, today)
    date.year == today.year ? date.strftime("%m/%d") : date.strftime("%m/%d/%y")
  end
end
