class RubylodeProgressController < ApplicationController
  menu_item :rubylode_progress
  before_action :find_project, :authorize
  before_action :load_progress_and_filter

  def show
    @tally = RubylodeProgress::Tally.from(@progress.items)
    load_checklist
  end

  # The checklist alone, for the filter links to swap in without reloading the page.
  def checklist
    load_checklist
    render partial: "rubylode_progress/checklist", locals: { sections: @sections, item_notes: @item_notes },
           layout: false
  end

  private

  def load_progress_and_filter
    @progress = RubylodeProgress::ProjectProgress.new(project: @project, viewer: User.current)
    @filter = RubylodeProgress::ChecklistFilter.resolve(requested: params[:filter], remembered: remembered_filter)
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

  def load_checklist
    @checklist_items = RubylodeProgress::ChecklistFilter.apply(@filter, @progress.items)
    @sections = RubylodeProgress::ChecklistSections.group(@checklist_items, by: @progress.settings.checklist_grouping,
                                                                  viewer: User.current)
    @item_notes = RubylodeProgress::ItemNotes.for(@checklist_items.map(&:issue), viewer: User.current,
                                                  settings: @progress.settings)
  end
end
