# 15. Design review: wider layout, tracker rail, filters in the checklist

Blocked by slice 14. Raised by the owner on 2026-11-19 after a design review of the demo (desktop and phone mock-ups);
blocks slice 12. Where this slice and slice 14 disagree, this slice wins.

## Done means

The page uses the full width of Redmine's content area. The stage tracker at the top and the stage list beside it read as
one parcel tracker: a mark per stage, joined by a line that fills to each stage's own progress, drawn horizontally on top
and vertically down the left of the stage list. The tiles are gone; their counts become the filter pills, which sit in
the checklist panel and change only the checklist. The page says "issue", never "step". It looks the same on a phone,
stacked. Everything still works in Redmine's default theme and every new colour is a theme property.

## The one rule for the line

A stage's mark sits at the end of its own segment, and **the segment running into a mark is filled to that stage's
closed share** (the percent rule's number for the stage, rounded). Done stage: full; partial stage at 86%: 86% filled;
current stage at 38%: 38% filled; upcoming: empty. The top tracker and the vertical rail use the same rule, the same
marks and the same colours.

Marks (circles, as slice 14): done is a filled circle with a tick (done colour); partial (left behind with open issues)
is a filled circle with "!" (behind colour); current is a ring with a dot and a soft halo (accent colour); upcoming is a
plain ring (muted line colour). Each mark keeps a text equivalent, so colour is never the only signal.

## Steps

1. **Full width.** `--rubylode-progress-column-width` defaults to `none`, so the page fills `#content`; a theme can
   still set a width. Below the tracker header, the stage list and the checklist sit side by side: a wrapping flex row,
   stage list `flex: 1 1 34em`, checklist `flex: 1 1 30em`, both `min-width: 0`, so they stack below about 1100px. No
   sticky side column, no `100vh`.
2. **Tracker header.** Left: "Stage N of M", the current stage's name, then the segmented top tracker. Right, beside it
   (stacking under it on narrow screens): the overall percent large, "X of Y issues closed", and up to two notices,
   each a short sentence with an icon:
   - **Behind** (behind colours), for a partial stage whose due date has passed: "Framing is 45 days overdue: 1 open
     issue". Several partial stages: the oldest first, then "and 2 more".
   - **Due soon** (needs-you colours), for the current stage when it has a due date: "Decking: 10 open, 14 days left".
     Whether this shows always or only past a threshold is the owner's call (open question 1); build it as "always
     when the current stage has a due date" until told otherwise.
3. **Top tracker, segmented.** Replace slice 14's one continuous bar with one segment per stage on a grid of equal
   columns: segment, then the mark, segments touching the marks so the line is continuous. Under each mark, right
   aligned: the stage name (bold for the current stage), its percent, and one line of date: "Done 08/21", "Overdue, due
   10/05" (behind colour, bold) or "Due 12/03, 14 days". The `aria-label` stays "N% done, X of Y stages finished"; the
   marks are `aria-hidden`, each label carries the state in words. The compact tracker on `/progress` uses the same
   segments and marks without the labels.
4. **Vertical rail on the stage list.** Each stage item gets a left rail: its mark beside the summary line, a line from
   the mark down to the next stage's mark (it runs past this stage's expanded issues). Per the rule, the line below a
   stage's mark is filled to the **next** stage's share, top down; the first stage gets a short lead-in above its mark
   filled to its own share. Draw the line with a `linear-gradient` from custom properties, not markup:
   `style="--rubylode-progress-share-into-next: 38%; --rubylode-progress-colour-into-next: var(--rubylode-progress-accent-color)"`.
   The cached stage fragment must not depend on its neighbour: move the `<li>` outside the `cache` block and put the
   two properties on it (or add the next stage's share to the key; prefer the uncached wrapper). The stage separator
   lines go; the rail separates the stages.
5. **Stage list rows.** In the current and partial stages, closed issues fold under a "Show N closed" toggle (closed
   first in issue order when shown); open issues show first. A partial stage that is folded shows one line under its
   name: "Blocking: <title> #id" for its open issue (or "N open issues" when several). The add link reads "New issue in
   <version name>". The pencil and the new-tab link show on row hover and on `:focus-within`, always on touch screens
   (`@media (hover: none)`).
6. **Tiles become filter pills.** Remove `_tiles`. The filters become pills that show their count then their label,
   placed in the checklist panel's heading, under its title. Filters, in order: Needs you, Overdue, Next up, Open, Done,
   All. `ChecklistFilter::NAMES` gains `overdue` (open issues whose due date, or whose version's due date, has passed;
   open question 2) and `next` (the item status Next). The pressed pill is filled with the accent colour; a pill with a
   count of 0 is muted but stays clickable; the Overdue pill uses the behind colours when its count is above 0. The
   pills keep `aria-pressed`, and choosing one swaps only the checklist (the stage list never changes with the filter).
7. **Checklist heading.** The title follows the filter: "Open work", "Needs you", "Overdue", "Next up", "Done", "All
   issues", with the count and "by category" beside it. On the right: "Open as issue query" (Redmine's issue list
   with the same project, versions and status; open question 3) and a **New issue** button that uses the existing new
   issue link for the current stage's version, with a `title` saying so. The empty state names the filter: "Nothing
   is waiting on you" for Needs you, "No issues match this filter" otherwise.
