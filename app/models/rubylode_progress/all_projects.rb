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

module RubylodeProgress
  # The projects the cross-project page may list for one viewer: visible to them, with the module enabled and the
  # viewer holding "View progress" in that project.
  class AllProjects
    def self.projects_for(viewer)
      scope_for(viewer).order(:name)
    end

    def self.any_for?(viewer)
      scope_for(viewer).exists?
    end

    def self.scope_for(viewer)
      Project.visible(viewer).where(Project.allowed_to_condition(viewer, :view_rubylode_progress))
    end
    private_class_method :scope_for
  end
end
