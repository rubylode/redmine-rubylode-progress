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
  # The three selects above the checklist: assignee, tracker and category. The offered values are only those that occur
  # among the issues handed in (the viewer's visible counted issues), found in one pass over issues already loaded. A
  # chosen value that is not offered (stale, unknown, not a string) is "any". They narrow the checklist and its pill
  # counts; the stage list and the top track never read them.
  module ChecklistNarrowing
    DIMENSIONS = %w[assignee tracker category].freeze
    ANY = "any"
    NONE = "none"

    Option = Struct.new(:value, :label, :count, keyword_init: true)

    module_function

    # { assignee: [Option], tracker: [Option], category: [Option] }, each sorted by name with "none" last; "any" is not
    # in the lists, the view puts it first.
    def options_for(items)
      tallies = DIMENSIONS.to_h { |dimension| [dimension, Hash.new { |hash, key| hash[key] = Option.new(value: key[0], label: key[1], count: 0) }] }
      items.each do |item|
        DIMENSIONS.each do |dimension|
          value, label = value_and_label(dimension, item.issue)
          tallies[dimension][[value, label]].count += 1
        end
      end
      DIMENSIONS.to_h { |dimension| [dimension.to_sym, sorted(tallies[dimension].values)] }
    end

    # The request's values, each kept only when it is offered: { "assignee" => "10" or "none" or "any", ... }.
    def resolve(requested, options)
      DIMENSIONS.to_h do |dimension|
        value = requested[dimension]
        offered = value.is_a?(String) && options.fetch(dimension.to_sym).any? { |option| option.value == value }
        [dimension, offered ? value : ANY]
      end
    end

    def apply(selection, items)
      chosen = selection.reject { |_dimension, value| value == ANY }
      return items if chosen.empty?

      items.select { |item| chosen.all? { |dimension, value| value_and_label(dimension, item.issue).first == value } }
    end

    # The chosen values only, for an address: nothing for "any".
    def parameters_for(selection)
      selection.reject { |_dimension, value| value == ANY }
    end

    def value_and_label(dimension, issue)
      case dimension
      when "assignee"
        issue.assigned_to_id ? [issue.assigned_to_id.to_s, issue.assigned_to&.name.to_s] : [NONE, I18n.t("rubylode_progress.narrowing.unassigned")]
      when "tracker"
        [issue.tracker_id.to_s, issue.tracker&.name.to_s]
      else
        issue.category_id ? [issue.category_id.to_s, issue.category&.name.to_s] : [NONE, I18n.t("rubylode_progress.no_category")]
      end
    end

    def sorted(options)
      options.sort_by { |option| [option.value == NONE ? 1 : 0, option.label.downcase] }
    end
  end
end
