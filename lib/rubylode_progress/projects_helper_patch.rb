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
  # Prepended to ProjectsHelper: the Progress tab in a project's Settings, for whoever may edit the project while the
  # module is enabled (the same two tests Redmine applies to its own tabs).
  module ProjectsHelperPatch
    def project_settings_tabs
      tabs = super
      if User.current.allowed_to?(:edit_project, @project) && @project.module_enabled?(:rubylode_progress)
        tabs << { name: "rubylode_progress", action: :edit_project, module: :rubylode_progress,
                  partial: "projects/settings/rubylode_progress", label: :label_rubylode_progress }
      end
      tabs
    end
  end
end
