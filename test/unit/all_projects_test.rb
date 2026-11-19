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

class AllProjectsTest < ActiveSupport::TestCase
  MEMBER_ROLE_ID = 1

  setup do
    @viewer = User.find(2)
  end

  test "only projects with the module and the permission are listed, by name" do
    role = Role.find(MEMBER_ROLE_ID)
    role.add_permission!(:view_rubylode_progress)
    listed_second = build_project("Zulu listed", member_role: role)
    listed_first = build_project("Alpha listed", member_role: role)
    without_module = build_project("Bravo no module", member_role: role, module_enabled: false)
    without_permission = build_project("Charlie no permission", member_role: Role.generate!(permissions: [:view_issues]))

    names = RubylodeProgress::AllProjects.projects_for(@viewer).map(&:name)

    assert_equal [listed_first.name, listed_second.name], names & [listed_first.name, listed_second.name]
    assert_not_includes names, without_module.name
    assert_not_includes names, without_permission.name
    assert RubylodeProgress::AllProjects.any_for?(@viewer)
  end

  test "any_for? is false when no project qualifies" do
    Role.all.each { |role| role.remove_permission!(:view_rubylode_progress) }

    assert_not RubylodeProgress::AllProjects.any_for?(@viewer)
    assert_empty RubylodeProgress::AllProjects.projects_for(@viewer)
  end

  private

  def build_project(name, member_role:, module_enabled: true)
    project = Project.generate!(name: name, is_public: false)
    project.enable_module!(:rubylode_progress) if module_enabled
    User.add_to_project(@viewer, project, member_role)
    project
  end
end
