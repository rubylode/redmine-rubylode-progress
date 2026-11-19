# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-11-19

First release. Needs Redmine 7.0 or newer.

### Added

- A Progress tab on every project that has the module "Rubylode Progress" enabled, at `/projects/:id/progress`, behind the permission "View progress". It shows the project's versions as stages on a track, with the current stage, the percent done and the steps of each stage.
- The stage list: every stage with its date, a progress bar and its issues as a compact checklist, folded when finished or still to come. A stage left behind with open issues shows as behind, and a notice names the overdue and the soon due stages.
- A checklist of every issue in the counted versions, with a status pill (Done, Needs you, Waiting, Next, To do), the assignee, the due date and the latest note or a custom field. A "How statuses are decided" box lists the rules in order.
- Filters: Open, Needs you, Overdue, Next up, Done and All. Each is a link that works without JavaScript, and the choice is remembered per person.
- Grouping of the checklist by version, category or parent issue, as the project default or just for you.
- A cross-project page at `/progress`, linked from the top menu, with one compact tracker for each project the viewer can see.
- Plugin-wide settings (Administration, Plugins, Configure) and a Progress tab in each project's Settings that overrides them: which versions count, how the checklist groups, which statuses mean in progress and waiting, how many issues are Next, and where the item note comes from. Anyone who may edit the project can save the project's tab.
- Editing from the page: a pencil for a quick edit of status, assignee, % done and a note, a New issue button on every open stage and above the checklist, and a modal that shows the issue when its title is clicked. All of it saves through Redmine's own issue forms, so permissions, workflow and notifications apply.
- Drag an issue to another open stage to move it. Closed and locked versions refuse it and say why. On a touch screen, the pencil's Target version field does the same.
- Change a version's status from the page: the status tag of a stage is a button for a viewer with "Manage versions" in the version's project, opening a modal to choose open, locked or closed. The save is Redmine's own version update.
- Every number, row and percent follows what the viewer may see.
- Styling through CSS custom properties, with a dark block to paste into a dark theme (`docs/theming.md`), and a layout for a phone.
- A throwaway demo Redmine with made-up projects (`ruby bin/demo up`), the README screenshots from it, and unit and integration tests (`bin/test`).

[1.0.0]: https://github.com/rubylode/redmine-rubylode-progress/releases/tag/v1.0.0
