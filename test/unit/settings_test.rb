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

class SettingsTest < ActiveSupport::TestCase
  test "unusable values read as the defaults" do
    settings = RubylodeProgress::Settings.new("counted_versions" => "some", "checklist_grouping" => "tracker",
                                              "next_issue_limit" => "many", "in_progress_status_ids" => ["2", "x", ""],
                                              "note_source" => "custom_field_")

    assert_equal "all", settings.counted_versions
    assert_equal "version", settings.checklist_grouping
    assert_equal 3, settings.next_issue_limit
    assert_equal [2], settings.in_progress_status_ids
    assert_nil settings.note_custom_field_id
  end

  test "a Next limit outside 0 to 20 is held to it and a custom field note source names its field" do
    assert_equal 20, RubylodeProgress::Settings.new("next_issue_limit" => "50").next_issue_limit
    assert_equal 0, RubylodeProgress::Settings.new("next_issue_limit" => "-1").next_issue_limit
    assert_equal 12, RubylodeProgress::Settings.new("note_source" => "custom_field_12").note_custom_field_id
  end

  test "the effective settings are frozen and their digest follows their values" do
    project = Project.find(1)
    plain = RubylodeProgress::EffectiveSettings.for(project)
    changed = with_settings(plugin_redmine_rubylode_progress: { "next_issue_limit" => "5" }) do
      RubylodeProgress::EffectiveSettings.for(project)
    end

    assert_predicate plain, :frozen?
    assert_equal 5, changed.next_issue_limit
    refute_equal plain.cache_digest, changed.cache_digest
  end
end
