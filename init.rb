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

Redmine::Plugin.register :redmine_rubylode_progress do
  name "Rubylode Progress"
  author "Rubylode"
  description "A Progress tab for each project: how far along it is, which stage is current, what is next."
  version "0.1.0"
  requires_redmine version_or_higher: "7.0.0"

  project_module :rubylode_progress do
    permission :view_rubylode_progress, { rubylode_progress: [:show, :checklist] }, read: true
  end

  menu :project_menu, :rubylode_progress,
       { controller: "rubylode_progress", action: "show" },
       caption: :label_rubylode_progress, after: :roadmap, param: :id
end
