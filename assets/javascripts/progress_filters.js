/* Rubylode Progress: swaps the checklist in place when a filter is chosen.
 * Copyright (C) 2026  Nick Gorbikoff. GPL v2 or later, as the rest of the plugin.
 *
 * A Stimulus controller, registered on the application that Redmine 7 starts. Without this file, or when a request
 * fails, the filters are ordinary links that reload the page with ?filter=<name>.
 */
import { Controller } from "@hotwired/stimulus"
import { application } from "controllers/application"

class ProgressFiltersController extends Controller {
  static targets = ["checklist", "filter"]

  async choose(event) {
    const link = event.currentTarget
    event.preventDefault()

    try {
      const response = await fetch(link.dataset.checklistPath, { credentials: "same-origin" })
      if (!response.ok) { throw new Error(response.status) }

      const template = document.createElement("template")
      template.innerHTML = await response.text()
      this.checklistTarget.replaceChildren(...template.content.childNodes)
      this.filterTargets.forEach((filter) => {
        filter.setAttribute("aria-pressed", filter === link ? "true" : "false")
      })
      history.replaceState(null, "", link.href)
    } catch (error) {
      window.location.href = link.href
    }
  }
}

application.register("rubylode-progress-filters", ProgressFiltersController)
