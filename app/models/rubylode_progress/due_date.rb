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
  # The day an issue is due: its own, else its version's. The checklist's Overdue filter and the dates on the rows both
  # read it, so the two always agree.
  module DueDate
    module_function

    def for(issue)
      issue.due_date || issue.fixed_version&.effective_date
    end

    # Whole days from today to the date, negative when it has passed.
    def days_until(date, today)
      (date - today).to_i
    end
  end
end
