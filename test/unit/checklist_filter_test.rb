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
  Item = Struct.new(:status)

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

  test "each filter keeps the right items" do
    items = %i[done needs_you waiting next to_do].map { |status| Item.new(status) }

    assert_equal %i[needs_you waiting next to_do], RubylodeProgress::ChecklistFilter.apply("open", items).map(&:status)
    assert_equal %i[needs_you], RubylodeProgress::ChecklistFilter.apply("needs_you", items).map(&:status)
    assert_equal %i[done], RubylodeProgress::ChecklistFilter.apply("done", items).map(&:status)
    assert_equal items, RubylodeProgress::ChecklistFilter.apply("all", items)
  end
end
