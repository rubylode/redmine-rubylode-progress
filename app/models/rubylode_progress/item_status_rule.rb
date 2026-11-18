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


module RubylodeProgress
  # Derives an issue's status on the page (never stored). The first matching rule wins, in the order of STATUSES.
  class ItemStatusRule
    STATUSES = %i[done needs_you waiting next to_do].freeze

    def initialize(viewer_id:, viewer_group_ids:, in_progress_status_ids:, waiting_status_ids:, next_issue_ids:)
      @viewer_id = viewer_id
      @viewer_group_ids = viewer_group_ids
      @in_progress_status_ids = in_progress_status_ids
      @waiting_status_ids = waiting_status_ids
      @next_issue_ids = next_issue_ids
    end

    def status_for(issue)
      return :done if issue.closed?
      return :needs_you if assigned_to_viewer?(issue)
      return :waiting if issue.blocked? || @waiting_status_ids.include?(issue.status_id)
      return :next if @in_progress_status_ids.include?(issue.status_id) || @next_issue_ids.include?(issue.id)

      :to_do
    end

    private

    # An unassigned issue and an anonymous viewer are both nil; that is not a match.
    def assigned_to_viewer?(issue)
      return false if issue.assigned_to_id.nil?

      issue.assigned_to_id == @viewer_id || @viewer_group_ids.include?(issue.assigned_to_id)
    end
  end
end
