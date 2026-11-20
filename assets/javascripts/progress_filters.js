/* Rubylode Progress: swaps the checklist panel in place when a filter or a grouping is chosen.
 * Copyright (C) 2026  Nick Gorbikoff. GPL v2 or later, as the rest of the plugin.
 *
 * A Stimulus controller, registered on the application that Redmine 7 starts. Without this file, or when a request
 * fails, the filters, "Show more" and the grouping buttons are ordinary links that reload the page with ?filter=<name>&group=<name>,
 * and the grouping select has its own button inside a noscript tag.
 */
import { Controller } from "@hotwired/stimulus"
import { application } from "controllers/application"

class ProgressFiltersController extends Controller {
  static targets = ["checklist"]

  connect() {
    this.foldMoreMenus()
  }

  // On a phone the pencil and the new-tab link sit behind a button, so the menus start closed.
  foldMoreMenus() {
    if (!window.matchMedia("(max-width: 640px)").matches) { return }

    this.checklistTarget.querySelectorAll(".rubylode-progress-more").forEach((menu) => { menu.open = false })
  }

  // A filter pill or a grouping button: fetch the panel that its link names.
  async choose(event) {
    event.preventDefault()
    const link = event.currentTarget
    await this.swap(link.dataset.checklistPath, link.href)
  }

  // The grouping select shown on a phone: the form holds the checklist address and the filter; the choice is added.
  async chooseGroup(event) {
    const form = event.currentTarget
    const select = form.querySelector("select")
    const checklistUrl = new URL(form.dataset.checklistPath, window.location.origin)
    const pageUrl = new URL(form.action, window.location.origin)
    checklistUrl.searchParams.set("group", select.value)
    pageUrl.search = checklistUrl.search
    await this.swap(checklistUrl.pathname + checklistUrl.search, pageUrl.toString())
  }

  // One of the three selects (assignee, tracker, category): the form holds the checklist address with the filter and the
  // grouping; the selects' values are added, "any" being no parameter at all.
  async chooseNarrowing(event) {
    const form = event.currentTarget
    const checklistUrl = new URL(form.dataset.checklistPath, window.location.origin)
    const pageUrl = new URL(form.action, window.location.origin)
    form.querySelectorAll("select").forEach((select) => {
      if (select.value === "any") { return }

      checklistUrl.searchParams.set(select.name, select.value)
    })
    pageUrl.search = checklistUrl.search
    await this.swap(checklistUrl.pathname + checklistUrl.search, pageUrl.toString())
  }

  // "Show more" under a section: fetch the panel with that section listed in full and swap only that section, so the
  // sections already opened stay as they are. The link is a real address that reloads the page without a script.
  async expand(event) {
    event.preventDefault()
    const link = event.currentTarget
    const section = link.closest(".rubylode-progress-section")
    try {
      const response = await fetch(link.dataset.checklistPath, { credentials: "same-origin" })
      if (!response.ok) { throw new Error(response.status) }

      const template = document.createElement("template")
      template.innerHTML = await response.text()
      const fresh = template.content.querySelector(`[data-section-key="${CSS.escape(section.dataset.sectionKey)}"]`)
      if (!fresh) { throw new Error("section missing") }

      section.replaceWith(fresh)
      this.foldMoreMenus()
      fresh.querySelector("summary").focus({ preventScroll: true })
    } catch (error) {
      window.location.href = link.href
    }
  }

  async swap(checklistPath, pageAddress) {
    try {
      const response = await fetch(checklistPath, { credentials: "same-origin" })
      if (!response.ok) { throw new Error(response.status) }

      const rules = this.checklistTarget.querySelector(".rubylode-progress-rules")
      const rulesWereOpen = rules ? rules.open : false
      const template = document.createElement("template")
      template.innerHTML = await response.text()
      this.checklistTarget.replaceChildren(...template.content.childNodes)
      const newRules = this.checklistTarget.querySelector(".rubylode-progress-rules")
      if (newRules) { newRules.open = rulesWereOpen }
      this.foldMoreMenus()
      history.replaceState(null, "", pageAddress)
    } catch (error) {
      window.location.href = pageAddress
    }
  }
}

application.register("rubylode-progress-filters", ProgressFiltersController)

// The three dots on the top track link to the fold row of the stage list. The anchor alone jumps there; this opens the
// fold too, and scrolls it into view.
class ProgressFoldController extends Controller {
  open(event) {
    const fold = document.getElementById(event.currentTarget.hash.slice(1))
    if (!fold) { return }

    event.preventDefault()
    fold.open = true
    fold.scrollIntoView({ block: "start", behavior: "smooth" })
    const summary = fold.querySelector("summary")
    if (summary) { summary.focus({ preventScroll: true }) }
    history.replaceState(null, "", event.currentTarget.hash)
  }
}

application.register("rubylode-progress-fold", ProgressFoldController)
