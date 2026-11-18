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

class StageListTest < ActiveSupport::TestCase
  include StageDoubles

  test "stages are ordered by date, then name, undated last" do
    versions = [
      version(1, "Undated"),
      version(2, "beta", Date.new(2026, 3, 1)),
      version(3, "Alpha", Date.new(2026, 3, 1)),
      version(4, "Earliest", Date.new(2026, 1, 15))
    ]

    stages = stage_list(versions, []).stages

    assert_equal ["Earliest", "Alpha", "beta", "Undated"], stages.map { |stage| stage.version.name }
    assert_equal [1, 2, 3, 4], stages.map(&:number)
  end

  test "steps are numbered stage dot position by issue number" do
    versions = [
      version(1, "First", Date.new(2026, 1, 1)),
      version(2, "Second", Date.new(2026, 2, 1)),
      version(3, "Third", Date.new(2026, 3, 1))
    ]
    issues = [open_issue(30, 3), open_issue(12, 3), open_issue(21, 3), open_issue(7, 1)]

    third_stage = stage_list(versions, issues).stages.last

    assert_equal ["3.1", "3.2", "3.3"], third_stage.steps.map(&:number)
    assert_equal [12, 21, 30], third_stage.steps.map { |step| step.issue.id }
  end

  test "the current stage is the furthest open stage with a closed or in-progress issue" do
    versions = [
      version(1, "A", Date.new(2026, 1, 1), status: "closed"),
      version(2, "B", Date.new(2026, 2, 1)),
      version(3, "C", Date.new(2026, 3, 1)),
      version(4, "D", Date.new(2026, 4, 1))
    ]
    issues = [
      closed_issue(1, 1),
      closed_issue(2, 2), open_issue(3, 2),
      open_issue(4, 3, status_id: IN_PROGRESS_STATUS_ID), open_issue(5, 3),
      open_issue(6, 4)
    ]

    list = stage_list(versions, issues)

    assert_equal "C", list.current_stage.version.name
    assert_equal [:done, :partial, :current, :upcoming], list.stages.map(&:state)
    assert_equal 1, list.finished_stage_count
    assert_equal 4, list.stage_count
    assert_not list.all_done?
  end

  test "with no started open stage the first open stage is current" do
    versions = [
      version(1, "A", Date.new(2026, 1, 1), status: "closed"),
      version(2, "B", Date.new(2026, 2, 1)),
      version(3, "C", Date.new(2026, 3, 1))
    ]
    issues = [closed_issue(1, 1), open_issue(2, 2), open_issue(3, 3)]

    assert_equal "B", stage_list(versions, issues).current_stage.version.name
  end

  test "a locked version is not done and can be current" do
    versions = [version(1, "Frozen", Date.new(2026, 1, 1), status: "locked"), version(2, "Later", Date.new(2026, 2, 1))]
    issues = [closed_issue(1, 1), open_issue(2, 1), open_issue(3, 2)]

    list = stage_list(versions, issues)

    assert_equal "Frozen", list.current_stage.version.name
    assert_equal 0, list.finished_stage_count
  end

  test "no versions: no stages, no current stage" do
    list = stage_list([], [])

    assert_empty list.stages
    assert_nil list.current_stage
    assert_equal 0, list.stage_count
    assert_not list.all_done?
  end

  test "all stages done: no current stage" do
    versions = [version(1, "A", Date.new(2026, 1, 1), status: "closed"), version(2, "B", Date.new(2026, 2, 1), status: "closed")]

    list = stage_list(versions, [closed_issue(1, 1)])

    assert_nil list.current_stage
    assert list.all_done?
    assert_equal 2, list.finished_stage_count
  end
end
