# Focus on one stage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `?stage=<version id>` narrows the Progress page to one stage: both columns, the top block, the counts and every
fragment route, with links to enter and leave the focus.

**Architecture:** `ProjectProgress` takes an optional `focused_stage_id`; its `items` (and so the pill counts, the selects,
the checklist, the editable set) narrow to that stage while `stages` stays whole, because the tracker rail keeps every
stage. The checklist is grouped `"flat"` (one headingless section) when focused. The page's own checked parameters
(`filter`, `group`, selects, now `stage`) are passed through the existing `rubylode_progress_checklist_params` helper.

**Tech Stack:** Redmine's Rails, ERB, plain CSS, Stimulus modules already in `assets/javascripts`, Minitest (`bin/test`,
`bin/test test/unit/some_test.rb` for one file).

**Spec:** `docs/specs/2026-11-20-focus-on-a-stage-design.md` (owner-approved 2026-11-20). Slice 22, for 1.2.0.

## Global Constraints

- Public code: no private names or data, no AI mention, no trailer or footer in commits; GPL v2 header on every Ruby file.
- Descriptive names, no abbreviations; no client framework, no build step; Minitest only.
- Only what the viewer may see: focus narrows the viewer's visible stages and never reads past them.
- A focus that is not one of the viewer's stages for this project, or is not a plain numeric string, is a 404.
- Focusing never writes the remembered filter or grouping; the cross-project page is unchanged.
- Every user-visible string goes in `config/locales/en.yml` (the locale structure test must stay green).
- Commits end with `refs #<ticket>`; file the ticket on the home tracker first (`bosun redmine`), nothing after the refs line.

## Review Focus

1. `stage[]=1`, `stage=abc`, `stage=` (empty) must not 500: array or non-numeric is 404, empty means no focus.
2. A stage id of another project's version, or any version that is not a stage of the page: 404 (a stage that shows no visible issue still focuses and shows the empty message).
3. Focus plus a filter with no rows (for example Needs you) shows the empty message, not a crash or a missing heading.
4. A focused stage that sits inside the finished-stage fold, and a focused stage when every stage is done (no current
   stage): both render the stage open, with no fold row and no "current stage" assumption.
5. A user's remembered filter and the project's grouping setting are unchanged after visiting with `stage` (and with
   `group=category` in the same request, which focus ignores).

## Files

- Modify `app/models/rubylode_progress/project_progress.rb`: `focused_stage_id:` keyword, `focused_stage`, narrowed `items`.
- Modify `app/models/rubylode_progress/checklist_sections.rb`: grouping `"flat"`.
- Modify `app/controllers/rubylode_progress_controller.rb`: read `stage`, 404, force flat grouping, pass `focused_stage` in locals.
- Modify `app/helpers/rubylode_progress_helper.rb`: `stage:` in `rubylode_progress_checklist_params`; new `rubylode_progress_focus_path`.
- Modify views in `app/views/rubylode_progress/`: `show`, `_tracker_panel`, `_track`, `_stage_list`, `_listed_stage`, `_stage`,
  `_checklist`, `_checklist_section`, `_group_by`, `_filters`, `_narrowing`.
- Modify `assets/stylesheets/rubylode_progress.css`, `config/locales/en.yml`, `README.md`, `CHANGELOG.md`, `docs/roadmap/ROADMAP.md`.
- Tests: `test/unit/project_progress_test.rb`, `test/unit/checklist_sections_test.rb`, new `test/integration/focus_on_a_stage_test.rb`
  (fixtures as in `test/integration/lazy_stages_test.rb`).

---

### Task 1: The focus in the rules (plain Ruby, test first)

**Files:** modify `project_progress.rb`, `checklist_sections.rb`; test the two unit files.

**Interfaces:**
- Produces: `ProjectProgress.new(project:, viewer:, settings:, focused_stage_id: nil)`;
  `ProjectProgress#focused_stage -> Stage | nil` (the stage whose `version.id == focused_stage_id`, nil when no focus);
  `ProjectProgress#focus_requested? -> Boolean` (a focus id was given); `ProjectProgress#items` narrowed to the focused
  stage's items when focused. `ChecklistSections.group(items, by: "flat", ...)` returns one `Section` with
  `key: "all"`, `title: nil`, `version: nil`, over all of `scope_items`.

