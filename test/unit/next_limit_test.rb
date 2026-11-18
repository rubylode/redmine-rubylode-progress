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


require File.expand_path("../test_helper", __dir__)
require File.expand_path("../support/status_doubles", __dir__)

class NextLimitTest < ActiveSupport::TestCase
  include StatusDoubles

  test "the Next limit takes 3 by priority, then due date with none last, then issue number" do
    current_stage_issues = [
      issue(1, priority_position: LOW_PRIORITY, due_date: Date.new(2026, 11, 19)),
      issue(2, priority_position: NORMAL_PRIORITY),
      issue(3, priority_position: HIGH_PRIORITY, due_date: Date.new(2026, 11, 27)),
      issue(4, priority_position: NORMAL_PRIORITY, due_date: Date.new(2026, 12, 20)),
      issue(5, priority_position: HIGH_PRIORITY, due_date: Date.new(2026, 11, 23))
    ]

    assert_equal [5, 3, 4], next_ids(current_stage_issues, limit: 3)
  end

  test "issues that Need you, Wait or are in progress do not use up the limit" do
    current_stage_issues = [
      issue(1, priority_position: HIGH_PRIORITY, assigned_to_id: VIEWER_ID),
      issue(2, priority_position: HIGH_PRIORITY, blocked: true),
      issue(3, priority_position: HIGH_PRIORITY, status_id: WAITING_STATUS_ID),
      issue(4, priority_position: HIGH_PRIORITY, status_id: IN_PROGRESS_STATUS_ID),
      issue(5, priority_position: HIGH_PRIORITY, status_id: CLOSED_STATUS_ID, closed: true),
      issue(6, priority_position: LOW_PRIORITY),
      issue(7, priority_position: LOW_PRIORITY),
      issue(8, priority_position: LOW_PRIORITY),
      issue(9, priority_position: LOW_PRIORITY)
    ]

    assert_equal [6, 7, 8], next_ids(current_stage_issues, limit: 3)
  end

  test "a limit of 5 takes 5; a limit of 0 takes none; no current stage takes none" do
    current_stage_issues = (1..6).map { |id| issue(id) }

    assert_equal [1, 2, 3, 4, 5], next_ids(current_stage_issues, limit: 5)
    assert_equal [], next_ids(current_stage_issues, limit: 0)
    assert_equal [], next_ids(nil, limit: 3)
  end

  private

  def next_ids(current_stage_issues, limit:)
    RubylodeProgress::NextLimit.issue_ids_for(current_stage_issues, limit: limit, status_rule_without_next: status_rule)
  end
end
