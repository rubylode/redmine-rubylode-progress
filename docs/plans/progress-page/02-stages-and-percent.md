# 2. Stages, the current stage and the percent

Blocked by slice 1 (test setup only; no database in these tests).

## Done means

Given versions and issues (any objects that answer the methods below), `StageList` orders the stages, numbers their
steps, marks each done, partial, current or upcoming, and `PercentRule` gives the design's percent.

## Steps

1. `app/models/rubylode_progress/stage.rb`: `Stage = Struct.new(:version, :number, :steps, :state, keyword_init:
   true)` with `#done?`, `#current?`, `#upcoming?`, `#done_step_count`, `#step_count`, `#empty?`.
   `Step = Struct.new(:issue, :number, keyword_init: true)` with `#done?` (`issue.closed?`); `number` reads `"3.2"`.
2. `app/models/rubylode_progress/stage_list.rb`: `StageList.new(versions:, issues:, in_progress_status_ids:)`, `#stages`,
   `#current_stage`, `#finished_stage_count`, `#stage_count`, `#all_done?`. Versions answer `id`, `name`,
   `effective_date`, `closed?`; issues answer `id`, `fixed_version_id`, `status_id`, `closed?`.
   - Order: effective date, then name (case-insensitive). Plan's call: versions without a date go last, as Redmine's
     `Version#<=>` puts them.
   - Steps: Plan's call: numbered `<stage>.<position>` by issue number within the version, so a step keeps its number
     when its priority changes.
   - Changed by the owner on 2026-11-18: a stage is done when none of its issues is open and its version is closed or
     behind the current stage; with open issues it is partial (`Stage#partial?`, `#open_step_count`). Only open and
     locked versions can be current, so the rule below rejects closed versions rather than done stages.
3. `app/models/rubylode_progress/current_stage_rule.rb`: `CurrentStageRule.pick(stages, in_progress_status_ids:)`:

       not_done = stages.reject { |stage| stage.version.closed? }
       started = not_done.select { |stage| stage.steps.any? { |step| step.done? || in_progress.include?(step.issue.status_id) } }
       started.last || not_done.first

   Plan's call: when every stage is done there is no current stage; slice 5 heads the panel "All 5 stages done".
4. `app/models/rubylode_progress/percent_rule.rb`: `PercentRule.percent_for(stages)` returns an Integer, or `nil` when
   there are no stages. Each stage contributes 1 when done; else its closed share; a current empty stage 0.5; an
   upcoming empty stage 0. Sum divided by the stage count, times 100, `round`.

## Tests, in order (`test/unit/stage_list_test.rb`, `test/unit/percent_rule_test.rb`, plain structs)

1. "stages are ordered by date, then name, undated last".
2. "steps are numbered stage dot position by issue number": issues 30, 12, 21 in stage 3 give `3.1` (12), `3.2`, `3.3`.
3. "the current stage is the furthest open stage with a closed or in-progress issue": stages A done, B open with one
   closed issue, C open with an issue in an in-progress status, D open untouched; C is current.
4. "with no started open stage the first open stage is current".
5. "a locked version is not done and can be current".
6. "no versions: no stages, no current stage, percent nil".
7. "all stages done: no current stage, percent 100".
8. "a current stage without issues counts one half": stages done, current empty, upcoming empty: (1 + 0.5 + 0) / 3
   gives 50.
9. "several open stages count their closed shares": done, 3 of 4 closed, 1 of 4 closed, empty upcoming: 50.
10. "a project with versions but no issues": three open empty versions; the first is current; percent 17.
11. Review Focus 2, "a closed version with open issues is a partial stage and counts its closed share": closed version
    with 1 of 3 issues closed, one open version with 0 of 2; stage 1 partial with 2 open steps, the open version current,
    percent 17.
12. "an open stage left behind the current one counts its closed share": done, open 2 of 3, current 1 of 4 with one in
    progress; states done, partial, current; percent 64.
13. "a closed version whose issues are all closed is done": percent 50 beside an untouched open version.

## Not in this slice

Which versions and issues come in (4), derived statuses (3), anything rendered (5).
