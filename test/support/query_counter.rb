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

# Counts the SQL statements a block runs, leaving out schema lookups, transaction control and cached repeats.
module QueryCounter
  IGNORED_NAMES = ["SCHEMA", "TRANSACTION"].freeze

  def self.count(&block)
    statements = statements(&block)
    statements.size
  end

  # The statements themselves, for naming each query in a ceiling's comment.
  def self.statements
    collected = []
    subscriber = lambda do |*, payload|
      next if IGNORED_NAMES.include?(payload[:name]) || payload[:cached]

      collected << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    collected
  end
end
