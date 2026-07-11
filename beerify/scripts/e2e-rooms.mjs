/**
 * Two-user room flow against the deployed app (real Redis backend):
 * Ana creates a room, Ben joins by code, Ana goes out and logs a beer, and
 * Ben watches her state update in his squad list.
 *
 * Run: BASE_URL=https://beerify-lime.vercel.app node scripts/e2e-rooms.mjs
 */
import { chromium, devices } from 'playwright'
import { fileURLToPath } from 'node:url'
import { mkdirSync } from 'node:fs'

const BASE = process.env.BASE_URL ?? 'https://beerify-lime.vercel.app'
const SHOTS = fileURLToPath(new URL('../output/playwright/', import.meta.url))
mkdirSync(SHOTS, { recursive: true })

const fails = []
async function expect(desc, cond) {
  if (!cond) {
    fails.push(desc)
    console.log(`FAIL  ${desc}`)
  } else {
    console.log(`ok    ${desc}`)
  }
}

async function onboard(page, name) {
  await page.goto(BASE)
  await page.getByRole('button', { name: 'Set up my night' }).click()
  await page.getByPlaceholder('Name or nickname').fill(name)
  await page.getByPlaceholder('72').fill('75')
  await page.getByRole('button', { name: 'Female', exact: true }).click()
  await page.getByRole('button', { name: 'Next: pub credentials' }).click()
  await page.getByRole('button', { name: /Weekend athlete/ }).click()
  await page.getByRole('button', { name: 'Enter Beerify' }).click()
  await page.getByRole('button', { name: 'Crew' }).click()
}

const browser = await chromium.launch()
const ctxA = await browser.newContext({ ...devices['iPhone 13'] })
const ctxB = await browser.newContext({ ...devices['iPhone 13'] })
const ana = await ctxA.newPage()
const ben = await ctxB.newPage()
await ben.clock.install()

await onboard(ana, 'Ana')
await onboard(ben, 'Ben')

// Ana creates a room.
await ana.getByRole('button', { name: 'Create room' }).click()
await ana.locator('.room-ticket').waitFor({ timeout: 15000 })
const code = (await ana.locator('.room-ticket strong').textContent())?.trim()
await expect(`Ana got a room code (${code})`, /^[A-Z2-9]{6}$/.test(code ?? ''))

// Ben joins with the code.
await ben.getByLabel('Room code').fill(code)
await ben.getByRole('button', { name: 'Join', exact: true }).click()
await ben.locator('.room-ticket').waitFor({ timeout: 15000 })

// Ben should soon see both members (poll runs every 30s on his mocked clock).
let rows = 0
for (let i = 0; i < 8 && rows < 2; i++) {
  await ben.clock.fastForward('31')
  await ben.waitForTimeout(1500)
  rows = await ben.locator('.squad__row').count()
}
await expect(`Ben sees both members (got ${rows})`, rows === 2)
await expect('Ben sees Ana resting', await ben.locator('.squad__row', { hasText: 'Ana' }).getByText(/Resting/).isVisible())

// Ana heads out and logs a beer.
await ana.getByRole('button', { name: 'Tonight' }).click()
await ana.getByRole('button', { name: 'Start the night →' }).click()
await ana.getByRole('button', { name: 'Log Guinness' }).click()
await ana.waitForTimeout(2500) // real clock: push fires 400ms after the tap

// Ben's next polls should show Ana in session with 1 drink.
let anaRow = ben.locator('.squad__row', { hasText: 'Ana' })
let seen = false
for (let i = 0; i < 8 && !seen; i++) {
  await ben.clock.fastForward('31')
  await ben.waitForTimeout(1500)
  seen = await anaRow.getByText(/1 drink/).isVisible().catch(() => false)
}
await expect('Ben sees Ana out with 1 drink', seen)
await ben.screenshot({ path: SHOTS + '07-room-ben.png' })

// Cleanup: both leave the room.
await ana.getByRole('button', { name: 'End the night' }).click()
await ana.getByRole('button', { name: /End night and make recap/ }).click()
await ana.getByRole('button', { name: 'Back to Beerify' }).click()
await ana.getByRole('button', { name: 'Crew' }).click()
await ana.getByRole('button', { name: 'Leave room' }).click()
await ben.getByRole('button', { name: 'Leave room' }).click()
await expect('Ana back to create-room state', await ana.getByRole('button', { name: 'Create room' }).isVisible())

await browser.close()
if (fails.length) {
  console.error(`\n${fails.length} check(s) failed`)
  process.exit(1)
}
console.log('\nAll room e2e checks passed')
