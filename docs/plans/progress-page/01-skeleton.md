# 1. Skeleton: module, permission and an empty Progress tab

Blocked by nothing.

## Done means

A member whose role has "View progress" in a project with the module "Rubylode Progress" enabled opens
`/projects/:id/progress` and sees the tab "Progress" selected and the project name; a non-member gets 403; `bin/test`
runs in Docker and CI runs Redmine 7.0.2 and 7.0-stable on Ruby 3.4 and 4.0.

## Steps

1. Check `.gitignore` holds `.claude/` before the first commit (it does today); add `tmp/` and `node_modules/`.
2. Copy from Rubylode Projects, renamed: `LICENSE`, `.gitattributes`, `bin/test`, `docker/test.Dockerfile`
   (`FROM redmine:7.0.2`), the `test` service of `docker-compose.yml`, `test/test_helper.rb`,
   `.github/workflows/tests.yml` (matrix from Rubylode To-do: 7.0.2 and 7.0-stable on 3.4 and 4.0) and
   `.github/dependabot.yml`. A project instructions file modelled on Projects', naming the reference as private.
3. `init.rb`: `Redmine::Plugin.register :redmine_rubylode_progress`, name "Rubylode Progress", author "Rubylode",
   `version "0.1.0"`, `requires_redmine version_or_higher: "7.0.0"`, then:
   - `project_module :rubylode_progress do permission :view_rubylode_progress, { rubylode_progress: [:show,
     :checklist] }, read: true end`
   - `menu :project_menu, :rubylode_progress, { controller: "rubylode_progress", action: "show" }, caption:
     :label_rubylode_progress, after: :roadmap, param: :id`
4. `config/routes.rb`: `get "projects/:id/progress", to: "rubylode_progress#show", as:
   "project_rubylode_progress"` and `get "projects/:id/progress/checklist", to:
   "rubylode_progress#checklist"` (the action arrives in slice 6).
5. `app/controllers/rubylode_progress_controller.rb`: `menu_item :rubylode_progress`, `before_action
   :find_project, :authorize`, `#show` renders the project name only.
6. `config/locales/en.yml`: `project_module_rubylode_progress: Rubylode Progress`, `permission_view_rubylode_progress:
   View progress`, `label_rubylode_progress: Progress`, then a `rubylode_progress:` block for the rest.

## Tests, in order

1. `test/unit/plugin_registered_test.rb`, "the plugin is registered for Redmine 7.0 and newer": id, name, the module
   `:rubylode_progress` and the permission `:view_rubylode_progress`, read only.
2. `test/integration/progress_tab_test.rb` (fixtures `projects`, `members`, `member_roles`, `roles`,
   `enabled_modules`, `users`), "a member with View progress sees the tab": 200, `#main-menu a.selected` reads
   "Progress", `h2` holds the project name.
3. "a signed-in non-member of a private project gets 403".
4. "with the module disabled the tab is gone and the page answers 403".
5. "an anonymous visitor follows Redmine's rules": public project, anonymous role without the permission, redirected to
   sign in; with the permission granted to Anonymous, 200.

## Not in this slice

Settings (4, 7), the page's content (5), the cross-project page (8), the stylesheet (10).
