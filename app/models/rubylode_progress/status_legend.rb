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
  # The names the "How statuses are decided" panel prints: the statuses the effective settings treat as in progress and
  # as waiting, and the Next limit. One query for both lists, so the panel tells the truth for this project.
  class StatusLegend
    def initialize(settings)
      @settings = settings
    end

    def in_progress_names = names_for(@settings.in_progress_status_ids)

    def waiting_names = names_for(@settings.waiting_status_ids)

    def next_issue_limit = @settings.next_issue_limit

    private

    def names_for(status_ids)
      status_ids.filter_map { |status_id| names_by_id[status_id.to_i] }
    end

    def names_by_id
      @names_by_id ||= begin
        ids = (@settings.in_progress_status_ids + @settings.waiting_status_ids).map(&:to_i).uniq
        ids.empty? ? {} : IssueStatus.where(id: ids).pluck(:id, :name).to_h
      end
    end
  end
end
