# 14. Owner revisions after the first demo

Blocked by slice 11 (the demo). Raised by the owner on 2026-11-19 after looking at the demo; blocks slice 12.

## Done means

The demo shows what the owner listed as missing from the original idea: round marks with a half-filled one for work in
progress, a row of circle, title, author, edit and open-in-new-tab, an item that opens Redmine's issue page in a modal,
stages and checklist sections that fold with their own progress bar and percentage, a labelled stage date, and a top
indicator drawn as one continuous bar with stage markers.

## Steps

1. **Round marks.** Steps in the stage list and rows in the checklist use circles, not squares (this replaces the
   2026-11-18 ruling that squares mark steps and circles mark stages). Empty circle for open, half-filled for in
   progress, filled with a tick for done. In progress means the issue's status is one of the "in progress" statuses of
   the settings; the rail still never shows the derived status, so the cached stage fragment stays valid (the settings
   digest and the issue's `updated_on` are already in its key). Stages keep their own dots on the track.
2. **Row layout.** Checklist row: circle, title, author (the issue's author, by name, muted), the edit pencil (as
   today, only where the viewer may edit), and a link that opens the issue in a new tab (`target="_blank"`,
   `rel="noopener"`, an icon-only link with a title and `aria-label`). The step in the stage list gets the same
   order: circle, title, author, pencil, new-tab link. The author is preloaded with the issues (no query growth).
3. **Item modal.** Clicking an item's title opens Redmine's own issue page for it inside Redmine's modal
   (`#ajax-modal`, `showModal`), in an `<iframe>` so the page is exactly Redmine's. Without JavaScript the title is a
   plain link to the issue. The modal action authorizes the same way the other two do: the plugin permission, the issue
   found through `Issue.visible`. Redmine sends the issue page same-origin, so framing works; check it.
4. **Folds with progress.** Every stage in the stage list and every section in the checklist gets an arrow that
   expands and collapses it (a `<details>` with a visible chevron, rotating when open), and next to its name a small
   progress bar with a percentage: closed share of its steps, rounded, as the percent rule counts a stage. Default
   open and folded as today (current and partial open, done and upcoming folded; checklist sections open).
5. **Stage date.** The date after a stage's name is the version's due date (Redmine's effective date); label it so
   ("Due 03/15/2026"), and show nothing when the version has no date.
6. **Top indicator.** One continuous progress bar for the overall percent, with a labelled marker at each stage
   boundary and the current stage highlighted, the percent at the right end. The `aria-label` stays "N% done, X of Y
   stages finished"; the stage dots may remain as the marker row. Both pages use it (the compact tracker on `/progress`
   shows the bar without the labels).

## Tests, in order

1. Integration: "in-progress steps and rows get the half-filled mark, open ones the empty mark, done ones the tick".
2. Integration: "a checklist row carries the author and a new-tab link that opens the issue".
3. Integration: "the item title links to the issue and the modal action answers for a visible issue and refuses one the
   viewer cannot see" (403/404, as the other modals).
4. Integration: "each stage and section shows a progress percentage that matches its closed share".
5. Integration: "the stage date is labelled Due and absent without a date".
6. Integration: "the top bar carries the overall percent and a marker per stage".
7. Stylesheet test updated for the new classes; the rail cache and query-count tests stay green (re-check the ceiling).

## Not in this slice

Showing the issue's own fields in a custom read-only view; drag and drop; anything the owner has not listed.
