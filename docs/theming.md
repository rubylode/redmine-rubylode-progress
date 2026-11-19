# Theming

The page uses plain CSS (`assets/stylesheets/rubylode_progress.css`), and every colour and size in it is a
`--rubylode-progress-*` custom property. The plugin sets its defaults in `:where(:root)`, which has no specificity, so a
theme wins whenever it sets a property, on `:root` or on any element, whatever order the stylesheets load in.

The defaults are light. The page never turns dark on its own inside a light theme: a dark theme sets the properties (the
block at the end of this page).

Colors:

| Property | Default | Used for |
|---|---|---|
| `--rubylode-progress-surface` | `#ffffff` | the panels: tracker, stage list, checklist, compact trackers |
| `--rubylode-progress-text-color` | `#1f2933` | panel text |
| `--rubylode-progress-muted-text-color` | `#5d6672` | dates, notes, assignees, the tally, the ring of an upcoming stage |
| `--rubylode-progress-line-color` | `#d9dee5` | panel borders and row dividers |
| `--rubylode-progress-accent-color` | `#1f5f8b` | the current stage's mark and line, the pressed pill and group button |
| `--rubylode-progress-on-accent-color` | `#ffffff` | text on the accent fill: the New issue button |
| `--rubylode-progress-focus-color` | `#1f5f8b` | the keyboard focus outline |
| `--rubylode-progress-drop-target-color` | the accent colour | the outline of a stage or section an issue is dragged over |
| `--rubylode-progress-done-color` | `#1b6e34` | Done: marks, the line of a finished stage, pill text |
| `--rubylode-progress-done-background` | `#e3f4e7` | the Done pill |
| `--rubylode-progress-next-color` | `#1a5fa0` | Next: mark, pill text |
| `--rubylode-progress-next-background` | `#e4eefa` | the Next pill |
| `--rubylode-progress-needs-you-color` | `#8a5200` | Needs you: mark, pill text; also Due soon (the notice and the dates within a week) |
| `--rubylode-progress-needs-you-background` | `#fdf0d5` | the Needs you pill and the Due soon notice |
| `--rubylode-progress-waiting-color` | `#4a5360` | Waiting: mark and pill text |
| `--rubylode-progress-waiting-background` | `#eceff3` | the Waiting pill |
| `--rubylode-progress-to-do-color` | `#4a5360` | To do: mark and pill text |
| `--rubylode-progress-to-do-background` | `#f4f5f7` | the To do pill |
| `--rubylode-progress-behind-color` | `#b3261e` | Behind: the mark and line of a stage left behind with open issues, overdue dates, the Behind notice, the Overdue pill |
| `--rubylode-progress-behind-background` | `#fdecea` | the Behind notice and the Overdue pill |
| `--rubylode-progress-track-empty-color` | `#d5dbe2` | the unfilled part of the tracker and the rail (decoration: the filled part and the marks carry the meaning) |

Sizes and type:

| Property | Default | Used for |
|---|---|---|
| `--rubylode-progress-column-width` | `none` | widest the page grows; `none` fills Redmine's content area, a theme can set a width such as `1100px` |
| `--rubylode-progress-radius` | `8px` | panel corners |
| `--rubylode-progress-panel-padding` | `1em 1.2em` | inside a panel |
| `--rubylode-progress-gap` | `1em` | space between panels |
| `--rubylode-progress-space-small` | `0.4em` | small spacing |
| `--rubylode-progress-mark-size` | `1em` | the status marks |
| `--rubylode-progress-stage-mark-size` | `1.6em` | the stage marks on the top tracker |
| `--rubylode-progress-rail-mark-size` | `1.4em` | the stage marks on the vertical rail |
| `--rubylode-progress-rail-width` | `4px` | the thickness of the tracker line and of the rail |
| `--rubylode-progress-bar-height` | `0.6em` | the thickness of the small progress bars |
| `--rubylode-progress-meter-width` | `7em` | the small progress bar beside a stage or section name |
| `--rubylode-progress-percent-size` | `2.4em` | the big overall percent in the header |
| `--rubylode-progress-small-text-size` | `0.85em` | pills, dates, labels |
| `--rubylode-progress-monospace-font` | `ui-monospace, Menlo, monospace` | percents, counts, issue numbers, dates |

The page also sets four properties inline, per stage, to draw the tracker and the rail. They are not theme properties
and have no default; a theme has no reason to set them: `--rubylode-progress-share` and
`--rubylode-progress-segment-color` (one segment of the top tracker), `--rubylode-progress-share-below` and
`--rubylode-progress-colour-below` (the rail line below a stage's mark, which also gives the first stage its short
lead-in: filled to that stage's own share, in that stage's own colour).

Each status also has its own mark shape on the checklist rows (done a filled circle with a check, in progress half filled, next a ring with a dot, needs you a ring,
waiting a dashed ring, to do a plain ring; the steps in the stage list keep done, in progress and open only; a stage mark is a tick when done, an exclamation mark when left behind, a ring with a dot when current, a plain ring when upcoming) and prints its label, so colour is never the only signal. Text contrast is at
least 4.5:1 for the defaults and for the dark block below; the marks and the filled line reach 3:1.

## Dark theme

Paste this into a dark theme's stylesheet:

```css
:root {
  --rubylode-progress-surface: #161b22;
  --rubylode-progress-text-color: #e6edf3;
  --rubylode-progress-muted-text-color: #9da7b3;
  --rubylode-progress-line-color: #2f3742;
  --rubylode-progress-accent-color: #6cb2eb;
  --rubylode-progress-on-accent-color: #0d1117;
  --rubylode-progress-focus-color: #6cb2eb;
  --rubylode-progress-drop-target-color: #6cb2eb;
  --rubylode-progress-done-color: #7ee08f;
  --rubylode-progress-done-background: #17301f;
  --rubylode-progress-next-color: #8cc4f5;
  --rubylode-progress-next-background: #14304d;
  --rubylode-progress-needs-you-color: #f2c56b;
  --rubylode-progress-needs-you-background: #3a2b0c;
  --rubylode-progress-waiting-color: #b4bcc6;
  --rubylode-progress-waiting-background: #262c34;
  --rubylode-progress-to-do-color: #b4bcc6;
  --rubylode-progress-to-do-background: #20252c;
  --rubylode-progress-behind-color: #ff9b94;
  --rubylode-progress-behind-background: #3d1a17;
  --rubylode-progress-track-empty-color: #3a424d;
}
```
