/* Rubylode Progress: swaps the checklist panel in place when a filter or a grouping is chosen.
 * Copyright (C) 2026  Nick Gorbikoff. GPL v2 or later, as the rest of the plugin.
 *
 * A Stimulus controller, registered on the application that Redmine 7 starts. Without this file, or when a request
 * fails, the filters and the grouping buttons are ordinary links that reload the page with ?filter=<name>&group=<name>,
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
    pageUrl.searchParams.set("filter", checklistUrl.searchParams.get("filter"))
    pageUrl.searchParams.set("group", select.value)
    await this.swap(checklistUrl.pathname + checklistUrl.search, pageUrl.toString())
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