8. **Checklist rows.** Mark, title (and the note under it, as today), then on the right: the pencil and new-tab link
   (hover, as step 5), the issue number in monospace in a fixed-width column, the status pill, the date. Dates: "Mon
   11/24, 5d" when due within 7 days (needs-you colour), "Overdue 45d" when past (behind colour, bold), the plain date
   otherwise, a dash without one. Closed issues in the Done and All filters get the done mark and "Closed 11/12".
9. **Grouping control and the status rules, in the checklist panel.** Under the pills: "Group by" with a three-button
   group, Version, Category, Parent issue (`aria-pressed`), the existing `checklist_grouping` choices. The pressed one
   starts at the project's setting, marked "project default"; picking another regroups the list in place (the same
   Stimulus swap as the filters, `?group=category`, a real link without JavaScript) and reads "just for you, project
   default: Category". Grouping changes the headings only, never which issues are listed (as `ChecklistSections`
   already does). Whether the viewer's choice is remembered like the filter is open question 5; build it as a URL
   parameter only until told. On the right of that row, a "How statuses are decided" disclosure (a `<details>`, folded by
   default) lists the derived status rules in their order, first match wins, each with its own pill so the panel doubles
   as the legend: Done (closed); Needs you (assigned to you or a group you are in); Waiting (blocked by an open issue, or
   in a waiting status, naming the statuses from the effective settings); Next (in an in-progress status, or one of the
   first N other open issues of the current stage by priority, due date, number, naming the statuses and N); To do
   (everything else). It reads the effective settings (plugin-wide with the project's overrides), so it always tells
   the truth for this project, and links "Change in project settings" for viewers who may manage the project. One line
   under it: the half-filled circle means an in-progress status. "In progress" is never a pill of its own: such an
   issue is Next with the half-filled mark.
10. **Words.** Every user-facing "step" becomes "issue" in `config/locales/en.yml` and the views:
   "8 issues closed", "6 of 7 closed, 1 left", "4 issues planned", "6 of 16 closed". Class names may keep `step`.
11. **Bugs seen in the review, each with a failing test first.** (a) One checklist section rendered twice for the same
    category. (b) A section showing "0/3" beside a 100% meter. (c) A closed issue listed among the open ones in the
    Open filter. (d) A partial stage past its due date with no warning (covered by step 2).
12. **Phone (≤ 640px).** Header, tracker, pills, checklist, stage list, in that order. The top tracker keeps its
    segments and marks but shows one label line: first stage, current stage with its due date, last stage. Pills
    scroll sideways in one row; Group by becomes a select under them and the rules panel stays a disclosure. Checklist rows take two lines: title, then number, pill and date; the pencil and
    new-tab link move behind a 44px "more" button. The stage list keeps the vertical rail. Touch targets at least
    44px.
13. **Theme properties.** New, with light defaults on `:where(:root)` and dark values in `docs/theming.md`'s block:
    `--rubylode-progress-behind-color` `#b3261e`, `--rubylode-progress-behind-background` `#fdecea`,
    `--rubylode-progress-track-empty-color` `#d5dbe2`, `--rubylode-progress-rail-width` `4px`,
    `--rubylode-progress-stage-mark-size` `1.6em` (top) and `--rubylode-progress-rail-mark-size` `1.4em` (rail). Due
    soon reuses the needs-you pair. Update the tables in `docs/theming.md`; contrast at least 4.5:1 for text and 3:1
    for the marks and the line, in both blocks.

## Tests, in order

1. Unit: `ChecklistFilter` knows `overdue` and `next`; an issue past its own or its version's due date is overdue, a
   closed one never is.
2. Integration: "the top tracker draws a segment per stage filled to its share and a mark per state, with the labels".
3. Integration: "each stage item carries the share and colour of the next stage, and the cached fragment is reused
   when only a neighbour changes".
4. Integration: "a partial stage past its due date shows the Behind notice with its open count".
5. Integration: "the filter pills show the same counts as the checklist they select, Overdue and Next up included, and
   the stage list is the same under every filter".
6. Integration: "the checklist heading follows the filter and carries the New issue link for the current version".
7. Integration: "closed issues fold under Show N closed in the current stage".
8. Integration: the three bugs of step 11, one test each.
9. Integration: "no user-facing text says step".
10. Integration: "the group buttons regroup the checklist without changing its issues, and the rules panel names the
    effective waiting and in-progress statuses and the Next limit".
11. Stylesheet test for the new classes and properties; look-and-accessibility, rail cache and query-count tests stay
    green (re-check the ceiling with the new filters).

## Open questions for the owner

1. Due soon notice: always for the current stage with a date, or only past a threshold (days left per open issue)?
2. Overdue: the issue's own due date only, or also its version's due date when the issue has none?
3. "Open as issue query": which Redmine filters should it carry (version, status open, the filter's own rule)?
4. Assignees on stage rows: keep the author and assignee names (slice 14), or show only other people than the viewer?
5. Grouping picked on the page: remembered per person (a Redmine preference, like the filter), or only for that visit?

## Not in this slice

A per-viewer setting to remember folds; drag and drop; anything the owner has not listed.
