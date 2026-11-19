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
require File.expand_path("../support/stage_doubles", __dir__)

class StageNoticesTest < ActiveSupport::TestCase
  include StageDoubles

  TODAY = Date.new(2026, 11, 19)

  def stages_for(versions, issues)
    stage_list(versions, issues).stages
  end

  test "a partial stage past its due date gives a Behind notice with its days overdue and open count" do
    stages = stages_for([version(1, "Framing", TODAY - 45), version(2, "Decking", TODAY + 14)],
                        [closed_issue(1, 1), open_issue(2, 1), open_issue(3, 2), open_issue(4, 2)])

    notices = RubylodeProgress::StageNotices.for(stages, today: TODAY)

    behind = notices.find { |notice| notice.kind == :behind }
    assert_equal ["Framing", 45, 1, 0], [behind.stage_name, behind.days, behind.open_count, behind.more_count]
  end

  test "several partial stages: the oldest first, the rest counted as more" do
    stages = stages_for([version(1, "Alpha", TODAY - 20), version(2, "Beta", TODAY - 60), version(3, "Gamma", TODAY - 5),
                         version(4, "Now", TODAY + 9)],
                        [open_issue(1, 1), open_issue(2, 2), open_issue(3, 2), open_issue(4, 3), open_issue(5, 4), closed_issue(6, 4)])

    behind = RubylodeProgress::StageNotices.for(stages, today: TODAY).find { |notice| notice.kind == :behind }

    assert_equal ["Beta", 60, 2, 2], [behind.stage_name, behind.days, behind.open_count, behind.more_count]
  end

  test "a partial stage that is not yet due, or has no date, gives no Behind notice" do
    stages = stages_for([version(1, "Early", TODAY + 2), version(2, "Undated"), version(3, "Now", TODAY + 9)],
                        [open_issue(1, 1), open_issue(2, 2), open_issue(3, 3), closed_issue(4, 3)])

    notices = RubylodeProgress::StageNotices.for(stages, today: TODAY)

    assert_empty(notices.select { |notice| notice.kind == :behind })
  end

  test "the current stage with a due date always gives a Due soon notice with its open count and days left" do
    stages = stages_for([version(1, "Decking", TODAY + 14)], [closed_issue(1, 1), open_issue(2, 1), open_issue(3, 1)])

    notice = RubylodeProgress::StageNotices.for(stages, today: TODAY).first

    assert_equal [:due_soon, "Decking", 14, 2], [notice.kind, notice.stage_name, notice.days, notice.open_count]
  end

  test "the current stage without a date gives no notice, and at most two notices are returned" do
    undated = stages_for([version(1, "Decking")], [open_issue(1, 1)])
    assert_empty RubylodeProgress::StageNotices.for(undated, today: TODAY)

    stages = stages_for([version(1, "Old", TODAY - 9), version(2, "Older", TODAY - 30), version(3, "Now", TODAY + 1)],
                        [open_issue(1, 1), open_issue(2, 2), open_issue(3, 3), closed_issue(4, 3)])
    assert_equal %i[behind due_soon], RubylodeProgress::StageNotices.for(stages, today: TODAY).map(&:kind)
  end

  test "a current stage already past its date is a Behind notice too" do
    stages = stages_for([version(1, "Decking", TODAY - 3)], [open_issue(1, 1)])

    notice = RubylodeProgress::StageNotices.for(stages, today: TODAY).first

    assert_equal [:behind, 3, 1], [notice.kind, notice.days, notice.open_count]
  end
end
