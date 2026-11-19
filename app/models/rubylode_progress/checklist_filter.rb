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
  # The four ways to narrow the checklist. The tiles are never filtered; only the rows are.
  module ChecklistFilter
    NAMES = %w[open needs_you done all].freeze
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

    def apply(name, items)
      case name
      when "needs_you" then items.select { |item| item.status == :needs_you }
      when "done" then items.select { |item| item.status == :done }
      when "all" then items
      else items.reject { |item| item.status == :done }
      end
    end
  end
end
