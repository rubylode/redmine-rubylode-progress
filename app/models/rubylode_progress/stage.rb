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
  # One version on the rail. State is :done, :partial (left behind with open steps), :current or :upcoming.
  Stage = Struct.new(:version, :number, :steps, :state, keyword_init: true) do
    def done?
      state == :done
    end

    def partial?
      state == :partial
    end

    def open_step_count
      step_count - done_step_count
    end

    def current?
      state == :current
    end

    def upcoming?
      state == :upcoming
    end

    def step_count
      steps.size
    end

    def done_step_count
      steps.count(&:done?)
    end

    def empty?
      steps.empty?
    end
  end
end
