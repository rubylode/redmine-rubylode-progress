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

module RubylodeProgressHelper
  def rubylode_progress_status_label(status)
    l("rubylode_progress.status.#{status}")
  end

  # The due date, else the day a done item was closed.
  def rubylode_progress_item_date(item)
    issue = item.issue
    date = issue.due_date || (item.status == :done ? issue.closed_on : nil)
    date && format_date(date)
  end

  # The round mark's state for one issue: done when closed, in progress when its status is one of the settings' in
  # progress statuses, else open. It never reads the derived status, so the cached stage fragment stays valid.
  def rubylode_progress_mark_state(issue, settings)
    if issue.closed?
      "done"
    elsif settings.in_progress_status_ids.include?(issue.status_id)
      "in-progress"
    else
      "open"
    end
  end

  # The fold's percentage, as the percent rule counts a stage.
  def rubylode_progress_stage_percent(stage)
    RubylodeProgress::PercentRule.percent_of(stage)
  end

  def rubylode_progress_stage_summary(stage)
    if stage.current?
      l("rubylode_progress.stage_summary.current", done: stage.done_step_count, total: stage.step_count)
    elsif stage.partial?
      l("rubylode_progress.stage_summary.partial", done: stage.done_step_count, total: stage.step_count,
                                                   left: stage.open_step_count)
    elsif stage.done?
      l("rubylode_progress.stage_summary.done", count: stage.step_count)
    else
      l("rubylode_progress.stage_summary.upcoming", count: stage.step_count)
    end
  end
end
