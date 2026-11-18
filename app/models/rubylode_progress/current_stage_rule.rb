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
  # The furthest open or locked version that has started (a closed issue, or one in progress); failing that, the first
  # open or locked version. When every version is closed there is no current stage.
  module CurrentStageRule
    module_function

    def pick(stages, in_progress_status_ids:)
      not_done = stages.reject { |stage| stage.version.closed? }
      started = not_done.select do |stage|
        stage.steps.any? { |step| step.done? || in_progress_status_ids.include?(step.issue.status_id) }
      end
      started.last || not_done.first
    end
  end
end
