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

class IssueScopeTest < ActiveSupport::TestCase
  MANAGER_ROLE_ID = 1
  JSMITH_ID = 2
  DLOPPER_ID = 3

  setup do
    @viewer = User.find(JSMITH_ID)
    @parent = Project.generate!(is_public: true)
    User.add_to_project(@viewer, @parent, Role.find(MANAGER_ROLE_ID))
  end

  test "issues without a version never appear" do
    version = Version.generate!(project: @parent)
    in_version = Issue.generate!(project: @parent, fixed_version: version)
    without_version = Issue.generate!(project: @parent)

    issue_ids = scope.issues.map(&:id)

    assert_includes issue_ids, in_version.id
    assert_not_includes issue_ids, without_version.id
  end

  test "issues of subprojects roll up into the parent" do
    subproject = Project.generate_with_parent!(@parent, is_public: true)
    version = Version.generate!(project: @parent, sharing: "descendants")
    subproject_issue = Issue.generate!(project: subproject, fixed_version: version)

    assert_equal [subproject_issue.id], scope.issues.map(&:id)
    assert_equal [version.id], scope.versions.map(&:id)
  end

  test "a subproject the viewer may not see adds nothing" do
    hidden = Project.generate_with_parent!(@parent, is_public: false)
    version = Version.generate!(project: hidden)
    Issue.generate!(project: hidden, fixed_version: version)

    outsider_scope = scope(viewer: User.find(DLOPPER_ID))

    assert_empty outsider_scope.versions
    assert_empty outsider_scope.issues
  end

  test "a version shared up from a subproject the viewer may not see adds nothing" do
    hidden = Project.generate_with_parent!(@parent, is_public: false)
    version = Version.generate!(project: hidden, sharing: "hierarchy")
    Issue.generate!(project: hidden, fixed_version: version)

    outsider_scope = scope(viewer: User.find(DLOPPER_ID))

    assert_empty outsider_scope.versions
    assert_empty outsider_scope.issues
  end

  test "a version shared in from another project counts only while it holds one of this project's visible issues" do
    elsewhere = Project.generate!(is_public: true)
    shared = Version.generate!(project: elsewhere, sharing: "system")
    Issue.generate!(project: elsewhere, fixed_version: shared)

    assert_not_includes scope.versions.map(&:id), shared.id

    Issue.generate!(project: @parent, fixed_version: shared)

    assert_includes scope.versions.map(&:id), shared.id
  end

  test "with the prefix setting only versions starting with it count, and their issues only" do
    counted = Version.generate!(project: @parent, name: "Stage one")
    skipped = Version.generate!(project: @parent, name: "Backlog")
    counted_issue = Issue.generate!(project: @parent, fixed_version: counted)
    Issue.generate!(project: @parent, fixed_version: skipped)

    with_settings plugin_redmine_rubylode_progress: { "counted_versions" => "prefix", "version_name_prefix" => "Stage" } do
      assert_equal [counted.id], scope.versions.map(&:id)
      assert_equal [counted_issue.id], scope.issues.map(&:id)
    end
  end

  private

  def scope(viewer: @viewer)
    RubylodeProgress::IssueScope.new(project: @parent, viewer: viewer,
                                     settings: RubylodeProgress::EffectiveSettings.for(@parent))
  end
end
