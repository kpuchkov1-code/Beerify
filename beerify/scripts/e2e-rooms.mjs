/**
 * Two-user room flow against the deployed app (real Edge Config backend):
 * Ana creates a room, Ben joins by code, Ana goes out and logs a beer, and
 * Ben watches her state update in his squad list.
 *
 * Run: BASE_URL=https://beerify-lime.vercel.app node scripts/e2e-rooms.mjs
 */
import { chromium, devices } from 'playwright'

const BASE = process.env.BASE_URL ?? 'https://beerify-lime.vercel.app'

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
  await page.getByRole('button', { name: "Let's set you up" }).click()
  await page.getByPlaceholder('Your name').fill(name)
  await page.getByPlaceholder('e.g. 72').fill('75')
  await page.getByRole('button', { name: 'Female', exact: true }).click()
  await page.getByRole('button', { name: /Most weeks/ }).click()
  await page.getByRole('button', { name: 'Done, take me in 🍻' }).click()
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
await ana.getByRole('button', { name: 'Create a room' }).click()
await ana.locator('.room-panel__code').waitFor({ timeout: 15000 })
const code = (await ana.locator('.room-panel__code').textContent())?.trim()
await expect(`Ana got a room code (${code})`, /^[A-Z2-9]{4}$/.test(code ?? ''))

// Ben joins with the code.
await ben.locator('.room-panel__join input').fill(code)
await ben.getByRole('button', { name: 'Join', exact: true }).click()
await ben.locator('.room-panel__code').waitFor({ timeout: 15000 })

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
await ana.getByRole('button', { name: 'Start night out 🌙' }).click()
await ana.getByRole('button', { name: 'Log one Beer' }).click()
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
await ben.screenshot({ path: new URL('../shots/07-room-ben.png', import.meta.url).pathname })

// Cleanup: both leave the room.
await ana.getByRole('button', { name: 'End night' }).click()
await ana.getByRole('button', { name: /sleep tight/ }).click()
await ana.getByRole('button', { name: 'Leave room' }).click()
await ben.getByRole('button', { name: 'Leave room' }).click()
await expect('Ana back to create-room state', await ana.getByRole('button', { name: 'Create a room' }).isVisible())

await browser.close()
if (fails.length) {
  console.error(`\n${fails.length} check(s) failed`)
  process.exit(1)
}
console.log('\nAll room e2e checks passed')
