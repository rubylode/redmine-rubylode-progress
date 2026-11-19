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
  # The six ways to narrow the checklist, in the order of the pills. The stage list is never filtered; only the rows are.
  module ChecklistFilter
    NAMES = %w[needs_you overdue next open done all].freeze
    DEFAULT = "open"
    PREFERENCE_KEY = :rubylode_progress_checklist_filter

    module_function

    def valid?(name)
      NAMES.include?(name)
    end

    # The requested filter if it exists, else the remembered one if it still exists, else Open.
    def resolve(requested:, remembered:)
      return requested if valid?(requested)
      return remembered if valid?(remembered)

      DEFAULT
    end

    def apply(name, items, today: Date.current)
      case name
      when "needs_you" then items.select { |item| item.status == :needs_you }
      when "overdue" then items.select { |item| overdue?(item, today: today) }
      when "next" then items.select { |item| item.status == :next }
      when "done" then items.select { |item| item.status == :done }
      when "all" then items
      else items.reject { |item| item.status == :done }
      end
    end

    # How many rows each filter would show, for the numbers on the pills.
    def counts(items, today: Date.current)
      NAMES.to_h { |name| [name, apply(name, items, today: today).size] }
    end

    # Open and past its own due date, or, with none of its own, its version's. A closed issue is never overdue.
    def overdue?(item, today:)
      return false if item.status == :done

      due = DueDate.for(item.issue)
      !due.nil? && due < today
    end
  end
end
