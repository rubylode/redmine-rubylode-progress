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
  # The finished stages (state done) older than the last few, folded into one row of the stage list and drawn as one
  # summary mark on the top track. Partial, current, open and upcoming stages are never folded, whatever their version's
  # status. Fewer than two stages to fold is no fold at all: one row for one stage would say nothing.
  class FinishedStageFold
    MINIMUM_FOLDED_STAGES = 2

    def initialize(stages, kept_count)
      @stages = stages
      finished = stages.select(&:done?)
      older = finished.size > kept_count ? finished.first(finished.size - kept_count) : []
      @folded_stages = older.size >= MINIMUM_FOLDED_STAGES ? older : []
      @folded_stage_ids = @folded_stages.to_set { |stage| stage.version.id }
    end

    attr_reader :folded_stages

    def active? = @folded_stages.any?

    def folded?(stage) = @folded_stage_ids.include?(stage.version.id)

    def stage_count = @folded_stages.size

    def first_stage = @folded_stages.first

    def issue_count = @folded_stages.sum(&:step_count)

    # The combined closed share of the folded stages: closed issues over all of them (all closed, for a done stage).
    def percent
      total = issue_count
      return 100 if total.zero?

      (@folded_stages.sum(&:done_step_count) * 100.0 / total).round
    end

    # The stage list in order, the fold standing where its first stage was.
    def list_entries
      return @stages unless active?

      @stages.each_with_object([]) do |stage, entries|
        if !folded?(stage) then entries << stage
        elsif stage.equal?(first_stage) then entries << self
        end
      end
    end
  end
end
