

class RubylodeProgressController < ApplicationController
  menu_item :rubylode_progress
  before_action :find_project, :authorize

  # The Open filter is the only one until the filters arrive: everything not Done.
  def show
    @progress = RubylodeProgress::ProjectProgress.new(project: @project, viewer: User.current)
    @filter = "open"
    @tally = RubylodeProgress::Tally.from(@progress.items)
    @checklist_items = @progress.items.reject { |item| item.status == :done }
    @sections = RubylodeProgress::ChecklistSections.group(@checklist_items, by: @progress.settings.checklist_grouping,
                                                                  viewer: User.current)
    @item_notes = RubylodeProgress::ItemNotes.for(@checklist_items.map(&:issue), viewer: User.current,
                                                  settings: @progress.settings)
  end
end
