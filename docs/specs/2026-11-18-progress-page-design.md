# Rubylode Progress: design

Date: 2026-11-18. Status: approved for planning.

Sources: the build brief for this plugin (2026-11-18, kept with the owner's project notes, outside this repository), the
earlier brief and the private reference page in `.claude/reference/` (look only; never copy its names, tickets or data).
Where the two briefs disagree, the 2026-11-18 brief wins.

## Intent

Redmine's Roadmap tab lists each version with a progress bar and a flat list of issues. It never answers the questions people
open it with: how far along are we, which stage are we in now, what is next, and what is waiting on me? The owner has a
hand-built page that answers them well (a stage rail with a percent bar, a summary row, filters and a grouped checklist), but it
is fed by hand. This plugin builds the same page from Redmine's own data, so it is always current, for one project and across
projects.

Audience: the owner's teams first (StellaLife runs it on Redmine 7.0.2 with Postgres), then anyone who installs it as a public
Rubylode plugin.

## Goals

- A **Progress** tab on every project where the module is enabled, showing that project's roadmap as one readable page.
- A **cross-project page** listing each project the viewer can see as a compact tracker.
- Always derived from Redmine data at view time; nothing stored except settings (plugin-wide, and one row per project that
  overrides them) and one user preference.

## Non-goals

- A full issue editor on the page. The page offers a quick edit and a quick new issue (see "Editing from the page");
  everything else is one click away on the issue's own edit page (owner's decision, 2026-11-18; this used to rule out
  editing altogether).
