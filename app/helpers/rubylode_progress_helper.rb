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
  # The colour a stage state draws its line and mark in, as a custom property.
  STATE_COLOR_PROPERTIES = {
    done: "--rubylode-progress-done-color", partial: "--rubylode-progress-behind-color",
    current: "--rubylode-progress-accent-color", upcoming: "--rubylode-progress-track-empty-color"
  }.freeze
  DUE_SOON_DAYS = 7
  NOTE_PREVIEW_LENGTH = 110 # about two lines of a checklist row
  # Over this many stages the top track stops labelling every stage: it folds the older finished ones into one mark and
  # labels only the current stage and its neighbours.
  TRACK_CONDENSE_THRESHOLD = 12
  FINISHED_FOLD_ANCHOR = "rubylode-progress-finished-fold"

# Redmine's modal is a jQuery UI dialog with an overlay behind it; a click on the overlay, that is anywhere outside
# the dialog, closes it. Appended to each modal response, after showModal has opened the dialog.
def rubylode_progress_close_on_outside_click_script
  "$('.ui-widget-overlay').off('click.rubylodeProgress').on('click.rubylodeProgress', function () { " \
    "$('#ajax-modal').dialog('close'); });".html_safe
end

def rubylode_progress_status_label(status)
    l("rubylode_progress.status.#{status}")
  end

  # "11/24": a short date, for the lines under the marks and on the rows.
  def rubylode_progress_short_date(date)
    date && I18n.l(date.to_date, format: "%m/%d")
  end

  def rubylode_progress_days(count)
    l("rubylode_progress.days", count: count)
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

  # The mark's state for a checklist row: done when closed, in progress when its status is one of the settings' in
  # progress statuses, else the derived status (to-do, next, waiting, needs-you), each with its own shape.
  def rubylode_progress_row_mark_state(item, settings)
    if item.status == :done
      "done"
    elsif settings.in_progress_status_ids.include?(item.issue.status_id)
      "in-progress"
    else
      item.status.to_s.dasherize
    end
  end

  # The assignee's name for a row, or nil when there is none or it is the viewer (the Needs you pill says that).
  def rubylode_progress_assignee_name(issue)
    assignee = issue.assigned_to
    assignee && assignee.id != User.current.id ? assignee.name : nil
  end

  # Why a version takes no new issues, for the drop that is refused: it is closed, locked, or (open) not shared with
  # the project. A viewer who may manage the version is told how to open it again. Depends on the version's status and
  # name and on that right, which the stage cache key already carries.
  def rubylode_progress_refuse_reason(version, can_manage: false)
    kind = %w[closed locked].include?(version.status) ? version.status : "not_shared"
    reason = l("rubylode_progress.refuse.#{kind}", version: version.name)
    reason += l("rubylode_progress.refuse_hint.#{kind}") if can_manage && kind != "not_shared"
    reason
  end

  # A day for the checklist's date column and the Updated line: the viewer's own plain day-month-year pattern with the
  # year dropped for this year, else Redmine's own format.
  def rubylode_progress_day_text(date, today)
    pattern = Setting.date_format.presence || ::I18n.t("date.formats.default")
    RubylodeProgress::RowDateFormat.format(date.to_date, today: today, pattern: pattern) || format_date(date)
  end

  # "11/19": the day of the last change, in the viewer's time zone.
  def rubylode_progress_updated_text(time, today)
    rubylode_progress_day_text(User.current.convert_time_to_user_timezone(time).to_date, today)
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

  def rubylode_progress_stage_state_label(stage)
    l("rubylode_progress.stage_state.#{stage.state}")
  end

  # The one line under a stage's mark in the top tracker, as [kind, text], or nil when there is nothing to say.
  def rubylode_progress_stage_date_line(stage, today)
    date = stage.version.effective_date
    if stage.done?
      closed_on = stage.steps.filter_map { |step| step.issue.closed_on }.max
      return [:done, closed_on ? l("rubylode_progress.track_dates.done", date: rubylode_progress_short_date(closed_on)) : l("rubylode_progress.track_dates.done_without_date")]
    end
    return nil unless date

    formatted = rubylode_progress_short_date(date)
    days = RubylodeProgress::DueDate.days_until(date, today)
    if days.negative? && (stage.partial? || stage.current?)
      [:overdue, l("rubylode_progress.track_dates.overdue", date: formatted)]
    elsif days.zero?
      [:due, l("rubylode_progress.track_dates.due_today", date: formatted)]
    elsif days.positive?
      [:due, l("rubylode_progress.track_dates.due_in", date: formatted, days: rubylode_progress_days(days))]
    else
      [:due, l("rubylode_progress.track_dates.due", date: formatted)]
    end
  end

  # The share a stage's segment and rail line are filled to: the percent rule's number for the stage.
  def rubylode_progress_stage_share(stage)
    rubylode_progress_stage_percent(stage)
  end

  # Inline properties for one segment of the top tracker.
  def rubylode_progress_segment_style(stage)
    "--rubylode-progress-share: #{rubylode_progress_stage_share(stage)}%; " \
      "--rubylode-progress-segment-color: var(#{STATE_COLOR_PROPERTIES.fetch(stage.state)})"
  end

# Inline properties for a stage's item on the rail. The line below a stage's mark belongs to that stage: it is
# filled, top down, to the stage's own share in the stage's own colour, so a done stage runs green to the next mark
# and a stage left behind runs red below its own mark. The first stage also gets a short lead-in above its mark in
# the same colour. Only the stage itself is read, so the cached fragment and its wrapper never depend on a neighbour.
def rubylode_progress_rail_style(stages, index)
  stage = stages[index]
  "--rubylode-progress-share-below: #{rubylode_progress_stage_share(stage)}%; " \
    "--rubylode-progress-colour-below: var(#{STATE_COLOR_PROPERTIES.fetch(stage.state)})"
