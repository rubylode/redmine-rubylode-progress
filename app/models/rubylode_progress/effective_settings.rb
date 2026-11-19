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

require "digest"

module RubylodeProgress
  # The settings that apply to one project, frozen: the plugin-wide values with the project's filled overrides laid over
  # them (an empty override falls back).
  EffectiveSettings = Data.define(:counted_versions, :version_name_prefix, :checklist_grouping,
                                  :in_progress_status_ids, :waiting_status_ids, :next_issue_limit,
                                  :note_custom_field_id) do
    def self.for(project, plugin_settings: Settings.new)
      row = project.rubylode_progress_setting
      plugin_settings = plugin_settings.with_overrides(row.overrides) if row
      new(counted_versions: plugin_settings.counted_versions,
          version_name_prefix: plugin_settings.version_name_prefix.freeze,
          checklist_grouping: plugin_settings.checklist_grouping,
          in_progress_status_ids: plugin_settings.in_progress_status_ids.freeze,
          waiting_status_ids: plugin_settings.waiting_status_ids.freeze,
          next_issue_limit: plugin_settings.next_issue_limit,
          note_custom_field_id: plugin_settings.note_custom_field_id)
    end

    # Changes whenever any value changes, for cache keys.
    def cache_digest
      Digest::SHA256.hexdigest(to_h.sort.inspect)
    end
  end
end
