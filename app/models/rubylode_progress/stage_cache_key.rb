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
  module StageCacheKey
    def self.for(stage:, project:, viewer:, settings:)
      step_issues = stage.steps.map(&:issue)
      ["rubylode_progress/stage", project.id, viewer.id, stage.version.id, precise(stage.version.updated_on), stage.number,
       stage.state, digest_of_ids(step_issues), digest_of_ids(stage.steps.select(&:done?).map(&:issue)),
       precise(step_issues.filter_map(&:updated_on).max), settings.cache_digest, I18n.locale]
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
