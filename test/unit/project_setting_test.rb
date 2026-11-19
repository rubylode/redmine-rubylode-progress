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

class ProjectSettingTest < ActiveSupport::TestCase
  fixtures :projects

  def build_setting(**attributes)
    RubylodeProgress::ProjectSetting.new(project: Project.find(1), **attributes)
  end

  test "an unknown grouping or a limit of 21 is refused" do
    refute_predicate build_setting(checklist_grouping: "tracker"), :valid?
    refute_predicate build_setting(next_issue_limit: 21), :valid?
    refute_predicate build_setting(counted_versions: "some"), :valid?
    refute_predicate build_setting(version_name_prefix: "a" * 61), :valid?
    refute_predicate build_setting(note_source: "journal"), :valid?
  end

  test "empty values and in-range values are accepted" do
    assert_predicate build_setting, :valid?
    assert_predicate build_setting(checklist_grouping: "parent", next_issue_limit: 0, note_source: "latest_note"), :valid?
    assert_predicate build_setting(next_issue_limit: 20, note_source: "custom_field_4"), :valid?
  end

  test "for finds the row or builds an unsaved one" do
    project = Project.find(1)
    built = RubylodeProgress::ProjectSetting.for(project)
    assert_predicate built, :new_record?

    built.update!(next_issue_limit: 4)
    assert_equal built, RubylodeProgress::ProjectSetting.for(project)
  end
end
