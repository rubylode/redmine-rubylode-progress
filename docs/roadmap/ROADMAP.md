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
3. The project page and its filters: ~~`05-project-page.md`~~ done 2026-11-18 (86d9bef), ~~`06-filters.md`~~ done 2026-11-18 (8aa9a93); then the quick-edit pencil and the
   new-issue plus: ~~`13-edit-and-add-modals.md`~~ done 2026-11-19 (af90140).
4. Settings, plugin-wide and per project: ~~`07-settings.md`~~ done 2026-11-18 (6ea5ea4).
5. The cross-project page at `/progress`: ~~`08-all-projects-page.md`~~ done 2026-11-18 (0e6b5d7).
6. Query count and the per-viewer rail cache, then the look and accessibility: ~~`09-performance.md`~~ done 2026-11-18 (ce8b166, 8bed01e),
   ~~`10-look-and-accessibility.md`~~ done 2026-11-18 (0dec454).
7. Demo data and `bin/demo`: ~~`11-demo.md`~~ done 2026-11-19 (b08a875).
8. The owner's revisions after the first demo: ~~`14-owner-revisions.md`~~ done 2026-11-19 (4dcdd5d).
9. The design review of the demo (full width, tracker rail, filter pills in the checklist, "issue" not "step"):
   ~~`15-design-review.md`~~ done 2026-11-19 (0141ac4).
10. Drag an issue to another stage, and a Target version field in quick edit: ~~`16-drag-to-move.md`~~ done 2026-11-19 (016de72).
11. The second pass after the demo review (button colour, marks, names, dates, top block, why a drop is refused):
   ~~`17-second-pass.md`~~ done 2026-11-19 (94b921b).
12. Change a version's status from the page: ~~`18-version-status.md`~~ done 2026-11-19 (661141b).
13. ~~Screenshots, README, CHANGELOG, the redmine.org listing text, then release v1.0.0 with `/rubylode:prepare-release`
   through the Gitea origin: `12-release.md`.~~ done 2026-11-19: v1.0.0 (0c8c2f2) is on GitHub and listed at
   https://www.redmine.org/plugins/redmine_rubylode_progress.
   - ~~Private Gitea origin and the public GitHub repository~~ done 2026-11-18: Gitea main publishes to
     `rubylode/redmine-rubylode-progress`, seeded once by hand.
14. Busy projects, many stages and many issues: ~~`19-busy-projects.md`~~ done 2026-11-19 (e6aa972), for 1.1.0.
15. Load a stage's issues when it is opened: ~~`20-lazy-stages.md`~~ done 2026-11-19 (e7b07cb), for 1.1.0.
16. Load a checklist section's rows when it is opened: ~~`21-lazy-sections.md`~~ done 2026-11-19 (fa4c3b7), for 1.1.0.
17. ~~Release 1.1.0~~ done 2026-11-20: v1.1.0 (45f5924) is on GitHub and on redmine.org (the same zip, sha256 checked).
    The settings number fields and the phone selects were fixed after the tag (74f64fb), for 1.1.1.
18. Focus on one stage: ~~`22-focus-on-a-stage.md`~~ (spec `docs/specs/2026-11-20-focus-on-a-stage-design.md`) done 2026-11-20, for 1.2.0.
19. ~~Release 1.2.0~~ done 2026-11-20: v1.2.0 (37a367f) is on GitHub and on redmine.org (the same zip, sha256 checked).

## Ideas

- A Progress block on the project Overview and on My page.
- A "Needs you" count per project on the cross-project page.
- A checklist on the cross-project page, folded per project.
- Translations beyond English.
