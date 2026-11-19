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

require_relative "lib/rubylode_progress/project_patch"
require_relative "lib/rubylode_progress/projects_helper_patch"

Redmine::Plugin.register :redmine_rubylode_progress do
  name "Rubylode Progress"
  author "Rubylode"
  description "A Progress tab for each project: how far along it is, which stage is current, what is next."
  version "1.0.0"
  requires_redmine version_or_higher: "7.0.0"

  settings default: RubylodeProgress::Settings::DEFAULTS, partial: "settings/rubylode_progress_settings"

  project_module :rubylode_progress do
    permission :view_rubylode_progress, { rubylode_progress: [:show, :checklist, :quick_edit, :new_issue, :item, :status] }, read: true
  end

  menu :project_menu, :rubylode_progress,
       { controller: "rubylode_progress", action: "show" },
       caption: :label_rubylode_progress, after: :roadmap, param: :id

  menu :top_menu, :rubylode_progress,
       { controller: "rubylode_progress_all_projects", action: "index" },
       caption: :label_rubylode_progress,
       if: ->(*) { RubylodeProgress::AllProjects.any_for?(User.current) }
end

# Redmine runs this file again on every code reload, so each patch goes in only once.
Project.include(RubylodeProgress::ProjectPatch) unless Project.include?(RubylodeProgress::ProjectPatch)
unless ProjectsHelper.ancestors.include?(RubylodeProgress::ProjectsHelperPatch)
  ProjectsHelper.prepend(RubylodeProgress::ProjectsHelperPatch)
end
