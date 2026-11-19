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

class BusyDemoDataTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :workflows

  DemoData = RubylodeProgress::DemoData
  TODAY = Date.new(2026, 11, 19)

  def busy_project
    Project.find_by!(identifier: DemoData::BUSY_PROJECT_IDENTIFIER)
  end

  test "the main demo build does not create the busy project" do
    DemoData.build(today: TODAY)

    assert_nil Project.find_by(identifier: DemoData::BUSY_PROJECT_IDENTIFIER)
  end

  test "the busy project builds with 45 versions, the right issue count, categories and members" do
    assert_equal :built, DemoData.build_busy(today: TODAY, issue_count: 120)
    project = busy_project

    assert project.is_public?
    assert_includes project.enabled_module_names, "rubylode_progress"
    assert_equal "Lighthouse", project.name
    assert_equal 45, project.versions.count
    assert_equal 120, Issue.where(project_id: project.id).count
    assert_equal 5, project.issue_categories.count
    assert_operator project.members.count, :>=, 5
    assert_operator Issue.where(project_id: project.id, assigned_to_id: User.find_by!(login: DemoData::DEMO_LOGIN).id).count, :>, 0
    assert_operator Issue.where(project_id: project.id).open.where("due_date < ?", TODAY).count, :>, 0
    assert Journal.where(journalized_type: "Issue", journalized_id: project.issues.select(:id)).exists?
  end

  test "the busy project's stages: 34 closed, then open done ones, one current, one upcoming" do
    DemoData.build_busy(today: TODAY, issue_count: 120)
    project = busy_project
    progress = RubylodeProgress::ProjectProgress.new(project: project, viewer: User.find_by!(login: DemoData::DEMO_LOGIN))
    stages = progress.stages

    assert_equal 45, stages.size
    assert_equal 34, project.versions.where(status: "closed").count
    assert_equal 30, stages.first(34).count(&:done?)
    assert_equal 4, stages.first(34).count { |stage| stage.state == :partial }
    assert_equal :current, stages[43].state
    assert_equal :upcoming, stages[44].state
    assert_equal "2016 Q1", stages.first.version.name # 43 quarters before the current one
    assert_equal TODAY.end_of_quarter, stages[43].version.effective_date
  end

  test "the busy project is deterministic and building twice changes nothing" do
    DemoData.build_busy(today: TODAY, issue_count: 120)
    subjects = busy_project.issues.order(:id).pluck(:subject)
    counts = -> { [Project.count, Version.count, Issue.count, User.count, Journal.count, Member.count] }
    before = counts.call

    assert_equal :already_loaded, DemoData.build_busy(today: TODAY, issue_count: 120)

    assert_equal before, counts.call
    assert_equal subjects, busy_project.issues.order(:id).pluck(:subject)
  end

  test "the busy project builds after the main demo and leaves its counts alone" do
    DemoData.build(today: TODAY)
    before = [Project.count, Issue.count]

    DemoData.build_busy(today: TODAY, issue_count: 120)

    assert_equal before.first + 1, Project.count
    assert_equal before.last + 120, Issue.count
    assert_equal 5, Project.find_by!(identifier: "bridge").versions.count
  end

  test "the busy project page opens for the demo person" do
    DemoData.build(today: TODAY)
    DemoData.build_busy(today: TODAY, issue_count: 120)
    log_user(DemoData::DEMO_LOGIN, DemoData::DEMO_PASSWORD)

    get "/projects/#{DemoData::BUSY_PROJECT_IDENTIFIER}/progress"

    assert_response :success
  end
end
