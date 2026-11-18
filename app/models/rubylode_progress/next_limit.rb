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
  # Picks the current stage's first open issues the team can pick up next: highest priority first, then due date (none
  # last), then issue number. Only issues that would otherwise be To do are candidates, so an issue that is done, needs
  # the viewer, waits or is already in progress never uses up the limit. Nil issues means there is no current stage.
  module NextLimit
    module_function

    def issue_ids_for(current_stage_issues, limit:, status_rule_without_next:)
      return [] if current_stage_issues.nil?

      current_stage_issues
        .select { |issue| status_rule_without_next.status_for(issue) == :to_do }
        .sort_by { |issue| [-issue.priority_position, issue.due_date ? 0 : 1, issue.due_date || Date.new, issue.id] }
        .first(limit)
        .map(&:id)
    end
  end
end
