# 3. Derived item status and the Next limit

Blocked by slice 1 (test setup only; no database in these tests).

## Done means

`ItemStatusRule` gives every issue exactly one of `:done`, `:needs_you`, `:waiting`, `:next`, `:to_do`, first match
wins in the design's order, and `NextLimit` picks the current stage's first open issues in the design's order.

## Steps

1. `app/models/rubylode_progress/item_status_rule.rb`: `ItemStatusRule::STATUSES = %i[done needs_you waiting next
   to_do].freeze`; `ItemStatusRule.new(viewer_id:, viewer_group_ids:, in_progress_status_ids:, waiting_status_ids:,
   next_issue_ids:)`, `#status_for(issue)`. Issues answer `closed?`, `assigned_to_id`, `status_id`, `blocked?`.
   - Done: `closed?`.
   - Needs you: `assigned_to_id` is `viewer_id` or in `viewer_group_ids`. An anonymous viewer passes `viewer_id: nil`
     and `viewer_group_ids: []`, so nothing needs them.
   - Waiting: `blocked?` (Redmine's own: blocked by an open issue) or `status_id` in `waiting_status_ids`.
   - Next: `status_id` in `in_progress_status_ids`, or `id` in `next_issue_ids`.
   - To do: the rest.
2. `app/models/rubylode_progress/next_limit.rb`: `NextLimit.issue_ids_for(current_stage_issues, limit:,
   status_rule_without_next:)` returns an Array of ids. Plan's call: the candidates are the current stage's open issues
   that no earlier rule claims (not Needs you, not Waiting) and that are not already Next by an in-progress status, so
   "the first 3 remaining" are 3 more issues the team can pick up. Order:

       candidates.sort_by { |issue| [-issue.priority_position, issue.due_date ? 0 : 1, issue.due_date || Date.new, issue.id] }.first(limit)

   Issues answer `priority_position` (`issue.priority.position`; higher is more urgent in Redmine) and `due_date`.
   `status_rule_without_next` is the same `ItemStatusRule` built with `next_issue_ids: []`.
3. A limit of 0 gives no ids; no current stage gives no ids.

## Tests, in order (`test/unit/item_status_rule_test.rb`, `test/unit/next_limit_test.rb`, plain structs)

1. "a closed issue is Done even when assigned to the viewer and blocked".
2. "an open issue assigned to the viewer Needs you even when blocked".
3. "an open issue assigned to a group the viewer is in Needs you" (`viewer_group_ids: [10]`, `assigned_to_id: 10`).
4. "an anonymous viewer never sees Needs you".
5. "a blocked issue is Waiting even when its status is in progress".
6. "a status listed as both in progress and waiting gives Waiting".
7. "an issue in a waiting status is Waiting".
8. "an issue in an in-progress status is Next in any stage, not only the current one".
9. "an issue picked by the Next limit is Next; any other open issue is To do".
10. "the Next limit takes 3 by priority, then due date with none last, then issue number": five open issues, priorities
    High (two, due 5 and 9 days out), Normal (two, one due, one without), Low; picks the two Highs then the Normal with a
    date.
11. "issues that Need you, Wait or are in progress do not use up the limit".
12. "a limit of 5 takes 5; a limit of 0 takes none; no current stage takes none".

## Not in this slice

Loading groups, relations and priorities (4), the settings that hold the lists and the limit (4, 7).
