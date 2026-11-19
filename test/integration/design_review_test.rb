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

class DesignReviewTest < Redmine::IntegrationTest
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
  end

  # Four stages: Foundations done, Framing left behind with one open issue and overdue, Decking current at a third,
  # Lighting upcoming.
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
                                    due_date: @today + 3, subject: "Mine to do")
    @decking_started = Issue.generate!(project: @project, fixed_version: @decking, author: @manager,
                                       status_id: IN_PROGRESS_STATUS_ID, subject: "Started")
    @lighting_issue = Issue.generate!(project: @project, fixed_version: @lighting, author: @manager)
    @foundations.update!(status: "closed")
    @framing.update!(status: "closed")
  end

  def progress_path(query = "")
    "/projects/#{@project.identifier}/progress#{query}"
  end

  def open_progress(query = "", login: "jsmith")
    log_user(login, login == "dlopper" ? "foo" : login)
    get progress_path(query)
    assert_response :success
  end

  def visible_text
    css_select(".rubylode-progress").map(&:text).join(" ")
  end

  def format_date_for_test(date)
    ApplicationController.new.helpers.format_date(date)
  end

  test "the top tracker draws a segment per stage filled to its share and a mark per state, with the labels" do
    build_stages

    open_progress

    segments = css_select("ol.rubylode-progress-track li.rubylode-progress-track__stage")
    assert_equal 4, segments.size
    assert_equal ["100%", "50%", "33%", "0%"], segments.map { |segment| segment["style"][/--rubylode-progress-share: (\d+%)/, 1] }
    assert_select "ol.rubylode-progress-track .rubylode-progress-stage-mark--done[aria-hidden=true]", count: 1
    assert_select "ol.rubylode-progress-track .rubylode-progress-stage-mark--partial[aria-hidden=true]", count: 1
    assert_select "ol.rubylode-progress-track .rubylode-progress-stage-mark--current[aria-hidden=true]", count: 1
    assert_select "ol.rubylode-progress-track .rubylode-progress-stage-mark--upcoming[aria-hidden=true]", count: 1
    assert_match(/\A\d+% done, 1 of 4 stages finished\z/, css_select("ol.rubylode-progress-track").first["aria-label"])
    assert_select ".rubylode-progress-track__stage--current .rubylode-progress-track__name", text: "Decking"
    assert_select ".rubylode-progress-track__date--overdue", text: "Overdue, due #{(@today - 30).strftime("%m/%d")}"
    assert_select ".rubylode-progress-track__date", text: "Due #{(@today + 14).strftime("%m/%d")}, 14 days"
    assert_select ".rubylode-progress-track__date", text: /\ADone /
  end

  test "each stage item carries the share and colour of the next stage" do
    build_stages

    open_progress

    items = css_select("li.rubylode-progress-stage-item")
    shares = items.map { |item| item["style"][/share-into-next: (\d+%)/, 1] }
    colours = items.map { |item| item["style"][/colour-into-next: var\((--[a-z-]+)\)/, 1] }
    assert_equal ["50%", "33%", "0%", nil], shares
    assert_equal ["--rubylode-progress-behind-color", "--rubylode-progress-accent-color",
                  "--rubylode-progress-track-empty-color", nil], colours
    assert_match(/share-into-self: 100%/, items.first["style"])
    assert_no_match(/share-into-self/, items.last["style"])
    assert_select "li.rubylode-progress-stage-item > .rubylode-progress-stage-mark", count: 4
  end

  test "a partial stage past its due date shows the Behind notice with its open count" do
    build_stages

    open_progress

    assert_select ".rubylode-progress-notice--behind", text: /Framing is 30 days overdue: 1 open issue/
    assert_select ".rubylode-progress-notice--due-soon", text: /Decking: 2 open, 14 days left/
    assert_select ".rubylode-progress-tracker__closed", text: "4 of 8 issues closed"
  end

  test "the filter pills show the same counts as the checklist they select, Overdue and Next up included, and the stage list is the same under every filter" do
    build_stages
    @decking_started.update_column(:due_date, @today - 2)
    open_progress
    stage_list = css_select("section.rubylode-progress-stage-list").to_s

    RubylodeProgress::ChecklistFilter::NAMES.each do |name|
      pill_count = css_select("[data-filter-name=#{name}] .rubylode-progress-filter__count").first.text.to_i
      get progress_path("?filter=#{name}")
      assert_select ".rubylode-progress-checklist .rubylode-progress-row", count: pill_count
      assert_equal stage_list, css_select("section.rubylode-progress-stage-list").to_s, name
    end

    get progress_path("?filter=overdue")
    assert_select ".rubylode-progress-row", text: /Started/
    assert_select ".rubylode-progress-row", text: /Repair the post/
    assert_select "[data-filter-name=overdue].rubylode-progress-filter--behind"
  end

  test "a pill with no issues is muted and still a link" do
    build_stages

    open_progress

    assert_select "a.rubylode-progress-filter--empty[data-filter-name=needs_you][href]", count: 0
    assert_select "a.rubylode-progress-filter[data-filter-name=next][href]"
  end

  test "the checklist heading follows the filter and carries the New issue link for the current version" do
    build_stages

    open_progress("?filter=needs_you")

    assert_select ".rubylode-progress-checklist__title", text: "Needs you"
    assert_select ".rubylode-progress-checklist__count", text: "1 issue"
    assert_select ".rubylode-progress-checklist__by", text: "by version"
    assert_select "a.rubylode-progress-new-issue-button[href=?][title=?]",
                  "/projects/#{@project.identifier}/progress/versions/#{@decking.id}/new_issue?filter=needs_you",
                  "New issue in Decking", text: "New issue"
    assert_select "a.rubylode-progress-issue-query[href^=?]", "/projects/#{@project.identifier}/issues?"
    %w[open overdue next done all].zip(["Open work", "Overdue", "Next up", "Done", "All issues"]) do |name, title|
      get progress_path("?filter=#{name}")
      assert_select ".rubylode-progress-checklist__title", text: title
    end
  end

  test "the issue query link carries the project, the versions and the status, and the filter's own rule, from known names only" do
    build_stages

    open_progress("?filter=needs_you&group=category")
    href = css_select("a.rubylode-progress-issue-query").first["href"]
    query = Rack::Utils.parse_nested_query(URI(href).query)

    assert_equal "1", query["set_filter"]
    assert_equal "o", query.dig("op", "status_id")
    assert_equal [@foundations, @framing, @decking, @lighting].map { |version| version.id.to_s }.sort, query.dig("v", "fixed_version_id").sort
    assert_equal ["me"], query.dig("v", "assigned_to_id")
    assert_no_match(/category/, href)
  end

  test "the empty state names the filter" do
    build_stages
    Issue.where(assigned_to_id: @manager.id).update_all(assigned_to_id: nil)

    open_progress("?filter=needs_you")
    assert_select ".rubylode-progress-checklist__empty", text: "Nothing is waiting on you"

    get progress_path("?filter=next&group=version")
    Issue.update_all(status_id: CLOSED_STATUS_ID)
    get progress_path("?filter=overdue")
    assert_select ".rubylode-progress-checklist__empty", text: "No issues match this filter"
  end

  test "closed issues fold under Show N closed in the current stage" do
    build_stages

    open_progress

    assert_select "details.rubylode-progress-stage[open] details.rubylode-progress-closed-fold > summary", text: "Show 1 closed", count: 2
    assert_select "details.rubylode-progress-closed-fold .rubylode-progress-step--done", count: 2
    assert_select "details.rubylode-progress-closed-fold .rubylode-progress-step--open", count: 0
    assert_select "details.rubylode-progress-stage:not([open]) details.rubylode-progress-closed-fold", count: 0
  end

  test "a folded partial stage names the issue that holds it up" do
    build_stages
    @framing.update!(status: "open")
    second_open = Issue.generate!(project: @project, fixed_version: @framing, author: @manager)
    @framing.update!(status: "closed")

    open_progress
    assert_select ".rubylode-progress-stage__blocking", text: "2 open issues"

    second_open.update!(status_id: CLOSED_STATUS_ID)
    get progress_path
    assert_select ".rubylode-progress-stage__blocking", text: "Blocking: Repair the post ##{@framing_open.id}"
  end

  test "the add link reads New issue in and the version name" do
    build_stages

    open_progress

    assert_select ".rubylode-progress-stage__add a.rubylode-progress-add", text: /New issue in Decking/
  end

  test "bug: one checklist section for one category name, even across a subproject" do
    build_stages
    subproject = Project.generate!(parent_id: @project.id, is_public: false)
    subproject.enable_module!(:issue_tracking)
    User.add_to_project(@manager, subproject, Role.find(MANAGER_ROLE_ID))
    own_category = IssueCategory.create!(project: @project, name: "Safety")
    sub_category = IssueCategory.create!(project: subproject, name: "Safety")
    @decking_mine.update!(category: own_category)
    @decking.update!(sharing: "descendants")
    Issue.generate!(project: subproject, fixed_version: @decking, author: @manager, category: sub_category)

    open_progress("?group=category")

    assert_select ".rubylode-progress-section__title", text: /\ASafety/, count: 1
  end

  test "bug: a section's tally and its meter come from the same issues, whatever the filter" do
    build_stages

    open_progress("?filter=open")

    assert_select ".rubylode-progress-section" do |sections|
      decking = sections.find { |section| section.text.include?("Decking") }
      assert_includes decking.text, "1 of 3 closed"
      assert_includes decking.text, "33%"
    end
    assert_select ".rubylode-progress-section__tally", text: "0 of 2 closed", count: 0
  end

  test "bug: a closed issue is never listed among the open ones" do
    build_stages

    open_progress("?filter=open")

    assert_select ".rubylode-progress-checklist .rubylode-progress-row--done", count: 0
    assert_select ".rubylode-progress-checklist .rubylode-progress-row .rubylode-progress-pill", text: "Done", count: 0
  end

  test "no user-facing text says step" do
    build_stages

    open_progress
    RubylodeProgress::ChecklistFilter::NAMES.product(%w[version category parent]).each do |name, grouping|
      get progress_path("?filter=#{name}&group=#{grouping}")
      assert_no_match(/\bsteps?\b/i, visible_text, "#{name} #{grouping}")
      css_select(".rubylode-progress [title], .rubylode-progress [aria-label]").each do |node|
        assert_no_match(/\bsteps?\b/i, "#{node['title']} #{node['aria-label']}")
      end
    end
    get "/progress"
    assert_no_match(/\bsteps?\b/i, visible_text)
    assert_no_match(/\bsteps?\b/i, File.read(File.expand_path("../../config/locales/en.yml", __dir__)).lines.reject { |line| line.strip.start_with?("#") }.join.scan(/:\s*"?([^"\n]*)"?\n/).flatten.join(" "))
  end

  test "the group buttons regroup the checklist without changing its issues" do
    build_stages
    @decking_mine.update!(category: IssueCategory.create!(project: @project, name: "Safety"))

    open_progress("?filter=all")
    ids_by_version = css_select(".rubylode-progress-row").map { |row| row["id"] }.sort
    assert_select ".rubylode-progress-group__button[aria-pressed=true]", count: 1
    assert_select ".rubylode-progress-group__button[aria-pressed=true][data-group-name=version]"
    assert_select ".rubylode-progress-group__note", text: /project default/

    get progress_path("?filter=all&group=category")
    assert_equal ids_by_version, css_select(".rubylode-progress-row").map { |row| row["id"] }.sort
    assert_select ".rubylode-progress-group__button[aria-pressed=true][data-group-name=category]"
    assert_select ".rubylode-progress-group__note", text: /just for you, project default: Version/
    assert_select ".rubylode-progress-section__title", text: /Safety/

    get "/projects/#{@project.identifier}/progress/checklist?filter=all&group=parent"
    assert_response :success
    assert_equal ids_by_version, css_select(".rubylode-progress-row").map { |row| row["id"] }.sort
    assert_select ".rubylode-progress-group__button[aria-pressed=true][data-group-name=parent]"
    assert_select ".rubylode-progress-filter[href*=group]", minimum: 1
    assert_select ".rubylode-progress-group__select-form select option[selected][value=parent]"
  end

  test "an unknown grouping falls back to the project's setting and is never copied into a link" do
    build_stages

    open_progress("?group=%22%3E%3Cscript%3E")

    assert_select ".rubylode-progress-group__button[aria-pressed=true][data-group-name=version]"
    assert_no_match(/<script>alert|%3Cscript/, response.body)
  end

  test "the rules panel is folded, names the effective waiting and in-progress statuses and the Next limit, and links to settings for those who may edit" do
    build_stages

    with_settings plugin_redmine_rubylode_progress: RubylodeProgress::Settings::DEFAULTS.merge(
      "in_progress_status_ids" => [IN_PROGRESS_STATUS_ID.to_s], "waiting_status_ids" => [WAITING_STATUS_ID.to_s],
      "next_issue_limit" => "4"
    ) do
      open_progress
      assert_select "details.rubylode-progress-rules:not([open])", count: 1
      assert_select "details.rubylode-progress-rules summary", text: "How statuses are decided"
      assert_select ".rubylode-progress-rules__list .rubylode-progress-pill", count: 5
      assert_select ".rubylode-progress-rules__list", text: /#{Regexp.escape(IssueStatus.find(WAITING_STATUS_ID).name)}/
      assert_select ".rubylode-progress-rules__list", text: /#{Regexp.escape(IssueStatus.find(IN_PROGRESS_STATUS_ID).name)}/
      assert_select ".rubylode-progress-rules__list", text: /first 4 other open issues/
      assert_select ".rubylode-progress-rules__note", text: /half-filled circle means an in-progress status/
      assert_select "a[href=?]", "/projects/#{@project.identifier}/settings/rubylode_progress", text: "Change in project settings"
    end
  end

  test "Change in project settings is hidden from a viewer who may not edit the project" do
    build_stages
    Role.find(DEVELOPER_ROLE_ID).remove_permission!(:edit_project)

    open_progress("", login: "dlopper")

    assert_select "details.rubylode-progress-rules"
    assert_select "a", text: "Change in project settings", count: 0
  end

  test "the new-tab links carry rel noopener" do
    build_stages

    open_progress

    links = css_select("a[target=_blank]")
    assert_not_empty links
    links.each { |link| assert_includes link["rel"].to_s, "noopener" }
  end

  test "the page uses the full width: no column cap in the markup and the stage list sits beside the checklist" do
    build_stages

    open_progress

    assert_select ".rubylode-progress-columns > section.rubylode-progress-stage-list"
    assert_select ".rubylode-progress-columns > .rubylode-progress-checklist-column section.rubylode-progress-checklist"
  end

  test "the compact tracker on the all-projects page uses the same segments and marks without labels" do
    build_stages

    open_progress
    get "/progress"

    assert_select ".rubylode-progress-compact-tracker .rubylode-progress-track__segment", count: 4
    assert_select ".rubylode-progress-compact-tracker .rubylode-progress-stage-mark", count: 4
    assert_select ".rubylode-progress-compact-tracker .rubylode-progress-track__label", count: 0
  end
end
