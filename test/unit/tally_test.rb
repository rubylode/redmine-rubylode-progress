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

class TallyTest < ActiveSupport::TestCase
  Item = RubylodeProgress::ProjectProgress::Item

  def items_with(*statuses)
    statuses.map { |status| Item.new(issue: nil, status: status, step_number: "1.1") }
  end

  test "Still open counts everything not Done" do
    tally = RubylodeProgress::Tally.from(items_with(:done, :done, :next, :needs_you, :waiting, :to_do))

    assert_equal 2, tally.done_count
    assert_equal 1, tally.next_count
    assert_equal 1, tally.needs_you_count
    assert_equal 4, tally.still_open_count
  end

  test "an empty scope tallies zero everywhere" do
    tally = RubylodeProgress::Tally.from([])

    assert_equal [0, 0, 0, 0], [tally.done_count, tally.next_count, tally.needs_you_count, tally.still_open_count]
  end
end