- [ ] **Step 1: Write failing tests.** In `project_progress_test.rb`: `test_focus_narrows_items_to_the_focused_stage`
  (two stages, focus the second: `items.map { _1.issue.fixed_version_id }.uniq == [second.id]`, `stages.size` still 2);
  `test_focused_stage_is_nil_for_an_id_that_is_not_a_stage` (`focus_requested?` true, `focused_stage` nil);
  `test_no_focus_changes_nothing`. In `checklist_sections_test.rb`: `test_flat_grouping_is_one_section_without_a_title`
  (`sections.size == 1`, `sections.first.key == "all"`, `title` nil, `items` all of them).
- [ ] **Step 2: Run** `bin/test test/unit/project_progress_test.rb test/unit/checklist_sections_test.rb`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement** the signatures above. `items` keeps its memoisation; the narrowing is a `select` on the stage's
  own steps, so `step_number` and status are unchanged. `flat` is a new `when "flat"` branch building one section via the
  existing `section(...)` helper (so counts and percent come out right).
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(progress): focus on one stage in the rules`.

### Task 2: The request: parameter, 404, routes

**Files:** modify the controller, `rubylode_progress_helper.rb`; test `test/integration/focus_on_a_stage_test.rb`.

**Interfaces:**
- Consumes: Task 1.
- Produces: controller `requested_focused_stage_id -> Integer | nil` (nil when `params[:stage]` is absent or `""`; a String of
  digits becomes its Integer; anything else, including an array, is a request for a focus that fails, so the action renders
  404); `checklist_locals` gains `focused_stage:`; helper `rubylode_progress_checklist_params(..., stage: nil)` adds
  `stage:` (compacted when nil); `rubylode_progress_focus_path(project, version, link_parameters)` returning
  `project_rubylode_progress_path(project, **link_parameters, stage: version.id)`.

- [ ] **Step 1: Write failing integration tests** in `focus_on_a_stage_test.rb`:
  `test_stage_param_narrows_both_columns` (GET with `stage=<id>`: only that version's name appears in the stage list and the
  checklist; another stage's issue subject is absent); `test_checklist_route_keeps_the_focus` (GET `/projects/:id/progress/checklist?stage=<id>`
  lists only that stage's issues); `test_unknown_array_and_foreign_stages_are_404` (`stage=999999`, `stage[]=1`, `stage=abc`, a
  version of another project); `test_empty_stage_param_means_no_focus`; `test_focus_does_not_touch_the_remembered_filter_or_grouping`
  (user pref `ChecklistFilter::PREFERENCE_KEY` and the project setting unchanged after a request with `stage` and `group=category`);
  `test_focus_with_a_filter_that_matches_nothing_shows_the_empty_message`.
- [ ] **Step 2: Run** `bin/test test/integration/focus_on_a_stage_test.rb`. Expected: FAIL.
- [ ] **Step 3: Implement.** In `load_progress_and_filter` build `ProjectProgress` with `focused_stage_id:`; add a
  `before_action :require_focus_to_be_a_stage` (after it, for `show` and `checklist` only) that renders 404 when
  `focus_requested?` and `focused_stage` is nil, or when the parameter is malformed. When focused, `@grouping = "flat"` (the
  `group` param is ignored, not remembered). Pass `focused_stage` in `checklist_locals`. Pass the focus in
  `status_grouping_parameters`/`@back_url` so a modal returns to the focused page.
- [ ] **Step 4: Run** the integration file. Expected: PASS (the narrowing tests that read markup for the focus links come in Task 3).
- [ ] **Step 5: Commit** `feat(progress): accept a stage to focus on`.

### Task 3: The two columns when focused

**Files:** modify `show`, `_stage_list`, `_listed_stage`, `_stage`, `_checklist`, `_checklist_section`, `_group_by`, `_filters`,
`_narrowing`; test the integration file.

**Interfaces:**
- Consumes: Task 2's locals and helpers. Every existing call of `rubylode_progress_checklist_params` (grep: 7 in `app`) passes
  `stage: focused_stage&.version&.id`, and the partials that need it receive `focused_stage` as a local.
- Produces: stage name link `a.rubylode-progress-stage__focus-link` (to `rubylode_progress_focus_path`) in each listed stage.

- [ ] **Step 1: Write failing tests:** `test_stage_name_links_to_the_focused_page_keeping_filter_and_selects` (name link `href`
  holds `stage=<id>` and the page's `filter` and `assignee`); `test_focused_stage_list_is_one_open_stage_without_fold_row`
  (a stage that the finished-stage fold would hide renders open when focused, no `.rubylode-progress-finished-fold`);
  `test_focused_checklist_is_flat` (no `.rubylode-progress-section__title`, no `.rubylode-progress-group` control, no
  "by version" text, a single `ul.rubylode-progress-rows`, "Show more" link keeps `stage`); `test_filter_and_narrowing_links_keep_the_focus`
  (pill and select form `checklist_path` contain `stage=<id>`); `test_all_stages_done_and_focused_stage_renders`.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.** In `_stage_list`, when focused render only `focused_stage` through `listed_stage` with
  `open_stage_id` set to it (no fold entries). In `_stage`, move the chevron and the name before the `cache` block and make
  the name the focus link (it carries `link_parameters`, so it cannot sit inside the cached summary, whose key does not
  include them); the cached part keeps the rest in its current order. In `_checklist_section`, when `grouping == "flat"`
  render only the `ul` rows and the "Show more" paragraph, with no `details`/summary. In `_checklist`, hide the group
  control, "by …" text and (kept) the filters and selects. The new-issue button already uses `current_stage`; when focused
  use the focused stage's version.
- [ ] **Step 4: Run** the file plus `bin/test test/integration/lazy_stages_test.rb test/integration/lazy_sections_test.rb`.
  Expected: PASS (the unfocused page is unchanged).
- [ ] **Step 5: Commit** `feat(progress): list only the focused stage and its work`.

### Task 4: The tracker: top block, rail dots, leaving the focus

**Files:** modify `_tracker_panel`, `_track`; test the integration file.

**Interfaces:**
- Consumes: Task 2 locals (`focused_stage`), `link_parameters` built as `_stage_list` builds it.
- Produces: rail dot link `a.rubylode-progress-track__focus-link`; classes `rubylode-progress-track__stage--focused` and
  `--dimmed` on the `li`; link `a.rubylode-progress-tracker__show-all` ("Show all stages") to the page without `stage`.

- [ ] **Step 1: Write failing tests:** `test_top_block_shows_the_focused_stage` (headline is that stage's name, percent is
  `rubylode_progress_stage_percent(stage)`, closed-of-total counts only that stage's issues, position reads that stage's
  number); `test_rail_keeps_every_stage_dims_the_others_and_links_each` (one `li` per stage, exactly one `--focused`, the
  rest `--dimmed`, every dot links with `stage=`); `test_show_all_stages_keeps_filter_grouping_and_selects_and_drops_stage`;
  `test_dragging_targets_survive` (every stage's drop target markup is still present in the focused page);
  `test_unfocused_page_has_no_focus_classes_or_show_all`.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement.** `_tracker_panel`: when focused, headline, description, position and percent come from the
  focused stage; notices are `StageNotices.for([focused_stage], ...)`. `_track`: wrap the mark (and the label name when labelled)
  in the focus link with an accessible label naming the stage; add the two state classes; the summary mark of the fold (more
  than 12 stages) stays as it is. Add "Show all stages" in the tracker's main block when focused.
- [ ] **Step 4: Run** the file and `bin/test test/integration/look_and_accessibility_test.rb`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(progress): keep the rail in focus and show the stage's own progress`.

