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

class PluginSettingsPageTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :roles, :issue_statuses, :custom_fields

  def settings_path
    "/settings/plugin/redmine_rubylode_progress"
  end

  test "an administrator saves the plugin-wide settings" do
    log_user("admin", "admin")

    get settings_path
    assert_response :success
    assert_select "select[name=?]", "settings[counted_versions]"
    assert_select "input[name=?]", "settings[version_name_prefix]"
    assert_select "select[name=?]", "settings[checklist_grouping]"
    assert_select "input[type=checkbox][name=?]", "settings[in_progress_status_ids][]"
    assert_select "input[type=checkbox][name=?]", "settings[waiting_status_ids][]"
    assert_select "input[name=?]", "settings[next_issue_limit]"
    assert_select "select[name=?]", "settings[note_source]"

    post settings_path, params: { settings: { counted_versions: "prefix", version_name_prefix: "Stage",
                                              checklist_grouping: "parent", in_progress_status_ids: ["", "2"],
                                              waiting_status_ids: ["", "3"], next_issue_limit: "4",
                                              note_source: "latest_note" } }
    assert_redirected_to settings_path

    saved = RubylodeProgress::Settings.new
    assert_equal "prefix", saved.counted_versions
    assert_equal "Stage", saved.version_name_prefix
    assert_equal "parent", saved.checklist_grouping
    assert_equal [2], saved.in_progress_status_ids
    assert_equal [3], saved.waiting_status_ids
    assert_equal 4, saved.next_issue_limit
  end

  test "a non-administrator cannot open them" do
    log_user("jsmith", "jsmith")

    get settings_path

    assert_response :forbidden
  end
end
