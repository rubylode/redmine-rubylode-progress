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

class ProjectProgressTest < ActiveSupport::TestCase
  MANAGER_ROLE_ID = 1
  DEVELOPER_ROLE_ID = 2
  JSMITH_ID = 2
  DLOPPER_ID = 3
  CLOSED_STATUS_ID = 5

  setup do
    @manager = User.find(JSMITH_ID)
    @developer = User.find(DLOPPER_ID)
    @project = Project.generate!(is_public: false)
    User.add_to_project(@manager, @project, Role.find(MANAGER_ROLE_ID))
    User.add_to_project(@developer, @project, Role.find(DEVELOPER_ROLE_ID))
    @version = Version.generate!(project: @project)
  end

  test "a private issue stays out for a viewer who may not see it and in for one who may" do
    Issue.generate!(project: @project, fixed_version: @version, author: @manager, status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: @project, fixed_version: @version, author: @manager, is_private: true)

    for_manager = progress(viewer: @manager)
    for_developer = progress(viewer: @developer)

    assert_equal 2, for_manager.items.size
    assert_equal 1, for_developer.items.size
    assert_equal 50, for_manager.percent
    assert_equal 100, for_developer.percent
  end

  test "a version shared from another project counts only this project's visible issues" do
    elsewhere = Project.generate!(is_public: false)
    shared = Version.generate!(project: elsewhere, sharing: "system")
    2.times { Issue.generate!(project: elsewhere, fixed_version: shared) }
    @version.destroy
    Issue.generate!(project: @project, fixed_version: shared, status_id: CLOSED_STATUS_ID)

    result = progress(viewer: @developer)

    assert_equal [shared.id], result.stages.map { |stage| stage.version.id }
    assert_equal 1, result.stages.first.step_count
    assert_equal 100, result.percent
  end

  test "an issue assigned to the viewer's group is Needs you through ProjectProgress" do
    group = Group.generate!
    group.users << @developer
    User.add_to_project(group, @project, Role.find(DEVELOPER_ROLE_ID))
    issue = with_settings(issue_group_assignment: "1") do
      Issue.generate!(project: @project, fixed_version: @version, assigned_to: group)
    end

    assert_equal :needs_you, progress(viewer: @developer).status_for(issue)
  end

  test "a blocked issue is Waiting while its blocker is open and not after it closes" do
    blocker = Issue.generate!(project: @project, fixed_version: @version)
    blocked = Issue.generate!(project: @project, fixed_version: @version)
    IssueRelation.create!(issue_from: blocker, issue_to: blocked, relation_type: IssueRelation::TYPE_BLOCKS)

    assert_equal :waiting, progress(viewer: @developer).status_for(blocked)

    blocker.update!(status_id: CLOSED_STATUS_ID)

    assert_equal :next, progress(viewer: @developer).status_for(blocked.reload)
  end

  test "the stages, the percent and the items come from the same issues" do
    later = Version.generate!(project: @project, effective_date: Date.today + 60)
    Issue.generate!(project: @project, fixed_version: @version, status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: @project, fixed_version: @version)
    Issue.generate!(project: @project, fixed_version: later)
    Issue.generate!(project: @project, fixed_version: later, is_private: true, author: @manager)

    [@manager, @developer].each do |viewer|
      result = progress(viewer: viewer)

      assert_equal result.items.size, result.stages.sum(&:step_count)
      assert_equal result.items.map(&:step_number), result.stages.flat_map(&:steps).map(&:number)
    end
  end

  private

  def progress(viewer:)
    RubylodeProgress::ProjectProgress.new(project: @project, viewer: viewer)
  end
end
