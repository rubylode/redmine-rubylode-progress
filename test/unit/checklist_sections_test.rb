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
  Named = Struct.new(:name)
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
end
