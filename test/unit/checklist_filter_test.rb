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

class ChecklistFilterTest < ActiveSupport::TestCase
  VersionDouble = Struct.new(:effective_date)
  IssueDouble = Struct.new(:due_date, :fixed_version, keyword_init: true)
  Item = Struct.new(:status, :issue) do
    def initialize(status, issue = IssueDouble.new)
      super
    end
  end

  TODAY = Date.new(2026, 11, 19)

  def overdue_item(status: :to_do, due_date: nil, version_date: nil)
    version = version_date && VersionDouble.new(version_date)
    Item.new(status, IssueDouble.new(due_date: due_date, fixed_version: version))
  end

  test "a valid request wins over the remembered filter" do
    assert_equal "done", RubylodeProgress::ChecklistFilter.resolve(requested: "done", remembered: "needs_you")
  end

  test "a missing request uses the remembered one" do
    assert_equal "needs_you", RubylodeProgress::ChecklistFilter.resolve(requested: nil, remembered: "needs_you")
  end

  test "Open is the default" do
    assert_equal "open", RubylodeProgress::ChecklistFilter.resolve(requested: nil, remembered: nil)
    assert_equal "open", RubylodeProgress::ChecklistFilter.resolve(requested: "bogus", remembered: "waiting")
  end

  test "the filters come in the order of the pills and include Overdue and Next up" do
    assert_equal %w[needs_you overdue next open done all], RubylodeProgress::ChecklistFilter::NAMES
    assert RubylodeProgress::ChecklistFilter.valid?("overdue")
    assert RubylodeProgress::ChecklistFilter.valid?("next")
  end

  test "each filter keeps the right items" do
    items = %i[done needs_you waiting next to_do].map { |status| Item.new(status) }

    assert_equal %i[needs_you waiting next to_do], RubylodeProgress::ChecklistFilter.apply("open", items, today: TODAY).map(&:status)
    assert_equal %i[needs_you], RubylodeProgress::ChecklistFilter.apply("needs_you", items, today: TODAY).map(&:status)
    assert_equal %i[next], RubylodeProgress::ChecklistFilter.apply("next", items, today: TODAY).map(&:status)
    assert_equal %i[done], RubylodeProgress::ChecklistFilter.apply("done", items, today: TODAY).map(&:status)
    assert_equal items, RubylodeProgress::ChecklistFilter.apply("all", items, today: TODAY)
  end

  test "an issue past its own due date is overdue, and so is one with no date of its own past its version's" do
    own = overdue_item(due_date: TODAY - 1)
    inherited = overdue_item(version_date: TODAY - 5)
    own_wins = overdue_item(due_date: TODAY + 3, version_date: TODAY - 5)
    on_time = overdue_item(due_date: TODAY)
    undated = overdue_item

    kept = RubylodeProgress::ChecklistFilter.apply("overdue", [own, inherited, own_wins, on_time, undated], today: TODAY)

    assert_equal [own, inherited], kept
  end

  test "a closed issue is never overdue" do
    closed = overdue_item(status: :done, due_date: TODAY - 30)

    assert_empty RubylodeProgress::ChecklistFilter.apply("overdue", [closed], today: TODAY)
  end

  test "counts give every pill the number of rows its filter would show" do
    items = [overdue_item(status: :needs_you, due_date: TODAY - 2), overdue_item(status: :next),
             overdue_item(status: :done, due_date: TODAY - 9), overdue_item(status: :to_do, version_date: TODAY - 1)]

    counts = RubylodeProgress::ChecklistFilter.counts(items, today: TODAY)

    assert_equal({ "needs_you" => 1, "overdue" => 2, "next" => 1, "open" => 3, "done" => 1, "all" => 4 }, counts)
  end
end
