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

class LookAndAccessibilityTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers, :user_preferences

  CLOSED_STATUS_ID = 5
  MANAGER_ROLE_ID = 1

  setup do
    @manager = User.find(2)
    @project = Project.generate!(is_public: false)
    @project.enable_module!(:rubylode_progress)
    @project.enable_module!(:issue_tracking)
    Role.find(MANAGER_ROLE_ID).add_permission!(:view_rubylode_progress)
    User.add_to_project(@manager, @project, Role.find(MANAGER_ROLE_ID))
    version = Version.generate!(project: @project, name: "Build", effective_date: Date.new(2026, 2, 15))
    Issue.generate!(project: @project, fixed_version: version, author: @manager, subject: "Finished thing",
                    status_id: CLOSED_STATUS_ID)
    Issue.generate!(project: @project, fixed_version: version, author: @manager, subject: "Mine to do",
                    assigned_to: @manager)
    log_user("jsmith", "jsmith")
  end

  test "the project page sits in one column wrapper, with folds as details and summary" do
    get "/projects/#{@project.identifier}/progress"

    assert_select "#content .rubylode-progress", count: 1
    assert_select ".rubylode-progress details.rubylode-progress-stage > summary"
  end

  test "the track has its aria-label" do
    get "/projects/#{@project.identifier}/progress"

    label = css_select("ol.rubylode-progress-track").first["aria-label"]
    assert_match(/\A\d+% done, \d+ of \d+ stages finished\z/, label)
  end

  test "the pressed filter has aria-pressed and the others say false" do
    get "/projects/#{@project.identifier}/progress?filter=all"

    assert_select ".rubylode-progress-filter[aria-pressed=true]", count: 1
    assert_select ".rubylode-progress-filter[aria-pressed=false]", count: RubylodeProgress::ChecklistFilter::NAMES.size - 1
  end

  test "each status shows its text label beside its mark" do
    get "/projects/#{@project.identifier}/progress?filter=all"

    assert_select ".rubylode-progress-row--done .rubylode-progress-pill", text: "Done"
    assert_select ".rubylode-progress-row--needs-you .rubylode-progress-pill", text: "Needs you"
    assert_select ".rubylode-progress-row__mark[aria-hidden=true]", minimum: 2
  end

  test "the cross-project page is wrapped too" do
    get "/progress"

    assert_select ".rubylode-progress .rubylode-progress-all-projects"
  end
end
