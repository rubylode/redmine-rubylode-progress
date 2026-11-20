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
  # One project's overrides of the plugin-wide settings. A NULL column means "use the plugin-wide value".
  class ProjectSetting < ActiveRecord::Base
    self.table_name = "rubylode_progress_project_settings"

    OVERRIDE_ATTRIBUTES = %w[counted_versions version_name_prefix checklist_grouping in_progress_status_ids
                             waiting_status_ids next_issue_limit note_source finished_stages_kept checklist_rows_per_section].freeze
    MAXIMUM_PREFIX_LENGTH = 60

    belongs_to :project

    serialize :in_progress_status_ids, coder: JSON
    serialize :waiting_status_ids, coder: JSON
    # The versions the project has unticked; NULL (the default) counts every version.
    serialize :excluded_version_ids, coder: JSON

    validates :project, presence: true
    validates :counted_versions, inclusion: { in: Settings::COUNTED_VERSIONS_CHOICES }, allow_nil: true
    validates :checklist_grouping, inclusion: { in: Settings::CHECKLIST_GROUPING_CHOICES }, allow_nil: true
    validates :next_issue_limit, numericality: { only_integer: true }, allow_nil: true
    validates :next_issue_limit, inclusion: { in: Settings::NEXT_ISSUE_LIMIT_RANGE }, allow_nil: true
    validates :finished_stages_kept, numericality: { only_integer: true }, allow_nil: true
    validates :finished_stages_kept, inclusion: { in: Settings::FINISHED_STAGES_KEPT_RANGE }, allow_nil: true
    validates :checklist_rows_per_section, numericality: { only_integer: true }, allow_nil: true
    validates :checklist_rows_per_section, inclusion: { in: Settings::CHECKLIST_ROWS_PER_SECTION_RANGE }, allow_nil: true
    validates :version_name_prefix, length: { maximum: MAXIMUM_PREFIX_LENGTH }, allow_nil: true
    validates :note_source, format: { with: /\A(latest_note|custom_field_\d+)\z/ }, allow_nil: true

    before_validation :turn_blank_strings_into_defaults

    def self.for(project)
      find_by(project_id: project.id) || new(project: project)
    end

    # The filled columns only, under the names Settings reads.
    def overrides
      OVERRIDE_ATTRIBUTES.each_with_object({}) do |name, filled|
        value = self[name]
        filled[name] = value unless value.nil?
      end
    end

    private

    def turn_blank_strings_into_defaults
      %w[counted_versions version_name_prefix checklist_grouping note_source].each do |name|
        self[name] = nil if self[name].blank?
      end
    end
  end
end
