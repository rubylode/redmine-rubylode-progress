# 9. Performance: a fixed number of queries and a rail cached per viewer

Blocked by slices 5 and 8.

## Done means

The project page runs the same number of queries for 5 issues as for 50; the cross-project page runs a fixed number per
project; each stage of the rail is fragment-cached under a key that includes the viewer, so two people with different
visibility never share a rendered stage.

## Steps

1. `test/support/query_counter.rb`: `QueryCounter.count { ... }` counts `sql.active_record` events, leaving out
   `SCHEMA`, `TRANSACTION` and cached ones. Required from `test/test_helper.rb`.
2. Measure the project page with the counter and remove every query that grows with issues (an unpreloaded
   association in a view, `issue.project` for the note's custom field visibility, `closed?` before `:status` is
   loaded). The design's "two or three queries" counts the main loads; the preloads add one query each, so the test
   asserts no growth plus a ceiling: Plan's call, the ceiling is the measured count once fixed, written into the test
   with a comment naming each query.
3. `app/models/rubylode_progress/stage_cache_key.rb`: `StageCacheKey.for(stage:, project:, viewer:, settings:)` returns
   an Array:

       ["rubylode_progress/stage", project.id, viewer.id, stage.version.id, stage.version.updated_on, stage.number,
        stage.state, Digest::SHA256.hexdigest(step_issue_ids.sort.join(",")), newest_step_updated_on,
        settings.cache_digest, I18n.locale]

   Plan's call, beyond the design's key (project, viewer, newest `updated_on`, settings): the version's own
   `updated_on` (a renamed or redated stage), the stage's number and state (another stage's issues can make this one
   current), the visible issue ids (an issue moved out or hidden from this viewer leaves the newest `updated_on`
   unchanged), and the locale.
4. Wrap `_stage.html.erb` in `cache StageCacheKey.for(...)`. Only the rail; the tiles and the checklist render each time.

## Tests, in order

1. Integration `test/integration/query_count_test.rb`: "the project page runs the same number of queries for 5 issues
   as for 50": build both in the test (each with relations, a group assignee and notes), compare counts, and stay under
   the ceiling.
2. "the cross-project page runs the same number of queries per project whatever the issue count".
3. Unit `stage_cache_key_test.rb`: "the key changes with the viewer, an issue update, an issue moved out, the version,
   the stage's state and the settings"; "it does not change on a second identical build".
4. Integration `test/integration/rail_cache_test.rb`, with `ActionController::Base.perform_caching = true` and a
   `ActiveSupport::Cache::MemoryStore` for the test: "two viewers with different visibility get different cached
   rails": viewer A's role sees all issues, viewer B's role has issues visibility "own issues only" (the "own" role
   case); A renders first, then B sees only the steps B authored or is assigned to, and the reverse order too.
5. "closing an issue updates its stage on the next view".

## Not in this slice

A cache for the cross-project page (the design caches only the project page's rail), tuning beyond the counts above.
