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

  def key_for(viewer: @manager, settings: nil)
    viewer = User.find(viewer.id)
    project = Project.find(@project.id)
    settings ||= RubylodeProgress::EffectiveSettings.for(project)
    progress = RubylodeProgress::ProjectProgress.new(project: project, viewer: viewer, settings: settings)
    stage = progress.stages.first
    RubylodeProgress::StageCacheKey.for(stage: stage, project: project, viewer: viewer, settings: settings,
                                        editable_issue_ids: progress.editable_issue_ids,
                                        new_issue_mode: progress.new_issue_mode_for(stage.version),
                                        accepts_issues: progress.accepts_issues?(stage.version))
  end

  test "the key changes with whether the stage is a drop target for the viewer" do
    project = Project.find(@project.id)
    settings = RubylodeProgress::EffectiveSettings.for(project)
    progress = RubylodeProgress::ProjectProgress.new(project: project, viewer: @manager, settings: settings)
    stage = progress.stages.first
    keys = [true, false].map do |accepts_issues|
      RubylodeProgress::StageCacheKey.for(stage: stage, project: project, viewer: @manager, settings: settings,
                                          editable_issue_ids: progress.editable_issue_ids, new_issue_mode: :none,
                                          accepts_issues: accepts_issues)
    end

    refute_equal keys.first, keys.last
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
