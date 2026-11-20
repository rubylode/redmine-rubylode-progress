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
  # The parameters of Redmine's own issue list for the checklist's "Open as issue query" link: the project's counted
  # versions and the filter's status, plus the filter's own rule where Redmine's query can say it. Built here from known
  # names and integer ids, never from what the request sends. Next up is derived on the page and has no Redmine filter.
  module IssueQuery
    STATUS_OPERATORS = { "done" => "c", "all" => "*" }.freeze

    module_function

    def parameters_for(filter_name, version_ids:, narrowing: {})
      name = ChecklistFilter.valid?(filter_name) ? filter_name : ChecklistFilter::DEFAULT
      fields = %w[status_id fixed_version_id]
      operators = { "status_id" => STATUS_OPERATORS.fetch(name, "o"), "fixed_version_id" => "=" }
      values = { "fixed_version_id" => version_ids.map { |version_id| Integer(version_id).to_s } }
      add_own_rule(name, fields, operators, values)
      add_narrowing(name, narrowing, fields, operators, values)
      { set_filter: 1, f: fields, op: operators, v: values, sort: "id" }
    end

    # The assignee, tracker and category the viewer chose, as Redmine's own filters ("none" is its "none" operator). Needs
    # you already holds the assignee field with "me", and one field cannot say both, so it keeps its own rule.
    NARROWING_FIELDS = { "assignee" => "assigned_to_id", "tracker" => "tracker_id", "category" => "category_id" }.freeze

    def add_narrowing(name, narrowing, fields, operators, values)
      NARROWING_FIELDS.each do |dimension, field|
        value = narrowing[dimension]
        next if value.blank? || value == ChecklistNarrowing::ANY
        next if dimension == "assignee" && name == "needs_you"

        fields << field
        if value == ChecklistNarrowing::NONE
          operators[field] = "!*"
          values[field] = [""]
        else
          operators[field] = "="
          values[field] = [Integer(value, 10).to_s]
        end
      end
    end

    def add_own_rule(name, fields, operators, values)
      case name
      when "needs_you"
        fields << "assigned_to_id"
        operators["assigned_to_id"] = "="
        values["assigned_to_id"] = ["me"]
      when "overdue"
        fields << "due_date"
        operators["due_date"] = "<t-"
        values["due_date"] = ["0"]
      end
    end
  end
end
