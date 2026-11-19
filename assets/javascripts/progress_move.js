/* Rubylode Progress: drag an issue onto another stage to move it.
 * Copyright (C) 2026  Nick Gorbikoff. GPL v2 or later, as the rest of the plugin.
 *
 * A Stimulus controller, registered on the application that Redmine 7 starts, using the browser's own drag and drop.
 * The server puts draggable="true", data-issue-id, data-current-version-id and data-update-path on the rows the viewer
 * may edit, and data-version-id on the stages and checklist sections that accept issues; this script only reads them.
 * A drop sends one request to Redmine's own issue update, which decides permissions, workflow and version rules. The
 * page reloads on success; on failure nothing moves and Redmine's answer is shown. Without this file, or on a touch
 * screen, the pencil's quick-edit form has a Target version field that does the same.
 */
import { Controller } from "@hotwired/stimulus"
import { application } from "controllers/application"

const DROP_TARGET_SELECTOR = "[data-version-id]"
const DRAGGED_CLASS = "rubylode-progress-dragged"
const DROP_OVER_CLASS = "rubylode-progress-drop-over"

class ProgressMoveController extends Controller {
  static targets = ["message"]
  static values = { refusedMessage: String, failedMessage: String }

  start(event) {
    const row = event.target.closest ? event.target.closest("[draggable='true'][data-issue-id]") : null
    if (!row) {
      console.error("Rubylode Progress move: dragstart ignored, no draggable issue row around", event.target)
      return
    }

    this.draggedRow = row
    row.classList.add(DRAGGED_CLASS)
    this.hideMessage()
    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", row.dataset.issueId)
    }
  }

  finish() {
    if (this.draggedRow) { this.draggedRow.classList.remove(DRAGGED_CLASS) }
    this.draggedRow = null
    this.clearHighlights()
  }

  // Firefox accepts a drop only when dragenter is cancelled too, so dragenter and dragover share this handler.
  // A target that qualifies, other than the stage the issue is already in, is highlighted and accepts the drop.
  over(event) {
    const target = this.targetFor(event)
    if (!target) { return }

    event.preventDefault()
    if (event.dataTransfer) { event.dataTransfer.dropEffect = "move" }
    target.classList.add(DROP_OVER_CLASS)
  }

  leave(event) {
    const target = event.target.closest ? event.target.closest(DROP_TARGET_SELECTOR) : null
    if (target && !target.contains(event.relatedTarget)) { target.classList.remove(DROP_OVER_CLASS) }
  }

  async drop(event) {
    const target = this.targetFor(event, "drop")
    const row = this.draggedRow
    if (!target || !row) { return }

    event.preventDefault()
    this.clearHighlights()
    const updatePath = row.dataset.updatePath
    this.finish()
    await this.move(updatePath, target.dataset.versionId)
  }

  // The stage or section under the pointer that takes the dragged issue, or null. A drop that is ignored says why in the
  // console (the dragover calls pass no reason, so they stay quiet).
  targetFor(event, reasonFor) {
    const row = this.draggedRow
    if (!row) {
      if (reasonFor) { console.error("Rubylode Progress move: drop ignored, no dragged row was remembered by dragstart") }
      return null
    }
    if (!event.target.closest) { return null }

    const target = event.target.closest(DROP_TARGET_SELECTOR)
    if (!target) {
      if (reasonFor) { console.error("Rubylode Progress move: drop ignored, no stage that takes issues under the pointer", event.target) }
      return null
    }
    if (target.dataset.versionId === row.dataset.currentVersionId) {
      if (reasonFor) { console.error("Rubylode Progress move: drop ignored, the issue is already in that stage") }
      return null
    }

    return target
  }

  async move(updatePath, versionId) {
    const token = document.querySelector("meta[name='csrf-token']")
    try {
      const response = await fetch(updatePath, {
        method: "PATCH",
        credentials: "same-origin",
        redirect: "manual",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token ? token.content : ""
        },
        body: new URLSearchParams({ "issue[fixed_version_id]": versionId })
      })
      if (response.ok) {
        window.location.reload()
      } else {
        console.error("Rubylode Progress move: Redmine answered", response.status, response.type)
        this.showMessage(await this.errorText(response))
      }
    } catch (error) {
      console.error("Rubylode Progress move: the request failed", error)
      this.showMessage(this.failedMessageValue)
    }
  }

  // Redmine's own error text for a refused update (422 has a JSON list); a plain refusal (403) has no body.
  async errorText(response) {
    try {
      const body = await response.json()
      if (body && Array.isArray(body.errors) && body.errors.length > 0) { return body.errors.join(" ") }
    } catch (error) {
      // No readable body: fall through to the plain message.
    }
    return response.status === 403 ? this.refusedMessageValue : this.failedMessageValue
  }

  clearHighlights() {
    this.element.querySelectorAll("." + DROP_OVER_CLASS).forEach((target) => target.classList.remove(DROP_OVER_CLASS))
  }

  showMessage(text) {
    if (!this.hasMessageTarget) { return }

    this.messageTarget.textContent = text
    this.messageTarget.hidden = false
  }

  hideMessage() {
    if (this.hasMessageTarget) { this.messageTarget.hidden = true }
  }
}

application.register("rubylode-progress-move", ProgressMoveController)
