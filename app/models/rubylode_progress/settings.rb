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
  # The plugin-wide settings (Administration, Plugins, Configure), kept by Redmine as one hash under
  # Setting.plugin_redmine_rubylode_progress. Anything missing or unusable reads as the default, so a half-filled hash
  # from an older version never breaks the page.
  class Settings
    PLUGIN_ID = :redmine_rubylode_progress
    COUNTED_VERSIONS_CHOICES = %w[all prefix].freeze
    CHECKLIST_GROUPING_CHOICES = %w[version category parent].freeze
    NEXT_ISSUE_LIMIT_RANGE = (0..20)
    CUSTOM_FIELD_NOTE_SOURCE = /\Acustom_field_(\d+)\z/

    DEFAULTS = {
      "counted_versions" => "all",
      "version_name_prefix" => "",
      "checklist_grouping" => "version",
      "in_progress_status_ids" => [],
      "waiting_status_ids" => [],
      "next_issue_limit" => "3",
      "note_source" => "latest_note"
    }.freeze

    # An unsaved hash can be passed in (tests, the settings form); by default the saved one is read.
    def initialize(values = nil)
      @values = (values || saved_values).to_h.stringify_keys
    end

    def counted_versions = choice("counted_versions", COUNTED_VERSIONS_CHOICES)

    def version_name_prefix = @values.fetch("version_name_prefix", DEFAULTS["version_name_prefix"]).to_s

    def checklist_grouping = choice("checklist_grouping", CHECKLIST_GROUPING_CHOICES)

    def in_progress_status_ids = status_ids("in_progress_status_ids")

    def waiting_status_ids = status_ids("waiting_status_ids")

    # A whole number outside the range is held to it; anything else reads as the default.
    def next_issue_limit
      Integer(@values["next_issue_limit"].to_s, 10).clamp(NEXT_ISSUE_LIMIT_RANGE)
    rescue ArgumentError, TypeError
      Integer(DEFAULTS["next_issue_limit"], 10)
    end

    # The custom field whose value is the item note, or nil for the latest visible note.
    def note_custom_field_id
      match = CUSTOM_FIELD_NOTE_SOURCE.match(@values["note_source"].to_s)
      match && Integer(match[1], 10)
    end

    # The note source as the settings form names it: "latest_note" or "custom_field_<id>".
    def note_source
      note_custom_field_id ? "custom_field_#{note_custom_field_id}" : DEFAULTS["note_source"]
    end

    # The same settings with a project's filled overrides laid over them.
    def with_overrides(overrides)
      self.class.new(@values.merge(overrides.to_h.stringify_keys))
    end

    private

    def choice(key, choices)
      value = @values[key]
      choices.include?(value) ? value : DEFAULTS[key]
    end

    def status_ids(key)
      Array(@values[key]).filter_map { |value| Integer(value.to_s, 10) rescue nil }.uniq
    end

    def saved_values
      Setting.send(:"plugin_#{PLUGIN_ID}") || {}
    end
  end
end
