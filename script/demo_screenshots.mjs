// README screenshots from the demo Redmine with the fake Kuma, in its default theme.
//   ruby bin/demo up && npm install && npm run screenshots
import { mkdirSync } from "node:fs"
import { baseUrl, launch, signedInPage } from "./browser.mjs"

const out = new URL("../docs/screenshots/", import.meta.url).pathname
mkdirSync(out, { recursive: true })
const fakeKuma = process.env.FAKE_KUMA_URL || "http://127.0.0.1:9112"

async function scenario(name) {
  const response = await fetch(`${fakeKuma}/__scenario/${name}`, { method: "POST" })
  if (!response.ok) throw new Error(`fake Kuma refused scenario ${name}`)
  await new Promise((resolve) => setTimeout(resolve, 2500)) // the demo caches Kuma's answer for one second
}

const browser = await launch()
const viewport = { width: 1100, height: 620 }
const sam = await signedInPage(browser, "sam.rivera", "demo-password-1", viewport)
const admin = await signedInPage(browser, "admin", "admin", viewport)

async function shootBlock(page, name) {
  await page.goto(`${baseUrl}/service_status`, { waitUntil: "load" })
  await page.waitForSelector(".rubylode-service-status")
  const block = await page.$("#content")
  await block.screenshot({ path: `${out}${name}.png` })
  console.log("saved", `${name}.png`)
}

await scenario("all_up")
await shootBlock(sam, "service-status-all-up")

await scenario("mixed")
await shootBlock(sam, "service-status-one-down-one-unknown")

await scenario("unavailable")
await shootBlock(admin, "service-status-unavailable")

await scenario("one_down")
await sam.goto(`${baseUrl}/projects/demo-project/wiki`, { waitUntil: "load" })
await sam.waitForSelector(".wiki .rubylode-service-status")
await (await sam.$("#content")).screenshot({ path: `${out}wiki-macro.png` })
console.log("saved wiki-macro.png")

await admin.goto(`${baseUrl}/settings/plugin/redmine_rubylode_uptime_kuma`, { waitUntil: "load" })
await admin.waitForSelector("#settings_services")
await admin.setViewportSize({ width: 1100, height: 1900 })
await (await admin.$("#content")).screenshot({ path: `${out}settings-page.png` })
console.log("saved settings-page.png")

await scenario("one_down")
const wide = await signedInPage(browser, "sam.rivera", "demo-password-1", { width: 1440, height: 760 })
await wide.goto(`${baseUrl}/`, { waitUntil: "load" })
await wide.waitForSelector(".rubylode-service-status")
await wide.screenshot({ path: `${out}welcome-page.png` })
console.log("saved welcome-page.png")

await scenario("all_up")
await browser.close()
