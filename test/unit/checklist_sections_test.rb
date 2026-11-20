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

class ChecklistSectionsTest < ActiveSupport::TestCase
  Item = RubylodeProgress::ProjectProgress::Item
  Named = Struct.new(:name, :id)
  ParentDouble = Struct.new(:id, :subject, :visible) do
    def visible?(_viewer) = visible != false
  end
  VIEWER = Object.new
  IssueDouble = Struct.new(:id, :fixed_version, :category, :parent, keyword_init: true)
  CategoryDouble = Struct.new(:id, :name)

  def item(id, status: :to_do, version: nil, category: nil, parent: nil)
    issue = IssueDouble.new(id: id, fixed_version: version, category: category, parent: parent)
    Item.new(issue: issue, status: status, step_number: "1.#{id}")
  end

  test "by version, sections follow the order the items arrive in and count their done items" do
    alpha = Named.new("Alpha")
    beta = Named.new("Beta")
    items = [item(1, status: :done, version: alpha), item(2, version: alpha), item(3, version: beta)]

    sections = RubylodeProgress::ChecklistSections.group(items, by: "version", viewer: VIEWER)

    assert_equal ["Alpha", "Beta"], sections.map(&:title)
    assert_equal [1, 0], sections.map(&:done_count)
    assert_equal [[1, 2], [3]], sections.map { |section| section.items.map { |row| row.issue.id } }
  end

  test "by category, sections are by name and issues without one go last under No category" do
    items = [item(1), item(2, category: Named.new("Zebra")), item(3, category: Named.new("Apple"))]

    sections = RubylodeProgress::ChecklistSections.group(items, by: "category", viewer: VIEWER)

    assert_equal ["Apple", "Zebra", I18n.t("rubylode_progress.no_category")], sections.map(&:title)
    assert_equal [[1]], sections.last.items.map { |row| [row.issue.id] }
  end

  test "by parent, a parent issue in a counted version is a row too" do
    parent = ParentDouble.new(5, "The parent")
    items = [item(5), item(6, parent: parent), item(7, parent: parent)]

    sections = RubylodeProgress::ChecklistSections.group(items, by: "parent", viewer: VIEWER)

    assert_equal ["#5 The parent", I18n.t("rubylode_progress.no_parent")], sections.map(&:title)
    assert_equal [[6, 7], [5]], sections.map { |section| section.items.map { |row| row.issue.id } }
  end

  test "by parent, a parent the viewer cannot see shows its number but never its subject" do
    hidden = ParentDouble.new(9, "Secret subject", false)
    items = [item(10, parent: hidden)]

    sections = RubylodeProgress::ChecklistSections.group(items, by: "parent", viewer: VIEWER)

    assert_equal ["#9"], sections.map(&:title)
  end

  test "grouping keeps the same items" do
    parent = ParentDouble.new(5, "The parent")
    items = [item(1, category: Named.new("A"), parent: parent, version: Named.new("V")), item(2), item(3, parent: parent)]

    %w[version category parent].each do |by|
      grouped = RubylodeProgress::ChecklistSections.group(items, by: by, viewer: VIEWER).flat_map(&:items)
      assert_equal items.map { |row| row.issue.id }.sort, grouped.map { |row| row.issue.id }.sort, by
    end
  end

  test "one category name is one section, even when two categories of different projects share it" do
    items = [item(1, category: CategoryDouble.new(10, "Safety")), item(2, category: CategoryDouble.new(20, "Safety")),
             item(3, category: CategoryDouble.new(30, "Surface"))]

    sections = RubylodeProgress::ChecklistSections.group(items, by: "category", viewer: VIEWER)

    assert_equal %w[Safety Surface], sections.map(&:title)
    assert_equal [[1, 2], [3]], sections.map { |section| section.items.map { |row| row.issue.id } }
  end

  test "a filtered list keeps each section's tally and percent over all its items, and drops sections with no rows" do
    safety = CategoryDouble.new(1, "Safety")
    surface = CategoryDouble.new(2, "Surface")
    everything = [item(1, status: :done, category: safety), item(2, category: safety), item(3, status: :done, category: surface)]
    open_only = everything.reject { |row| row.status == :done }

    sections = RubylodeProgress::ChecklistSections.group(open_only, by: "category", viewer: VIEWER, scope_items: everything)

    assert_equal ["Safety"], sections.map(&:title)
    assert_equal 1, sections.first.items.size
    assert_equal 2, sections.first.total_count
    assert_equal 1, sections.first.total_done_count
    assert_equal 50, sections.first.percent
  end
  test "sections carry a stable key: the version, category or parent id, and none for the empty one" do
    parent = ParentDouble.new(5, "The parent")
    by_version = RubylodeProgress::ChecklistSections.group([item(1, version: Named.new("A", 31)), item(2, version: Named.new("B", 32))], by: "version", viewer: VIEWER)
    by_category = RubylodeProgress::ChecklistSections.group([item(1, category: CategoryDouble.new(4, "Z")), item(2)], by: "category", viewer: VIEWER)
    by_parent = RubylodeProgress::ChecklistSections.group([item(1, parent: parent), item(2)], by: "parent", viewer: VIEWER)

    assert_equal %w[31 32], by_version.map(&:key)
    assert_equal %w[4 none], by_category.map(&:key)
    assert_equal %w[5 none], by_parent.map(&:key)
  end

  test "flat grouping is one section without a title over all the items" do
    items = [item(1, status: :done, version: Named.new("Alpha", 1)), item(2, version: Named.new("Beta", 2)), item(3)]

    sections = RubylodeProgress::ChecklistSections.group(items, by: "flat", viewer: VIEWER)

    assert_equal 1, sections.size
    assert_equal "all", sections.first.key
    assert_nil sections.first.title
    assert_nil sections.first.version
    assert_equal [1, 2, 3], sections.first.items.map { |row| row.issue.id }
    assert_equal 3, sections.first.total_count
    assert_equal 1, sections.first.total_done_count
  end

  test "limit cuts each section to its first rows, counts the rest, and keeps the expanded section whole" do
    alpha = Named.new("Alpha", 1)
    beta = Named.new("Beta", 2)
    items = (1..5).map { |id| item(id, version: alpha) } + (6..8).map { |id| item(id, version: beta) }
    sections = RubylodeProgress::ChecklistSections.group(items, by: "version", viewer: VIEWER)

    cut = RubylodeProgress::ChecklistSections.limit(sections, rows_per_section: 3)
    assert_equal [[1, 2, 3], [6, 7, 8]], cut.map { |section| section.items.map { |row| row.issue.id } }
    assert_equal [2, 0], cut.map(&:hidden_count)
    assert_equal [5, 3], cut.map(&:row_count)
    assert_equal [5, 3], cut.map(&:total_count)

    expanded = RubylodeProgress::ChecklistSections.limit(sections, rows_per_section: 3, expanded_key: "1")
    assert_equal [5, 3], expanded.map { |section| section.items.size }
    assert_equal [0, 0], expanded.map(&:hidden_count)

    unknown = RubylodeProgress::ChecklistSections.limit(sections, rows_per_section: 3, expanded_key: "999")
    assert_equal [3, 3], unknown.map { |section| section.items.size }
    assert_equal 5, sections.first.items.size, "the grouped sections are not changed"
  end
end
