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

# Two nullable columns on the project settings row: the version ids a project has unticked (NULL means every counted
# version is a stage, so existing rows change nothing) and how many finished stages stay unfolded (NULL means the
# plugin-wide value).
class AddBusyProjectSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :rubylode_progress_project_settings, :excluded_version_ids, :text
    add_column :rubylode_progress_project_settings, :finished_stages_kept, :integer
  end
end