### Task 5: Look, words, docs

**Files:** `rubylode_progress.css`, `en.yml`, `README.md`, `CHANGELOG.md`, `docs/roadmap/ROADMAP.md`; tests `stylesheet_test.rb`,
`locale_structure_test.rb`, `changelog_test.rb` stay green.

- [ ] **Step 1:** Add the locale keys the views use (`focus.link_label`, `focus.show_all`, `focus.stage_position`,
  and any aria labels), under `rubylode_progress:` in `en.yml`.
- [ ] **Step 2:** CSS: `.rubylode-progress-stage__focus-link` (looks like the existing stage name, underline on hover/focus),
  `.rubylode-progress-track__stage--dimmed` (reduced opacity, still pointer-clickable, restored on hover/focus),
  `--focused` (marked by the existing current-stage emphasis, plus a visible outline for keyboard focus),
  `.rubylode-progress-tracker__show-all`. Use only existing colour variables.
- [ ] **Step 3:** README: a line under the Progress page features ("Click a stage to focus on it; the address is the view").
  CHANGELOG `[Unreleased]`: "Added: focus on one stage". ROADMAP: item 18, "Focus on one stage: `22-focus-on-a-stage.md`", for 1.2.0.
- [ ] **Step 4: Run the whole suite** `bin/test`. Expected: all green; report the count.
- [ ] **Step 5: Commit** `docs(progress): focus on a stage`.

## Out of scope (spec)

Keyboard shortcuts, remembering the last focused stage, focusing several stages, the cross-project page.
