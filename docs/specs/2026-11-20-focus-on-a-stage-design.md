# Focus on one stage

Status: approved by the owner 2026-11-20. For 1.2.0.

## Intent

On a project with many stages the page is long and both columns mix everything. The owner wants to pick one stage (a
version, for example "Hermes in R1 in Production") and see and work on only that stage and its progress, with an address
that reproduces the view.

## Goals

- One click on a stage focuses the whole page on it: the left column lists only that stage, the right column lists only
  its open work, the top block shows that stage's own percent and "N of M closed".
- The address carries the focus, so a link or a reload lands in the same view.
- Everything that works on the full page keeps working inside the focus: the status pills and their counts, the assignee,
  tracker and category selects, quick edit, new issue, drag, the version status modal.
- Leaving the focus is one click and keeps the filter, grouping and selects.

## Non-goals

- Keyboard shortcuts, remembering the last focused stage, focusing several stages at once.
- Any change to the cross-project page.
- Changing the remembered filter or grouping: focusing never writes a preference.

## Anti-goals

- A focus done by hiding rows in the browser: counts, pills and "Show more" would be wrong and lazy loading would fight it.
- Taking away the fold and unfold of a stage: the chevron keeps it.

## Approaches

1. **Server-side focus (chosen).** `?stage=<version id>` narrows the stages and the items on the server, so every count,
   pill and fragment agrees. Fits the existing `filter`, `group` and narrowing parameters.
2. Hide rows with a script. Rejected: wrong counts, not a real view, fights lazy loading.

## Design

- **Address:** `/projects/:id/progress?stage=<version id>`, beside `filter`, `group`, `assignee`, `tracker`, `category`.
  A value that is not the id of one of the viewer's stages for this project is a 404 (same rule as the stage fragments);
  a non-numeric value is a 404 too. The stage fragment and checklist routes accept and keep `stage`, so a swapped-in
  fragment never widens the view.
- **Entering:** in the stage list the stage name is a link to the focused page; in the top tracker the stage's dot is a
  link to it. The chevron keeps the fold. A focused stage renders open. Links keep filter, grouping and selects.
- **Focused page:**
  - The tracker stays. The focused stage's dot is highlighted, the others are dimmed and still links (jump to another
    stage). The rail was never a drop target; drag between stages works on the full page only, and a focused page lists one
    stage. A "Show all stages" link leaves the focus.
  - The top block shows the focused stage's name, its percent and "N of M closed" in place of the whole-project ones.
  - The left column renders only that stage.
  - The right column lists only that stage's issues, as one flat list: no version grouping and no version group
    heading, and the "Group by" control is hidden. Pills, counts and selects are computed over that stage's issues only.
  - New issue offers that stage only.
- **Focusable:** exactly the stages the page already lists for the viewer. A stage that shows no visible issue is still a
  stage of the page, so it focuses and shows the empty message; a version that is not a stage of the page is a 404.
- **Unchanged:** remembered filter and grouping, the cross-project page, settings, the release zip layout.

## Constraints

- Public code: no private names or data; GPL v2 header on every Ruby file; descriptive names; no client framework, no
  build step; Minitest through `bin/test`.
- Only what the viewer may see: focusing narrows the viewer's visible stages, it never reads past them.

## Left to the builder

- Where the focus lives in the code (a small value object over `ProjectProgress` versus a parameter on the existing
  grouping) and the exact markup and class names, following the existing partials.
- The wording of "Show all stages" and the focus link's accessible label, in the existing locale file.
