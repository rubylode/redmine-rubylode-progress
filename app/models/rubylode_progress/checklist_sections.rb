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
  # Splits the checklist rows under headings. Grouping only changes the headings, never which items appear.
  module ChecklistSections
    Section = Struct.new(:title, :items, :done_count, keyword_init: true)

    module_function

    # by is "version" (in the order the items arrive, which is stage order), "category" (by name, then "No category")
    # or "parent" (by parent issue number, then "No parent").
    def group(items, by:)
      case by
      when "category" then grouped(items, ->(issue) { issue.category }, :name, "no_category")
      when "parent" then grouped(items, ->(issue) { issue.parent }, :id, "no_parent", title: ->(parent) { "##{parent.id} #{parent.subject}" })
      else grouped(items, ->(issue) { issue.fixed_version }, nil, nil)
      end
    end

    def grouped(items, owner_of, sort_key, missing_key, title: :name.to_proc)
      owned, missing = items.partition { |item| owner_of.call(item.issue) }
      groups = owned.group_by { |item| owner_of.call(item.issue) }
      owners = sort_key ? groups.keys.sort_by(&sort_key) : groups.keys
      sections = owners.map { |owner| section(title.call(owner), groups.fetch(owner)) }
      sections << section(I18n.t("rubylode_progress.#{missing_key}"), missing) if missing.any? && missing_key
      sections << section(nil, missing) if missing.any? && !missing_key
      sections
    end

    def section(title, items)
      Section.new(title: title, items: items, done_count: items.count { |item| item.status == :done })
    end
  end
end
