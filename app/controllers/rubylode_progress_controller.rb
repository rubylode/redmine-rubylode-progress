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

class RubylodeProgressController < ApplicationController
  menu_item :rubylode_progress
  before_action :find_project, :authorize
  before_action :load_progress_and_filter, only: [:show, :checklist]
  before_action :load_progress_for_modal, only: [:quick_edit, :new_issue]
  helper_method :checklist_locals

  def show
    load_checklist
  end

  # The checklist alone, for the filter links to swap in without reloading the page.
  def checklist
    load_checklist
    render partial: "rubylode_progress/checklist", locals: checklist_locals, layout: false
  end

  # Redmine's own issue page for one item, framed in Redmine's modal. The frame's address is built here from the issue's
  # id; the page inside is Redmine's, so it decides again what the viewer sees. Without a script request the viewer
  # goes straight to the issue.
  def item
    @issue = Issue.visible(User.current).where(project_id: @project.self_and_descendants.select(:id))
                  .find_by(id: params[:issue_id])
    return render_404 unless @issue

    respond_to do |format|
      format.html { redirect_to issue_path(@issue) }
      format.js
    end
  end

  # The modal's form. The save goes to Redmine's own issue update, which decides again what this viewer may change.
  def quick_edit
    @issue = Issue.visible(User.current).where(project_id: @project.self_and_descendants.select(:id))
                  .find_by(id: params[:issue_id])
    return render_404 unless @issue
    return render_403 unless @issue.editable?(User.current)

    respond_to do |format|
      format.html
      format.js
    end
  end

  # The modal for a new issue in one stage. A project that needs fields the modal does not show goes to Redmine's form.
  def new_issue
    @version = @progress.stages.map(&:version).find { |version| version.id == params[:version_id].to_i }
    return render_404 unless @version

    mode = @progress.new_issue_mode_for(@version)
    return render_403 if mode == :none

    @tracker_choices = Issue.allowed_target_trackers(@project, User.current).to_a
    @full_form_url = new_project_issue_path(@project, issue: { fixed_version_id: @version.id }, back_url: @back_url)
    @full_form = mode == :full_form
    return redirect_to(@full_form_url) if @full_form && request.format.html?

    @issue = Issue.new(project: @project, author: User.current, fixed_version: @version, tracker: @tracker_choices.first)
    respond_to do |format|
      format.html
      format.js
    end
  end

  private

  # Where Redmine sends the viewer after the save: built here from the project and the filter, never taken from the request.
  def load_progress_for_modal
    @progress = RubylodeProgress::ProjectProgress.new(project: @project, viewer: User.current)
    @filter = RubylodeProgress::ChecklistFilter.resolve(requested: params[:filter], remembered: remembered_filter)
    @back_url = project_rubylode_progress_path(@project, filter: @filter)
  end

  # Everything the checklist panel reads. The counts on the pills are taken over every issue, so they match the rows each
  # filter would show whatever filter is chosen now.
  def checklist_locals
    { sections: @sections, item_notes: @item_notes, project: @project, progress: @progress, filter: @filter,
      grouping: @grouping, default_grouping: @progress.settings.checklist_grouping, counts: @counts,
      shown_count: @checklist_items.size, today: @today }
  end

  def load_progress_and_filter
    @progress = RubylodeProgress::ProjectProgress.new(project: @project, viewer: User.current)
    @filter = RubylodeProgress::ChecklistFilter.resolve(requested: params[:filter], remembered: remembered_filter)
    @grouping = requested_grouping
    @today = User.current.today
    remember_filter
  end

  def remembered_filter
    User.current.logged? ? User.current.pref[RubylodeProgress::ChecklistFilter::PREFERENCE_KEY] : nil
  end

  # Only a valid choice that differs from the stored one is written; a plain visit never rewrites it.
  def remember_filter
    return unless User.current.logged? && RubylodeProgress::ChecklistFilter.valid?(params[:filter])
    return if params[:filter] == remembered_filter

    preferences = User.current.pref
    preferences[RubylodeProgress::ChecklistFilter::PREFERENCE_KEY] = params[:filter]
    preferences.save
  end

  # Only a known grouping is taken from the address; anything else falls back to the project's setting. It is not
  # remembered: it lasts for the visit.
  def requested_grouping
    requested = params[:group].to_s
    if RubylodeProgress::Settings::CHECKLIST_GROUPING_CHOICES.include?(requested)
      requested
    else
      @progress.settings.checklist_grouping
    end
  end

  def load_checklist
    @counts = RubylodeProgress::ChecklistFilter.counts(@progress.items, today: @today)
    @checklist_items = RubylodeProgress::ChecklistFilter.apply(@filter, @progress.items, today: @today)
    @sections = RubylodeProgress::ChecklistSections.group(@checklist_items, by: @grouping, viewer: User.current,
                                                                            scope_items: @progress.items)
    @item_notes = RubylodeProgress::ItemNotes.for(@checklist_items.map(&:issue), viewer: User.current,
                                                  settings: @progress.settings)
  end
end
