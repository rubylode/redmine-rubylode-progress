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
    this.openedSectionListener = (event) => this.openedSection(event)
    this.checklistTarget.addEventListener("toggle", this.openedSectionListener, true)
  }

  disconnect() {
    this.checklistTarget.removeEventListener("toggle", this.openedSectionListener, true)
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
    await this.swapSection(link.closest(".rubylode-progress-section"), link.dataset.checklistPath, link.href)
  }

  // Fetch the panel at checklistPath and replace one section with the same section from it. Any failure leaves the
  // viewer on pageAddress, which is the same step as a page load.
  async swapSection(section, checklistPath, pageAddress) {
    try {
      const response = await fetch(checklistPath, { credentials: "same-origin" })
      if (!response.ok) { throw new Error(response.status) }

      const template = document.createElement("template")
      template.innerHTML = await response.text()
      const fresh = template.content.querySelector(`[data-section-key="${CSS.escape(section.dataset.sectionKey)}"]`)
      if (!fresh) { throw new Error("section missing") }
      if (fresh.hasAttribute("data-lazy-section-path")) { throw new Error("section still folded") }

      section.replaceWith(fresh)
      this.foldMoreMenus()
      fresh.querySelector("summary").focus({ preventScroll: true })
    } catch (error) {
      console.error("Rubylode Progress checklist: the section did not load", error)
      window.location.href = pageAddress
    }
  }

  // A folded section holds a link in place of its rows. The toggle event does not bubble, so the listener is on the panel
  // in the capture phase. The first time the section is opened, its rows are fetched and the section is swapped in place.
  openedSection(event) {
    const section = event.target
    if (!section.matches || !section.matches("details[data-lazy-section-path]")) { return }
    if (!section.open) { return }

    const placeholder = section.querySelector(":scope > .rubylode-progress-section__lazy")
    if (!placeholder) {
      console.error("Rubylode Progress checklist: the section was opened but holds no place for its rows", section)
      return
    }
    if (placeholder.dataset.loading === "true") {
      console.error("Rubylode Progress checklist: the rows of this section are already loading")
      return
    }

    const link = placeholder.querySelector("a")
    placeholder.dataset.loading = "true"
    placeholder.setAttribute("role", "status")
    placeholder.replaceChildren(placeholder.dataset.loadingMessage)
    this.loadSection(section, placeholder, link)
  }

  // Like "Show more", but a failure keeps the folded section and offers the plain link again, so nothing is lost.
  async loadSection(section, placeholder, link) {
    try {
      const response = await fetch(section.dataset.lazySectionPath, { credentials: "same-origin" })
      if (!response.ok) { throw new Error(response.status) }

      const template = document.createElement("template")
      template.innerHTML = await response.text()
      const fresh = template.content.querySelector(`[data-section-key="${CSS.escape(section.dataset.sectionKey)}"]`)
      if (!fresh) { throw new Error("section missing") }
      if (fresh.hasAttribute("data-lazy-section-path")) { throw new Error("section still folded") }

      section.replaceWith(fresh)
      this.foldMoreMenus()
    } catch (error) {
      console.error("Rubylode Progress checklist: the rows of the section did not load", error)
      placeholder.dataset.loading = "false"
      placeholder.removeAttribute("role")
      placeholder.replaceChildren(placeholder.dataset.failedMessage + " ", ...(link ? [link] : []))
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

// A folded stage renders its summary only; its issues come from the address on its details tag when it is first opened.
// The toggle event does not bubble, so the listener is on the list in the capture phase. Until the issues arrive the
// stage holds a link to the same stage opened by a full page load, which is also where a failed load leaves the viewer.
class ProgressLazyStageController extends Controller {
  static values = { loadingMessage: String, failedMessage: String }

  connect() {
    this.openedStage = (event) => this.load(event)
    this.element.addEventListener("toggle", this.openedStage, true)
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.openedStage, true)
  }

  async load(event) {
    const stage = event.target
    if (!stage.matches || !stage.matches("details[data-lazy-issues-path]")) { return }
    if (!stage.open) { return }

    const placeholder = stage.querySelector(":scope > .rubylode-progress-stage__lazy")
    if (!placeholder) {
      console.error("Rubylode Progress stages: the stage was opened but holds no place for its issues", stage)
      return
    }
    if (placeholder.dataset.loading === "true") {
      console.error("Rubylode Progress stages: the issues of this stage are already loading")
      return
    }

    const link = placeholder.querySelector("a")
    placeholder.dataset.loading = "true"
    placeholder.setAttribute("role", "status")
    placeholder.replaceChildren(this.loadingMessageValue)
    try {
      const response = await fetch(stage.dataset.lazyIssuesPath, { credentials: "same-origin", headers: { "Accept": "text/html" } })
      if (!response.ok) { throw new Error(response.status) }

      const template = document.createElement("template")
      template.innerHTML = await response.text()
      placeholder.replaceWith(template.content)
      stage.removeAttribute("data-lazy-issues-path")
    } catch (error) {
      console.error("Rubylode Progress stages: the issues of the stage did not load", error)
      placeholder.dataset.loading = "false"
      placeholder.removeAttribute("role")
      placeholder.replaceChildren(this.failedMessageValue + " ", ...(link ? [link] : []))
    }
  }
}

application.register("rubylode-progress-lazy-stage", ProgressLazyStageController)
