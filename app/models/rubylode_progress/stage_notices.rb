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
  # The notices in the tracker header: at most one Behind (the oldest overdue stage, with a count of the others) and one
  # Due soon (the current stage, whenever it has a due date). A current stage already past its date is Behind instead.
  module StageNotices
    # A Behind notice names the oldest stage, up to two others (other_stage_names) and counts the rest (more_count): never
    # more than three names.
    Notice = Struct.new(:kind, :stage_name, :days, :open_count, :other_stage_names, :more_count, keyword_init: true)
    NAMED_OTHER_STAGES = 2

    module_function

    def for(stages, today:)
      overdue = stages.select { |stage| (stage.partial? || stage.current?) && overdue?(stage, today) }
                      .sort_by { |stage| stage.version.effective_date }
      notices = []
      notices << behind_notice(overdue, today) if overdue.any?
      current = stages.find(&:current?)
      notices << due_soon_notice(current, today) if current && current.version.effective_date && !overdue?(current, today)
      notices
    end

    def overdue?(stage, today)
      date = stage.version.effective_date
      !date.nil? && date < today
    end

    def behind_notice(overdue, today)
      oldest = overdue.first
      others = overdue.drop(1)
      Notice.new(kind: :behind, stage_name: oldest.version.name, days: (today - oldest.version.effective_date).to_i,
                 open_count: oldest.open_step_count, other_stage_names: others.first(NAMED_OTHER_STAGES).map { |stage| stage.version.name },
                 more_count: [others.size - NAMED_OTHER_STAGES, 0].max)
    end

    def due_soon_notice(stage, today)
      Notice.new(kind: :due_soon, stage_name: stage.version.name, days: DueDate.days_until(stage.version.effective_date, today),
                 open_count: stage.open_step_count, other_stage_names: [], more_count: 0)
    end
  end
end
