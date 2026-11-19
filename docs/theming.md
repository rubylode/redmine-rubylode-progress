# Theming

The page uses plain CSS (`assets/stylesheets/rubylode_progress.css`), and every colour and size in it is a
`--rubylode-progress-*` custom property. The plugin sets its defaults in `:where(:root)`, which has no specificity, so a
theme wins whenever it sets a property, on `:root` or on any element, whatever order the stylesheets load in.

The defaults are light. The page never turns dark on its own inside a light theme: a dark theme sets the properties (the
block at the end of this page).

Colors:

| Property | Default | Used for |
|---|---|---|
| `--rubylode-progress-surface` | `#ffffff` | the panels: tracker, tiles, checklist, compact trackers |
| `--rubylode-progress-text-color` | `#1f2933` | panel text |
| `--rubylode-progress-muted-text-color` | `#5d6672` | dates, notes, assignees, tile labels, the tally |
| `--rubylode-progress-line-color` | `#d9dee5` | panel borders and row dividers |
| `--rubylode-progress-accent-color` | `#1f5f8b` | the stage dots and the pressed filter |
| `--rubylode-progress-focus-color` | `#1f5f8b` | the keyboard focus outline |
| `--rubylode-progress-done-color` | `#1b6e34` | Done: mark, pill text, tile number |
| `--rubylode-progress-done-background` | `#e3f4e7` | the Done pill |
| `--rubylode-progress-next-color` | `#1a5fa0` | Next: mark, pill text, tile number |
| `--rubylode-progress-next-background` | `#e4eefa` | the Next pill |
| `--rubylode-progress-needs-you-color` | `#8a5200` | Needs you: mark, pill text, tile number |
| `--rubylode-progress-needs-you-background` | `#fdf0d5` | the Needs you pill |
| `--rubylode-progress-waiting-color` | `#4a5360` | Waiting: mark and pill text |
| `--rubylode-progress-waiting-background` | `#eceff3` | the Waiting pill |
| `--rubylode-progress-to-do-color` | `#4a5360` | To do: mark and pill text |
| `--rubylode-progress-to-do-background` | `#f4f5f7` | the To do pill |

Sizes and type:

| Property | Default | Used for |
|---|---|---|
| `--rubylode-progress-column-width` | `1100px` | widest the centred column grows |
| `--rubylode-progress-radius` | `8px` | panel corners |
| `--rubylode-progress-panel-padding` | `1em 1.2em` | inside a panel |
| `--rubylode-progress-gap` | `1em` | space between panels and tiles |
| `--rubylode-progress-space-small` | `0.4em` | small spacing |
| `--rubylode-progress-mark-size` | `1em` | the status marks |
| `--rubylode-progress-track-dot-size` | `1em` | the stage markers on the top bar |
| `--rubylode-progress-bar-height` | `0.6em` | the thickness of the top bar |
| `--rubylode-progress-meter-width` | `7em` | the small progress bar beside a stage or section name |
| `--rubylode-progress-tile-number-size` | `1.6em` | the big numbers in the tiles |
| `--rubylode-progress-percent-size` | `1.6em` | the percent beside the track |
| `--rubylode-progress-small-text-size` | `0.85em` | pills, dates, labels |
| `--rubylode-progress-monospace-font` | `ui-monospace, Menlo, monospace` | the percent, tile numbers, issue numbers |

Each status also has its own mark shape (done a filled circle with a check, next a ring with a dot, needs you a ring,
waiting a dashed ring, to do a plain ring) and prints its label, so colour is never the only signal. Text contrast is at
least 4.5:1 for the defaults and for the dark block below.

## Dark theme

Paste this into a dark theme's stylesheet:

```css
:root {
  --rubylode-progress-surface: #161b22;
  --rubylode-progress-text-color: #e6edf3;
  --rubylode-progress-muted-text-color: #9da7b3;
  --rubylode-progress-line-color: #2f3742;
  --rubylode-progress-accent-color: #6cb2eb;
  --rubylode-progress-focus-color: #6cb2eb;
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
}
```
