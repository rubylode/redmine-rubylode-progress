# 5. The project page

Blocked by slice 4.

## Done means

`/projects/:id/progress` shows, top to bottom, the title with "Last change <date>", the tracker panel, the four tiles
and the checklist in sections, as the design describes, with the Open filter applied; "nothing to track yet" when there
are no stages.

## Steps

1. `RubylodeProgressController#show`: `@progress = RubylodeProgress::ProjectProgress.new(project: @project,
   viewer: User.current)`; `@filter = "open"` until slice 6.
2. `app/views/rubylode_progress/show.html.erb` with partials in `app/views/rubylode_progress/`: `_title`,
   `_tracker_panel`, `_stage` (one per stage, cached in slice 9), `_tiles`, `_checklist`, `_checklist_row`. Stylesheet
   linked through `content_for :header_tags`.
3. Tracker panel: "Stage 3 of 5" (with no current stage, "All 5 stages done" in its place, from slice 2); the current
   stage's name as the headline, the version description under it; the
   track as an `<ol>` of dots (done, current, upcoming) with `aria-label` from `rubylode_progress.track_label`:
   "%{percent}% done, %{finished} of %{total} stages finished"; the percent at the right end; then the stage list,
   each with its rail dot, name, effective date and steps linking to their issues. Done and upcoming stages fold in
   `<details>` ("9 steps done", "5 steps planned"); the current stage is open with "13 of 17 steps done". Plan's call:
   rail steps show done or open only, never the derived status, so slice 9 can cache a stage on its own issues.
   Plan's call: dates through Redmine's `format_date`, which honours the viewer's date format.
4. `app/models/rubylode_progress/tally.rb`: `Tally.from(items)` with `#done_count`, `#next_count`,
   `#needs_you_count`, `#still_open_count` (every item not Done). Tiles: Done, Next up, Needs you, Still open.
5. `app/models/rubylode_progress/checklist_sections.rb`: `ChecklistSections.group(items, by:)` returns `Section =
   Struct.new(:title, :items, :done_count, keyword_init: true)`. By version in stage order; by category by name, then
   "No category"; by parent by parent issue number, then "No parent". Grouping never changes which items appear.
6. `app/models/rubylode_progress/item_notes.rb`: `ItemNotes.for(issues, viewer:, settings:)` returns `{ issue_id =>
   text }`. Latest note: one query, `Journal.visible(viewer).where(journalized_id: ids).where.not(notes: [nil, ""])`,
   newest per issue, first 240 characters. Custom field: only when `custom_field.visible_by?(issue.project, viewer)`,
   from preloaded `custom_values`.
7. Row: status mark, title, status pill (text label), `#123` linking to the issue, date (due date, else `closed_on` for
   Done), note under it. Last change: `format_date(@progress.last_change_on)`.

## Tests, in order

1. Unit `checklist_sections_test.rb`: "by category, issues without one go last under No category"; "by parent, a parent
   issue in a counted version is a row too"; "grouping keeps the same items".
2. Unit `tally_test.rb`: "Still open counts everything not Done".
3. Integration `test/integration/project_page_test.rb`: "a member sees the title, Last change, Stage N of M and the
   track's label" (exact: "50% done, 1 of 3 stages finished" for the fixture built in the test).
4. "the current stage is open with N of M steps done; the others are folded".
5. "the four tiles carry the counts of the scope".
6. "a project without counted versions says there is nothing to track yet and shows no track".
7. "the item date is the due date, else the closed date for a done item".
8. "the open issues of a closed version still show under Open" (Review Focus 2, second half).
9. Review Focus 3, "an issue assigned to a group the viewer is in shows as Needs you and counts in the tile".
10. Review Focus 4, "a private note is never the item note for a viewer without View private notes": the issue's newest
    journal is private; the viewer without the permission sees the older public note, one with it sees the private one.
11. "a custom field note shows only where the field is visible to the viewer".

## Not in this slice

Filters and the preference (6), project overrides (7), caching (9), the look (10).
