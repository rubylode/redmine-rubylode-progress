# 18. Change a version's status from the page

Blocked by slice 17. Raised by the owner on 2026-11-19 while trying the demo; blocks slice 12 (its README, changelog and
screenshots must mention it).

## Done means

A viewer who may manage the versions of a stage's project can click the status tag in a stage's summary (open, locked,
closed) and change the version's status from the Progress page, without opening the Roadmap or the project settings. The
change is Redmine's own version update, so Redmine's permission and rules decide. Reopening a closed stage is what makes
it accept dragged issues again.

## Steps

1. **The tag as a control.** In the stage list, the status tag of a stage becomes a button for a viewer who may manage
   versions in the version's own project (`manage_versions`, which for a version shared from another project means that
   project). It shows on every such stage, open ones included ("open", "locked", "closed"), with a small caret and a
   `title` saying what it does ("Change the status of Framing"). Every other viewer sees what slice 17 shows: a plain
   tag on closed and locked stages, nothing on open ones. Keyboard focusable, `aria-label` with the version name and its
   current status, 44px target on touch screens.
2. **Routes and the modal.** `GET progress/versions/:version_id/status` answers HTML (a plain page for a no-JavaScript
   click) and JS (fills `#ajax-modal`, `showModal`, closes on an outside click, as the other modals do). The version must
   be one of this page's stages and the viewer must hold `manage_versions` on its project, otherwise 403 (404 for a
   version that is not a stage). The modal shows the version name and a choice of the three statuses (radio buttons, the
   current one selected, each with one line saying what it means: open takes new issues; locked takes no new issues but
   its issues stay editable; closed is finished and takes no new issues).
3. **The save goes to Redmine.** The form is `PUT /versions/:id` with `version[status]` and a `back_url` built on the
   server to the Progress page with the current filter and grouping. The plugin adds no second write path. Redmine's
   answer is shown the way it is for the other modals (its own flash after the redirect).
4. **Cache.** The status tag changes with the viewer's right to manage versions, and the stage fragment is cached per
   viewer. Add the right (per stage, true or false) to `StageCacheKey`; the version status is already in it.
5. **Words and look.** Locale keys for the three statuses and their one-line meanings; the tag button uses the existing
   tag look with a caret, in theme properties only (no new colour unless contrast demands one).

## Tests, in order

1. Integration: "the status tag is a button only for a viewer who may manage the version's project; others see a plain
   tag on closed and locked stages and nothing on open ones".
2. Integration: "the status modal answers for a stage and refuses a viewer without manage_versions (403) and a version
   that is not a stage (404)".
3. Integration: "the modal offers the three statuses with the current one selected and posts to Redmine's version
   update with a back_url to the Progress page".
4. Integration: "after Redmine's update the stage shows its new status, and a reopened stage becomes a drop target".
5. Unit: the stage cache key changes with the manage-versions right.
6. Stylesheet test for the new class; rail cache and query-count tests stay green (re-check the ceiling; compute the
   right once per project, not per stage).

## Not in this slice

Editing a version's name, dates or description; creating or deleting versions; changing the status of several versions
at once.
