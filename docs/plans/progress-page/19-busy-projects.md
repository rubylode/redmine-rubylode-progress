# 19. Busy projects: many stages, many issues

Blocked by slice 18 (the 1.0.0 release is out; this is for 1.1.0). Raised by the owner on 2026-11-19 after installing 1.0.0
on a real project with 45 stages (a version per quarter since 2019) and 560 issues, where the page was too long and the
track's 45 labels overlapped. Nothing is broken: this is about reading a lot of data. The load project of the demo (slice
19a) shows it.

## Done means

On a project with 45 stages and 1000 issues the page opens on one screen of useful things: the finished stages are folded
into one line, the track shows a summary mark for them and readable marks for the rest, the checklist lists a few issues
per section with "Show more", and the checklist can be narrowed by assignee, tracker or category. Which versions count as
stages is chosen in the project's settings. A small project looks exactly as it does now.

## Owner's rulings (2026-11-19)

- Finished stages fold into one line by default (not hidden, not cut by year).
- The top track gets one summary mark for the finished stages.
- Versions are picked by ticking them in the project's settings (no rule language).
- The checklist shows 10 issues per section with "Show more", and gains filters by assignee, tracker and category.

## Steps

1. **Finished stages fold.** In the stage list, finished stages (state done) older than the last N finished ones are
   replaced by one row "38 finished stages" with a meter at their combined closed share and the count of issues closed
   ("440 issues closed"). The row is a `<details>`; opened, it lists those stages as today. N is a setting (default 3,
   range 0 to 20, per project with the plugin-wide default). Open, current, partial and upcoming stages are never folded,
   and a project with N or fewer finished stages looks as before. The fold is rendered from the stage list, outside the
   per-stage cache, and its summary reads only data already in the cache keys.
2. **Top track with many stages.** With more than 12 stages the track draws: one summary mark for the folded finished
   stages (a green segment, label "38 stages done"), then the last N finished, then every other stage as a mark, each with
   its label. Labels never overlap: with more than 12 marks only the current stage and its two neighbours get a full label
   (name, percent, date), the others a mark and a tooltip (`title`) and a visually hidden label for screen readers. The
   `aria-label` of the track keeps its wording and counts all stages. Up to 12 stages nothing changes.
3. **Pick the stages.** The project's Progress settings tab gets a list of the project's counted versions with a checkbox
   each (all ticked by default, new versions counted as they appear). Unticked versions are stored as ids in the project
   setting row (a new column, a migration) and never become stages; their issues are not counted. The existing
   "versions that make the stages" and prefix rules stay and apply first. The plugin-wide page has no list (it is per
   project). Ticks of deleted versions are ignored.
4. **The checklist shows 10 per section.** Each section lists its first 10 issues (the order it has now) and a link "Show
   N more" that reveals the rest in place (no reload; a real link to `?expand=<section>` without JavaScript). The section
   heading still counts all of its issues. The number is a setting like N above (default 10, range 5 to 100).
5. **Filter by assignee, tracker, category.** Above the checklist, next to the status pills, three selects (assignee,
   tracker, category) offering the values that occur in the project's counted issues, with "any" first. They narrow the
   checklist and its pill counts together; the stage list and the top tracker never change with them. Plain GET
   parameters (`assignee`, `tracker`, `category`), real links/forms without JavaScript, swapped in place like the filters
   and the grouping. Only values the viewer's visible issues have are listed. They are not remembered.
6. **Show less.** The "How statuses are decided" panel and the notices stay as they are but long issue notes in the
   checklist are cut at 2 lines with "show note" (a `<details>`), and the Behind notice names at most 3 stages ("and 5
   more" as today's rule).
7. **Phone.** The finished-stages row, the summary mark and the filter selects stack and keep 44px targets.
8. **Docs.** README (Settings table: the two numbers and the version list; the filters), CHANGELOG `## [1.1.0] - <date>`
   (Added), `docs/theming.md` if a new colour appears.

## Slice 19a: the busy demo project (done first)

A second demo project "Lighthouse" built by `DemoData.build_busy` (not by `DemoData.build`, so the existing demo tests and
screenshots do not change; the rake task `redmine_rubylode_progress:demo` and `bin/demo up` call both): 45 versions, one
per quarter from 2019 Q2 to 2030 Q2 (dates relative to `today` so the current quarter is stage 44-like: about 30 closed with
all issues closed, 4 closed with a few issues left open, the current one, the rest upcoming), 1000 issues with generated
made-up subjects (no real text), 6 people, 5 categories, 3 trackers, some assigned to the demo person, some overdue, some
with notes. Deterministic (a fixed seed), made in one transaction in batches, does nothing when the project exists.
`bin/demo seed-busy` runs it alone. Nothing about the owner's real project is copied: no names, titles or dates.

## Tests

1. Unit: the folding of finished stages (N, fewer than N, none, partial never folded) and its combined numbers.
2. Integration (the busy project built in the test with generated versions): the stage list shows the fold row with the
   right counts, opens to the stages, and keeps the others; a small project is unchanged.
3. Integration: the track with more than 12 stages has the summary mark, full labels only for the current stage and its
   neighbours, and no label text overlaps in the markup order (one label per mark); up to 12 stages is as before.
4. Integration: unticked versions are not stages and their issues are not counted; the migration adds the column; a
   deleted version's tick is ignored; the settings form saves and shows the list.
5. Integration: sections list 10 issues and "Show N more"; the heading counts all; `?expand=` shows all without JS.
6. Integration: the three filters list only values present for the viewer, narrow the checklist and its counts, and leave
   the stage list and the track unchanged.
7. Integration: long notes are cut with "show note"; the Behind notice names at most 3.
8. The query count: with 45 stages and 1000 issues the page stays under a fixed ceiling and does not grow with the
   number of issues or stages (measure at 100 and 1000 issues; the cache and the batching must hold).
9. The demo: the busy project builds in the test with a smaller size and is idempotent.

## Not in this slice

Server-side paging of the issue query for projects with tens of thousands of issues; a plugin-wide list of versions;
rule languages for choosing stages; remembering the three new filters.
