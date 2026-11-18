# 10. Look and accessibility

Blocked by slices 6 and 8 (it styles both pages and the filters).

## Done means

Both pages look as the design describes in Redmine's default theme (light), in a dark theme that sets the plugin's
properties, in a theme that restyles `#content`, beside Rubylode Projects and Rubylode Status, and at phone width without
horizontal scroll; the page never turns dark on its own inside a light theme; every colour is a custom property; text
contrast is at least 4.5:1 for the light defaults and for the dark block in `docs/theming.md`.

## Steps

1. `assets/stylesheets/rubylode_progress.css`, every rule under `.rubylode-progress` (no bare element or `#content`
   selectors). Tokens on `:where(:root)` as `docs/theming.md` in Projects explains, so a theme always wins. Plan's
   call, the colours: start from the reference's light and dark tokens (page, surface, text, muted text, line, accent),
   then map status pairs (colour and tint) to the design: done green, next blue, needs you amber (the reference's
   amber pair), waiting grey, to do neutral, each light and dark. Names: `--rubylode-progress-done-color`,
   `--rubylode-progress-done-background`, and so on for `next`, `needs-you`, `waiting`, `to-do`; plus `surface`,
   `text-color`, `muted-text-color`, `line-color`, `accent-color`, `focus-color`, sizes and spacing.
2. Dark only under a dark theme (owner's decision, 2026-11-18): no `prefers-color-scheme` rule in the stylesheet. The
   defaults are light; a dark theme turns the page dark by setting the plugin's properties, exactly as Rubylode Projects
   works. `docs/theming.md` carries a ready dark block (from the reference's dark tokens) to paste into a theme. The
   panels set their own background and text from the tokens, so a theme that restyles `#content` sees a coherent panel.
3. Layout: one centred column, `max-width: 1100px`; the percent and tile numbers in `ui-monospace, Menlo, monospace`
   with tabular figures; body text inherits the theme's font; no web fonts.
4. Status marks (Plan's call, from the reference): done a filled circle with a check, next a ring with a dot, needs
   you a ring, waiting a dashed ring, to do a plain ring; each pill also prints its label.
5. Phone (`max-width: 640px`): the tracker panel stacks, tiles go `repeat(2, 1fr)`, rows wrap their date and number
   under the title, no fixed widths over the viewport.
6. Focus: `:focus-visible` outline in `--rubylode-progress-focus-color` on links, filters and `<summary>`.
7. `docs/theming.md` in the form of Projects': every property, its default and what it colours, and a block to paste
   into a theme.

## Tests, in order (`test/unit/stylesheet_test.rb`, reading the CSS file as text)

1. "every colour is a custom property": no hex, `rgb` or `hsl` value outside the token block.
2. "the stylesheet has no prefers-color-scheme rule" and "the dark block in docs/theming.md sets every colour token of
   the stylesheet".
3. "text and muted text reach 4.5:1 on the surface, and each status colour on its tint", for the stylesheet's light
   defaults and for the dark block in `docs/theming.md`: a small WCAG relative-luminance helper in the test.
4. "no rule selects #content, body or a bare element".
5. "phone width puts the tiles two by two and stacks the panel".
6. "a focus-visible rule covers links, the filters and summary".
7. "every --rubylode-progress- property in the stylesheet is listed in docs/theming.md".
8. Integration: "the folds are details and summary, the track has its aria-label, the pressed filter has aria-pressed,
   and each status shows its text label".

## Not in this slice

Screenshots (12); checking in a browser unless the owner asks.
