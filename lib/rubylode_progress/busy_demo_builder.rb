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
  module DemoData
    BUSY_PROJECT_IDENTIFIER = "lighthouse".freeze
    BUSY_STAGE_COUNT = 45
    BUSY_CURRENT_STAGE_INDEX = 43 # the 44th stage, counting from zero
    BUSY_FULLY_CLOSED_STAGES = 30
    BUSY_PARTIAL_STAGES = 4
    BUSY_RANDOM_SEED = 20_191_119
    BUSY_CATEGORY_NAMES = %w[Lamps Lenses Stairs Keeper Signals].freeze
    BUSY_VERBS = %w[Polish Replace Inspect Calibrate Repaint Tighten Document Measure Order Clean Rewire Test Label
                    Sort Move Check Seal Rebuild Review Schedule].freeze
    BUSY_ADJECTIVES = %w[north south old new spare main rear upper lower brass copper outer inner].freeze
    BUSY_NOUNS = %w[lamp lens gear hinge railing stair door window shutter bell horn winch ladder bracket valve
                    gutter lantern shelf latch beam cable fuse panel gauge hatch].freeze

    # Builds the second demo project, a busy one: 45 versions (one per quarter, the current quarter being the 44th),
    # about a thousand generated issues, six people and five categories. Reuses the demo role, people and statuses, and
    # inserts the issues in batches, so a thousand take seconds. Deterministic: a fixed seed.
    class BusyBuilder < Builder
      def initialize(today, issue_count)
        super(today)
        @issue_count = issue_count
        @random = Random.new(BUSY_RANDOM_SEED)
      end

      def build
        Redmine::DefaultData::Loader.load("en") if Tracker.none?
        prepare_redmine
        load_people
        create_busy_project
        create_busy_versions
        insert_busy_issues
        insert_busy_notes
        close_finished_versions
      end

      private

      def load_people
        if User.exists?(login: DEMO_LOGIN)
          @people = PEOPLE.to_h { |login, *| [login, User.find_by!(login: login)] }
          @demo_person = @people.fetch(DEMO_LOGIN)
          @group = Group.find_by(lastname: DEMO_GROUP_NAME)
        else
          create_people
        end
      end

      def create_busy_project
        @busy_project = Project.new(name: "Lighthouse", identifier: BUSY_PROJECT_IDENTIFIER,
                                    description: "A made-up lighthouse keeper's list: forty-five quarters of upkeep.",
                                    is_public: true, enabled_module_names: MODULES)
        @busy_project.trackers = @trackers
        @busy_project.save!
        add_members(@busy_project, @people.values + [@group].compact)
        @busy_categories = BUSY_CATEGORY_NAMES.map { |name| IssueCategory.create!(project: @busy_project, name: name) }
      end

      def create_busy_versions
        current_quarter_start = @today.beginning_of_quarter
        @busy_versions = Array.new(BUSY_STAGE_COUNT) do |index|
          quarter_start = current_quarter_start << (3 * (BUSY_CURRENT_STAGE_INDEX - index))
          name = "#{quarter_start.year} Q#{((quarter_start.month - 1) / 3) + 1}"
          Version.create!(project: @busy_project, name: name, effective_date: quarter_start.end_of_quarter,
                          status: "open", sharing: "none")
        end
      end

      def insert_busy_issues
        now = Time.current
        rows = @busy_versions.each_with_index.flat_map do |version, index|
          Array.new(issue_count_for(index)) { |position| issue_row(version, index, position, now) }
        end
        Issue.insert_all(rows) if rows.any?
        Issue.where(project_id: @busy_project.id).update_all("root_id = id")
      end

      def issue_count_for(index)
        base, remainder = @issue_count.divmod(BUSY_STAGE_COUNT)
        base + (index < remainder ? 1 : 0)
      end

      def issue_row(version, stage_index, position, now)
        status = status_for(stage_index, position, issue_count_for(stage_index))
        closed = status == @statuses.fetch("Closed")
        started_on = [version.effective_date.beginning_of_quarter, @today - 1].min
        created_on = started_on.to_time + @random.rand(0..80).days
        row = {
          project_id: @busy_project.id, tracker_id: @trackers.sample(random: @random).id, subject: busy_subject,
          status_id: status.id, priority_id: @priorities.fetch(%w[Low Normal Normal Normal High].sample(random: @random)).id,
          author_id: @people.fetch("ada.lovelace").id, assigned_to_id: assignee_for(closed),
          category_id: @busy_categories.sample(random: @random).id, fixed_version_id: version.id,
          due_date: nil, done_ratio: closed ? 100 : 0, is_private: false, lock_version: 0, lft: 1, rgt: 2,
          created_on: created_on, updated_on: now, closed_on: closed ? [created_on + 20.days, now].min : nil
        }
        row[:due_date] = @today - @random.rand(2..40) if !closed && stage_index <= BUSY_CURRENT_STAGE_INDEX && @random.rand < 0.5
        row[:due_date] = @today + @random.rand(3..30) if !closed && row[:due_date].nil? && @random.rand < 0.2
        row
      end

      # Past stages are closed; the first few after the fully closed ones keep a few open; the current stage is mixed.
      def status_for(stage_index, position, stage_size)
        closed = @statuses.fetch("Closed")
        return closed if stage_index < BUSY_FULLY_CLOSED_STAGES
        if stage_index < BUSY_FULLY_CLOSED_STAGES + BUSY_PARTIAL_STAGES
          return position < [stage_size / 8, 1].max ? @statuses.fetch("New") : closed
        end
        return closed if stage_index < BUSY_CURRENT_STAGE_INDEX
        return @statuses.fetch("New") if stage_index > BUSY_CURRENT_STAGE_INDEX

        [closed, closed, @statuses.fetch("In Progress"), @statuses.fetch("Feedback"), @statuses.fetch("New")].sample(random: @random)
      end

      def assignee_for(closed)
        roll = @random.rand
        return @demo_person.id if roll < (closed ? 0.1 : 0.25)
        return nil if roll > 0.85

        @people.values.sample(random: @random).id
      end

      def busy_subject
        "#{BUSY_VERBS.sample(random: @random)} the #{BUSY_ADJECTIVES.sample(random: @random)} #{BUSY_NOUNS.sample(random: @random)}"
      end

      def insert_busy_notes
        issue_ids = Issue.where(project_id: @busy_project.id).order(:id).pluck(:id)
        author_id = @people.fetch("alan.turing").id
        rows = issue_ids.select { @random.rand < 0.06 }.map do |issue_id|
          { journalized_id: issue_id, journalized_type: "Issue", user_id: author_id, private_notes: false,
            notes: "#{BUSY_VERBS.sample(random: @random)} it next visit.", created_on: Time.current }
        end
        Journal.insert_all(rows) if rows.any?
      end

      def close_finished_versions
        @busy_versions.first(BUSY_FULLY_CLOSED_STAGES + BUSY_PARTIAL_STAGES).each { |version| version.update!(status: "closed") }
      end
    end

    # Returns :built, or :already_loaded when the busy project is there already.
    def build_busy(today: Date.current, issue_count: 1000)
      return :already_loaded if Project.exists?(identifier: BUSY_PROJECT_IDENTIFIER)

      previous_user = User.current
      ActiveRecord::Base.transaction do
        BusyBuilder.new(today, issue_count).build
      end
      :built
    ensure
      User.current = previous_user
    end
    module_function :build_busy
  end

  # Zeitwerk expects this file to define a constant named after it; the builder lives in DemoData beside the other one.
  BusyDemoBuilder = DemoData::BusyBuilder
end
