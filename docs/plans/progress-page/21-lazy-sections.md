# 21. Load a checklist section's rows when it is opened

Blocked by slice 20 (done). Found on 2026-11-19 with the busy demo project: at the Open filter the Lighthouse page is 198 KB,
but under All or Done a plain visit is about 1 MB, because 45 version sections each list 10 rows. For 1.1.0. The owner chose
to fix these two filters before releasing.

## Done means

Under any filter, a checklist with many sections renders the first few sections with their rows and the rest folded, with
their heading (title, counts, meter) but no rows; a folded section loads its first rows when opened. The Lighthouse page is
light under every filter (under 250 KB under All and Done), and a project with few sections looks and behaves as it does now.
Every section still works without JavaScript.

## Steps

1. **Which sections start open.** When the checklist has more than 8 sections, only the first 5 start open and render rows;
   the others start folded and render no rows. With 8 or fewer, all start open as today. The heading of a folded section
   keeps its title, its counts and its meter (they come from the narrowed issues the checklist already holds).
2. **Opening loads.** A folded section carries `data-lazy-section-path`: the existing checklist route with the current filter,
   grouping and selects plus `open=<section key>`, which returns that one section, open, with its first N rows (N is the
   rows-per-section setting) and its "Show more" link, and swaps it in place like "Show more" does today (reuse that handler
   and its in-place swap; do not add a new mechanism). One-line loading state; on failure a message and the plain link of the
   next step. Validate the key against the sections that exist (an unknown key changes nothing, no error).
3. **Without JavaScript.** A folded section has a real link "Show the M issues" to the page with `?open=<key>` (keeping filter,
   grouping and selects); the page then renders that section open. Several `open` keys may be given (comma separated, at
   most 10).
4. **Rows that load later work like the others.** They carry the pencil and the new-tab link, they are draggable where the
   viewer may edit and the checklist is grouped by version, and the drop targets (the version sections) are still on the
   section element even when it is folded and empty.
5. **Weight.** Measure the Lighthouse page under Open, Needs you, Overdue, Next up, Done and All (as a signed-in demo person
   whose saved filter you set back afterwards) and report KB and time. If a filter is still over 250 KB find what else is
   big (the status rules panel, repeated markup in the 45 section headings) and slim it within the same rules.
6. **Docs.** README (a line under the checklist: long lists open section by section), CHANGELOG `[Unreleased]`.

## Tests, in order

1. Integration: with more than 8 sections only the first 5 render rows, the rest are folded with heading, counts, meter and
   their lazy path and "Show the M issues" link; with 8 or fewer nothing is folded.
2. Integration: the route with `open=<key>` returns that section open with its first N rows and "Show more"; an unknown key
   returns the checklist unchanged; keys are validated; the narrowing filters and grouping carry through.
3. Integration: `?open=<key>` (and two keys) renders those sections open on the full page; more than 10 keys are cut at 10.
4. Integration: a folded version section is still a drop target (its `data-version-id`) and its lazily loaded rows are
   draggable for a viewer who may edit.
5. Integration: the size of the page under All does not grow with the number of sections beyond the fifth (compare a
   project with 12 and one with 40 sections).
6. The query-count and cache tests stay green (the ceiling is 51; opening a section must not add queries per issue); the
   script test (no backslash-n) stays green; the handler's early returns log a reason.

## Not in this slice

Paging within a section beyond "Show more"; changing the grouping defaults; remembering which sections are open.
