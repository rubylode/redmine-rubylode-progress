# 13. Quick edit and new issue in a stage

Blocked by slice 5 (the page and its step and row partials). Added by the owner on 2026-11-18. Design: "Editing from the
page" in the spec.

## Done means

A viewer who may edit an issue sees a pencil after its step and its checklist row; it opens Redmine's modal with status,
assignee, % done and a note, and Save lands back on the Progress page with the change shown. A viewer who may add issues
sees a plus on each open stage; it opens a modal that files a new issue into that version and lands back on the page.
Neither shows for a viewer without the permission, and both work as plain links without JavaScript.

## Steps

1. Routes under the project: `GET progress/issues/:issue_id/quick_edit` and `GET progress/versions/:version_id/new_issue`,
   answering both HTML (a plain page for the no-JavaScript link) and JS (fills `#ajax-modal` and calls
   `showModal('ajax-modal', '600px')`, the way Redmine's own `issue_categories/new.js.erb` does).
2. The forms post to Redmine itself, not to the plugin: `PATCH /issues/:id` and `POST /projects/:id/issues`, each with a
   `back_url` to `/projects/:id/progress` plus the current filter. Redmine's `IssuesController#update` and
   `redirect_after_create` both honour `back_url` (read in 7.0.2).
3. Fields: only `issue.safe_attribute?` ones; statuses from `issue.new_statuses_allowed_to(User.current)`; assignees from
   `issue.assignable_users`. New issue: trackers from `project.trackers` the viewer may add, version fixed and hidden.
4. When the new issue would need a required custom field the modal does not show, the plus links to
   `new_project_issue_path(project, issue: { fixed_version_id:, subject: })` with the same `back_url` instead.
5. Icons: `sprite_icon('edit')` and `sprite_icon('add')`, `icon-only`, with a title and an `aria-label`.

## Tests, in order

1. Integration: "the pencil shows only for a viewer who may edit the issue".
2. Integration: "quick edit offers only the statuses the workflow allows this viewer".
3. Integration: "saving a quick edit returns to the Progress page with the same filter" (through Redmine's update).
4. Integration: "the plus shows only on open stages and only for a viewer who may add issues".
5. Integration: "a new issue from a stage lands in that version and returns to the Progress page".
6. Integration: "a required custom field sends the plus to Redmine's full new-issue form".
7. Integration: "a viewer without the plugin's permission cannot open either modal" (403).

## Not in this slice

Inline editing in the row itself, drag and drop between stages, bulk edit.
