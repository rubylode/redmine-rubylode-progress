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


module RubylodeProgress
  # The page's percent: each stage contributes 1 when done, otherwise its closed share; a current stage without issues
  # contributes one half and an upcoming one nothing. Nil when there are no stages.
  module PercentRule
    module_function

    def percent_for(stages)
      return nil if stages.empty?

      total = stages.sum { |stage| contribution(stage) }
      (total * 100 / stages.size).round
    end

    # One stage's own percent, rounded, counted the same way as its share of the page's percent.
    def percent_of(stage)
      (contribution(stage) * 100).round
    end

    def contribution(stage)
      return 1r if stage.done?
      return(stage.current? ? 1/2r : 0r) if stage.empty?

      Rational(stage.done_step_count, stage.step_count)
    end
  end
end
