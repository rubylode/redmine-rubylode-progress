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

class ProjectTrackerTest < ActiveSupport::TestCase
  CLOSED_STATUS_ID = 5

  setup do
    @viewer = User.find(2)
    @project = Project.generate!(is_public: false)
    User.add_to_project(@viewer, @project, Role.find(1))
  end

  test "a tracker gives the same stages and percent as ProjectProgress for that project" do
    first = Version.generate!(project: @project, effective_date: Date.today + 10)
    second = Version.generate!(project: @project, effective_date: Date.today + 40)
    Issue.generate!(project: @project, fixed_version: first, status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: @project, fixed_version: first)
    Issue.generate!(project: @project, fixed_version: second)

    tracker = RubylodeProgress::ProjectTracker.for(@project, viewer: @viewer)
    progress = RubylodeProgress::ProjectProgress.new(project: @project, viewer: @viewer)

    assert_equal progress.stages.map { |stage| [stage.version.id, stage.state, stage.step_count] },
                 tracker.stages.map { |stage| [stage.version.id, stage.state, stage.step_count] }
    assert_equal progress.current_stage&.version&.id, tracker.current_stage&.version&.id
    assert_equal progress.percent, tracker.percent
    assert_equal @project, tracker.project
  end

  test "a parent's tracker includes its subprojects' issues, and the subproject has its own tracker" do
    child = Project.generate_with_parent!(@project, is_public: false)
    User.add_to_project(@viewer, child, Role.find(1))
    parent_version = Version.generate!(project: @project)
    child_version = Version.generate!(project: child)
    Issue.generate!(project: @project, fixed_version: parent_version, status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: child, fixed_version: child_version)

    parent_tracker = RubylodeProgress::ProjectTracker.for(@project, viewer: @viewer)
    child_tracker = RubylodeProgress::ProjectTracker.for(child, viewer: @viewer)

    assert_equal [parent_version.id, child_version.id].sort, parent_tracker.stages.map { |stage| stage.version.id }.sort
    assert_equal 50, parent_tracker.percent
    assert_equal [child_version.id], child_tracker.stages.map { |stage| stage.version.id }
    assert_equal 0, child_tracker.percent
  end

  test "a project without counted versions has no stages" do
    tracker = RubylodeProgress::ProjectTracker.for(@project, viewer: @viewer)

    assert_empty tracker.stages
    assert_nil tracker.current_stage
  end
end
