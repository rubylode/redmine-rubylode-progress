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
  # Demo data for the throwaway Redmine in docker-compose.yml (bin/demo), also run by
  # `rake redmine_rubylode_progress:demo`. Everything is made up: the people are computer scientists of the past, the
  # projects and versions are plain nouns.
  #
  # One main project (Bridge) with five versions: Foundations is done, Framing is closed with one issue still open
  # (partial), Decking is current, and Lighting and Opening are open and upcoming (so an issue can be dragged into them). Its subproject Bridge Cables
  # shares the versions. Three smaller projects feed the cross-project page: Kiln (all done), Loom (not started) and
  # Quill (no versions). Safe to run twice: it runs in one transaction and does nothing when Bridge exists.
  # The demo people sign in with their login and DEMO_PASSWORD; the administrator stays admin / admin.
  module DemoData
    DEMO_PASSWORD = "demo-password-1".freeze
    DEMO_LOGIN = "grace.hopper".freeze
    DEMO_GROUP_NAME = "Maintainers".freeze
    MAIN_PROJECT_IDENTIFIER = "bridge".freeze
    ROLE_NAME = "Contributor".freeze
    PERMISSIONS = %i[view_issues add_issues edit_issues add_issue_notes view_private_notes set_notes_private
                     view_rubylode_progress manage_versions].freeze
    PEOPLE = [
      %w[grace.hopper Grace Hopper], %w[alan.turing Alan Turing], %w[ada.lovelace Ada Lovelace],
      %w[edsger.dijkstra Edsger Dijkstra], %w[john.backus John Backus]
    ].freeze
    MODULES = %w[issue_tracking rubylode_progress].freeze

    # The stage each main-project issue belongs to, as [subject, state, category, extras]. State is :closed or the name
    # of an open status; extras may hold assignee:, blocked_by:, due_in:, note:, private_note: and priority:.
    FOUNDATIONS = [
      ["Survey the river bank", :closed, "Structure"], ["Test the soil samples", :closed, "Structure"],
      ["Pour the east footing", :closed, "Structure"], ["Pour the west footing", :closed, "Structure"],
      ["Drive the support piles", :closed, "Structure"], ["Mark the road closures", :closed, "Safety"],
      ["Order the steel", :closed, "Structure"], ["Fence the work site", :closed, "Safety"]
    ].freeze
    FRAMING = [
      ["Raise the first tower", :closed, "Structure"], ["Raise the second tower", :closed, "Structure"],
      ["Hang the main cables", :closed, "Structure"], ["Fit the cable clamps", :closed, "Structure"],
      ["Inspect the welds", :closed, "Safety"], ["Paint the primer coat", :closed, "Surface"],
      ["Repair the damaged railing post", "New", "Safety", { assignee: "alan.turing", due_in: -12, note: "Waiting on the new part." }]
    ].freeze
    DECKING = [
      ["Lay the first deck panels", :closed, "Structure"], ["Lay the second deck panels", :closed, "Structure"],
      ["Seal the panel joints", :closed, "Surface"], ["Fit the expansion gaps", :closed, "Structure"],
      ["Mark the lane lines", :closed, "Surface"],
      ["Weld the last support brackets", "In Progress", "Structure", { assignee: "alan.turing", priority: "High" }],
      ["Approve the paving mix", "Feedback", "Surface", { assignee: "edsger.dijkstra", note: "The council has the sample." }],
      ["Pave the footpath", "New", "Surface", { blocked_by: "Approve the paving mix" }],
      ["Sign off the load test", "New", "Safety", { assignee: DEMO_LOGIN, priority: "High", due_in: 5,
                                                   note: "Needs the engineer's signature before Friday." }],
      ["Review the drainage plan", "New", "Structure", { assignee: DEMO_GROUP_NAME, private_note: "Budget is tight; do not share." }],
      ["Install the drain covers", "New", "Safety", { priority: "High", due_in: 8 }],
      ["Fit the handrail lights", "New", "Safety", { due_in: 12 }],
      ["Sweep the deck", "New", "Surface"], ["Clear the site office", "New", "Surface"],
      ["Order the street signs", "New", "Safety", { priority: "Low" }]
    ].freeze
    LIGHTING = [
      ["Choose the lamp posts", "New", "Structure"], ["Run the power cable", "New", "Safety"],
      ["Test the night lighting", "New", "Safety"]
    ].freeze
    OPENING = [
      ["Plan the opening day", "New", "Surface"], ["Print the invitations", "New", "Surface"],
      ["Book the ribbon", "New", "Surface"]
    ].freeze
    CATEGORY_NAMES = %w[Structure Surface Safety].freeze

    module_function

    # Returns :built, or :already_loaded when the main project is there already.
    def build(today: Date.current)
      return :already_loaded if Project.exists?(identifier: MAIN_PROJECT_IDENTIFIER)

      previous_user = User.current
      ActiveRecord::Base.transaction do
        Builder.new(today).build
      end
      :built
    ensure
      User.current = previous_user
    end

    # The work of one build, kept in an object so the helpers share what was made so far.
    class Builder
      def initialize(today)
        @today = today
      end

      def build
        Redmine::DefaultData::Loader.load("en") if Tracker.none?
        prepare_redmine
        create_people
        create_main_project
        create_smaller_projects
        choose_settings
      end

      private

      def prepare_redmine
        Setting.default_language = "en"
        Setting.notified_events = [] # no mail from the demo
        Setting.issue_group_assignment = "1"
        User.where(admin: true).update_all(must_change_passwd: false)
        @trackers = %w[Feature Bug].map { |name| Tracker.find_by(name: name) }.compact
        @trackers = [Tracker.first] if @trackers.empty?
        @statuses = %w[New In\ Progress Feedback Closed].to_h { |name| [name, status_named(name)] }
        @priorities = %w[Low Normal High].to_h { |name| [name, priority_named(name)] }
        @role = create_role
      end

      def status_named(name)
        IssueStatus.find_by(name: name) || IssueStatus.create!(name: name, is_closed: name == "Closed")
      end

      def priority_named(name)
        IssuePriority.find_by(name: name) || IssuePriority.create!(name: name, is_default: name == "Normal")
      end

      def create_role
        role = Role.find_by(name: ROLE_NAME)
        return role if role

        role = Role.create!(name: ROLE_NAME, permissions: PERMISSIONS, issues_visibility: "all", assignable: true,
                            users_visibility: "all", time_entries_visibility: "all")
        @trackers.each do |tracker|
          @statuses.values.product(@statuses.values).each do |from, to|
            next if from == to

            WorkflowTransition.create!(role: role, tracker: tracker, old_status: from, new_status: to)
          end
        end
        role
      end

      def create_people
        @people = PEOPLE.to_h do |login, firstname, lastname|
          user = User.find_or_initialize_by(login: login)
          user.assign_attributes(firstname: firstname, lastname: lastname, mail: "#{login}@example.com", language: "en",
                                 must_change_passwd: false)
          user.password = user.password_confirmation = DEMO_PASSWORD
          user.save!
          [login, user]
        end
        @demo_person = @people.fetch(DEMO_LOGIN)
        @group = Group.create!(lastname: DEMO_GROUP_NAME)
        @group.users << @demo_person
        @group.users << @people.fetch("john.backus")
        User.current = @people.fetch("ada.lovelace")
      end

      def make_project(name, identifier, description, parent: nil)
        project = Project.new(name: name, identifier: identifier, description: description, is_public: false,
                              enabled_module_names: MODULES, inherit_members: parent.present?)
        project.parent = parent
        project.trackers = @trackers
        project.save!
        project
      end

      def add_members(project, principals)
        principals.each { |principal| Member.create!(project: project, principal: principal, roles: [@role]) }
      end

      def make_version(project, name, days_from_today, sharing: "none")
        Version.create!(project: project, name: name, effective_date: @today + days_from_today, status: "open",
                        sharing: sharing)
      end

      def create_main_project
        @main_project = make_project("Bridge", MAIN_PROJECT_IDENTIFIER, "A made-up bridge, built in five stages.")
        add_members(@main_project, @people.values + [@group])
        @cables_project = make_project("Bridge Cables", "bridge-cables", "The cables, as a subproject.", parent: @main_project)
        @categories = CATEGORY_NAMES.to_h do |name|
          [name, IssueCategory.create!(project: @main_project, name: name)]
        end
        @cables_project_categories = CATEGORY_NAMES.to_h { |name| [name, IssueCategory.create!(project: @cables_project, name: name)] }
        versions = {
          foundations: make_version(@main_project, "Foundations", -90, sharing: "descendants"),
          framing: make_version(@main_project, "Framing", -45, sharing: "descendants"),
          decking: make_version(@main_project, "Decking", 14, sharing: "descendants"),
          lighting: make_version(@main_project, "Lighting", 45, sharing: "descendants"),
          opening: make_version(@main_project, "Opening", 75, sharing: "descendants")
        }
        { foundations: FOUNDATIONS, framing: FRAMING, decking: DECKING, lighting: LIGHTING, opening: OPENING }.each do |key, rows|
          rows.each { |subject, state, category, extras| make_issue(@main_project, versions.fetch(key), subject, state, category, extras || {}) }
        end
        make_issue(@cables_project, versions.fetch(:decking), "Anchor the cable ends", :closed, "Structure", {})
        make_issue(@cables_project, versions.fetch(:lighting), "Wire the cable lights", "New", "Safety", {})
        make_issue(@cables_project, versions.fetch(:opening), "Cut the cable ribbon", "New", "Surface", {})
        link_blocked_issues
        versions.fetch(:foundations).update!(status: "closed")
        versions.fetch(:framing).update!(status: "closed")
      end

      def make_issue(project, version, subject, state, category, extras)
        issue = Issue.new(project: project, tracker: @trackers.first, author: @people.fetch("ada.lovelace"),
                          subject: subject, fixed_version: version,
                          status: state == :closed ? @statuses.fetch("Closed") : @statuses.fetch(state),
                          priority: @priorities.fetch(extras.fetch(:priority, "Normal")),
                          category: category_for(project, category))
        issue.assigned_to = principal_named(extras[:assignee]) if extras[:assignee]
        issue.due_date = @today + extras[:due_in] if extras[:due_in]
        issue.save!
        (@blocked_pairs ||= []) << [issue, extras[:blocked_by]] if extras[:blocked_by]
        add_notes(issue, extras)
        issue
      end

      def category_for(project, name)
        project == @main_project ? @categories.fetch(name) : @cables_project_categories.fetch(name)
      end

      def principal_named(name)
        name == DEMO_GROUP_NAME ? @group : @people.fetch(name)
      end

      def add_notes(issue, extras)
        { note: false, private_note: true }.each do |key, private_note|
          next unless extras[key]

          issue.reload
          journal = issue.init_journal(@people.fetch("alan.turing"), extras[key])
          journal.private_notes = private_note
          issue.save!
        end
      end

      def link_blocked_issues
        (@blocked_pairs || []).each do |blocked_issue, blocker_subject|
          blocker = Issue.find_by!(project_id: @main_project.id, subject: blocker_subject)
          IssueRelation.create!(issue_from: blocker, issue_to: blocked_issue, relation_type: "blocks")
        end
      end

      def create_smaller_projects
        kiln = make_project("Kiln", "kiln", "Everything here is finished.")
        loom = make_project("Loom", "loom", "Nothing here has started.")
        quill = make_project("Quill", "quill", "No versions yet.")
        [kiln, loom, quill].each { |project| add_members(project, [@demo_person]) }
        { "Clay" => -60, "Glaze" => -20 }.each do |name, days|
          version = make_version(kiln, name, days)
          2.times { |index| make_smaller_issue(kiln, version, "#{name} step #{index + 1}", @statuses.fetch("Closed")) }
          version.update!(status: "closed")
        end
        version = make_version(loom, "Warp", 30)
        3.times { |index| make_smaller_issue(loom, version, "Warp step #{index + 1}", @statuses.fetch("New")) }
        quill
      end

      def make_smaller_issue(project, version, subject, status)
        Issue.create!(project: project, tracker: @trackers.first, author: @people.fetch("ada.lovelace"), subject: subject,
                      fixed_version: version, status: status, priority: @priorities.fetch("Normal"))
      end

      def choose_settings
        Setting.send(:"plugin_#{Settings::PLUGIN_ID}=",
                     Settings::DEFAULTS.merge("in_progress_status_ids" => [@statuses.fetch("In Progress").id.to_s],
                                              "waiting_status_ids" => [@statuses.fetch("Feedback").id.to_s]))
        ProjectSetting.create!(project: @main_project, checklist_grouping: "category")
      end
    end
  end
end

require_relative "busy_demo_builder"
