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
require File.expand_path("../../lib/rubylode_progress/demo_data", __dir__)

class DemoDataTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :workflows

  DemoData = RubylodeProgress::DemoData

  setup do
    DemoData.build(today: Date.new(2026, 11, 19))
    @main_project = Project.find_by!(identifier: DemoData::MAIN_PROJECT_IDENTIFIER)
    @demo_person = User.find_by!(login: DemoData::DEMO_LOGIN)
  end

  test "the demo builds five versions and between 35 and 45 issues in the main project" do
    assert_equal 5, @main_project.versions.count

    progress = RubylodeProgress::ProjectProgress.new(project: @main_project, viewer: @demo_person)
    assert_equal 5, progress.stages.size
    assert_includes 35..45, progress.items.size
    assert_includes 35..45, Issue.where(project_id: @main_project.self_and_descendants.pluck(:id)).count
  end

  test "the demo shows every stage state: a done, a partial, a current, an upcoming and a locked stage" do
    progress = RubylodeProgress::ProjectProgress.new(project: @main_project, viewer: @demo_person)

    assert_equal %i[done partial current upcoming upcoming], progress.stages.map(&:state)
    assert_equal 1, progress.stages.count { |stage| stage.version.status == "locked" }
    assert_equal 1, progress.stages.count { |stage| stage.version.open? && stage.upcoming? }
    assert_equal 2, progress.stages.count { |stage| stage.version.closed? }
  end

  test "the demo shows every checklist status: Done, Needs you, Waiting, Next and To do" do
    progress = RubylodeProgress::ProjectProgress.new(project: @main_project, viewer: @demo_person)
    statuses = progress.items.map(&:status).tally

    %i[done needs_you waiting next to_do].each do |status|
      assert_operator statuses.fetch(status, 0), :>=, 1, "no #{status} item in the demo"
    end
    assert_operator statuses[:needs_you], :>=, 2, "one issue for the person and one for the group"
    assert_operator statuses[:next], :>=, 3
  end

  test "the demo has a private note, a group assignment, the category grouping override and edit rights" do
    assert Journal.where(private_notes: true).exists?
    assert Issue.where(assigned_to_id: Group.find_by!(lastname: DemoData::DEMO_GROUP_NAME).id).exists?
    assert_equal "category", RubylodeProgress::EffectiveSettings.for(@main_project).checklist_grouping

    progress = RubylodeProgress::ProjectProgress.new(project: @main_project, viewer: @demo_person)
    assert_operator progress.editable_issue_ids.size, :>=, 3
    assert progress.stages.any? { |stage| progress.new_issue_mode_for(stage.version) != :none }
  end

  test "the cross-project page lists the main project and the three smaller ones" do
    log_user(DemoData::DEMO_LOGIN, DemoData::DEMO_PASSWORD)
    get "/progress"

    assert_response :success
    %w[Bridge Kiln Loom Quill].each do |name|
      assert_select ".rubylode-progress-compact-tracker a", text: name
    end

    get "/projects/#{DemoData::MAIN_PROJECT_IDENTIFIER}/progress"
    assert_response :success
  end

  test "running the demo twice changes nothing" do
    counts = lambda do
      [Project.count, Version.count, Issue.count, User.count, Journal.count, IssueRelation.count, Member.count]
    end
    before = counts.call

    assert_equal :already_loaded, DemoData.build(today: Date.new(2026, 11, 19))

    assert_equal before, counts.call
  end
end
