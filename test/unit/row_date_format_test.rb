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

class RowDateFormatTest < ActiveSupport::TestCase
  Format = RubylodeProgress::RowDateFormat
  TODAY = Date.new(2026, 11, 19)

  test "this year drops the year from a month-day-year pattern" do
    assert_equal "11/27", Format.format(Date.new(2026, 11, 27), today: TODAY, pattern: "%m/%d/%Y")
  end

  test "another year gets a two-digit year" do
    assert_equal "01/03/27", Format.format(Date.new(2027, 1, 3), today: TODAY, pattern: "%m/%d/%Y")
  end

  test "a day-month-year pattern keeps its order and separator" do
    assert_equal "27.11", Format.format(Date.new(2026, 11, 27), today: TODAY, pattern: "%d.%m.%Y")
    assert_equal "03.01.27", Format.format(Date.new(2027, 1, 3), today: TODAY, pattern: "%d.%m.%Y")
  end

  test "a year-first pattern drops the year with its separator" do
    assert_equal "11-27", Format.format(Date.new(2026, 11, 27), today: TODAY, pattern: "%Y-%m-%d")
    assert_equal "27-01-03", Format.format(Date.new(2027, 1, 3), today: TODAY, pattern: "%Y-%m-%d")
  end

  test "a pattern that is not plain gives nil, so Redmine's own format stays" do
    assert_nil Format.format(Date.new(2026, 11, 27), today: TODAY, pattern: "%d %b %Y")
    assert_nil Format.format(Date.new(2026, 11, 27), today: TODAY, pattern: "%B %d, %Y")
    assert_nil Format.format(Date.new(2026, 11, 27), today: TODAY, pattern: "%d/%Y/%m")
    assert_nil Format.format(Date.new(2026, 11, 27), today: TODAY, pattern: "")
  end
end
