# 20. Load a stage's issues when it is opened

Blocked by slice 19 (done). Found on 2026-11-19 with the busy demo project: after slice 19 the Lighthouse page (45 stages,
1000 issues) was still 1,413 KB, of which the stage list is about 1,320 KB, because every stage renders all of its issues
inside a closed `<details>`. The checklist is 70 KB. For 1.1.0.

## Done means

The first response renders the stage list without the issues of the stages that start folded. A folded stage shows its
summary (name, date, meter, counts, status button) and fetches its issues when it is opened. The Lighthouse page is under
150 KB, and its size no longer grows with the number of issues in folded stages. A small project looks and behaves as it
does now, and every stage still works without JavaScript.

## Steps

1. **Which stages are eager.** Stages that start open (current and partial) render their issues in the first response. Done
   stages, upcoming stages and the stages inside the finished-stages fold start folded and render no issues; their summary
   stays complete (it is computed from the stage's issues, which are loaded anyway).
2. **A route for a stage's issues.** `GET progress/stages/:version_id/issues` (HTML, no layout) answers the stage's issue
   list partial exactly as the stage renders it today. It authorizes like the other plugin actions (the plugin permission in
   the permission map, the version must be one of this page's stages, 404 otherwise; the issues are the viewer's visible
   ones, so it never shows more than the page). It reuses the stage fragment cache: the cache key is the stage's key as
   today; the summary and the issue list are separate fragments so the summary never depends on the list.
3. **Opening loads.** A folded stage has `data-lazy-issues-path` on its `<details>`. A Stimulus handler (in the existing
   script, no new library) loads the path on the first open, shows a one-line "Loading" state, inserts the HTML, and handles
   failure with a message and a plain link to `?open_stage=<id>`. The inserted rows are draggable and carry the pencil and
   new-tab links as eager ones do (the drag handlers are delegated from the page root; check it).
4. **Without JavaScript.** A folded stage's summary has a real link "Show the N issues" to `?open_stage=<version id>` (and
   keeping the current filter, grouping and the other parameters); the page then renders that stage open with its issues.
   Validate the id against the page's stages (an unknown id shows nothing extra, never an error).
5. **The finished-stages fold.** Its stages are listed (names, meters, counts) without issues; each opens like any folded
   stage. The ellipsis link on the track still opens the fold.
6. **The rest of the weight.** After 1 to 5, measure the Lighthouse page. If it is still over 150 KB, find what else is big
   (the track's 45 labels' markup, repeated inline styles, the checklist's 10 rows for each of many sections) and slim it
   within the same rules (no change of look). Report the numbers before and after.
7. **Docs.** README (a line in Where it shows / the stage list: folded stages load when opened), CHANGELOG `[Unreleased]`.

## Tests, in order

1. Integration: the first response of a project with many stages holds the issues of the current and partial stages and
   none of the folded ones, and each folded stage carries its lazy path and its "Show the N issues" link.
2. Integration: the issues route answers a stage's list for a viewer who may see it, only the viewer's visible issues, 404
   for a version that is not a stage, 403 without the plugin permission, and renders the same rows the eager stage renders.
3. Integration: `?open_stage=<id>` renders that stage open with its issues; an unknown id changes nothing.
4. Integration: the size of the stage list does not grow with the number of issues in folded stages (build 60 and 300
   issues in folded stages and compare, or assert the folded stages' issue rows are absent).
5. The rail cache and query-count tests stay green (the ceiling is 51; the route must not add queries per issue).
6. The script test (no backslash-n) stays green; the handler's early returns log a reason like the drag script's.

## Not in this slice

Paging a stage's issues (a stage with thousands of issues); lazy loading the checklist (it already lists 10 per section).