end

  # What the top track draws, in order, as [entry, labelled] pairs: a stage or the fold's summary mark. Up to
  # TRACK_CONDENSE_THRESHOLD stages (or without labels, as on the cross-project page) it is every stage, labelled. Above
  # that: the first folded stage's mark, the summary mark, then every other stage; only the current stage and its two
  # neighbours are labelled (the last two stages when none is current).
  def rubylode_progress_track_entries(stages, fold, condense:)
    return stages.map { |stage| [stage, true] } unless condense && stages.size > TRACK_CONDENSE_THRESHOLD

    labelled = rubylode_progress_labelled_stages(stages)
    stages.each_with_object([]) do |stage, entries|
      if !fold.folded?(stage)
        entries << [stage, labelled.any? { |other| other.equal?(stage) }]
      elsif stage.equal?(fold.first_stage)
        entries << [stage, false] << [fold, false]
      end
    end
  end

  def rubylode_progress_labelled_stages(stages)
    current_index = stages.index(&:current?)
    return stages.last(2) unless current_index

    stages[[current_index - 1, 0].max..(current_index + 1)]
  end

  # The tooltip of a mark that has no visible label.
  def rubylode_progress_track_mark_title(stage)
    l("rubylode_progress.track_mark_title", name: stage.version.name, percent: rubylode_progress_stage_percent(stage),
                                            state: rubylode_progress_stage_state_label(stage))
  end

  # The sentence of one notice in the tracker header.
  def rubylode_progress_notice_text(notice)
    open_text = if notice.kind == :behind
                  l("rubylode_progress.notices.open_issues", count: notice.open_count)
                else
                  l("rubylode_progress.notices.open_count", count: notice.open_count)
                end
    if notice.kind == :behind
      key = notice.other_stage_names.any? ? "behind_also" : "behind"
      l("rubylode_progress.notices.#{key}", stage: notice.stage_name, days: rubylode_progress_days(notice.days),
                                          open: open_text, others: rubylode_progress_other_stages_text(notice))
    elsif notice.days.zero?
      l("rubylode_progress.notices.due_today", stage: notice.stage_name, open: open_text)
    else
      l("rubylode_progress.notices.due_soon", stage: notice.stage_name, open: open_text, days: rubylode_progress_days(notice.days))
    end
  end

  # The other stages a Behind notice names, with "and N more" for the rest: "Alpha and Gamma", "Alpha, Gamma and 4 more".
  def rubylode_progress_other_stages_text(notice)
    names = notice.other_stage_names.dup
    names << l("rubylode_progress.notices.and_more", count: notice.more_count) if notice.more_count.positive?
    names.to_sentence
  end

  # An issue note cut for the row: [the text shown, whether there is more to show in the "show note" details].
  def rubylode_progress_note_preview(note)
    [truncate(note, length: NOTE_PREVIEW_LENGTH, separator: " "), note.length > NOTE_PREVIEW_LENGTH]
  end
  # What a folded partial stage says under its name: its one open issue, or how many there are.
  def rubylode_progress_blocking_text(stage)
    open_steps = stage.steps.reject(&:done?)
    return nil if open_steps.empty?

    if open_steps.one?
      issue = open_steps.first.issue
      l("rubylode_progress.blocking", count: 1, title: issue.subject, id: issue.id)
    else
      l("rubylode_progress.blocking", count: open_steps.size)
    end
  end

  # A row's date as [kind, text]: Closed for a done issue, then overdue, due within a week (with the weekday and the days
  # left), the plain date, or a dash.
  def rubylode_progress_row_date(item, today)
    issue = item.issue
    if item.status == :done
      return [:none, l("rubylode_progress.row_dates.none")] unless issue.closed_on

      return [:closed, l("rubylode_progress.row_dates.closed", date: rubylode_progress_short_date(issue.closed_on))]
    end

    due = RubylodeProgress::DueDate.for(issue)
    return [:none, l("rubylode_progress.row_dates.none")] unless due

    days = RubylodeProgress::DueDate.days_until(due, today)
    if days.negative?
      [:overdue, l("rubylode_progress.row_dates.overdue", days: -days)]
    elsif days <= DUE_SOON_DAYS
      [:soon, l("rubylode_progress.row_dates.due_soon", date: I18n.l(due.to_date, format: "%a %m/%d"), days: days)]
    else
      [:plain, rubylode_progress_day_text(due, today)]
    end
  end

  # Where "Open as issue query" goes: Redmine's issue list, built from the project and the filter.
  def rubylode_progress_issue_query_path(project, filter, stages, narrowing = {})
    project_issues_path(project, **RubylodeProgress::IssueQuery.parameters_for(filter, version_ids: stages.map { |stage| stage.version.id },
                                                                                          narrowing: narrowing))
  end

  # The page's own address with one more stage opened, for a folded stage's link without a script. The parameters are the
  # page's own, already checked ones (filter, grouping, selects); nothing else the request carried is copied.
  def rubylode_progress_open_stage_path(project, version, link_parameters)
    project_rubylode_progress_path(project, **link_parameters, open_stage: version.id)
  end

  # The checklist's own address with its filter, the grouping only when it differs from the project's setting, the
  # chosen assignee, tracker and category (none for "any"), and the section to list in full when one is named.
  def rubylode_progress_checklist_params(filter:, grouping:, default_grouping:, narrowing: {}, expand: nil, open: nil)
    { filter: filter, group: (grouping == default_grouping ? nil : grouping), expand: expand, open: open,
      **RubylodeProgress::ChecklistNarrowing.parameters_for(narrowing).transform_keys(&:to_sym) }.compact
  end
end
