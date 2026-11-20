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

# Slice 21: with many sections only the first few list rows; a folded section keeps its heading and loads its rows when opened.
class LazySectionsTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  setup do
    @manager = User.find(2)
    Role.find(1).add_permission!(:view_rubylode_progress)
    Role.find(2).add_permission!(:view_rubylode_progress)
    log_user("jsmith", "jsmith")
  end

  # section_count versions in date order, each holding rows_each open issues named "Section 03 row 2".
  def build_project(section_count, rows_each: 3, name: "Sectioned")
    @project = Project.generate!(name: name, is_public: false)
    @project.enable_module!(:rubylode_progress)
    @project.enable_module!(:issue_tracking)
    User.add_to_project(@manager, @project, Role.find(1))
    @versions = Array.new(section_count) do |index|
      version = Version.generate!(project: @project, name: format("Section %02d", index + 1), effective_date: Date.new(2031, 1, 1) >> index)
      rows_each.times { |row| Issue.generate!(project: @project, fixed_version: version, author: @manager, subject: format("Section %02d row %d", index + 1, row + 1)) }
      version
    end
    @project
  end

  def progress_path = "/projects/#{@project.identifier}/progress"

  def checklist_path = "#{progress_path}/checklist"

  def section_node(version) = css_select(".rubylode-progress-section[data-section-key='#{version.id}']").first

  def folded_sections = css_select(".rubylode-progress-section[data-lazy-section-path]")

  def query_of(address) = Rack::Utils.parse_query(URI.parse(address).query)

  test "with more than 8 sections only the first 5 list rows and the rest are folded with heading, tally, meter and links" do
    build_project(12)

    get progress_path

    assert_response :success
    assert_select ".rubylode-progress-section", count: 12
    assert_select ".rubylode-progress-section[open]", count: 5
    assert_equal 7, folded_sections.size
    assert_equal 15, css_select(".rubylode-progress-row").size
    assert_select ".rubylode-progress-row__title", text: /Section 06 row/, count: 0
    folded = section_node(@versions[8])
    assert_nil folded["open"]
    assert_includes folded.text, "Section 09"
    assert_includes folded.text, "3 open"
    assert folded.css("[class*='meter']").any?
    path = folded["data-lazy-section-path"]
    assert_equal checklist_path, path.split("?").first
    assert_equal @versions[8].id.to_s, query_of(path)["open"]
    assert_equal "open", query_of(path)["filter"]
    link = folded.css("a.rubylode-progress-section__lazy-link").first
    assert_equal "Show the 3 issues", link.text.strip
    assert_equal @versions[8].id.to_s, query_of(link["href"])["open"]
    assert_equal progress_path, link["href"].split("?").first
  end

  test "with 8 or fewer sections nothing is folded" do
    build_project(8)

    get progress_path

    assert_select ".rubylode-progress-section[open]", count: 8
    assert_equal 0, folded_sections.size
    assert_equal 24, css_select(".rubylode-progress-row").size
  end

  test "the route with open returns that section open with its first rows and Show more" do
    build_project(12, rows_each: 14)

    get checklist_path, params: { filter: "open", open: @versions[9].id.to_s }

    assert_response :success
    node = section_node(@versions[9])
    assert node["open"]
    assert_nil node["data-lazy-section-path"]
    assert_equal 10, node.css(".rubylode-progress-row").size
    assert_select "a.rubylode-progress-show-more", text: "Show 4 more"
    assert_nil section_node(@versions[10])["open"]
  end

  test "an unknown, blank or non-string open key returns the checklist as it is" do
    build_project(12)
    get checklist_path, params: { filter: "open" }
    plain = css_select(".rubylode-progress-section[open]").size

    [{ open: "999999" }, { open: "" }, { open: "abc,;<script>" }, { open: { a: "b" } }].each do |extra|
      get checklist_path, params: { filter: "open" }.merge(extra)
      assert_response :success
      assert_equal plain, css_select(".rubylode-progress-section[open]").size
    end
  end

  test "the route keeps the filter and the narrowing" do
    build_project(12)
    Issue.where(project_id: @project.id, fixed_version_id: @versions[9].id).first.update!(assigned_to_id: @manager.id)

    get checklist_path, params: { filter: "open", open: @versions[9].id.to_s, assignee: @manager.id.to_s }

    assert_response :success
    assert_select ".rubylode-progress-section", count: 1
    assert section_node(@versions[9])["open"]
    assert_equal 1, css_select(".rubylode-progress-row").size
  end

  test "the route keeps the grouping" do
    build_project(12)
    category = IssueCategory.create!(project: @project, name: "Plumbing")
    @versions.each { |version| Issue.where(fixed_version_id: version.id).update_all(category_id: category.id) }

    get checklist_path, params: { filter: "open", group: "category", open: category.id.to_s }

    assert_response :success
    assert_select ".rubylode-progress-section", count: 1
    assert_select ".rubylode-progress-section[open]", count: 1
  end

  test "open on the full page renders those sections open and a path keeps the other parameters" do
    build_project(12)

    get progress_path, params: { open: "#{@versions[9].id},#{@versions[11].id}" }

    assert_response :success
    assert_select ".rubylode-progress-section[open]", count: 7
    assert section_node(@versions[9])["open"]
    assert section_node(@versions[11])["open"]
    assert_nil section_node(@versions[8])["open"]
    assert_equal 21, css_select(".rubylode-progress-row").size
  end

  test "more than 10 open keys are cut at 10" do
    build_project(20)
    keys = @versions.last(12).map(&:id).join(",")

    get progress_path, params: { open: keys }

    assert_response :success
    assert_select ".rubylode-progress-section[open]", count: 15
    assert section_node(@versions[17])["open"]
    assert_nil section_node(@versions[18])["open"]
    assert_nil section_node(@versions[19])["open"]
  end

  test "a folded version section is still a drop target and its loaded rows are draggable" do
    build_project(12)

    get progress_path

    folded = section_node(@versions[9])
    assert_equal @versions[9].id.to_s, folded["data-version-id"]
    assert_equal 0, folded.css(".rubylode-progress-row").size

    get checklist_path, params: { filter: "open", open: @versions[9].id.to_s }

    node = section_node(@versions[9])
    assert_equal @versions[9].id.to_s, node["data-version-id"]
    assert_select ".rubylode-progress-section[data-section-key='#{@versions[9].id}'] .rubylode-progress-row[draggable=true]", count: 3
  end

  test "the size of the page under All does not grow with the sections beyond the fifth" do
    build_project(12, name: "Twelve")
    get progress_path, params: { filter: "all" }
    rows_in_twelve = css_select(".rubylode-progress-row").size
    twelve_rows_markup = css_select(".rubylode-progress-row").sum { |row| row.to_s.size }
    assert_equal 15, rows_in_twelve

    build_project(40, name: "Forty")
    get progress_path, params: { filter: "all" }

    assert_equal rows_in_twelve, css_select(".rubylode-progress-row").size
    assert_in_delta twelve_rows_markup, css_select(".rubylode-progress-row").sum { |row| row.to_s.size }, twelve_rows_markup * 0.01
    assert_equal 35, folded_sections.size
  end

  test "opening sections adds no queries per issue" do
    build_project(12, rows_each: 12)
    counts = [1, 5].map do |opened|
      keys = @versions.last(opened).map(&:id).join(",")
      QueryCounter.count { get checklist_path, params: { filter: "open", open: keys } }
    end

    assert_operator counts.last - counts.first, :<=, 4
    assert_operator counts.last, :<=, 51
  end
end
