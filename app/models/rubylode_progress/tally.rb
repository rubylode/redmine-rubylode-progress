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
  # The four numbers on the summary tiles, counted over every item in the scope (never a filtered subset).
  class Tally
    def self.from(items)
      new(items.map(&:status))
    end

    def initialize(statuses)
      @statuses = statuses
    end

    def done_count = count(:done)

    def next_count = count(:next)

    def needs_you_count = count(:needs_you)

    # Everything not Done, so Next up and Needs you are part of it.
    def still_open_count = @statuses.size - done_count

    private

    def count(status)
      @statuses.count(status)
    end
  end
end
