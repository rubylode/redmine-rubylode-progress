# 4. The issue scope, plugin-wide settings and ProjectProgress

Blocked by slices 2 and 3.

## Done means

For a project and a viewer, `ProjectProgress` holds the stages, current stage, percent and every counted issue with its
derived status, all from one scope, so the rail, percent, tiles and checklist always agree; nothing the viewer may not
see is in it.

## Steps

1. `app/models/rubylode_progress/settings.rb`, the plugin-wide hash as Rubylode Projects' `Settings` reads it (unusable
   values fall back to the default on read). `DEFAULTS`: `"counted_versions" => "all"` (or `"prefix"`),
   `"version_name_prefix" => ""`, `"checklist_grouping" => "version"` (`category`, `parent`),
   `"in_progress_status_ids" => []`, `"waiting_status_ids" => []`, `"next_issue_limit" => "3"` (0 to 20),
   `"note_source" => "latest_note"` (or `"custom_field_<id>"`). Register it with `settings default:
   RubylodeProgress::Settings::DEFAULTS` in `init.rb` (the form comes in slice 7).
2. `app/models/rubylode_progress/effective_settings.rb`: `EffectiveSettings.for(project)` returns a frozen value with
   readers for each key (`#counted_versions`, `#version_name_prefix`, `#checklist_grouping`, `#in_progress_status_ids`,
   `#waiting_status_ids`, `#next_issue_limit`, `#note_custom_field_id`) and `#cache_digest`. This slice reads the
   plugin-wide values only; slice 7 lays the project's row over them.
3. `app/models/rubylode_progress/issue_scope.rb`: `IssueScope.new(project:, viewer:, settings:)`:
   - `#versions`: Plan's call, as Redmine's Roadmap with subprojects on: `project.shared_versions` plus
     `project.rolled_up_versions.visible(viewer)`, unique, then the prefix filter when `counted_versions == "prefix"`. Then (owner's ruling, 2026-11-18) a version is
     kept only when it holds a visible issue of this project or its subprojects, or belongs to this project's tree in a
     project where the viewer may view issues: a version shared in from elsewhere with nothing of ours (Roadmap drops
     it too) and a version a hidden private subproject shares up (Roadmap would show its name) never become stages.
   - `#issues`: `Issue.visible(viewer).where(project_id: project.self_and_descendants.select(:id), fixed_version_id:
     version ids)`, preloading `:status`, `:priority`, `:assigned_to`, `:category`, `:parent`,
     `relations_to: { issue_from: :status }`, `:fixed_version`.
   - `#viewer_group_ids`: `viewer.logged? ? viewer.group_ids : []`.
4. `app/models/rubylode_progress/project_progress.rb`: `ProjectProgress.new(project:, viewer:, settings:
   EffectiveSettings.for(project))` with `#stage_list`, `#stages`, `#current_stage`, `#percent`, `#items`,
   `#status_for(issue)`, `#last_change_on` (newest `updated_on` of all counted issues; Plan's call: the whole scope, so
   it does not move with the filter). `Item = Struct.new(:issue, :status, :step_number, keyword_init: true)`. It builds
   the `ItemStatusRule` once without Next, takes `NextLimit` ids for the current stage, then the final rule.

## Tests, in order (`test/unit/issue_scope_test.rb`, `test/unit/project_progress_test.rb`, Redmine fixtures)

1. "issues without a version never appear".
2. "issues of subprojects roll up into the parent": an issue of a subproject in a version shared with the parent counts.
3. "a private issue stays out for a viewer who may not see it and in for one who may": counts, percent and items differ.
4. "a subproject the viewer may not see adds nothing".
5. "with the prefix setting only versions starting with it count, and their issues only".
6. Review Focus 1, "a version shared from another project counts only this project's visible issues": a system-shared
   version holding two issues of another project the viewer cannot see and one of this project; the stage has one step
   and the percent ignores the other two.
7. "an issue assigned to the viewer's group is Needs you through ProjectProgress" (group fixture, `groups_users`).
8. "a blocked issue is Waiting while its blocker is open and not after it closes".
9. "the stages, the percent and the items come from the same issues": the sum of step counts equals the item count.

## Not in this slice

The project's override row (7), rendering (5), the item note (5), queries counted (9).
