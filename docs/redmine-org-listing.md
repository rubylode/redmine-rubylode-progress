# Listing on www.redmine.org

The text to paste at www.redmine.org, Plugins, New plugin. Redmine's "Check for updates" asks that directory about every installed plugin, so the listing must carry the same name, author and version as the plugin.

| Field | Value |
|---|---|
| Name | Rubylode Progress |
| Short description | A Progress tab for each project: the versions as stages on a track, the current stage, the percent done and a filtered checklist; a page for all projects; quick edit, drag to another stage and a version's status from the page |
| Homepage | https://github.com/rubylode/redmine-rubylode-progress |
| Compatible with | Redmine 7.0.x |
| License | GNU General Public License, version 2 or (at your option) any later version |
| Author | Rubylode |

## Notes for this version

Version 1.1.0, for projects with many stages and many issues: finished stages fold into one row, the track gets a summary mark, versions can be ticked off in the project's settings, long checklists list a few issues per section, and folded stages and sections load when opened. It keeps everything from 1.0.0: a Progress tab for each project with the versions as stages on a track, the current stage, the percent done and a checklist with filters (Open, Needs you, Overdue, Next up, Done, All); a page for all projects; quick edit, new issue, drag to another stage and changing a version's status from the page; settings for the whole site and for each project. Needs Redmine 7.0 or newer. There are two new migrations: run the migrate command when you upgrade. Install and settings are described in the README at https://github.com/rubylode/redmine-rubylode-progress.

## File to upload

`redmine_rubylode_progress-1.1.0.zip`, the file the GitHub release workflow publishes when a `v1.1.0` tag is pushed. Upload the same file that is attached to the GitHub release.

## Checking the result

The name, author and version in the listing must match what the plugin registers (`Rubylode Progress`, `Rubylode`, `1.1.0`). When they do, Administration, Plugins, Check for updates shows:

- a green tick: the installed version is the latest one listed on redmine.org;
- an amber warning: redmine.org lists a newer version than the installed one;
- a grey question mark: the plugin is not found, so the name or the listing needs a look.

The answer comes only from the redmine.org directory. Nothing in the plugin can change it, and it stays grey until the listing exists.
