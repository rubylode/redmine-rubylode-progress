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
  # The quiet line under a checklist row: the issue's latest note the viewer may see, or the value of the custom field
  # named in the settings when the viewer may see that field.
  class ItemNotes
    NOTE_LENGTH = 240

    def self.for(issues, viewer:, settings:)
      new(issues, viewer: viewer, settings: settings).notes
    end

    def initialize(issues, viewer:, settings:)
      @issues = issues
      @viewer = viewer
      @settings = settings
    end

    # { issue_id => text }, with no key for an issue that has nothing to say.
    def notes
      return {} if @issues.empty?

      @settings.note_custom_field_id ? custom_field_notes : latest_notes
    end

    private

    def latest_notes
      rows = Journal.visible(@viewer)
                    .where(journalized_type: "Issue", journalized_id: @issues.map(&:id))
                    .where.not(notes: [nil, ""])
                    .reorder(:id)
                    .pluck(:journalized_id, :notes)
      rows.to_h.transform_values { |text| shorten(text) }
    end

    def custom_field_notes
      field_id = @settings.note_custom_field_id
      @issues.each_with_object({}) do |issue, notes|
        value = issue.custom_values.find { |custom_value| custom_value.custom_field_id == field_id }
        next unless value&.custom_field&.visible_by?(issue.project, @viewer)
        next if value.value.blank?

        notes[issue.id] = shorten(value.value)
      end
    end

    def shorten(text)
      text.to_s.strip[0, NOTE_LENGTH]
    end
  end
end
