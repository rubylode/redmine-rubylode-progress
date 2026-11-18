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
require File.expand_path("../support/stage_doubles", __dir__)

class PercentRuleTest < ActiveSupport::TestCase
  include StageDoubles

  def percent(versions, issues)
    RubylodeProgress::PercentRule.percent_for(stage_list(versions, issues).stages)
  end

  test "no versions: percent nil" do
    assert_nil percent([], [])
  end

  test "all stages done: percent 100" do
    versions = [version(1, "A", Date.new(2026, 1, 1), status: "closed"), version(2, "B", Date.new(2026, 2, 1), status: "closed")]

    assert_equal 100, percent(versions, [closed_issue(1, 1)])
  end

  test "a current stage without issues counts one half" do
    versions = [
      version(1, "Done", Date.new(2026, 1, 1), status: "closed"),
      version(2, "Current", Date.new(2026, 2, 1)),
      version(3, "Upcoming", Date.new(2026, 3, 1))
    ]

    assert_equal 50, percent(versions, [closed_issue(1, 1)])
  end

  test "several open stages count their closed shares" do
    versions = [
      version(1, "Done", Date.new(2026, 1, 1), status: "closed"),
      version(2, "Three of four", Date.new(2026, 2, 1)),
      version(3, "One of four", Date.new(2026, 3, 1)),
      version(4, "Empty", Date.new(2026, 4, 1))
    ]
    issues = [
      closed_issue(1, 2), closed_issue(2, 2), closed_issue(3, 2), open_issue(4, 2),
      closed_issue(5, 3), open_issue(6, 3), open_issue(7, 3), open_issue(8, 3)
    ]

    assert_equal 50, percent(versions, issues)
  end

  test "a project with versions but no issues" do
    versions = [version(1, "A", Date.new(2026, 1, 1)), version(2, "B", Date.new(2026, 2, 1)), version(3, "C", Date.new(2026, 3, 1))]

    list = stage_list(versions, [])

    assert_equal "A", list.current_stage.version.name
    assert_equal 17, RubylodeProgress::PercentRule.percent_for(list.stages)
  end

  test "a closed version with open issues is a partial stage and counts its closed share" do
    versions = [version(1, "Shipped", Date.new(2026, 1, 1), status: "closed"), version(2, "Open", Date.new(2026, 2, 1))]
    issues = [closed_issue(1, 1), open_issue(2, 1), open_issue(3, 1), open_issue(4, 2), open_issue(5, 2)]

    list = stage_list(versions, issues)
    shipped = list.stages.first

    assert shipped.partial?
    assert_not shipped.done?
    assert_equal 2, shipped.open_step_count
    assert_equal "Open", list.current_stage.version.name
    assert_equal 17, RubylodeProgress::PercentRule.percent_for(list.stages)
  end

  test "an open stage left behind the current one counts its closed share" do
    versions = [
      version(1, "Discovery", Date.new(2026, 1, 1), status: "closed"),
      version(2, "Design", Date.new(2026, 2, 1)),
      version(3, "Build", Date.new(2026, 3, 1))
    ]
    issues = [
      closed_issue(1, 1),
      closed_issue(2, 2), closed_issue(3, 2), open_issue(4, 2),
      closed_issue(5, 3), open_issue(6, 3, status_id: IN_PROGRESS_STATUS_ID), open_issue(7, 3), open_issue(8, 3)
    ]

    list = stage_list(versions, issues)

    assert_equal [:done, :partial, :current], list.stages.map(&:state)
    assert_equal 1, list.finished_stage_count
    assert_equal 64, RubylodeProgress::PercentRule.percent_for(list.stages)
  end

  test "a closed version whose issues are all closed is done" do
    versions = [version(1, "Shipped", Date.new(2026, 1, 1), status: "closed"), version(2, "Next", Date.new(2026, 2, 1))]

    list = stage_list(versions, [closed_issue(1, 1), closed_issue(2, 1), open_issue(3, 2)])

    assert list.stages.first.done?
    assert_equal 50, RubylodeProgress::PercentRule.percent_for(list.stages)
  end
end
