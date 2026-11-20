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

require "digest"

module RubylodeProgress
  # The fragment-cache key for one stage of the rail, as one viewer sees it. It names the viewer, and carries a digest of
  # the ids of the issues that viewer may see in the stage, so two people with different visibility never share an entry.
  # It does not name the viewer's role: visibility also depends on the person (own issues, private issues). The ids of
  # the closed steps are in it too, because updated_on is only stored to the second: closing one of several issues inside
  # the second of the last change would otherwise leave the state and the ids unchanged.
  # The round marks, the assignee and the stage's own percent are in the fragment too: the in-progress set and the assignees'
  # names are digested into the key; the percent follows the closed steps, already in it.
  # The pencils and the plus sit in the cached fragment, so the key also carries what decides them: a digest of the ids of
  # the stage's issues this viewer may edit, what the plus does for this viewer (none, modal or full form, which holds
  # the add-issues right), and the version's status. A role that loses a right changes the key on the next view.
  # The rows are draggable only where the viewer may edit (already in the digest of editable ids).
  # The status tag is a button only for a viewer who may manage versions in the version's own project, so that right is in
  # the key too, as true or false; it is worked out once per project, not per stage.
  # The rail line below a stage depends on the next stage, so it is drawn from properties on the uncached item around
  # this fragment, and nothing about a neighbour is in the key. Nothing in the fragment reads today, so no date is in it.
  module StageCacheKey
    # The stage's summary (name, status button, date, meter, counts, the blocking line) is one fragment and its issue
    # list another, so a folded stage can show the first and load the second later, and the summary never depends on the
    # list. Each key carries what its fragment reads. The summary reads the stage's state and counts (the ids digests),
    # the version, the settings and the right to manage versions. The list (the open issues and the closed fold, whose
    # closed rows are a third fragment, part: :closed, fetched when the fold is opened) reads the issues themselves: the assignees,
    # the in-progress marks, the pencils and the plus. Whether the stage is a drop target is not in either: that is on the
    # details tag, outside the cache.
    def self.for_summary(stage:, project:, viewer:, settings:, can_manage_version:)
      step_issues = stage.steps.map(&:issue)
      ["rubylode_progress/stage_summary", *shared_parts(stage, project, viewer, settings, step_issues), can_manage_version]
    end

    def self.for_issues(stage:, project:, viewer:, settings:, editable_issue_ids:, new_issue_mode:, part: :open, closed_inline: false)
      step_issues = stage.steps.map(&:issue)
      editable_step_issues = step_issues.select { |issue| editable_issue_ids.include?(issue.id) }
      ["rubylode_progress/stage_issues", part, closed_inline, *shared_parts(stage, project, viewer, settings, step_issues),
       digest_of_ids(editable_step_issues), new_issue_mode, digest_of_ids(in_progress_issues(step_issues, settings)),
       digest_of_assignees(step_issues)]
    end

    def self.shared_parts(stage, project, viewer, settings, step_issues)
      [project.id, viewer.id, stage.version.id, precise(stage.version.updated_on), stage.number, stage.state,
       digest_of_ids(step_issues), digest_of_ids(stage.steps.select(&:done?).map(&:issue)),
       precise(step_issues.filter_map(&:updated_on).max), settings.cache_digest, I18n.locale, stage.version.status]
    end

    # The half-filled marks: open issues in one of the settings' in-progress statuses. updated_on is stored to the
    # second, so the set is in the key itself, like the closed steps.
    def self.in_progress_issues(issues, settings)
      issues.select { |issue| !issue.closed? && settings.in_progress_status_ids.include?(issue.status_id) }
    end

    # The assignees' names are in the fragment but not on the issue, so a renamed person must change the key. The viewer
    # (whose own issues show no name) is already in the key.
    def self.digest_of_assignees(issues)
      Digest::SHA256.hexdigest(issues.map { |issue| "#{issue.id}:#{issue.assigned_to&.id}:#{issue.assigned_to&.name}" }.sort.join(","))
    end

    def self.digest_of_ids(issues)
      Digest::SHA256.hexdigest(issues.map(&:id).sort.join(","))
    end

    # A Time in a cache key is written to the second, so two changes inside one second would share an entry.
    def self.precise(time)
      time&.utc&.iso8601(6)
    end
  end
end
