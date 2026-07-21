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
}

const browser = await chromium.launch()
const ctxA = await browser.newContext({ ...devices['iPhone 13'] })
const ctxB = await browser.newContext({ ...devices['iPhone 13'] })
const ana = await ctxA.newPage()
const ben = await ctxB.newPage()
await ben.clock.install()

await onboard(ana, 'Ana')
await onboard(ben, 'Ben')

// Ana plans before the night. Her draft becomes the one room-owned route.
await ana.context().setGeolocation({ latitude: 51.5, longitude: -0.12 })
await ana.context().grantPermissions(['geolocation'], { origin: new URL(BASE).origin })
await ana.route('**/api/maps?*', async (route) => {
  const action = new URL(route.request().url()).searchParams.get('action')
  if (action === 'nearby') return route.fulfill({ json: { venues: [
    { id: 'green', name: 'Bottle Green', lat: 51.5, lng: -0.12, type: 'pub', distanceMeters: 30 },
    { id: 'hop', name: 'Hop Room', lat: 51.505, lng: -0.115, type: 'bar', distanceMeters: 700 },
    { id: 'owl', name: 'Night Owl', lat: 51.51, lng: -0.11, type: 'nightclub', distanceMeters: 1500 },
  ] } })
  return route.fulfill({ json: { distanceMeters: 1800, durationSeconds: 1320, geometry: { type: 'LineString', coordinates: [[-0.12, 51.5], [-0.115, 51.505], [-0.11, 51.51]] } } })
})
await ana.getByRole('button', { name: 'Pubs', exact: true }).click()
await ana.getByRole('button', { name: 'Use my location' }).click()
await ana.getByText('Bottle Green').first().waitFor()
for (const venue of ['Bottle Green', 'Hop Room', 'Night Owl']) await ana.locator('.venue-list article', { hasText: venue }).getByRole('button', { name: '+ Crawl' }).click()
await ana.getByRole('button', { name: 'Back to crawl' }).click()
await expect('Ana saves a three-stop draft before starting', await ana.locator('.crawl-stop').count() === 3)
await ana.getByRole('button', { name: 'Tonight', exact: true }).click()

// Ana chooses Squad once, creates the shared night, then starts it.
await ana.getByRole('button', { name: /^Squad/ }).click()
await ana.setViewportSize({ width: 320, height: 568 })
await expect('squad setup fits a 320px phone', await ana.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth))
await ana.setViewportSize({ width: 390, height: 664 })
await ana.getByRole('button', { name: 'Create squad' }).click()
await ana.getByText('Squad connected').waitFor({ timeout: 15000 })
const code = await ana.evaluate(() => JSON.parse(localStorage.getItem('beerify:v2')).room.code)
await expect(`Ana got a room code (${code})`, /^[A-Z2-9]{6}$/.test(code ?? ''))
await ana.getByRole('button', { name: 'Start squad night →' }).click()
await ana.locator('.night-bar').waitFor({ timeout: 15000 })
await expect('Ana squad mode is locked into the active night', await ana.locator('.night-bar').getByText(/Squad/).isVisible())
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

// Ben chooses Squad, joins the same code and starts his side of that night.
await ben.getByRole('button', { name: /^Squad/ }).click()
await ben.getByLabel('Squad code').fill(code)
await ben.getByRole('button', { name: 'Join', exact: true }).click()
await ben.getByText('Squad connected').waitFor({ timeout: 15000 })
await ben.getByRole('button', { name: 'Start squad night →' }).click()
await expect('Ben starts in the same persistent squad context', await ben.locator('.night-bar').getByText(/Squad/).isVisible())
await ben.locator('.active-night-nav__item', { hasText: 'Crew' }).click()
await ben.locator('.room-ticket').waitFor({ timeout: 15000 })

// Ben should soon see both members (poll runs every 30s on his mocked clock).
let rows = 0
for (let i = 0; i < 8 && rows < 2; i++) {
  await ben.clock.fastForward('31')
  await ben.waitForTimeout(1500)
  rows = await ben.locator('.squad__row').count()
}
await expect(`Ben sees both members (got ${rows})`, rows === 2)
await expect('Ben sees Ana active in the squad night', await ben.locator('.squad__row', { hasText: 'Ana' }).getByText(/0 drinks/).isVisible())

