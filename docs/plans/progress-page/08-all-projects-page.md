# 8. The cross-project page

Blocked by slice 4.

## Done means

`/progress` lists, ordered by name, one compact tracker per project the viewer may see with the module enabled and
"View progress": the name linking to its tab, the bar with its dots, the percent and the current stage's name. The top
menu shows "Progress" only to people with at least one such project.

## Steps

1. Route `get "progress", to: "rubylode_progress_all_projects#index", as: "rubylode_progress_all_projects"`.
   Plan's call: the design's path and link are kept as written (`/progress`, top menu "Progress"); no Redmine route
   takes `/progress`.
2. `app/models/rubylode_progress/all_projects.rb`: `AllProjects.projects_for(viewer)`:
   `Project.visible(viewer).where(Project.allowed_to_condition(viewer, :view_rubylode_progress)).order(:name)`;
   `AllProjects.any_for?(viewer)` is the same with `exists?`.
3. `app/models/rubylode_progress/project_tracker.rb`: `ProjectTracker = Struct.new(:project, :stages, :current_stage,
   :percent, keyword_init: true)` (not `Tracker`, which is Redmine's model), built by `ProjectTracker.for(project,
   viewer:)` with that project's `EffectiveSettings`. It uses `IssueScope#versions` and a
   light issue query: `Issue.visible(viewer)` on the same project and version ids, selecting only `id`,
   `fixed_version_id`, `status_id`, with `:status` preloaded for `closed?`; never journals, relations or custom
   values. It feeds `StageList` and `PercentRule` unchanged. A parent's tracker includes its subprojects' issues; each
   subproject listed gets its own tracker.
4. `RubylodeProgressAllProjectsController#index`: no project; `deny_access` when `AllProjects.any_for?` is false
   (anonymous goes to sign in, a signed-in person gets 403). `app/views/rubylode_progress_all_projects/index.html.erb`
   and `app/views/rubylode_progress/_compact_tracker.html.erb` reusing the track markup of slice 5 (extract
   `_track.html.erb` there if not done). Plan's call: no checklist and no Needs you counts, as the design says.
5. `init.rb`: `menu :top_menu, :rubylode_progress, { controller: "rubylode_progress_all_projects", action: "index" },
   caption: :label_rubylode_progress, if: ->(*) { RubylodeProgress::AllProjects.any_for?(User.current) }`.
   The check is one `EXISTS` query per page; accepted.

## Tests, in order

1. Unit `all_projects_test.rb`: "only projects with the module and the permission are listed, by name".
2. Unit `project_tracker_test.rb`: "a tracker gives the same stages and percent as ProjectProgress for that project"
   (the two must never disagree).
3. "a parent's tracker includes its subprojects' issues, and the subproject has its own tracker".
4. Integration `test/integration/all_projects_page_test.rb`: "each tracker links to the project's Progress tab and
   shows the percent and the current stage's name".
5. "a private project the viewer is not a member of is not listed", and "a private issue does not move another
   viewer's percent".
6. "someone with no such project gets 403 and sees no Progress link in the top menu".
7. "a project with the module but no counted versions says nothing to track yet".

## Not in this slice

Query counts across projects (9), the look (10).
