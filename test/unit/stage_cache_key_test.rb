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

class StageCacheKeyTest < ActiveSupport::TestCase
  fixtures :projects, :members, :member_roles, :roles, :enabled_modules, :users, :email_addresses, :trackers,
           :projects_trackers, :issue_statuses, :enumerations, :workflows

  CLOSED_STATUS_ID = 5

  setup do
    @project = Project.generate!(is_public: true)
    @project.enable_module!(:issue_tracking)
    @manager = User.find(2)
    @developer = User.find(3)
    @manager_role = Role.find(1)
    @developer_role = Role.find(2)
    User.add_to_project(@manager, @project, @manager_role)
    User.add_to_project(@developer, @project, @developer_role)
    @version = Version.generate!(project: @project, name: "Build", effective_date: Date.new(2026, 2, 1))
    @issue = Issue.generate!(project: @project, fixed_version: @version, author: @manager)
    @other_issue = Issue.generate!(project: @project, fixed_version: @version, author: @manager)
  end

  # Both fragments' keys together: a change to what either reads must change the pair.
  def key_for(viewer: @manager, settings: nil)
    [summary_key_for(viewer: viewer, settings: settings), issues_key_for(viewer: viewer, settings: settings)]
  end

  def stage_context(viewer, settings)
    viewer = User.find(viewer.id)
    project = Project.find(@project.id)
    settings ||= RubylodeProgress::EffectiveSettings.for(project)
    progress = RubylodeProgress::ProjectProgress.new(project: project, viewer: viewer, settings: settings)
    [progress, progress.stages.first, project, viewer, settings]
  end

  def summary_key_for(viewer: @manager, settings: nil, can_manage_version: nil)
    progress, stage, project, viewer, settings = stage_context(viewer, settings)
    RubylodeProgress::StageCacheKey.for_summary(stage: stage, project: project, viewer: viewer, settings: settings,
                                                can_manage_version: can_manage_version.nil? ? progress.can_manage_version?(stage.version) : can_manage_version)
  end

  def issues_key_for(viewer: @manager, settings: nil, new_issue_mode: nil)
    progress, stage, project, viewer, settings = stage_context(viewer, settings)
    RubylodeProgress::StageCacheKey.for_issues(stage: stage, project: project, viewer: viewer, settings: settings,
                                               editable_issue_ids: progress.editable_issue_ids,
                                               new_issue_mode: new_issue_mode || progress.new_issue_mode_for(stage.version))
  end

  test "the summary key changes with the viewer's right to manage the version, and the list key does not" do
    refute_equal summary_key_for(can_manage_version: true), summary_key_for(can_manage_version: false)
    assert_equal issues_key_for, issues_key_for
  end

  test "the list key changes with what the plus does for the viewer, and the summary key does not" do
    refute_equal issues_key_for(new_issue_mode: :modal), issues_key_for(new_issue_mode: :none)
    assert_equal summary_key_for, summary_key_for
  end

  test "the summary key does not read the assignees, the edit rights or the in-progress marks" do
    settings = RubylodeProgress::EffectiveSettings.for(Project.find(@project.id),
                                                       plugin_settings: RubylodeProgress::Settings.new("in_progress_status_ids" => ["2"]))
    @issue.update_column(:assigned_to_id, @developer.id)
    @issue.update_column(:updated_on, Time.utc(2000, 1, 1))
    @other_issue.update_column(:updated_on, Time.utc(2000, 1, 1))
    summary_before = summary_key_for(settings: settings)
    issues_before = issues_key_for(settings: settings)
    @developer.update_column(:lastname, "Renamed")
    @issue.update_columns(status_id: 2)
    @manager_role.remove_permission!(:edit_issues, :edit_own_issues, :add_issue_notes)

    assert_equal summary_before, summary_key_for(settings: settings)
    refute_equal issues_before, issues_key_for(settings: settings)
  end

test "the manager can manage the version and the developer cannot, as the progress object says it" do
  @manager_role.add_permission!(:manage_versions)
  @developer_role.remove_permission!(:manage_versions)
  [[@manager, true], [@developer, false]].each do |viewer, expected|
    progress = RubylodeProgress::ProjectProgress.new(project: Project.find(@project.id), viewer: User.find(viewer.id))
    assert_equal expected, progress.can_manage_version?(progress.stages.first.version)
  end
