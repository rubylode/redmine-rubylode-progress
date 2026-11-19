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
  # A date for the checklist's date column, built from the viewer's own date pattern when that is a plain
  # day-month-year one with the year first or last and a single separator ("%m/%d/%Y", "%d.%m.%Y", "%Y-%m-%d"): the
  # year is dropped for the current year and shortened to two digits for another. Any other pattern gives nil, and the
  # caller leaves Redmine's own format as it is.
  module RowDateFormat
    PLAIN_PATTERN = /\A%([dmY])([^%\w\s]+)%([dmY])\2%([dmY])\z/

    module_function

    def format(date, today:, pattern:)
      match = PLAIN_PATTERN.match(pattern.to_s)
      return nil unless match

      parts = [match[1], match[3], match[4]]
      return nil unless parts.sort == %w[Y d m]
      return nil unless parts.first == "Y" || parts.last == "Y"

      parts = parts.reject { |part| part == "Y" } if date.year == today.year
      date.strftime(parts.map { |part| part == "Y" ? "%y" : "%#{part}" }.join(match[2]))
    end
  end
end
