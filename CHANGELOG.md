# Changelog

All notable changes to this plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Focus on one stage: click a stage's name in the stage list, or its mark on the track, and the page lists only that stage and its issues, with the stage's own name, percent and closed count at the top. The address is the view, `/projects/:id/progress/stages/:version_id` (filter, grouping and selects follow as the query; the older `?stage=<id>` still works, and the path wins when both are given), so it can be shared; the other stages stay on the track, dimmed, as links, and "Show all stages" leaves the focus.

### Changed

- The stage name in the stage list is now a link to the focused page; the chevron folds the stage, as before.

## [1.1.1] - 2026-11-20

No migration: replace the folder and restart Redmine.

### Fixed

- The three number fields in the settings (How many issues are Next, Finished stages kept in the list, Issues listed per checklist section) are wide enough to show their "Use the default" hint, and the date next to a version in the tick list stays on its line.
- On a phone the three filter selects (assignee, tracker, category) fit the column instead of running past the edge of the panel.

## [1.1.0] - 2026-11-19

For projects with many stages and many issues. Two migrations add the new settings: after replacing the folder run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production` and restart Redmine.

### Added

- Finished stages fold into one row of the stage list ("38 finished stages", with their combined meter and the issues closed), keeping the last few unfolded. How many is a setting, per project with a plugin-wide default.
- The top track draws the folded stages as one summary mark and, with more than 12 stages, labels only the current stage and its neighbours, so the labels no longer overlap.
- A list of versions in the project's Progress settings, each ticked by default: untick one and it is not a stage and its issues are not counted.
- Each checklist section lists its first 10 issues and a "Show more" link for the rest. The rest is not in the first response, so a busy page loads far lighter; without JavaScript the link reloads the page with that section in full. The number is a setting, per project with a plugin-wide default.
- Three selects above the checklist narrow it by assignee, tracker or category. They offer only values the viewer can see, change the pill counts with the list, and are carried into "Open as issue query".
- Long issue notes are cut at two lines with a "show note" link, and the Behind notice names at most three stages.
- A folded stage in the stage list renders its summary only and loads its issues when it is opened, from `GET /projects/:id/progress/stages/:version_id/issues` (the stage's issues as the viewer may see them); the closed issues inside a current or behind stage load the same way, from `.../closed_issues`, when its closed fold is opened. Without JavaScript its "Show the N issues" link reloads the page with `?open_stage=<id>`. A busy project's page is a fraction of its size and no longer grows with the issues in folded stages.
- With more than 8 checklist sections only the first 5 list their rows; the others keep their title, counts and meter and load their first rows when opened, through the checklist route with `open=<section key>`. Without JavaScript their "Show the N issues" link reloads the page with `?open=<key>` (several keys, comma separated, at most 10). The checklist is now light under every filter, however many versions the project has.
- A layout for a phone for the folded row, the summary mark, the selects and "Show more".

### Fixed

- The page wrapper's layout no longer applies to the menu links Redmine gives the same class.

## [1.0.0] - 2026-11-19

First release. Needs Redmine 7.0 or newer.

### Added

- A Progress tab on every project that has the module "Rubylode Progress" enabled, at `/projects/:id/progress`, behind the permission "View progress". It shows the project's versions as stages on a track, with the current stage, the percent done and the issues of each stage.
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

[1.1.1]: https://github.com/rubylode/redmine-rubylode-progress/releases/tag/v1.1.1
[1.1.0]: https://github.com/rubylode/redmine-rubylode-progress/releases/tag/v1.1.0
[1.0.0]: https://github.com/rubylode/redmine-rubylode-progress/releases/tag/v1.0.0
