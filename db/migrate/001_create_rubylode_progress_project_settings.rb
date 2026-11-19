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

# One row per project that overrides anything. Every override is its own nullable column, so an empty one (NULL) means
# the plugin-wide default and each keeps its type.
class CreateRubylodeProgressProjectSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :rubylode_progress_project_settings do |table|
      table.integer :project_id, null: false
      table.string :counted_versions
      table.string :version_name_prefix
      table.string :checklist_grouping
      table.text :in_progress_status_ids
      table.text :waiting_status_ids
      table.integer :next_issue_limit
      table.string :note_source
      table.timestamps null: true
    end
    add_index :rubylode_progress_project_settings, :project_id, unique: true,
              name: "index_rubylode_progress_project_settings_on_project_id"
  end
end
