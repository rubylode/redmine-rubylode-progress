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

class EffectiveSettingsTest < ActiveSupport::TestCase
  fixtures :projects

  setup do
    @project = Project.find(1)
  end

  def effective_settings
    RubylodeProgress::EffectiveSettings.for(@project.reload)
  end

  test "with no row every value is the plugin-wide one" do
    with_settings(plugin_redmine_rubylode_progress: { "next_issue_limit" => "5", "checklist_grouping" => "parent" }) do
      assert_equal 5, effective_settings.next_issue_limit
      assert_equal "parent", effective_settings.checklist_grouping
    end
  end

  test "a filled column overrides, an empty one falls back" do
    RubylodeProgress::ProjectSetting.create!(project: @project, checklist_grouping: "category",
                                             in_progress_status_ids: [2], note_source: "custom_field_7")

    with_settings(plugin_redmine_rubylode_progress: { "next_issue_limit" => "5", "checklist_grouping" => "parent" }) do
      assert_equal "category", effective_settings.checklist_grouping
      assert_equal [2], effective_settings.in_progress_status_ids
      assert_equal 7, effective_settings.note_custom_field_id
      assert_equal 5, effective_settings.next_issue_limit
    end
  end

  test "an override can choose All versions over a plugin-wide prefix" do
    RubylodeProgress::ProjectSetting.create!(project: @project, counted_versions: "all")

    with_settings(plugin_redmine_rubylode_progress: { "counted_versions" => "prefix", "version_name_prefix" => "Stage" }) do
      assert_equal "all", effective_settings.counted_versions
    end
  end

  test "an empty list of statuses is an override, not a fallback" do
    RubylodeProgress::ProjectSetting.create!(project: @project, waiting_status_ids: [])

    with_settings(plugin_redmine_rubylode_progress: { "waiting_status_ids" => ["3"] }) do
      assert_equal [], effective_settings.waiting_status_ids
    end
  end

  test "the digest changes with any effective value" do
    plain_digest = effective_settings.cache_digest
    RubylodeProgress::ProjectSetting.create!(project: @project, next_issue_limit: 9)

    refute_equal plain_digest, effective_settings.cache_digest
  end
end
