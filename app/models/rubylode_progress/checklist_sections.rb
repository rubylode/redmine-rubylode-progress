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
  # Splits the checklist rows under headings. Grouping only changes the headings, never which items appear. Each
  # section's tally and percent count all of its issues, however the rows are filtered, so a heading never says "0/3"
  # beside a full meter.
  module ChecklistSections
    Section = Struct.new(:title, :version, :items, :done_count, :total_count, :total_done_count, keyword_init: true) do
      # The closed share of all the section's issues, rounded.
      def percent
        total_count.to_i.zero? ? 0 : Rational(total_done_count * 100, total_count).round
      end
    end

    module_function

    # by is "version" (in the order the items arrive, which is stage order), "category" (by name, then "No category")
    # or "parent" (by parent issue number, then "No parent"). scope_items is every issue the sections are made of; items
    # are the rows to show. Sections left without a row are dropped.
    def group(items, by:, viewer:, scope_items: items)
      shown = items.to_set.compare_by_identity
      case by
      when "category"
        grouped(scope_items, shown, key: ->(issue) { issue.category&.name }, title: ->(issue) { issue.category.name },
                                    order: :sorted, missing_key: "no_category", version: nil)
      when "parent"
        grouped(scope_items, shown, key: ->(issue) { issue.parent&.id }, title: ->(issue) { parent_title(issue.parent, viewer) },
                                    order: :sorted, missing_key: "no_parent", version: nil)
      else
        grouped(scope_items, shown, key: ->(issue) { issue.fixed_version }, title: ->(issue) { issue.fixed_version.name },
                                    order: :arrival, missing_key: nil, version: ->(issue) { issue.fixed_version })
      end
    end

    def grouped(scope_items, shown, key:, title:, order:, missing_key:, version:)
      owned, missing = scope_items.partition { |item| key.call(item.issue) }
      groups = owned.group_by { |item| key.call(item.issue) }
      keys = order == :sorted ? groups.keys.sort : groups.keys
      sections = keys.map do |group_key|
        first_issue = groups.fetch(group_key).first.issue
        section(title.call(first_issue), groups.fetch(group_key), shown, version: version&.call(first_issue))
      end
      missing_title = missing_key ? I18n.t("rubylode_progress.#{missing_key}") : nil
      sections << section(missing_title, missing, shown, version: nil) if missing.any?
      sections.reject { |built| built.items.empty? }
    end

    # The subject of a parent the viewer may not see is not theirs to read; its number is all the heading says.
    def parent_title(parent, viewer)
      parent.visible?(viewer) ? "##{parent.id} #{parent.subject}" : "##{parent.id}"
    end

    def section(title, scope_items, shown, version:)
      rows = scope_items.select { |item| shown.include?(item) }
      Section.new(title: title, version: version, items: rows, done_count: rows.count { |item| item.status == :done },
                  total_count: scope_items.size, total_done_count: scope_items.count { |item| item.status == :done })
    end
  end
end
