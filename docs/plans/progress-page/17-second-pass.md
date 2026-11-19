# 17. Second pass after the demo review

Blocked by slice 16. Raised by the owner on 2026-11-19 from a written review of the demo; blocks slice 12. Where this
slice and slices 14 to 16 disagree, this slice wins, except for the two rulings below.

## Rulings by the owner (2026-11-19)

- **The rail keeps its current rule.** The line below a stage's mark belongs to that stage: its own share, its own
  colour (Foundations runs green, the red starts below the stage left behind). The review's item 1 (back to the next
  stage's share) is declined; do not change the rail. The top tracker is not changed either.
- **Rows show the assignee only**, not the author, and not when the assignee is the viewer (the Needs you pill already
  says it) or when there is none. Open question 4 of slice 15 is answered this way. The author appears in the issue
  modal only.

## Done means

Each item below is either fixed or shown, with a test, not to be a problem in the current code. Where the review's
claim does not match the code (for example that closed issues are listed beside "Show N closed"), say so in the report
and add a test that pins the right behaviour.

## Steps

1. **Bug: the New issue button is unreadable.** Dark text on the dark accent fill in the checklist heading. Give it a
   readable pair of colours from theme properties (text on accent), and check contrast at 4.5:1 in the light and dark
   blocks.
2. **Folding follows the rules; verify first.** Done and upcoming stages start folded, the current and partial stages
   start open; in a current or partial stage the closed issues are not listed until "Show N closed" is opened; the
   toggle looks clickable (link colour, a chevron, and "Hide N closed" when open) and is a real `<details>`/button with
   keyboard focus. Test each rule in the markup.
3. **Marks keep their shapes; verify first.** `docs/theming.md` promises a ring with a dot for Next and a dashed ring
   for Waiting; open rows must not all be the same plain ring. To do: plain ring; Next: ring with a dot; Waiting: dashed
   ring; in progress: half filled (as today); Needs you: ring in the needs-you colour; done: tick. The rail steps keep
   done, in progress and open only (slice 14). Colour is never the only cue (each mark keeps a text equivalent).
4. **Names.** Checklist rows and stage-list rows show the assignee only, per the ruling, muted, and nothing when there
   is none or it is the viewer. The author leaves the rows and stays in the issue modal (it is Redmine's own page).
5. **Section headings under the Open filter.** Lead with "N open" and keep the meter for context; under Done and All
   keep "N of M closed". The count in the heading is always the same number the list below it shows.
6. **Dates.** In the checklist date column drop the year when it is the current year (11/27), show a two-digit year for
   another year (01/03/27), keep "Tue 11/24, 5d" and "Overdue 45d" as they are. Build it from the viewer's own date
   format when it is a plain day-month-year pattern; otherwise leave Redmine's format as it is.
7. **Top block.** Remove the repeated project name row ("Bridge / Last change"): the project name stays as a visually
   hidden heading for assistive technology and for the existing tests; "Updated 11/19" moves into the tracker panel
   beside the percent.
8. **The percent explained.** Next to the large percent, small print or a tooltip: "Average of stage progress", so 45%
   beside "20 of 39 issues closed" is not read as a mistake.
9. **Top tracker labels.** Two lines per stage: the name with its percent on the first ("Framing 86%"), the date line
   second. Same state colours and `aria` wording as today.
10. **"How statuses are decided" reads as a control.** Info icon, a 28px minimum height, button styling, still a folded
    `<details>`, still placed beside the Group by control; on a phone it stays a disclosure under it.

## Tests, in order

1. Contrast test: the New issue button's text on its fill, light and dark.
2. Integration: the fold rules of step 2, in the markup, per stage state; the toggle label changes with `open`.
3. Integration: the mark class per status (To do, Next, Waiting, Needs you, in progress, done) in the stage list and
   the checklist.
4. Integration: rows show the assignee only, not when it is the viewer, not when unassigned, and no author on rows.
5. Integration: the Open heading leads with the open count; Done keeps "N of M closed".
6. Unit: the date column formatting for this year, another year, due soon and overdue.
7. Integration: no visible project-name row, the hidden heading exists, "Updated" is in the tracker panel, the percent
   carries its explanation.
8. Integration: the top tracker label has the percent on the name line.
9. Stylesheet test updated; the rail cache and query-count tests stay green (re-check the ceiling).

## Not in this slice

Changing the rail or the top tracker's colour rule; anything the owner has not listed.
