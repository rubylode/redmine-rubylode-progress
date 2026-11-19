# Roadmap

## Goal

Show where a project's work stands inside Redmine, like a parcel tracker: how far along it is, which stage is current,
what is next and what waits on me, for one project and across projects, always from Redmine's own data and only what
the viewer may see.

## Next

1. ~~Write the implementation plan from `docs/specs/2026-11-18-progress-page-design.md` into `docs/plans/`~~ done
   2026-11-18 (plan written): `docs/plans/progress-page/`, modelled on Rubylode Projects 2.1.0 and Rubylode Beszel.
2. Skeleton and the rules as plain Ruby objects, test first: `01-skeleton.md` through `04-issue-scope.md`.
   - ~~`01-skeleton.md`~~ done 2026-11-18 (33e450d).
   - ~~`02-stages-and-percent.md`~~ done 2026-11-18 (031234b, then bbff6d0: partial stages count their closed share).
   - ~~Rename to **Rubylode Progress** before slice 03 (owner's decision, 2026-11-18): plugin id
     `redmine_rubylode_progress`, namespace, prefixes, docs, and the Gitea and GitHub repositories.~~ done 2026-11-18;
     the local data volumes were carried over.
   - ~~`03-item-status.md`~~ done 2026-11-18 (84717b6).
   - ~~`04-issue-scope.md`~~ done 2026-11-18 (a705062; versions with nothing visible of ours never become stages).
3. The project page and its filters: ~~`05-project-page.md`~~ done 2026-11-18 (86d9bef; the done-row closed date still
   needs a test once the All filter exists), `06-filters.md`; then the quick-edit pencil and the
   new-issue plus: `13-edit-and-add-modals.md`.
4. Settings, plugin-wide and per project: `07-settings.md`.
5. The cross-project page at `/progress`: `08-all-projects-page.md`.
6. Query count and the per-viewer rail cache, then the look and accessibility: `09-performance.md`,
   `10-look-and-accessibility.md`.
7. Demo data and `bin/demo`: `11-demo.md`.
8. Screenshots, README, CHANGELOG, the redmine.org listing text, then release v1.0.0 with `/rubylode:prepare-release`
   through the Gitea origin: `12-release.md`.
   - ~~Private Gitea origin and the public GitHub repository~~ done 2026-11-18: Gitea main publishes to
     `rubylode/redmine-rubylode-progress`, seeded once by hand.

## Ideas

- A Progress block on the project Overview and on My page.
- A "Needs you" count per project on the cross-project page.
- A checklist on the cross-project page, folded per project.
- Translations beyond English.
