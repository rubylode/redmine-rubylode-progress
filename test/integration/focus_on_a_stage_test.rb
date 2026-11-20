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
    get progress_path, params: { stage: @upcoming.id, filter: "done" }
    get checklist_path, params: { stage: @upcoming.id, filter: "all" }

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

  test "the modals opened with a stage build a back address that keeps the stage" do
    build_project
    log_user("jsmith", "jsmith")
    expected = "#{progress_path}?filter=all&stage=#{@upcoming.id}"
    modal_paths = [
      "#{progress_path}/versions/#{@upcoming.id}/status",
      "#{progress_path}/issues/#{@current_open_issue.id}/quick_edit",
      "#{progress_path}/versions/#{@upcoming.id}/new_issue"
    ]

    modal_paths.each do |path|
      get path, params: { filter: "all", stage: @upcoming.id }
      assert_response :success, path
      assert_equal expected, css_select("input[name=back_url]").first["value"], path
    end
  end

  def focus_link_for(version) = css_select("li.rubylode-progress-stage-item a.rubylode-progress-stage__focus-link").find { |link| link.text.strip == version.name }

  def query_of(address) = Rack::Utils.parse_query(URI.parse(address).query)

  test "the stage name links to the focused page keeping the filter and the selects" do
    build_project
    @project.issues.where(fixed_version_id: @upcoming.id).update_all(assigned_to_id: @developer.id)
    log_user("jsmith", "jsmith")

    get progress_path, params: { filter: "all", assignee: @developer.id }

    assert_response :success
    link = focus_link_for(@upcoming)
    assert link, "the upcoming stage's name is a focus link"
    assert_equal progress_path, URI.parse(link["href"]).path
    query = query_of(link["href"])
    assert_equal @upcoming.id.to_s, query["stage"]
    assert_equal "all", query["filter"]
    assert_equal @developer.id.to_s, query["assignee"]
    assert_nil query["open_stage"]
  end

  test "the focused stage list is one open stage without a fold row" do
    build_project
    finished = Array.new(8) do |index|
      version = Version.generate!(project: @project, name: "Finished #{index + 1}", effective_date: Date.new(2025, 1, 1) >> index)
      2.times { Issue.generate!(project: @project, fixed_version: version, author: @manager, status_id: CLOSED_STATUS_ID) }
      version.update!(status: "closed")
      version
    end
    log_user("jsmith", "jsmith")
    get progress_path
    assert_select ".rubylode-progress-finished-fold", count: 1

    get progress_path, params: { stage: finished.first.id }

    assert_response :success
    assert_select ".rubylode-progress-finished-fold", count: 0
    assert_select "ol.rubylode-progress-stages > li.rubylode-progress-stage-item", count: 1
    assert_select "details.rubylode-progress-stage[open]", count: 1
    assert_select "details.rubylode-progress-stage:not([open])", count: 0
    assert_select "a.rubylode-progress-stage__focus-link", text: "Finished 1"
  end

  test "the focused checklist is flat" do
    build_project
    4.times { |count| Issue.generate!(project: @project, fixed_version: @upcoming, author: @developer, subject: "More #{count}") }
    RubylodeProgress::ProjectSetting.create!(project: @project, checklist_rows_per_section: 5)
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id, filter: "all" }

    assert_response :success
    assert_select ".rubylode-progress-section__title", count: 0
    assert_select "details.rubylode-progress-section", count: 0
    assert_select ".rubylode-progress-group", count: 0
    assert_select ".rubylode-progress-checklist__by", count: 0
    assert_no_match(/translation missing/i, response.body)
    assert_select ".rubylode-progress-checklist ul.rubylode-progress-rows", count: 1
    assert_equal 5, checklist_row_ids.size
    more = css_select("a.rubylode-progress-show-more").first
    assert more, "a show more link"
    assert_equal @upcoming.id.to_s, query_of(more["href"])["stage"]
    assert_equal "all", query_of(more["data-checklist-path"])["expand"]
    assert_equal @upcoming.id.to_s, query_of(more["data-checklist-path"])["stage"]

    get checklist_path, params: { stage: @upcoming.id, filter: "all", expand: "all" }
    assert_equal 7, checklist_row_ids.size
    assert_select "a.rubylode-progress-show-more", count: 0
  end

  test "the filter and narrowing links keep the focus" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id }

    assert_response :success
    pills = css_select("a.rubylode-progress-filter")
    assert_operator pills.size, :>, 1
    pills.each do |pill|
      assert_equal @upcoming.id.to_s, query_of(pill["href"])["stage"]
      assert_equal @upcoming.id.to_s, query_of(pill["data-checklist-path"])["stage"]
    end
    form = css_select("form.rubylode-progress-narrowing").first
    assert_equal @upcoming.id.to_s, query_of(form["data-checklist-path"])["stage"]
    assert_select "form.rubylode-progress-narrowing input[type=hidden][name=stage][value=?]", @upcoming.id.to_s
  end

  test "the new issue button offers the focused stage" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id }

    assert_response :success
    assert_select "a.rubylode-progress-new-issue-button[href*=?]", "/versions/#{@upcoming.id}/new_issue"
  end

  test "when every stage is done the focused stage still renders open" do
    build_project
    @project.issues.update_all(status_id: CLOSED_STATUS_ID)
    @current.update!(status: "closed")
    @upcoming.update!(status: "closed")
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id, filter: "all" }

    assert_response :success
    assert_select ".rubylode-progress-finished-fold", count: 0
    assert_select "details.rubylode-progress-stage[open]", count: 1
    assert_select "ol.rubylode-progress-stages > li.rubylode-progress-stage-item", count: 1
    assert_select "a.rubylode-progress-stage__focus-link", text: "Upcoming stage"
    assert_equal 3, checklist_row_ids.size
  end

  def stage_named(name) = RubylodeProgress::ProjectProgress.new(project: Project.find(@project.id), viewer: @manager).stages.find { |stage| stage.version.name == name }

  test "the top block shows the focused stage's own name, position, percent and closed count" do
    build_project
    @upcoming.update!(description: "The second half")
    @upcoming_issues.first.update!(status_id: CLOSED_STATUS_ID)
    log_user("jsmith", "jsmith")
    stage = stage_named("Upcoming stage")

    get progress_path, params: { stage: @upcoming.id }

    assert_response :success
    assert_select "h3.rubylode-progress-tracker__headline", text: "Upcoming stage"
    assert_select "p.rubylode-progress-tracker__description", text: "The second half"
    assert_select "p.rubylode-progress-tracker__position", text: "Stage 2 of 2"
    assert_select "p.rubylode-progress-tracker__percent", text: "#{RubylodeProgress::PercentRule.percent_of(stage)}%"
    assert_select "p.rubylode-progress-tracker__closed", text: "1 of 3 issues closed"
    assert_select "p.rubylode-progress-tracker__percent-note", count: 0

    get progress_path
    assert_select "p.rubylode-progress-tracker__percent", text: "#{RubylodeProgress::ProjectProgress.new(project: Project.find(@project.id), viewer: @manager).percent}%"
    assert_select "p.rubylode-progress-tracker__closed", text: "2 of 5 issues closed"
    assert_select "p.rubylode-progress-tracker__percent-note", count: 1
  end

  test "the notices of a focused page read the focused stage alone" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @current.id }
    assert_select "li.rubylode-progress-notice", text: /Current stage/

    get progress_path, params: { stage: @upcoming.id }
    assert_response :success
    assert_select "li.rubylode-progress-notice", count: 0
  end

  test "a focused stage that is done fills the top block without a current stage" do
    build_project
    @project.issues.update_all(status_id: CLOSED_STATUS_ID)
    @current.update!(status: "closed")
    @upcoming.update!(status: "closed")
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id, filter: "all" }

    assert_response :success
    assert_select "h3.rubylode-progress-tracker__headline", text: "Upcoming stage"
    assert_select "p.rubylode-progress-tracker__position", text: "Stage 2 of 2"
    assert_select "p.rubylode-progress-tracker__percent", text: "100%"
    assert_select "p.rubylode-progress-tracker__closed", text: "3 of 3 issues closed"
    assert_select "li.rubylode-progress-track__stage--focused", count: 1
  end

  test "the rail keeps every stage, marks the focused one, dims the others and links each to its focus" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id }

    assert_response :success
    stages = css_select("ol.rubylode-progress-track > li.rubylode-progress-track__stage")
    assert_equal 2, stages.size
    assert_select "li.rubylode-progress-track__stage--focused", count: 1
    assert_select "li.rubylode-progress-track__stage--dimmed", count: 1
    assert_select "li.rubylode-progress-track__stage--focused a.rubylode-progress-track__focus-link[aria-label*=?]", "Upcoming stage"
    assert_select "li.rubylode-progress-track__stage--dimmed a.rubylode-progress-track__focus-link[aria-label*=?]", "Current stage"
    stages.each do |item|
      links = item.css("a.rubylode-progress-track__focus-link")
      assert_operator links.size, :>=, 1
      links.each do |link|
        assert_equal progress_path, URI.parse(link["href"]).path
        assert_includes [@current.id.to_s, @upcoming.id.to_s], query_of(link["href"])["stage"]
        assert link["aria-label"].present?, "the dot's link names its stage"
      end
    end
    assert_equal [@current.id.to_s, @upcoming.id.to_s].sort,
                 css_select("li.rubylode-progress-track__stage a.rubylode-progress-track__focus-link").map { |link| query_of(link["href"])["stage"] }.uniq.sort
  end

  test "the rail's links and the show all link keep the filter, grouping and selects, and the show all link drops the stage" do
    build_project
    @project.issues.where(fixed_version_id: @upcoming.id).update_all(assigned_to_id: @developer.id)
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id, filter: "all", group: "category", assignee: @developer.id }

    assert_response :success
    show_all = css_select("a.rubylode-progress-tracker__show-all").first
    assert show_all, "a show all stages link"
    assert_equal "Show all stages", show_all.text.strip
    assert_equal progress_path, URI.parse(show_all["href"]).path
    query = query_of(show_all["href"])
    assert_nil query["stage"]
    assert_equal "all", query["filter"]
    assert_equal "category", query["group"]
    assert_equal @developer.id.to_s, query["assignee"]
    css_select("a.rubylode-progress-track__focus-link").each do |link|
      kept = query_of(link["href"])
      assert_equal "all", kept["filter"]
      assert_equal "category", kept["group"]
      assert_equal @developer.id.to_s, kept["assignee"]
    end
  end

  # Every address the page (or a swapped-in fragment) carries, and the hidden fields of its forms.
  def addresses_on_the_page
    css_select("[href], [data-checklist-path], [data-lazy-section-path]").flat_map do |node|
      [node["href"], node["data-checklist-path"], node["data-lazy-section-path"]].compact
    end
  end

  def assert_grouping_kept_in_links(grouping)
    addresses = addresses_on_the_page
    assert_empty addresses.grep(/group=flat/), "no address names the flat grouping"
    assert_select "input[type=hidden][name=group][value=flat]", count: 0
    assert_not_includes response.body, "group=flat"
    pills = css_select("a.rubylode-progress-filter")
    assert_operator pills.size, :>, 1
    pills.each do |pill|
      assert_equal grouping, query_of(pill["href"])["group"], "pill #{pill["href"]}"
      assert_equal grouping, query_of(pill["data-checklist-path"])["group"], "pill #{pill["data-checklist-path"]}"
    end
    form = css_select("form.rubylode-progress-narrowing").first
    assert_equal grouping, query_of(form["data-checklist-path"])["group"]
    assert_select "form.rubylode-progress-narrowing input[type=hidden][name=group][value=?]", grouping
    more = css_select("a.rubylode-progress-show-more").first
    assert more, "a show more link"
    assert_equal grouping, query_of(more["href"])["group"]
    assert_equal grouping, query_of(more["data-checklist-path"])["group"]
    name_link = focus_link_for(@upcoming)
    assert name_link, "the focused stage's name is a link"
    assert_equal grouping, query_of(name_link["href"])["group"]
  end

  test "a focused page keeps the chosen grouping in every link, and leaving the focus restores it" do
    build_project
    4.times { |count| Issue.generate!(project: @project, fixed_version: @upcoming, author: @developer, subject: "More #{count}") }
    RubylodeProgress::ProjectSetting.create!(project: @project, checklist_rows_per_section: 5)
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @upcoming.id, filter: "all", group: "category" }

    assert_response :success
    assert_grouping_kept_in_links("category")
    assert_select "a.rubylode-progress-group__button", count: 0

    get css_select("a.rubylode-progress-filter[data-filter-name=open]").first["href"]

    assert_response :success
    assert_grouping_kept_in_links("category")
    show_all = css_select("a.rubylode-progress-tracker__show-all").first
    assert_equal "category", query_of(show_all["href"])["group"]
    assert_nil query_of(show_all["href"])["stage"]

    get show_all["href"]

    assert_response :success
    assert_select "a.rubylode-progress-group__button[aria-pressed=true][data-group-name=category]", count: 1
    assert_select "a.rubylode-progress-tracker__show-all", count: 0
  end

  test "the checklist fragment of a focused page keeps the chosen grouping in its links" do
    build_project
    4.times { |count| Issue.generate!(project: @project, fixed_version: @upcoming, author: @developer, subject: "More #{count}") }
    RubylodeProgress::ProjectSetting.create!(project: @project, checklist_rows_per_section: 5)
    log_user("jsmith", "jsmith")

    get checklist_path, params: { stage: @upcoming.id, filter: "all", group: "category" }

    assert_response :success
    assert_empty addresses_on_the_page.grep(/group=flat/)
    assert_not_includes response.body, "group=flat"
    css_select("a.rubylode-progress-filter, a.rubylode-progress-show-more").each do |link|
      assert_equal "category", query_of(link["href"])["group"], link["href"]
      assert_equal "category", query_of(link["data-checklist-path"])["group"], link["data-checklist-path"]
    end
    assert_select "form.rubylode-progress-narrowing input[type=hidden][name=group][value=category]", count: 1
  end

  test "the unfocused page keeps its group-by links and carries no stage or flat grouping" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path, params: { filter: "all", group: "category" }

    assert_response :success
    assert_not_includes response.body, "group=flat"
    buttons = css_select("a.rubylode-progress-group__button")
    assert_equal %w[version category parent], buttons.map { |button| button["data-group-name"] }
    assert_equal "category", css_select("a.rubylode-progress-group__button[aria-pressed=true]").first["data-group-name"]
    css_select("a.rubylode-progress-filter").each do |pill|
      assert_equal "category", query_of(pill["href"])["group"]
      assert_not_includes query_of(pill["href"]).keys, "stage"
    end
    assert_select "form.rubylode-progress-narrowing input[type=hidden][name=group][value=category]", count: 1
  end

  test "dragging targets survive the focus and the rail gains no drop target markup" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path
    rail_attributes = css_select("ol.rubylode-progress-track *").flat_map { |node| node.attribute_nodes.map(&:name) }.uniq.reject { |name| name == "class" || name == "style" }

    get progress_path, params: { stage: @upcoming.id }

    assert_response :success
    assert_select "details.rubylode-progress-stage[data-version-id=?]", @upcoming.id.to_s
    focused_attributes = css_select("ol.rubylode-progress-track *").flat_map { |node| node.attribute_nodes.map(&:name) }.uniq
    assert_empty focused_attributes - rail_attributes - %w[class style href aria-label]
    assert_select "ol.rubylode-progress-track [data-version-id], ol.rubylode-progress-track [data-refuse-reason]", count: 0
  end

  test "the page that is not focused has no focus classes, rail links or show all link" do
    build_project
    log_user("jsmith", "jsmith")

    get progress_path

    assert_response :success
    assert_select "[class*=track__stage--focused], [class*=track__stage--dimmed]", count: 0
    assert_select "a.rubylode-progress-tracker__show-all", count: 0
    assert_select "a.rubylode-progress-track__focus-link", count: 0
  end

  test "a focused stage inside the rail's finished-stage summary mark keeps that mark as it is" do
    build_project
    Array.new(12) do |index|
      version = Version.generate!(project: @project, name: "Done #{index + 1}", effective_date: Date.new(2025, 1, 1) >> index)
      2.times { Issue.generate!(project: @project, fixed_version: version, author: @manager, status_id: CLOSED_STATUS_ID) }
      version.update!(status: "closed")
      version
    end
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @current.id }

    assert_response :success
    assert_select "li.rubylode-progress-track__stage--summary", count: 1
    assert_select "li.rubylode-progress-track__stage--summary a.rubylode-progress-track__ellipsis", count: 1
    assert_select "li.rubylode-progress-track__stage--summary a.rubylode-progress-track__focus-link", count: 0
    assert_select "li.rubylode-progress-track__stage--summary.rubylode-progress-track__stage--dimmed", count: 0
    assert_select "li.rubylode-progress-track__stage--focused", count: 1
  end

  # Every link of the page that opens a modal, by where it sits, so a test can read each one's address.
  def modal_links
    { "row quick edit" => css_select("li.rubylode-progress-row a.rubylode-progress-edit"),
      "row item" => css_select("li.rubylode-progress-row a.rubylode-progress-item-link"),
      "step quick edit" => css_select("li.rubylode-progress-step a.rubylode-progress-edit"),
      "step item" => css_select("li.rubylode-progress-step a.rubylode-progress-item-link"),
      "stage plus" => css_select("a.rubylode-progress-add"),
      "new issue button" => css_select("a.rubylode-progress-new-issue-button"),
      "stage status button" => css_select("a.rubylode-progress-status-button") }
  end

  test "every link that opens a modal carries the focused stage" do
    build_project
    Role.find(1).add_permission!(:manage_versions)
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @current.id, filter: "all" }

    assert_response :success
    modal_links.each do |name, links|
      assert_operator links.size, :>, 0, "the focused page has a #{name} link"
      links.each { |link| assert_equal @current.id.to_s, query_of(link["href"])["stage"], "#{name} #{link["href"]}" }
    end
  end

  test "the same links on the page that is not focused carry no stage" do
    build_project
    Role.find(1).add_permission!(:manage_versions)
    log_user("jsmith", "jsmith")

    get progress_path, params: { filter: "all" }

    assert_response :success
    modal_links.each do |name, links|
      assert_operator links.size, :>, 0, "the page has a #{name} link"
      links.each { |link| assert_not_includes query_of(link["href"]).keys, "stage", "#{name} #{link["href"]}" }
    end
  end

  def back_url_of(link) = Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)["back_url"]

  test "the full new-issue form comes back to the focused stage, and to the page when not focused" do
    build_project
    IssueCustomField.generate!(name: "Customer code", field_format: "string", is_required: true,
                               is_for_all: true, tracker_ids: Tracker.pluck(:id))
    log_user("jsmith", "jsmith")

    get progress_path, params: { stage: @current.id, filter: "all" }

    ["a.rubylode-progress-new-issue-button", "a.rubylode-progress-add"].each do |selector|
      back_url = back_url_of(css_select(selector).first)
      assert_equal progress_path, URI.parse(back_url).path, selector
      assert_equal @current.id.to_s, query_of(back_url)["stage"], selector
    end
    assert_equal "all", query_of(back_url_of(css_select("a.rubylode-progress-new-issue-button").first))["filter"]

    get progress_path, params: { filter: "all" }

    ["a.rubylode-progress-new-issue-button", "a.rubylode-progress-add"].each do |selector|
      assert_not_includes query_of(back_url_of(css_select(selector).first)).keys, "stage", selector
    end
  end

  test "the item modal and its back address keep the focused stage" do
    build_project
    log_user("jsmith", "jsmith")

    get "#{progress_path}/issues/#{@current_open_issue.id}/item", params: { filter: "all", stage: @upcoming.id }, xhr: true

    assert_response :success
    back_url = CGI.unescape(response.body[/back_url=([^"\\]+)/, 1].to_s)
    assert_equal "#{progress_path}?filter=all&stage=#{@upcoming.id}", back_url
  end

  test "a stage that is not one of the viewer's is dropped from the item modal's back address" do
    build_project
    log_user("jsmith", "jsmith")

    get "#{progress_path}/issues/#{@current_open_issue.id}/item", params: { stage: "abc" }, xhr: true

    assert_response :success
    assert_not_includes response.body, "stage="
  end

  # The cached pencils, plus and status button read the focus, so a focused render must not leave its links in the entry
  # the unfocused page reads, nor the other way round.
  test "a focused render and an unfocused render of one stage never share cached links" do
    original_caching = ActionController::Base.perform_caching
    original_store = ActionController::Base.cache_store
    cached_selectors = ["li.rubylode-progress-step a.rubylode-progress-edit", "li.rubylode-progress-step a.rubylode-progress-item-link",
                        "a.rubylode-progress-add", "a.rubylode-progress-status-button"]
    stage_of_links = lambda do |selector|
      css_select(selector).map { |link| query_of(link["href"])["stage"] }.uniq
    end
    build_project
    Role.find(1).add_permission!(:manage_versions)
    log_user("jsmith", "jsmith")

    [%i[focused unfocused], %i[unfocused focused]].each do |order|
      ActionController::Base.perform_caching = true
      ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
      order.each do |kind|
        get progress_path, params: kind == :focused ? { stage: @current.id } : {}
        assert_response :success
        cached_selectors.each do |selector|
          expected = kind == :focused ? [@current.id.to_s] : [nil]
          assert_equal expected, stage_of_links.call(selector), "#{order.join(" then ")}: #{kind} #{selector}"
        end
      end
    end
  ensure
    ActionController::Base.perform_caching = original_caching
    ActionController::Base.cache_store = original_store
  end
end