// The host draft is already canonical; Ben receives that same stop order.
await ana.getByRole('button', { name: 'More', exact: true }).click()
await ana.getByRole('button', { name: /Pubs/ }).click()
await ana.locator('.crawl-stop').first().waitFor({ timeout: 10000 })
await expect('host draft seeds the shared crawl', await ana.locator('.crawl-stop').count() === 3)
await ben.getByRole('button', { name: 'More', exact: true }).click()
await ben.getByRole('button', { name: /Pubs/ }).click()
let crawlCount = 0
for (let i = 0; i < 6 && crawlCount !== 3; i++) {
  await ben.clock.fastForward(6000)
  await ben.waitForTimeout(300)
  crawlCount = await ben.locator('.crawl-stop').count()
}
await expect('guest receives the same three crawl stops', crawlCount === 3)
await expect('guest cannot reorder the host crawl', await ben.locator('.crawl-stop__actions button').first().isDisabled())
await ana.locator('.crawl-stop__actions button').nth(1).click()
for (let i = 0; i < 6 && await ben.locator('.crawl-stop').first().getByText('Hop Room').isVisible().catch(() => false) === false; i++) {
  await ben.clock.fastForward(4000)
  await ben.waitForTimeout(300)
}
await expect('host reordering updates the guest route order', await ben.locator('.crawl-stop').first().getByText('Hop Room').isVisible())

// Ana starts a live game; both devices submit into the same canonical round.
await ana.getByRole('button', { name: 'Games', exact: true }).click()
await ana.locator('.game-row', { hasText: 'Would You Rather' }).getByRole('button', { name: 'Start for squad' }).click()
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
await ana.getByRole('button', { name: 'Drinks', exact: true }).click()
await ben.clock.fastForward(2000)
await ben.locator('.active-night-nav__item', { hasText: 'Crew' }).click()

// Ana logs a beer; the already-selected Squad context carries it into the room.
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
await ben.locator('.crew-disclosure').filter({ hasText: 'Leaderboard' }).getByText('Leaderboard', { exact: true }).click()
await expect('Ben sees the drinks leaderboard', await ben.locator('.leaderboard-categories article', { hasText: 'Drinks' }).getByText('Ana').isVisible())
await ben.getByRole('button', { name: /Drink up in 8/ }).click()
await ana.getByText(/called drink up/).waitFor({ timeout: 8000 })
await expect('Countdown remains visible in active Crew', await ana.locator('.cheers-overlay').isVisible())
await ben.screenshot({ path: SHOTS + '07-room-ben.png', fullPage: true })

// A stale token clears itself and offers an in-context rejoin instead of trapping the user.
await ben.evaluate(() => {
  const data = JSON.parse(localStorage.getItem('beerify:v2'))
  data.room.memberToken = crypto.randomUUID()
  localStorage.setItem('beerify:v2', JSON.stringify(data))
})
await ben.reload()
await ben.getByText('Squad connection lost').waitFor({ timeout: 10000 })
await expect('rejected credentials become a recoverable squad connection state', await ben.getByRole('button', { name: 'Reconnect' }).isVisible())
await ben.getByRole('button', { name: 'Reconnect' }).click()
await ben.getByRole('button', { name: 'Join', exact: true }).click()
await ben.locator('.room-ticket').waitFor({ timeout: 10000 })
await expect('Ben can rejoin the same room with a fresh room identity', await ben.locator('.room-ticket').getByText(code).isVisible())

// Cleanup: ending each night closes its squad membership automatically.
await ana.getByRole('navigation', { name: 'Active night navigation' }).getByRole('button', { name: 'Drinks', exact: true }).click()
await ana.getByRole('button', { name: 'End the night' }).click()
await ana.getByRole('button', { name: /End night and make recap/ }).click()
await ben.getByRole('navigation', { name: 'Active night navigation' }).getByRole('button', { name: 'Drinks', exact: true }).click()
await ben.getByRole('button', { name: 'End the night' }).click()
await ben.getByRole('button', { name: /End night and make recap/ }).click()
await expect('ending the night clears room credentials on both devices', await ana.evaluate(() => JSON.parse(localStorage.getItem('beerify:v2')).room === null) && await ben.evaluate(() => JSON.parse(localStorage.getItem('beerify:v2')).room === null))

await browser.close()
if (fails.length) {
  console.error(`\n${fails.length} check(s) failed`)
  process.exit(1)
}
console.log('\nAll room e2e checks passed')
