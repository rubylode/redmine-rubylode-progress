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
  before_action :load_progress_for_modal, only: [:quick_edit, :new_issue, :status, :stage_issues, :stage_closed_issues]
  after_action :trim_indentation, only: [:show, :checklist, :stage_issues, :stage_closed_issues]
  helper_method :checklist_locals

  def show
    @open_stage_id = requested_open_stage_id
    load_checklist
  end

  # One stage's issue list alone, for a folded stage to fetch when it is opened. It is the partial the stage renders
  # itself, over the same viewer-visible stages, so it never shows more than the page; a version that is not one of the
  # page's stages is a 404.
  def stage_issues
    render_stage_fragment("rubylode_progress/stage_issues", closed_inline: false)
  end

  # The closed issues of one stage, for the closed fold of a current or partial stage to fetch when it is opened.
  def stage_closed_issues
    render_stage_fragment("rubylode_progress/stage_closed_issues")
  end

  # The checklist alone, for the filter links to swap in without reloading the page.
  def checklist
    load_checklist
    return render_opened_sections if @opened_section_keys.any?

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

  # The modal for a version's status. Only a stage of this page, and only for a viewer who holds manage_versions on the
  # version's own project. The save goes to Redmine's own version update, which decides again.
  def status
    @version = @progress.stages.map(&:version).find { |version| version.id == params[:version_id].to_i }
    return render_404 unless @version
    return render_403 unless @progress.can_manage_version?(@version)

    @back_url = project_rubylode_progress_path(@project, filter: @filter, **status_grouping_parameters)
    respond_to do |format|
      format.html
      format.js
    end
  end

  private

  # A busy page is mostly indentation and blank lines left by the templates. Dropping them changes nothing on screen, but
  # whitespace is meaningful inside a pre or a textarea, so a page that holds one is left as it is.
  def trim_indentation
    return unless response.media_type == "text/html"

    markup = response.body
    return if markup.match?(/<(?:pre|textarea)\b/i)

    response.body = markup.gsub(/^[ \t]+/, "").gsub(/\n{2,}/, "\n")
  end
  # Where Redmine sends the viewer after the save: built here from the project and the filter, never taken from the request.
  def load_progress_for_modal
    @progress = RubylodeProgress::ProjectProgress.new(project: @project, viewer: User.current)
    @filter = RubylodeProgress::ChecklistFilter.resolve(requested: params[:filter], remembered: remembered_filter)
    @back_url = project_rubylode_progress_path(@project, filter: @filter)
  end

  # The grouping to come back to, only when it is a known one that differs from the project's setting.
  def status_grouping_parameters
    grouping = requested_grouping
    grouping == @progress.settings.checklist_grouping ? {} : { group: grouping }
  end

  # Everything the checklist panel reads. The counts on the pills are taken over every issue, so they match the rows each
  # filter would show whatever filter is chosen now.
  def checklist_locals
    { sections: @sections, item_notes: @item_notes, project: @project, progress: @progress, filter: @filter,
      grouping: @grouping, default_grouping: @progress.settings.checklist_grouping, counts: @counts,
      shown_count: @checklist_items.size, today: @today, narrowing: @narrowing, narrowing_options: @narrowing_options }
  end

  def load_progress_and_filter
    @progress = RubylodeProgress::ProjectProgress.new(project: @project, viewer: User.current)
    @filter = RubylodeProgress::ChecklistFilter.resolve(requested: params[:filter], remembered: remembered_filter)
    @grouping = requested_grouping
    @narrowing_options = RubylodeProgress::ChecklistNarrowing.options_for(@progress.items)
    @narrowing = RubylodeProgress::ChecklistNarrowing.resolve(requested_narrowing, @narrowing_options)
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

  # The three selects' values as the request sent them; only strings are kept. They are checked against the offered
  # values afterwards, and not remembered.
  def requested_narrowing
    RubylodeProgress::ChecklistNarrowing::DIMENSIONS.to_h { |dimension| [dimension, params[dimension].is_a?(String) ? params[dimension] : nil] }
  end

  # Both routes answer a partial the stage renders itself, for a stage of this page only: 404 for any other version.
  def render_stage_fragment(partial, **extra_locals)
    stage = @progress.stages.find { |candidate| candidate.version.id == params[:version_id].to_i }
    return render_404 unless stage

    render partial: partial, layout: false,
           locals: { stage: stage, project: @project, settings: @progress.settings,
                     editable_issue_ids: @progress.editable_issue_ids,
                     new_issue_mode: @progress.new_issue_mode_for(stage.version), **extra_locals }
  end

  # The id of the one folded stage to render open, only when it is one of the page's stages; anything else opens nothing.
  def requested_open_stage_id
    requested = params[:open_stage]
    return nil unless requested.is_a?(String) && requested.match?(/\A\d+\z/)

    @progress.stages.map { |stage| stage.version.id }.find { |id| id == requested.to_i }
  end

  # The key of the one section to list in full, only when it names a section that exists; anything else shows nothing extra.
  def expanded_section_key(sections)
    requested = params[:expand]
    requested.is_a?(String) && sections.any? { |section| section.key == requested } ? requested : nil
  end

  # The sections named by open= alone, listed as the page would list them (open, with their first rows), for a folded
  # section to swap itself for. Only keys that name a section get here; an unknown key renders the whole checklist.
  def render_opened_sections
    opened = @sections.select { |section| @opened_section_keys.include?(section.key) }
    render partial: "rubylode_progress/checklist_sections", layout: false, locals: checklist_locals.merge(sections: opened)
  end

  # The keys of the sections to open, from the address, comma separated, at most ten, and only those that name a section
  # that exists; anything else is dropped without an error.
  def requested_open_keys(sections)
    requested = params[:open]
    return [] unless requested.is_a?(String)

    known = sections.map(&:key)
    requested.split(",").first(RubylodeProgress::ChecklistSections::MAX_OPEN_KEYS).select { |key| known.include?(key) }
  end

  # The narrowing comes first: the pill counts, the rows and the section tallies all read the narrowed issues, so the
  # counts match the list each pill selects. Sections list only their first rows; the notes are read for those rows only.
  def load_checklist
    narrowed_items = RubylodeProgress::ChecklistNarrowing.apply(@narrowing, @progress.items)
    @counts = RubylodeProgress::ChecklistFilter.counts(narrowed_items, today: @today)
    @checklist_items = RubylodeProgress::ChecklistFilter.apply(@filter, narrowed_items, today: @today)
    sections = RubylodeProgress::ChecklistSections.group(@checklist_items, by: @grouping, viewer: User.current,
                                                                           scope_items: narrowed_items)
    expanded_key = expanded_section_key(sections)
    @opened_section_keys = requested_open_keys(sections)
    sections = RubylodeProgress::ChecklistSections.fold(sections, open_keys: @opened_section_keys + [expanded_key].compact)
    @sections = RubylodeProgress::ChecklistSections.limit(sections, rows_per_section: @progress.settings.checklist_rows_per_section,
                                                                    expanded_key: expanded_key)
    @item_notes = RubylodeProgress::ItemNotes.for(@sections.flat_map { |section| section.items.map(&:issue) }, viewer: User.current,
                                                  settings: @progress.settings)
  end
end