end

test "it does not change on a second identical build" do
    assert_equal key_for, key_for
  end

  test "the key changes with the viewer" do
    refute_equal key_for(viewer: @manager), key_for(viewer: @developer)
  end

  test "the key changes with an issue update" do
    before = key_for
    @issue.update_column(:updated_on, 1.hour.from_now)

    refute_equal before, key_for
  end

  test "the key changes when an issue moves out of the stage, though the newest update stays the same" do
    newest = [@issue, @other_issue].map(&:updated_on).max
    before = key_for
    @other_issue.update_columns(fixed_version_id: nil, updated_on: newest)
    @issue.update_column(:updated_on, newest)

    refute_equal before, key_for
  end

  test "the key changes when an issue is hidden from the viewer" do
    before = key_for(viewer: @developer)
    @other_issue.update_columns(is_private: true)

    refute_equal before, key_for(viewer: @developer)
  end

  test "the key changes with an update less than a second later" do
    before = key_for
    @issue.update_column(:updated_on, @issue.updated_on + 0.25)
    @other_issue.update_column(:updated_on, @issue.updated_on - 1)

    refute_equal before, key_for
  end

  test "the key changes when one issue closes, even if its update time did not move" do
    before = key_for
    @issue.update!(status_id: CLOSED_STATUS_ID)
    @issue.update_column(:updated_on, Time.utc(2000, 1, 1))
    @other_issue.update_column(:updated_on, Time.utc(2000, 1, 1))
    unchanged_time = key_for
    @issue.update_columns(status_id: 1)
    @issue.update_column(:updated_on, Time.utc(2000, 1, 1))

    refute_equal unchanged_time, key_for
    refute_equal before, unchanged_time
  end

  test "the key changes when one issue enters an in-progress status, even if its update time did not move" do
    settings = RubylodeProgress::EffectiveSettings.for(Project.find(@project.id),
                                                       plugin_settings: RubylodeProgress::Settings.new("in_progress_status_ids" => ["2"]))
    @issue.update_column(:updated_on, Time.utc(2000, 1, 1))
    @other_issue.update_column(:updated_on, Time.utc(2000, 1, 1))
    before = key_for(settings: settings)
    @issue.update_columns(status_id: 2, updated_on: Time.utc(2000, 1, 1))

    refute_equal before, key_for(settings: settings)
  end

  test "the key changes when an assignee is renamed, though no issue changed" do
    @issue.update_column(:assigned_to_id, @developer.id)
    before = key_for
    @developer.update_column(:lastname, "Renamed")

    refute_equal before, key_for
  end

  test "the key changes with the version" do
    before = key_for
    @version.update_column(:updated_on, 1.hour.from_now)

    refute_equal before, key_for
  end

  test "the key changes with the stage's state" do
    before = key_for
    @issue.update!(status_id: CLOSED_STATUS_ID)
    @other_issue.update!(status_id: CLOSED_STATUS_ID)
    @version.update!(status: "closed")

    refute_equal before, key_for
  end

  test "the key changes with the settings" do
    before = key_for
    RubylodeProgress::ProjectSetting.create!(project: @project, next_issue_limit: 9)

    refute_equal before, key_for
  end

  test "the key changes with the locale" do
    before = key_for
    changed = I18n.with_locale(:fr) { key_for }

    refute_equal before, changed
  end

  test "the key changes when the viewer's role loses the right to edit" do
    before = key_for
    @manager_role.remove_permission!(:edit_issues, :edit_own_issues, :add_issue_notes)

    refute_equal before, key_for
  end

  test "the key changes when the viewer's role loses the right to add issues" do
    before = key_for
    @manager_role.remove_permission!(:add_issues)

    refute_equal before, key_for
  end

  test "the key changes with the version's status, even when its update time does not move" do
    before = key_for
    @version.update_columns(status: "locked")

    refute_equal before, key_for
  end

  test "two viewers with different edit rights get different keys" do
    @developer_role.remove_permission!(:edit_issues, :edit_own_issues, :add_issue_notes)

    refute_equal key_for(viewer: @manager), key_for(viewer: @developer)
  end
end
