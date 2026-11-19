// README screenshots from the demo Redmine (ruby bin/demo up), in its default theme, with the demo's made-up data.
// Only reads: no issue is moved or edited.
//   npm install && npm run screenshots
import { mkdirSync, readFileSync } from "node:fs"
import { baseUrl, launch, signedInPage } from "./browser.mjs"

const out = new URL("../docs/screenshots/", import.meta.url).pathname
mkdirSync(out, { recursive: true })

async function shoot(page, name, path, selector, extra = {}) {
  await page.goto(`${baseUrl}${path}`, { waitUntil: "load" })
  await page.waitForSelector(selector)
  await page.screenshot({ path: `${out}${name}.png`, ...extra })
  console.log("saved", `${name}.png`)
}

// The dark block from docs/theming.md, with a dark page behind it as a dark theme would give.
function darkStyles() {
  const theming = readFileSync(new URL("../docs/theming.md", import.meta.url), "utf8")
  const block = theming.split("## Dark theme")[1].match(/```css\n([\s\S]*?)```/)[1]
  return `${block}
body, #wrapper, #main, #content { background: #0d1117 !important; color: #e6edf3 !important; }
#content h2, #content h3 { color: #e6edf3 !important; }`
}

const browser = await launch()
const page = await signedInPage(browser, "grace.hopper", "demo-password-1", { width: 1280, height: 900 })
const trackerSelector = ".rubylode-progress .rubylode-progress-checklist-column"

// The chosen filter is remembered per person, so every shot names its filter and the last one leaves it on Open.
await shoot(page, "progress-tab", "/projects/bridge/progress?filter=open", trackerSelector, { fullPage: true })
await shoot(page, "progress-needs-you", "/projects/bridge/progress?filter=needs_you", trackerSelector, { fullPage: true })
await page.goto(`${baseUrl}/projects/bridge/progress?filter=open`, { waitUntil: "load" })
await shoot(page, "all-projects", "/progress", ".rubylode-progress-all-projects", { fullPage: true })

await page.goto(`${baseUrl}/projects/bridge/progress`, { waitUntil: "load" })
await page.addStyleTag({ content: darkStyles() })
await page.waitForSelector(trackerSelector)
await page.screenshot({ path: `${out}progress-dark.png`, fullPage: true })
console.log("saved progress-dark.png")

await page.setViewportSize({ width: 390, height: 844 })
await shoot(page, "progress-phone", "/projects/bridge/progress", trackerSelector, { fullPage: true })

const admin = await signedInPage(browser, "admin", "admin", { width: 1280, height: 800 })
await shoot(admin, "project-settings", "/projects/bridge/settings/rubylode_progress", "form.tabular", { fullPage: true })

await browser.close()
