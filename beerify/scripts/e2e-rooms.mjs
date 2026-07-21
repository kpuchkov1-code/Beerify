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
  await page.getByRole('checkbox').check()
  await page.getByRole('button', { name: 'Enter Beerify' }).click()
  await page.getByRole('button', { name: 'Crew', exact: true }).click()
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
await ana.getByRole('button', { name: 'Drinks', exact: true }).click()
await ana.getByRole('button', { name: 'Create room' }).click()
await ana.getByRole('heading', { name: 'How chaotic is tonight?' }).waitFor({ timeout: 15000 })
const roomCallout = (await ana.locator('.crew-callout strong').textContent())?.trim() ?? ''
const code = roomCallout.match(/[A-Z2-9]{6}/)?.[0]
await expect(`Ana got a room code (${code})`, /^[A-Z2-9]{6}$/.test(code ?? ''))
const protocol = await ana.evaluate(async () => {
  const membership = JSON.parse(localStorage.getItem('beerify:v2')).room
  const post = (body) => fetch('/api/room', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ...membership, ...body }) })
  const registered = await post({ action: 'push-register', token: 'a'.repeat(64), environment: 'sandbox' })
  const unregistered = await post({ action: 'push-unregister' })
  const clientEventId = crypto.randomUUID()
  const event = { action: 'event', type: 'reaction', reaction: 'cheers', clientEventId }
  const first = await post(event)
  const duplicate = await post(event)
  const room = await fetch(`/api/room?code=${membership.code}`).then((response) => response.json())
  return { registered: registered.status, unregistered: unregistered.status, first: first.status, duplicate: duplicate.status, copies: room.events.filter((item) => item.id === clientEventId).length }
})
await expect('push registration and removal authenticate successfully', protocol.registered === 200 && protocol.unregistered === 200)
await expect('retried room events remain idempotent', protocol.first === 200 && protocol.duplicate === 200 && protocol.copies === 1)

// Ben joins with the code.
await ben.getByLabel('Room code').fill(code)
await ben.getByRole('button', { name: 'Join', exact: true }).click()
await ben.getByRole('heading', { name: 'How chaotic is tonight?' }).waitFor({ timeout: 15000 })
await expect('Ben lands in Tonight setup after joining', await ben.getByText(`Room ${code}`).isVisible())
await ben.locator('.app-nav__item', { hasText: 'Crew' }).click()
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

// Ana starts a live game; both devices submit into the same canonical round.
await ana.getByRole('button', { name: 'Games', exact: true }).click()
await ana.locator('.game-row', { hasText: 'Would You Rather' }).getByRole('button', { name: 'Room' }).click()
await ana.getByRole('heading', { name: /Would You Rather/ }).waitFor()
await ben.getByRole('button', { name: 'Games', exact: true }).click()
await ben.getByRole('heading', { name: /Would You Rather/ }).waitFor({ timeout: 10000 })
await ben.getByRole('button', { name: /ready/i }).click()
await ana.waitForTimeout(1500)
await ana.getByRole('button', { name: 'Start live round' }).click()
await ana.locator('.game-options button').first().waitFor()
await ben.locator('.game-options button').nth(1).click()
await ana.locator('.game-options button').first().click()
await ana.getByRole('heading', { name: 'Receipts' }).waitFor({ timeout: 10000 })
await ben.clock.fastForward(2000)
await ben.waitForTimeout(300)
await expect('both devices complete the same live round', await ben.getByRole('heading', { name: 'Receipts' }).isVisible())
await ana.getByRole('button', { name: 'Close game' }).click()
await ana.getByRole('button', { name: 'Tonight', exact: true }).click()
await ben.clock.fastForward(2000)
await ben.locator('.app-nav__item', { hasText: 'Crew' }).click()

// Ana heads out and logs a beer.
await ana.getByRole('button', { name: 'Start the night →' }).click()
await ana.getByRole('button', { name: 'Log Guinness' }).click()
await ana.waitForTimeout(2500) // real clock: push fires 400ms after the tap
await ana.locator('.active-night-nav__item', { hasText: 'Crew' }).click()
await ana.locator('.room-ticket').waitFor({ timeout: 15000 })
await expect('Ana can open the full room without ending her night', !(await ana.getByRole('heading', { name: 'Ready to start?' }).isVisible().catch(() => false)))
await expect('Ana stays active after switching to Crew', await ana.locator('.squad__row', { hasText: 'Ana' }).getByText(/1 drink/).isVisible())
await ana.screenshot({ path: SHOTS + '08-active-night-crew.png', fullPage: true })

// Ben's next polls should show Ana in session with 1 drink.
let anaRow = ben.locator('.squad__row', { hasText: 'Ana' })
let seen = false
for (let i = 0; i < 8 && !seen; i++) {
  await ben.clock.fastForward('31')
  await ben.waitForTimeout(1500)
  seen = await anaRow.getByText(/1 drink/).isVisible().catch(() => false)
}
await expect('Ben sees Ana out with 1 drink', seen)
await expect('Ben sees the drinks leaderboard', await ben.locator('.leaderboard-categories article', { hasText: 'Drinks' }).getByText('Ana').isVisible())
await ben.getByRole('button', { name: /Drink up in 8/ }).click()
await ana.getByText(/called drink up/).waitFor({ timeout: 8000 })
await expect('Countdown remains visible in active Crew', await ana.locator('.cheers-overlay').isVisible())
await ben.screenshot({ path: SHOTS + '07-room-ben.png', fullPage: true })

// Cleanup: both leave the room.
await ana.getByRole('navigation', { name: 'Active night navigation' }).getByRole('button', { name: 'Drinks', exact: true }).click()
await ana.getByRole('button', { name: 'End the night' }).click()
await ana.getByRole('button', { name: /End night and make recap/ }).click()
await ana.locator('.app-nav__item', { hasText: 'Crew' }).click()
await ana.getByRole('button', { name: 'Leave room' }).click()
await ben.getByRole('button', { name: 'Leave room' }).click()
await expect('Ana back to create-room state', await ana.getByRole('button', { name: 'Create room' }).isVisible())

await browser.close()
if (fails.length) {
  console.error(`\n${fails.length} check(s) failed`)
  process.exit(1)
}
console.log('\nAll room e2e checks passed')
