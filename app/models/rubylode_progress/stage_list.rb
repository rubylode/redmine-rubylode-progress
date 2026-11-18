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
  # Turns versions and their issues into ordered, numbered stages, each done, current or upcoming.
  class StageList
    def initialize(versions:, issues:, in_progress_status_ids:)
      @versions = versions
      @issues = issues
      @in_progress_status_ids = in_progress_status_ids
    end

    def stages
      @stages ||= build_stages
    end

    def current_stage
      stages.find(&:current?)
    end

    def finished_stage_count
      stages.count(&:done?)
    end

    def stage_count
      stages.size
    end

    def all_done?
      stages.any? && stages.all?(&:done?)
    end

    private

    # Only an open or locked version can be current. A stage is done when nothing in it is open and its version is
    # closed or lies behind the current stage; any other stage behind the current one, or closed, is partial.
    def build_stages
      built = ordered_versions.each_with_index.map do |version, index|
        stage_number = index + 1
        Stage.new(version: version, number: stage_number, steps: steps_for(version, stage_number), state: :upcoming)
      end
      current = CurrentStageRule.pick(built, in_progress_status_ids: @in_progress_status_ids)
      current_number = current&.number || built.size + 1
      built.each { |stage| stage.state = state_for(stage, current_number) }
      built
    end

    def state_for(stage, current_number)
      return :current if stage.number == current_number

      finished_already = stage.version.closed? || stage.number < current_number
      return :upcoming unless finished_already

      stage.steps.all?(&:done?) ? :done : :partial
    end

    # Positions follow the issue number, so a step keeps its number when its priority changes.
    def steps_for(version, stage_number)
      issues_by_version_id.fetch(version.id, []).sort_by(&:id).each_with_index.map do |issue, index|
        Step.new(issue: issue, number: "#{stage_number}.#{index + 1}")
      end
    end

    def issues_by_version_id
      @issues_by_version_id ||= @issues.group_by(&:fixed_version_id)
    end

    # Undated versions go last, as Redmine's own Version#<=> puts them.
    def ordered_versions
      @versions.sort_by do |version|
        undated = version.effective_date.nil? ? 1 : 0
        [undated, version.effective_date || Date.new(0), version.name.to_s.downcase]
      end
    end
  end
end
