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

class ChecklistNarrowingTest < ActiveSupport::TestCase
  Named = Struct.new(:name)
  IssueDouble = Struct.new(:id, :assigned_to_id, :assigned_to, :tracker_id, :tracker, :category_id, :category, keyword_init: true)
  Item = Struct.new(:issue)

  ADA = Named.new("Ada")
  BOB = Named.new("Bob")
  BUG = Named.new("Bug")
  TASK = Named.new("Task")
  UI = Named.new("UI")

  def item(id, assignee: nil, tracker: BUG, category: nil)
    assignees = { ADA => 10, BOB => 11 }
    trackers = { BUG => 1, TASK => 2 }
    categories = { UI => 7 }
    Item.new(IssueDouble.new(id: id, assigned_to_id: assignees[assignee], assigned_to: assignee, tracker_id: trackers.fetch(tracker),
                             tracker: tracker, category_id: categories[category], category: category))
  end

  def items
    @items ||= [item(1, assignee: ADA, category: UI), item(2, assignee: ADA, tracker: TASK), item(3, assignee: BOB), item(4)]
  end

  test "the offered values are those that occur, with counts, sorted by name, none last" do
    options = RubylodeProgress::ChecklistNarrowing.options_for(items)

    assert_equal [["10", "Ada", 2], ["11", "Bob", 1], ["none", I18n.t("rubylode_progress.narrowing.unassigned"), 1]],
                 options[:assignee].map { |option| [option.value, option.label, option.count] }
    assert_equal [["1", "Bug", 3], ["2", "Task", 1]], options[:tracker].map { |option| [option.value, option.label, option.count] }
    assert_equal [["7", "UI", 1], ["none", I18n.t("rubylode_progress.no_category"), 3]],
                 options[:category].map { |option| [option.value, option.label, option.count] }
  end

  test "a value that is not offered, or not a string, falls back to any" do
    options = RubylodeProgress::ChecklistNarrowing.options_for(items)

    selection = RubylodeProgress::ChecklistNarrowing.resolve({ "assignee" => "99", "tracker" => "2", "category" => ["7"] }, options)

    assert_equal({ "assignee" => "any", "tracker" => "2", "category" => "any" }, selection)
    assert_equal "any", RubylodeProgress::ChecklistNarrowing.resolve({}, options)["assignee"]
  end

  test "each choice narrows the items and the choices combine" do
    narrowing = RubylodeProgress::ChecklistNarrowing

    assert_equal [1, 2], narrowing.apply({ "assignee" => "10", "tracker" => "any", "category" => "any" }, items).map { |row| row.issue.id }
    assert_equal [4], narrowing.apply({ "assignee" => "none", "tracker" => "any", "category" => "any" }, items).map { |row| row.issue.id }
    assert_equal [1], narrowing.apply({ "assignee" => "10", "tracker" => "1", "category" => "7" }, items).map { |row| row.issue.id }
    assert_equal [2, 3, 4], narrowing.apply({ "assignee" => "any", "tracker" => "any", "category" => "none" }, items).map { |row| row.issue.id }
  end

  test "nothing chosen leaves the items as they are and reports no narrowing" do
    any = { "assignee" => "any", "tracker" => "any", "category" => "any" }

    assert_equal items, RubylodeProgress::ChecklistNarrowing.apply(any, items)
    assert_empty RubylodeProgress::ChecklistNarrowing.parameters_for(any)
    assert_equal({ "tracker" => "2" }, RubylodeProgress::ChecklistNarrowing.parameters_for(any.merge("tracker" => "2")))
  end
end