- Gantt, calendar or time tracking.
- A JSON API (Redmine's REST API already covers the data).
- Planned steps without a ticket ("ticket to file" in the reference). A step is always an issue; to plan a step, file it.
- Replacing Redmine's Roadmap tab, which stays as it is.

## Anti-goals (a failure even if it works)

- Showing an issue, version or project the viewer may not see. Visibility always goes through `Issue.visible` /
  `Project.visible` and the plugin's permission, never raw SQL around them.
- N+1 queries: the page must not slow down as a project grows.
- Anything from `.claude/reference/` in a commit: names, tickets, dates, copy or screenshots.
- A page that only works in Redmine's default theme.
- A save that goes around Redmine: every edit and new issue goes through Redmine's own issue update and create, so its
  permissions, workflow, required fields, journals and notifications apply exactly as on the issue page.

## Constraints

- **Redmine 7.0 and newer only** (owner's decision, 2026-11-18). Redmine 7 ships Stimulus on an importmap and no Turbo. Ruby:
  whatever Redmine 7.0 supports; test the range the siblings test.
- Plugin id `redmine_rubylode_progress`, product name "Rubylode Progress", Ruby namespace `RubylodeProgress`, settings stored as
  `plugin_redmine_rubylode_progress`. Public repository later at `github.com/rubylode/redmine-rubylode-progress`.
- A standard Redmine plugin following the Rubylode standard (`../redmine-rubylode-projects` is closest: its project
  instructions, `docs/theming.md`, `docs/releasing.md`; `../redmine-rubylode-beszel` for `bin/demo`, `bin/test`, Docker,
  workflows, README badges, thumbnail and the redmine.org listing). Release rules:
  `../redmine-todo/.claude/instructions/plugin-release.md`.
- Server-rendered ERB views, plain CSS in `assets/stylesheets/`, Stimulus only where behaviour is needed. No React or any other
  client framework, no build step. One migration: the per-project settings table (see Settings).
- Tests are Minitest with Redmine's own test setup and fixtures.
- Descriptive names everywhere, no abbreviations. The GPL v2 header on every Ruby file.
- `.claude/` is git-ignored before the first commit.

## Approaches considered

1. **A standard Redmine plugin, rules as plain Ruby objects (chosen).** Stage, percent and status rules are small objects tested
   first; one controller per page; views rendered on the server; one Stimulus controller for the filters. Fits the house
   standard and the stack rules.
2. **Bundle Turbo as a plugin asset** so the filters reload a Turbo frame, as the brief first said. Rejected: Redmine 7 has no
   Turbo, and with Stimulus guaranteed a few lines of script do the same without a second framework next to Redmine's scripts.
3. **Draw the page in the browser from the REST API.** Rejected: against the no-client-framework rule, and it would repeat the
   permission checks Redmine already makes on the server.

## What was decided

### Where it shows

- **Project tab "Progress"** at `/projects/:id/progress`, in a project module "Rubylode Progress" with one permission,
  "View progress" (`view_rubylode_progress`). Non-members without the permission get 403; anonymous follows Redmine's rules.
- **Cross-project page** at `/progress`, linked from the top menu as "Progress" for anyone who can see at least one project with
  the module enabled and the permission (*builder's call: the top-menu link and the path*). One compact tracker per project:
  name (linking to its tab), the bar with its dots, the percent and the current stage's name. Ordered by project name. No
  checklist and no "Needs you" counts in the first release (*builder's call*).

### Data mapping

**Which issues count** (one scope for the whole page: rail, percent, tiles and checklist all use it, so their numbers
always agree):

- Only issues the viewer may see (`Issue.visible` for that user). Every count, percent and row is per viewer, never a
  total that includes hidden issues.
- Issues of the project and its subprojects, as Redmine's own Roadmap does with "display subprojects issues" on (owner's
  decision, 2026-11-18). On the cross-project page each project, parent or subproject, gets its own tracker, and a parent's
  tracker includes its subprojects.
- Only issues in a counted version (all shared versions, or those matching the prefix setting). Issues without a version
  never appear.

| Page element | Redmine source |
| --- | --- |
| Stages (the rail) | The versions shared with the project, ordered by effective date, then name. A stage is done when none of its issues is open and its version is closed or lies behind the current stage. A stage that still has open issues and is closed or behind the current stage is partial: work moved on and left something behind (owner's decision, 2026-11-18). Only open and locked versions can be current (*builder's call: locked means frozen for new issues, not finished, as in Redmine's own Roadmap*). A setting can limit them to names starting with a prefix. |
| A stage's steps | The issues in that version. A step is done when its issue is closed. Steps are numbered `<stage>.<position>` (*builder's call, from the reference*). |
| Current stage | The furthest version that is open and has at least one closed issue or an issue in progress; if none, the first open version. |
| Checklist sections | A per-project setting: by version (default), by category, or by parent issue. Grouping only changes the headings, never which issues appear; issues without a category or parent go in a last section ("No category", "No parent"). A parent issue in a counted version is a row and a step like any other (*builder's call*). |
| Item note | The issue's latest journal note, first 240 characters, or a custom field named in the settings. |
| Item date | The due date if set, otherwise the closed date for done items. |

**Derived item status** (never stored), first match wins:

1. **Done**: the issue is closed.
2. **Needs you**: assigned to the viewer, or to a group the viewer is in.
3. **Waiting**: blocked by an open issue (a "blocked by" relation), or in a status listed as waiting in the settings.
4. **Next**: in a status listed as in progress (in any stage), or one of the first 3 remaining open issues of the current stage,
   ordered by priority (highest first), then due date (none last), then issue number (owner's decision, 2026-11-18). The 3 is
   a setting.
5. **To do**: everything else.

**Percent**: the sum over stages divided by the number of stages, rounded. A stage contributes 1 if it is done; otherwise the
share of its issues that are closed, so a closed or passed version with open issues counts only what was finished; 0.5 for
a current stage with no issues. No stages: the page says there is nothing to track
yet and shows no bar.

### The project page, top to bottom

1. **Title and freshness**: the project name and "Last change <date>", the newest `updated_on` among the shown issues.
2. **Tracker panel**: "Stage N of M"; the current stage's name as a large headline with the version's description under it; a
   horizontal track with one dot per stage (done, partial as a half-filled dot, current, upcoming), filled up to the current
   stage, the percent at the right end; then an ordered list of every stage with a rail dot, its name, its date (effective
   date) and its steps as a compact checklist, each linking to its issue and followed by its assignee's name, muted (a
   group's name for a group; nothing when unassigned). A step's mark is a square: empty when open, half-filled when in
   progress, checked when closed; circles belong to stages only (owner's decision, 2026-11-18). Every stage folds its steps in a `<details>`: done and upcoming
   stages start folded ("9 steps done", "5 steps planned"); the current stage starts open ("13 of 17 steps done") and a
   partial stage starts open ("2 of 3 steps done, 1 left") so the leftovers show (owner's decision, 2026-11-18).
3. **Summary row**: four tiles, Done, Next up, Needs you, Still open, each a large number and a label.
4. **Filters**: Open (default), Needs you, Done, All. Each is a real link (`?filter=needs_you`) that works without JavaScript; a
   Stimulus controller fetches the checklist part and swaps it in place, and sets `aria-pressed`. The choice is remembered per
   person in a Redmine user preference, not in the browser.
5. **Checklist**: one section per group with a heading and a done/total tally. A row: status mark, title, status pill, ticket
   number as a link, date, and the note under it in a quieter colour.

### Editing from the page

Owner's decision, 2026-11-18. Both use Redmine's own modal and its pencil and plus icons, and both save through Redmine's
own issue update or create with a `back_url`, so the viewer lands back on the Progress page with the same filter.

- **Quick edit**: a pencil after each step and each checklist row, shown only when the viewer may edit that issue. It opens
  a modal with the status (only the transitions the workflow allows this viewer), the assignee, % done and a note. A
  "Full edit" link in the modal opens the issue's edit page. Fields the viewer may not change are not shown.
- **New issue in a stage**: a plus button on each stage, shown only when the viewer may add issues to the project and the
  version is open (Redmine refuses new issues on closed and locked versions). It opens a modal with tracker, subject,
  assignee and description; the version is set to that stage. Required custom fields the modal does not show send the
  viewer to Redmine's full new-issue form instead, with the version and subject filled in.
- Without JavaScript both are plain links to Redmine's edit and new-issue pages with the same `back_url`.

### Look and feel

- One centred column, max about 1100 px, generous spacing, one accent colour for progress. Status colours: done green, next
  blue, needs you amber, waiting grey, to do neutral. Each status also has its own mark shape and a text label, so colour is
  never the only signal (marks as in the reference: filled circle with a check, ring with a dot, ring, dashed ring, plain ring;
  *builder's call*).
- Large numbers (percent, tiles) in a monospace face; body text in the theme's sans-serif. No web fonts loaded.
- Every colour a CSS custom property. Dark only under a dark theme (owner's decision, 2026-11-18, replacing the brief's
  `prefers-color-scheme`): the defaults are light, a dark theme sets the properties, and `docs/theming.md` carries a dark
  block to paste, as Rubylode Projects does; the page never turns dark on its own inside a light theme. Must look right in Redmine's
  default theme and in themes that restyle `#content`, and alongside Rubylode Projects and Rubylode Status (follow
  `../redmine-rubylode-projects/docs/theming.md`).
- Phone width: the tracker panel stacks, tiles go two by two, the stage list stays readable, no horizontal scroll.
- Accessible: the track has an `aria-label` such as "71% done, 8 of 11 stages finished"; filters carry `aria-pressed`; folds are
  `<details>`/`<summary>`; visible focus ring; text contrast 4.5:1 in both themes.

### Settings

Plugin-wide defaults in Administration > Plugins. Each project can override them in a "Progress" tab of the project's Settings,
editable by anyone with Redmine's "Edit project" permission (`:edit_project`, which the Manager role has by default; owner's
decision, 2026-11-18). Overrides live in one plugin
table, one row per project (`project_id` unique, the overrides as columns or one serialized column: builder's call), deleted
with the project. An empty override means "use the plugin-wide default".

- Which versions count: all shared versions, or only names starting with a given prefix.
- How the checklist groups: by version, category or parent issue.
- Which statuses mean "in progress" and which mean "waiting".
- How many current-stage issues are "Next" (default 3).
- Optional custom field to use as the item note.

### Performance

- Two or three queries for the project page, versions and issues preloaded (with relations, assignee groups and the latest
  note). A test counts the queries and fails on growth with the number of issues.
- The stage rail is fragment-cached per stage, keyed by project, the viewer (user id), the newest `updated_on` of its issues
  and the effective settings. Keyed by viewer, not by role, because Redmine visibility also depends on the person ("own issues
  only" roles, private issues they wrote or are assigned to); a role key could show one person's issues to another
  (*builder's call, replacing the brief's role key*). Only the rail is cached; the checklist and tiles are rendered each time.
- The cross-project page computes stages and percent per project without loading issue notes or journals.

### Deliverables

1. The plugin with a README covering install (`bundle exec rake redmine:plugins:migrate`), enabling the module, every setting
   and screenshots, plus CHANGELOG, thumbnail and the redmine.org listing text, as the siblings have.
2. Minitest coverage: each derived-status rule and their order; percent and current-stage rules (no versions, all done, a
   current stage without issues, several open stages); visibility (private issues and projects stay hidden, on both pages); the
   filters and the remembered preference; the "Next" limit and its ordering; subproject roll-up; per-project overrides falling
   back to the defaults, and only "Edit project" may save them; two viewers with different visibility getting different
   cached rails; a functional test rendering the tab for a member and returning 403 for a non-member;
   the query-count test.
3. `rake redmine_rubylode_progress:demo`, building a demo project with five versions and about forty issues in mixed states
   (every stage state and every checklist status), plus a few smaller projects for the cross-project page. `bin/demo` runs a
   throwaway Redmine 7 with this folder mounted as the plugin and calls it, as the siblings do.

## Left to the builder

- Class layout under `app/models/rubylode_progress/` and how the rule objects are split.
- How a plugin registers its Stimulus controller on Redmine 7's importmap: check first, and fall back to a plain script loaded
  through the layout hook (as Rubylode Projects does) if the importmap cannot take plugin controllers cleanly.
- Exact wording of labels and settings help, in the voice of the sibling plugins.
- Date formatting on the rail and in rows.
- The colour values, starting from the reference's tokens and adjusted to the status colours above.
