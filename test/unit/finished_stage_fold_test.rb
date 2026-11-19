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

require File.expand_path("../test_helper", __dir__)
require File.expand_path("../support/stage_doubles", __dir__)

class FinishedStageFoldTest < ActiveSupport::TestCase
  include StageDoubles

  # Closed versions with one closed issue each are done stages; then the given extra stages follow.
  def stages_with(done_count:, partial_after_first: false, current: true)
    versions = []
    issues = []
    done_count.times do |index|
      id = index + 1
      versions << version(id, "Done #{id}", Date.new(2025, 1, 1) >> index, status: "closed")
      issues << closed_issue(id, id)
      issues << closed_issue(100 + id, id)
    end
    if partial_after_first
      versions << version(50, "Partial", Date.new(2025, 1, 15), status: "closed")
      issues << closed_issue(500, 50) << open_issue(501, 50)
    end
    if current
      versions << version(60, "Now", Date.new(2030, 1, 1))
      issues << closed_issue(600, 60) << open_issue(601, 60)
      versions << version(61, "Later", Date.new(2030, 2, 1))
      issues << open_issue(610, 61)
    end
    stage_list(versions, issues).stages
  end

  test "the last N finished stages stay, the older ones fold with their combined numbers" do
    fold = RubylodeProgress::FinishedStageFold.new(stages_with(done_count: 8), 3)

    assert_predicate fold, :active?
    assert_equal 5, fold.stage_count
    assert_equal ["Done 1", "Done 2", "Done 3", "Done 4", "Done 5"], fold.folded_stages.map { |stage| stage.version.name }
    assert_equal 10, fold.issue_count
    assert_equal 100, fold.percent
  end

  test "N or fewer finished stages fold nothing, and one stage to fold is no fold" do
    assert_not RubylodeProgress::FinishedStageFold.new(stages_with(done_count: 3), 3).active?
    assert_not RubylodeProgress::FinishedStageFold.new(stages_with(done_count: 2), 3).active?
    assert_not RubylodeProgress::FinishedStageFold.new(stages_with(done_count: 4), 3).active?
    assert_predicate RubylodeProgress::FinishedStageFold.new(stages_with(done_count: 5), 3), :active?
  end

  test "none finished folds nothing" do
    assert_not RubylodeProgress::FinishedStageFold.new(stages_with(done_count: 0), 3).active?
  end

  test "N zero folds every finished stage" do
    fold = RubylodeProgress::FinishedStageFold.new(stages_with(done_count: 4), 0)

    assert_equal 4, fold.stage_count
  end

  test "partial, current and upcoming stages are never folded" do
    stages = stages_with(done_count: 6, partial_after_first: true)
    fold = RubylodeProgress::FinishedStageFold.new(stages, 0)

    assert_equal 6, fold.stage_count
    partial = stages.find { |stage| stage.version.name == "Partial" }
    assert_equal :partial, partial.state
    assert_not fold.folded?(partial)
    assert_not fold.folded?(stages.find(&:current?))
    assert_not fold.folded?(stages.find(&:upcoming?))
  end

  test "the list entries put the fold where its first stage was and keep the others in order" do
    stages = stages_with(done_count: 6)
    fold = RubylodeProgress::FinishedStageFold.new(stages, 2)
    entries = fold.list_entries

    assert_same fold, entries.first
    assert_equal ["Done 5", "Done 6", "Now", "Later"], entries.drop(1).map { |stage| stage.version.name }
  end

  test "an open version whose issues are all closed is a finished stage and folds" do
    versions = (1..5).map { |id| version(id, "Open done #{id}", Date.new(2025, 1, 1) >> id) } +
               [version(9, "Now", Date.new(2030, 1, 1)), version(10, "Later", Date.new(2030, 2, 1))]
    issues = (1..5).map { |id| closed_issue(id, id) } + [closed_issue(90, 9), open_issue(91, 9), open_issue(100, 10)]
    stages = stage_list(versions, issues).stages
    fold = RubylodeProgress::FinishedStageFold.new(stages, 3)

    assert_equal 5, stages.count(&:done?)
    assert_equal 2, fold.stage_count
  end
end
