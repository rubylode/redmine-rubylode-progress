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

class ItemStatusRuleTest < ActiveSupport::TestCase
  include StatusDoubles

  test "a closed issue is Done even when assigned to the viewer and blocked" do
    closed = issue(1, status_id: CLOSED_STATUS_ID, closed: true, assigned_to_id: VIEWER_ID, blocked: true)

    assert_equal :done, status_rule.status_for(closed)
  end

  test "an open issue assigned to the viewer Needs you even when blocked" do
    mine = issue(2, assigned_to_id: VIEWER_ID, blocked: true)

    assert_equal :needs_you, status_rule.status_for(mine)
  end

  test "an open issue assigned to a group the viewer is in Needs you" do
    ours = issue(3, assigned_to_id: VIEWER_GROUP_ID)

    assert_equal :needs_you, status_rule(viewer_group_ids: [VIEWER_GROUP_ID]).status_for(ours)
  end

  test "an anonymous viewer never sees Needs you" do
    unassigned = issue(4)
    someone_elses = issue(5, assigned_to_id: OTHER_USER_ID)
    anonymous = status_rule(viewer_id: nil, viewer_group_ids: [])

    assert_equal :to_do, anonymous.status_for(unassigned)
    assert_equal :to_do, anonymous.status_for(someone_elses)
  end

  test "a blocked issue is Waiting even when its status is in progress" do
    blocked = issue(6, status_id: IN_PROGRESS_STATUS_ID, blocked: true)

    assert_equal :waiting, status_rule.status_for(blocked)
  end

  test "a status listed as both in progress and waiting gives Waiting" do
    both = issue(7, status_id: 4)
    rule = status_rule(in_progress_status_ids: [4], waiting_status_ids: [4])

    assert_equal :waiting, rule.status_for(both)
  end

  test "an issue in a waiting status is Waiting" do
    on_hold = issue(8, status_id: WAITING_STATUS_ID)

    assert_equal :waiting, status_rule.status_for(on_hold)
  end

  test "an issue in an in-progress status is Next in any stage, not only the current one" do
    started_elsewhere = issue(9, status_id: IN_PROGRESS_STATUS_ID)

    assert_equal :next, status_rule(next_issue_ids: [99]).status_for(started_elsewhere)
  end

  test "an issue picked by the Next limit is Next; any other open issue is To do" do
    picked = issue(10)
    not_picked = issue(11)
    rule = status_rule(next_issue_ids: [10])

    assert_equal :next, rule.status_for(picked)
    assert_equal :to_do, rule.status_for(not_picked)
  end
end
