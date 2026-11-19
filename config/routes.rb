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

get "progress", to: "rubylode_progress_all_projects#index", as: "rubylode_progress_all_projects"
get "projects/:id/progress", to: "rubylode_progress#show", as: "project_rubylode_progress"
get "projects/:id/progress/checklist", to: "rubylode_progress#checklist"
patch "projects/:id/progress/settings", to: "rubylode_progress_project_settings#update",
                                        as: "project_rubylode_progress_settings"
get "projects/:id/progress/issues/:issue_id/quick_edit", to: "rubylode_progress#quick_edit",
                                                         as: "project_rubylode_progress_quick_edit"
get "projects/:id/progress/versions/:version_id/new_issue", to: "rubylode_progress#new_issue",
                                                            as: "project_rubylode_progress_new_issue"
get "projects/:id/progress/issues/:issue_id/item", to: "rubylode_progress#item",
                                                    as: "project_rubylode_progress_item"
get "projects/:id/progress/versions/:version_id/status", to: "rubylode_progress#status",
                                                         as: "project_rubylode_progress_version_status"
