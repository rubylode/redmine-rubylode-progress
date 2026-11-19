# Progress page: implementation plan

Spec: `docs/specs/2026-11-18-progress-page-design.md`. Date: 2026-11-18. Models: Rubylode Projects 2.1.0
(`~/Code/ruby/redmine-rubylode-projects`) for the plugin layout, Rubylode Beszel for `bin/demo`, `bin/test`, Docker,
workflows, the README and the redmine.org listing. The Kubernetes plan is the format.

## Goal

A **Progress** tab on each project with the module enabled, answering how far along we are, which stage is current, what
is next and what waits on me, and a cross-project page with one compact tracker per project. Always derived from
Redmine's data at view time and only ever from what the viewer may see.

## Architecture

The rules (which stage is current, the percent, each issue's derived status, the Next limit) are plain Ruby objects
under `app/models/rubylode_progress/`, fed by `IssueScope`, which loads the visible versions and issues once with
everything preloaded. `ProjectProgress` joins the two for one project and viewer; two controllers render it as ERB;
one Stimulus controller swaps the checklist when a filter is chosen.

Seams: (1) the rule objects, tested with plain structs and no database; (2) `IssueScope` and `ProjectProgress` against
Redmine's fixtures; (3) integration tests through the routes. No test reaches into a private method.

## Order

| # | File | What becomes true | Blocked by |
|---|---|---|---|
| 1 | `01-skeleton.md` | Module, permission, tab and route answer; CI runs | nothing |
| 2 | `02-stages-and-percent.md` | Stage states, current stage, percent | 1 |
| 3 | `03-item-status.md` | Derived item status and the Next limit | 1 |
| 4 | `04-issue-scope.md` | The one scope: visible, subprojects, counted versions | 2, 3 |
| 5 | `05-project-page.md` | Title, tracker panel, tiles, checklist | 4 |
| 6 | `06-filters.md` | Filters, the remembered preference, Stimulus | 5 |
| 7 | `07-settings.md` | Plugin settings page, project overrides and their tab | 4 |
| 8 | `08-all-projects-page.md` | `/progress` and the top-menu link | 4 |
| 9 | `09-performance.md` | Query count fixed; rail cached per viewer | 5, 8 |
| 10 | `10-look-and-accessibility.md` | Tokens, dark variant, phone width, contrast | 6, 8 |
| 11 | `11-demo.md` | `rake redmine_rubylode_progress:demo` and `bin/demo` | 6, 7, 8 |
| 12 | `12-release.md` | README, CHANGELOG, listing, v1.0.0 released through Gitea | 9, 10, 11, 13, 14 |
| 13 | `13-edit-and-add-modals.md` | Quick-edit pencil and new-issue plus, through Redmine's own saves | 5 |
| 14 | `14-owner-revisions.md` | Round marks, author and new-tab link, item modal, folds with progress, Due label, one top bar | 11 |

Slices 2 and 3 go in either order; 7 and 8 can run beside 5 and 6. Each slice starts in a fresh session from its file,
works test first, runs single files with `bin/test <file>` while working and `bin/test` once at the end, and ends with
conventional commits.

## Global Constraints

- Redmine 7.0 and newer only; Ruby 3.4 and 4.0, as Rubylode To-do tests (Redmine 7.0 accepts 3.2 to 4.0).
- Plugin id `redmine_rubylode_progress`, product "Rubylode Progress", namespace `RubylodeProgress`, settings
  `plugin_redmine_rubylode_progress`.
- Project page `/projects/:id/progress` (tab "Progress"); cross-project page `/progress`.
- Project module "Rubylode Progress" (`:rubylode_progress`); one permission `view_rubylode_progress`, "View progress".
- Locale prefix `rubylode_progress`, CSS prefix `rubylode-progress-`, properties `--rubylode-progress-*`, stylesheet
  `rubylode_progress.css`, script `progress_filters.js`.
- Tests are Minitest with Redmine's test helper and fixtures. Never RSpec.
- GPL v2 header on every Ruby file, first line `# Rubylode Progress: a progress page for Redmine projects`.
- Descriptive names without abbreviations (`next_issue_limit`, not `next_lim`; `viewer_group_ids`, not `gids`).
- ERB views, plain CSS, no build step, no client framework, no Turbo. One migration.
- Nothing from `.claude/reference/` in a commit: no names, tickets, dates, copy or screenshots.
- `.claude/` is git-ignored before the first commit (already in `.gitignore`; slice 1 checks it).
- Visibility only through `Issue.visible`, `Project.visible`, `Journal.visible` and the plugin's permission.

## Review Focus

Five ways this can hurt a user that the obvious tests would miss. Each owning slice carries the named test.

1. A version shared from another project whose issues the viewer cannot see: slice 4, "a version shared from another
   project counts only this project's visible issues".
2. A closed version that still holds open issues: slice 2, "a closed version with open issues is a partial stage and
   counts its closed share" (changed by the owner on 2026-11-18; it used to count 1). Slice 5 adds "the open issues of a closed version still show under Open".
3. An issue assigned to a group: slice 5, "an issue assigned to a group the viewer is in shows as Needs you and counts
   in the tile".
4. A private journal note: slice 5, "a private note is never the item note for a viewer without View private notes".
5. A remembered filter that no longer applies: slice 6, "a remembered filter that no longer exists falls back to Open".

Also covered by their slices: an "own issues only" role (9), a project with versions but no issues (2), a status listed
as both in progress and waiting (3), a deleted project's settings row (7), a theme that restyles `#content` (10).

## Redmine 7 facts relied on (read from the 7.0.2 image's source, not run)

- `config/importmap.rb` pins `@hotwired/stimulus` and `pin_all_from "app/javascript/controllers", under:
  "controllers"`; `controllers/application.js` exports the started `application`. The layout prints
  `javascript_importmap_tags` before `yield :header_tags`. `lib/redmine/plugin.rb` has no importmap support.
- So a plugin's module script, loaded with `type: "module"` in `content_for :header_tags`, can
  `import { application } from "controllers/application"` and call `application.register`. Rubylode To-do ships
  exactly this on 7.0.2. Slice 6 confirms it first and names the fallback.
- No "Manage project" permission exists; Redmine's settings tabs use `:edit_project` ("Edit project").
- `Journal.visible(user)` applies private-note rules; `Issue#blocked?` reads `relations_to` and each `issue_from`.
- Subprojects are destroyed through `destroy`, so `dependent: :delete` on `Project` reaches their settings rows.
