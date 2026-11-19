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

class RubylodeProgressAllProjectsController < ApplicationController
  before_action :require_progress_project

  def index
    @trackers = RubylodeProgress::AllProjects.projects_for(User.current).map do |project|
      RubylodeProgress::ProjectTracker.for(project, viewer: User.current)
    end
  end

  private

  # Which projects to list is decided per project in AllProjects; this only turns away someone with none.
  def require_progress_project
    deny_access unless RubylodeProgress::AllProjects.any_for?(User.current)
  end
end
