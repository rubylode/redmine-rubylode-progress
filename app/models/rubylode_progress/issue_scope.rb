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
  # The counted versions and the issues in them that one viewer may see, loaded once with everything the rules read.
  # Versions are gathered as Redmine's Roadmap does with subprojects shown, then kept only when they hold a visible issue
  # here, or belong to this project's tree in a project whose issues the viewer may see (owner's ruling, 2026-11-18): so
  # a version shared in from elsewhere with nothing of ours, or one of a hidden subproject, never becomes a stage.
  class IssueScope
    ISSUE_PRELOADS = [:project, :status, :priority, :assigned_to, :category, :parent, :fixed_version,
                      { relations_to: { issue_from: :status } }, { custom_values: :custom_field }].freeze

    # The cross-project page passes a short preload list and column list, as it reads only status and version.
    def initialize(project:, viewer:, settings:, issue_preloads: ISSUE_PRELOADS, issue_columns: nil)
      @project = project
      @viewer = viewer
      @settings = settings
      @issue_preloads = issue_preloads
      @issue_columns = issue_columns
    end

    def versions
      @versions ||= begin
        version_ids_with_issues = issues.map(&:fixed_version_id).to_set
        candidate_versions.select do |version|
          version_ids_with_issues.include?(version.id) || own_and_visible?(version)
        end
      end
    end

    # Every issue here belongs to a candidate version that holds it, so each one's version is in #versions.
    def issues
      @issues ||= begin
        relation = Issue.visible(@viewer)
                        .where(project_id: tree_project_ids, fixed_version_id: candidate_versions.map(&:id))
                        .preload(*@issue_preloads)
        relation = relation.select(*@issue_columns.map { |column| Issue.arel_table[column] }) if @issue_columns
        relation.to_a
      end
    end

    # The ids of the counted versions an issue of this project may be filed in (Redmine refuses any other).
    def shared_version_ids
      @shared_version_ids ||= shared_versions.map(&:id).to_set
    end

    def viewer_group_ids
      @viewer.logged? ? @viewer.group_ids : []
    end

    private

    def candidate_versions
      @candidate_versions ||= counted_only(
        (shared_versions + @project.rolled_up_versions.visible(@viewer).preload(:project).to_a).uniq
      )
    end

    def shared_versions
      @shared_versions ||= @project.shared_versions.to_a
    end

    def tree_project_ids
      @tree_project_ids ||= @project.self_and_descendants.pluck(:id)
    end

    def own_and_visible?(version)
      tree_project_ids.include?(version.project_id) && @viewer.allowed_to?(:view_issues, version.project)
    end

    def counted_only(candidates)
      return candidates unless @settings.counted_versions == "prefix"

      candidates.select { |version| version.name.to_s.start_with?(@settings.version_name_prefix) }
    end
  end
end
