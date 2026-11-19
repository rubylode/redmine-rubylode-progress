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

class RailCacheTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :issue_categories, :enumerations, :workflows, :custom_fields,
           :custom_values, :custom_fields_projects, :custom_fields_trackers

  CLOSED_STATUS_ID = 5

  setup do
    @original_caching = ActionController::Base.perform_caching
    @original_store = ActionController::Base.cache_store
    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new

    @manager = User.find(2)
    @developer = User.find(3)
    @project = Project.generate!(is_public: false)
    @project.enable_module!(:rubylode_progress)
    @project.enable_module!(:issue_tracking)
    Role.find(1).add_permission!(:view_rubylode_progress)
    Role.find(2).add_permission!(:view_rubylode_progress)
    Role.find(2).update!(issues_visibility: "own")
    User.add_to_project(@manager, @project, Role.find(1))
    User.add_to_project(@developer, @project, Role.find(2))
    @version = Version.generate!(project: @project, name: "Build", effective_date: Date.new(2026, 2, 1))
    @managers_issue = Issue.generate!(project: @project, fixed_version: @version, author: @manager,
                                      subject: "Written by the manager")
    @developers_issue = Issue.generate!(project: @project, fixed_version: @version, author: @developer,
                                        subject: "Written by the developer")
  end

  teardown do
    ActionController::Base.perform_caching = @original_caching
    ActionController::Base.cache_store = @original_store
  end

  def steps_seen_by(login)
    post "/logout" if @logged_in
    @logged_in = true
    log_user(login, login == "dlopper" ? "foo" : login)
    get "/projects/#{@project.identifier}/progress"
    assert_response :success
    css_select(".rubylode-progress-step a.rubylode-progress-item-link").map(&:text)
  end

  test "each stage of the rail is written to the fragment cache, and a second view reads it" do
    writes = []
    reads = []
    subscriber_writes = ActiveSupport::Notifications.subscribe("write_fragment.action_controller") { |*, payload| writes << payload[:key] }
    subscriber_reads = ActiveSupport::Notifications.subscribe("read_fragment.action_controller") { |*, payload| reads << payload[:key] }

    steps_seen_by("jsmith")
    assert_equal 1, writes.size
    steps_seen_by("jsmith")

    assert_equal 1, writes.size
    assert_equal 2, reads.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber_writes)
    ActiveSupport::Notifications.unsubscribe(subscriber_reads)
  end

  test "two viewers with different visibility get different cached rails" do
    assert_equal ["Written by the manager", "Written by the developer"].sort, steps_seen_by("jsmith").sort
    assert_equal ["Written by the developer"], steps_seen_by("dlopper")
    assert_equal ["Written by the manager", "Written by the developer"].sort, steps_seen_by("jsmith").sort
  end

  test "the restricted viewer first does not narrow the rail of the viewer who sees everything" do
    assert_equal ["Written by the developer"], steps_seen_by("dlopper")
    assert_equal ["Written by the manager", "Written by the developer"].sort, steps_seen_by("jsmith").sort
    assert_equal ["Written by the developer"], steps_seen_by("dlopper")
  end

  test "closing an issue updates its stage on the next view" do
    steps_seen_by("jsmith")
    assert_select ".rubylode-progress-step--done", count: 0

    @managers_issue.reload.update!(status_id: CLOSED_STATUS_ID)
    get "/projects/#{@project.identifier}/progress"

    assert_select ".rubylode-progress-step--done", count: 1
  end

  test "changing the viewer's role changes what a cached rail shows" do
    steps_seen_by("dlopper")
    Role.find(2).update!(issues_visibility: "all")
    assert_equal ["Written by the manager", "Written by the developer"].sort, steps_seen_by("dlopper").sort
  end

  test "the cached fragment is reused when only a neighbour changes, while each stage's own rail line follows its issues" do
    middle = Version.generate!(project: @project, name: "Launch", effective_date: Date.new(2026, 3, 1))
    last = Version.generate!(project: @project, name: "Final", effective_date: Date.new(2026, 4, 1))
    neighbour_issue = Issue.generate!(project: @project, fixed_version: middle, author: @manager)
    Issue.generate!(project: @project, fixed_version: middle, author: @manager)
    Issue.generate!(project: @project, fixed_version: last, author: @manager, status_id: CLOSED_STATUS_ID)
    writes = []
    subscriber = ActiveSupport::Notifications.subscribe("write_fragment.action_controller") { |*, payload| writes << payload[:key] }

    steps_seen_by("jsmith")
    assert_equal 3, writes.size
    assert_select "li.rubylode-progress-stage-item:nth-child(2)[style*=?]", "share-below: 0%"

    neighbour_issue.reload.update!(status_id: CLOSED_STATUS_ID)
    get "/projects/#{@project.identifier}/progress"

    assert_equal 4, writes.size, "only the stage that changed is written again, not the stage above it"
    assert_select "li.rubylode-progress-stage-item:nth-child(2)[style*=?]", "share-below: 50%"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
