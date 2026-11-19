# 16. Drag an issue to another stage

Blocked by slice 15. Raised by the owner on 2026-11-19 while reviewing the demo; blocks slice 12.

## Done means

A viewer who may edit an issue can drag it from one stage to another, in the stage list and in the checklist when it is
grouped by version, for example from Framing to Foundations. The move is Redmine's own issue update, so its permissions,
workflow and version rules decide; the page shows what Redmine answered. A viewer who cannot use a pointer (keyboard,
touch) can do the same from the quick-edit form, which gains a Target version field.

## Steps

1. **Draggable rows.** An issue row in the stage list and in the checklist gets `draggable="true"` and
   `data-issue-id`, only where the viewer may edit the issue (the same rule as the pencil, already part of the stage
   cache key). Not draggable: other issues, and every row when the checklist is grouped by category or parent (the
   checklist's stage drop targets exist only when grouped by version, as the owner chose).
2. **Drop targets.** A stage in the stage list, and a version section of the checklist when it is grouped by version,
   gets `data-version-id` and a drop target only when the version accepts issues for this viewer (the rule the new-issue
   plus uses: open, and one the viewer may assign issues to, via `assignable_versions` of the project). A stage that does
   not qualify shows no highlight and refuses the drop. Dropping on the stage an issue is already in does nothing.
3. **The move.** A Stimulus controller (registered the way `progress_filters.js` is, in the same import map file or a
   second small file) uses the browser's native drag and drop, no library. On drop it sends one request to Redmine:
   `PATCH /issues/:id` with `issue[fixed_version_id]` and the page's CSRF token, asking for JSON, `back_url` not needed.
   Success: reload the Progress page with the current filter and grouping (a plain page load keeps every cached fragment
   rule intact). Failure (403, 422): leave the page as it is and show Redmine's own error text in an `aria-live`
   message above the checklist; the row snaps back because nothing moved.
4. **Look.** `grab` cursor on a draggable row; the dragged row dimmed; a drop target outlined in the accent colour while
   a draggable is over it (a new `--rubylode-progress-drop-target-color` property, defaulting to the accent colour, in
   `docs/theming.md` with its dark value). A short note under the stage-list title tells people what is possible, only
   when something on the page is draggable: "Drag an issue to another stage to move it."
5. **Without a pointer.** The quick-edit form (slice 13) gains a Target version select with the project's
   `assignable_versions` (current one selected, blank excluded), only when `fixed_version_id` is a safe attribute for
   this viewer and issue. Saving goes to Redmine's update as today. Touch screens use this field; native drag and drop
   is not promised on touch.

## Tests, in order

1. Integration: "only an issue the viewer may edit is draggable, and none when the checklist is grouped by category".
2. Integration: "only a version that accepts issues is a drop target, in the stage list and in the version sections".
3. Integration: "the page names no drop target for a version the viewer cannot assign to".
4. Integration: "the quick-edit form offers the assignable versions and saving it moves the issue to that version
   (through Redmine's update, back to the Progress page)".
5. Integration: "the quick-edit form has no Target version for a viewer who may not change it".
6. Integration: "the move request goes to Redmine's own issue update": the page carries the update path and the CSRF
   meta tag the controller needs (the script itself is not exercised; say so in the report).
7. Unit/stylesheet: the new classes and the drop-target property, with the dark value and contrast.
8. The rail cache and query-count tests stay green (re-check the ceiling).

## Not in this slice

Reordering within a stage; dragging between category or parent sections (that would change a different field);
moving several issues at once; a drag library; touch drag.
