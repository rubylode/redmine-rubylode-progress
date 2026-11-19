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
  # One project's compact tracker for the cross-project page: its stages, the current one and the percent. Built from
  # the same IssueScope, StageList and PercentRule as the project page, but with only the issue columns they read.
  ProjectTracker = Struct.new(:project, :stages, :current_stage, :percent, keyword_init: true) do
    LIGHT_ISSUE_COLUMNS = %w[id project_id fixed_version_id status_id].freeze

    def self.for(project, viewer:)
      settings = EffectiveSettings.for(project)
      scope = IssueScope.new(project: project, viewer: viewer, settings: settings,
                             issue_preloads: [:status], issue_columns: LIGHT_ISSUE_COLUMNS)
      stage_list = StageList.new(versions: scope.versions, issues: scope.issues,
                                 in_progress_status_ids: settings.in_progress_status_ids)
      new(project: project, stages: stage_list.stages, current_stage: stage_list.current_stage,
          percent: PercentRule.percent_for(stage_list.stages))
    end
  end
end
