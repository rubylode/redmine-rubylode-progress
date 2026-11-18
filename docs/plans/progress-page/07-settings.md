# 7. Plugin settings page, project overrides and the project's Progress settings tab

Blocked by slice 4.

## Done means

Administration > Plugins > Rubylode Progress edits every setting in the design; each project can override any of them
in a "Progress" tab of its Settings, saved by people with Redmine's "Edit project"; an empty override means the
plugin-wide default; the row goes when the project goes.

## Steps

1. `db/migrate/001_create_rubylode_progress_project_settings.rb`, the plugin's one migration: table
   `rubylode_progress_project_settings` with `project_id` (integer, not null, unique index), and Plan's call, one nullable
   column per override rather than a serialized column, so "empty" is `NULL` and each is typed: `counted_versions`
   (string), `version_name_prefix` (string), `checklist_grouping` (string), `in_progress_status_ids` (text, JSON array),
   `waiting_status_ids` (text, JSON array), `next_issue_limit` (integer), `note_source` (string), timestamps.
2. `app/models/rubylode_progress/project_setting.rb`: `ProjectSetting < ActiveRecord::Base`, `self.table_name =
   "rubylode_progress_project_settings"`, `belongs_to :project`, `serialize :in_progress_status_ids, coder: JSON`
   (same for waiting), validations matching `Settings` (choices, limit 0 to 20, prefix up to 60 characters).
   `ProjectSetting.for(project)` finds or builds.
3. `lib/rubylode_progress/project_patch.rb`, included into `Project` once per reload as Projects guards its patches:
   `has_one :rubylode_progress_setting, class_name: "RubylodeProgress::ProjectSetting", dependent: :delete`.
4. `EffectiveSettings.for(project)` now lays the row's non-`NULL` columns over the plugin-wide values; `#cache_digest`
   covers the merged values.
5. Plugin-wide form `app/views/settings/_rubylode_progress_settings.html.erb`: counted versions (All shared versions /
   Names starting with), the prefix, grouping, two status checkbox lists from `IssueStatus.sorted`, the Next limit,
   the note source (Latest note / each issue custom field). Register it with `partial:` in `init.rb`. Help text in
   the voice of Projects' settings page.
6. Project tab: `lib/rubylode_progress/projects_helper_patch.rb` prepended to `ProjectsHelper#project_settings_tabs`,
   adding `{ name: "rubylode_progress", action: :edit_project, module: :rubylode_progress, partial:
   "projects/settings/rubylode_progress", label: :label_rubylode_progress }`; Redmine's own filters then hide it
   without the permission or the module. Each field offers "Use the default (<value>)", stored as `NULL`; the status
   lists take a "Use the default" checkbox.
7. Plan's call: the design's "Manage project" is Redmine's "Edit project" (`:edit_project`); Redmine has no permission
   by the first name. Route `patch "projects/:id/progress/settings", to: "rubylode_progress_project_settings#update"`;
   the controller runs `find_project`, then `deny_access unless User.current.allowed_to?(:edit_project, @project) &&
   @project.module_enabled?(:rubylode_progress)`, saves, and redirects to `settings_project_path(@project, tab:
   "rubylode_progress")` with Redmine's flash.

## Tests, in order

1. Unit `effective_settings_test.rb`: "with no row every value is the plugin-wide one"; "a filled column overrides,
   an empty one falls back"; "an override can choose All versions over a plugin-wide prefix"; "the digest changes
   with any effective value".
2. Unit `project_setting_test.rb`: "an unknown grouping or a limit of 21 is refused".
3. Integration `test/integration/project_settings_tab_test.rb`: "someone with Edit project sees the Progress tab and
   saves an override"; the page then groups by category.
4. "someone with View progress only gets 403 and nothing is saved".
5. "the tab is hidden while the module is disabled".
6. "clearing a field brings back the plugin-wide default".
7. "deleting a project deletes its settings row, and a subproject's with it".
8. Integration `plugin_settings_page_test.rb`: "an administrator saves the plugin-wide settings";
   "a non-administrator cannot open them".

## Not in this slice

Caching on the settings (9; the digest is ready), the demo's settings (11).
