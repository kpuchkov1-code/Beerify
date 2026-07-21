import { chromium, devices, webkit } from 'playwright'
import { mkdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const BASE = process.env.BASE_URL ?? 'http://localhost:4173'
const SHOTS = fileURLToPath(new URL('../output/playwright/', import.meta.url))
mkdirSync(SHOTS, { recursive: true })
const browser = await (process.env.BROWSER === 'webkit' ? webkit : chromium).launch()
const page = await browser.newPage({ ...devices['iPhone 13'] })
page.on('pageerror', (error) => console.error('PAGE ERROR', error.message))
await page.clock.install()
const failures = []
const expect = (description, condition) => {
  if (!condition) failures.push(description)
  console.log(`${condition ? 'ok  ' : 'FAIL'}  ${description}`)
}

try {
  await page.goto(BASE)
  await expect('welcome shows Beerify', await page.getByText('BEERIFY').first().isVisible())
  await page.getByRole('button', { name: 'Set up my night' }).click()
  await page.getByPlaceholder('Name or nickname').fill('Sam')
  await page.getByPlaceholder('72').fill('80')
  await page.getByRole('button', { name: 'Male', exact: true }).click()
  await page.screenshot({ path: SHOTS + 'beerify-profile-390.png', fullPage: true })
  await page.getByRole('button', { name: 'Next: pub credentials' }).click()
  await page.screenshot({ path: SHOTS + 'beerify-persona-390.png', fullPage: true })
  await page.getByRole('button', { name: /Weekend athlete/ }).click()
  await page.getByRole('checkbox').check()
  await page.getByRole('button', { name: 'Enter Beerify' }).click()
  await expect('home greets Sam', await page.getByText('Alright, Sam?').isVisible())
  await expect('main navigation has Tonight, Crew, Games, Pubs and More', await page.getByRole('navigation', { name: 'Main navigation' }).getByRole('button').count() === 5)
  await expect('Lightweight is the default', await page.getByRole('button', { name: /Lightweight/ }).getAttribute('aria-pressed') === 'true')
  await expect('meal choices use two columns', (await page.locator('.meal-picker > div').evaluate((element) => getComputedStyle(element).gridTemplateColumns.split(' ').length)) === 2)
  await page.screenshot({ path: SHOTS + 'beerify-home-390.png', fullPage: true })
  await page.setViewportSize({ width: 320, height: 568 })
  await expect('favourites fit at 320px', await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth))
  await page.screenshot({ path: SHOTS + 'beerify-home-320.png', fullPage: true })
  await page.setViewportSize({ width: 390, height: 664 })
  await page.getByRole('button', { name: 'Games', exact: true }).click()
  const gameTitles = ['Heads Up!', 'Psych!', 'Hot Takes', 'Bomb Pass', 'Medusa', 'Bus Driver', 'Dare Ladder', 'Flip Cup', 'Who Said It?', 'ID Game', 'Higher or Lower', 'Kings Cup', 'Would You Rather', 'Most Likely To', 'Never Have I Ever', 'Truth or Dare', 'Trivia Sprint', 'Two Truths & a Lie', 'Categories', 'Emoji Charades', 'Roulette', 'Guess My BAC']
  await page.locator('.game-row').first().waitFor()
  const gameCount = await page.locator('.game-row').count()
  await expect(`all 22 games are present (found ${gameCount})`, gameCount === 22)
  for (const title of gameTitles) {
    const row = page.locator('.game-row', { hasText: title }).first()
    await row.getByRole('button', { name: 'Local' }).click()
    await expect(`${title} opens locally`, await page.locator('.game-play').isVisible())
    await page.getByRole('button', { name: 'Start game' }).click()
    await expect(`${title} starts a local round`, await page.locator('.game-prompt').isVisible())
    await page.getByRole('button', { name: 'Close game' }).click()
  }
  await page.context().clearPermissions()
  await page.context().setGeolocation({ latitude: 51.5, longitude: -0.12 })
  await page.route('**/api/maps?*', async (route) => {
    const url = new URL(route.request().url())
    if (url.searchParams.get('action') === 'nearby') return route.fulfill({ json: { venues: [
      { id: 'one', name: 'The Bottle Green', lat: 51.5, lng: -0.12, type: 'pub' },
      { id: 'two', name: 'The Hop Room', lat: 51.505, lng: -0.115, type: 'bar' },
      { id: 'three', name: 'Night Owl', lat: 51.51, lng: -0.11, type: 'nightclub' },
    ] } })
    return route.fulfill({ json: { distanceMeters: 1800, durationSeconds: 1320, geometry: { type: 'LineString', coordinates: [[-0.12, 51.5], [-0.115, 51.505], [-0.11, 51.51]] } } })
  })
  await page.getByRole('button', { name: 'Pubs', exact: true }).click()
  await page.locator('.pubs-screen').waitFor().catch(() => {})
  await expect('pub tools expose map, crawl, golf and bingo', await page.locator('.pub-tool-tabs button').count() === 4)
  await expect('map attribution remains visible', await page.locator('.map-attribution').isVisible())
  await page.getByRole('button', { name: 'Use my location' }).click()
  await page.getByText(/Location was not shared/).waitFor()
  await expect('location denial keeps pub tools usable', await page.getByText(/cached places and external maps/).isVisible())
  await page.context().grantPermissions(['geolocation'], { origin: new URL(BASE).origin })
  await page.getByRole('button', { name: 'Use my location' }).click()
  await page.getByText('The Bottle Green').waitFor()
  for (const venue of ['The Bottle Green', 'The Hop Room', 'Night Owl']) await page.locator('.venue-list article', { hasText: venue }).getByRole('button', { name: '+ Crawl' }).click()
  await page.getByRole('button', { name: 'Crawl', exact: true }).click()
  await page.getByRole('button', { name: 'Estimate route' }).click()
  await page.getByText(/1.8 km/).waitFor()
  await expect('crawl route returns walking estimates', await page.getByText(/1.8 km/).isVisible())
  await page.getByRole('button', { name: 'Golf', exact: true }).click()
  for (let hole = 0; hole < 3; hole++) {
    await page.getByLabel('Your strokes / sips').fill(String(3 + hole))
    await page.getByLabel('Hole drink').fill(`Drink ${hole + 1}`)
    await page.getByRole('button', { name: hole === 2 ? 'Finish hole' : 'Next hole' }).click()
  }
  await expect('pub golf tracks a complete three-hole card', await page.getByText(/Score:/).isVisible())
  await page.getByRole('button', { name: 'Bingo', exact: true }).click()
  for (let cell = 0; cell < 5; cell++) await page.locator('.bingo-square').nth(cell).click()
  await expect('pub bingo detects the first line', await page.getByText(/BINGO!/).isVisible())
  await page.getByRole('button', { name: 'Crew', exact: true }).click()
  await expect('leaderboard choices are Drinks, Social and Chaos', await page.getByRole('button', { name: 'Drinks', exact: true }).isVisible() && await page.getByRole('button', { name: 'Social', exact: true }).isVisible() && await page.getByRole('button', { name: 'Chaos', exact: true }).isVisible())
  await page.screenshot({ path: SHOTS + 'beerify-room-entry-390.png', fullPage: true })
  await page.getByRole('button', { name: 'Tonight', exact: true }).click()
  await page.getByRole('button', { name: /Pissed/ }).click()
  await page.getByRole('button', { name: 'Start the night →' }).click()
  await expect('active night navigation shows Drinks, Crew, Games and More', await page.getByRole('navigation', { name: 'Active night navigation' }).getByRole('button').count() === 4)
  await expect('meter starts at zero', await page.locator('.meter__value').getByText('.000', { exact: true }).isVisible())
  const crewSwitchStarted = performance.now()
  await page.getByRole('button', { name: 'Crew', exact: true }).click()
  await page.getByRole('heading', { name: 'Crew', exact: true }).waitFor()
  await expect('active-night view switches within 250ms', performance.now() - crewSwitchStarted < 250)
  await expect('Crew stays available during an active solo night', await page.getByRole('heading', { name: 'Crew', exact: true }).isVisible() && await page.getByRole('button', { name: 'Create room' }).isVisible())
  await page.getByRole('navigation', { name: 'Active night navigation' }).getByRole('button', { name: 'Drinks', exact: true }).click()
  await page.getByRole('button', { name: 'More', exact: true }).click()
  await expect('More menu stays compact', await page.locator('#active-night-more').evaluate((element) => element.getBoundingClientRect().height <= 320))
  await page.screenshot({ path: SHOTS + 'beerify-night-more-390.png' })
  await page.getByRole('button', { name: /History Past nights and recaps/ }).click()
  await page.getByRole('heading', { name: 'Receipts from previous chaos' }).waitFor()
  await expect('History opens without ending the night', await page.getByRole('heading', { name: 'Receipts from previous chaos' }).isVisible())
  await expect('More closes after choosing History', !(await page.locator('#active-night-more').isVisible()))
  await page.getByRole('button', { name: 'More', exact: true }).click()
  await page.getByRole('button', { name: /Profile Modes, look and preferences/ }).click()
  await page.getByRole('heading', { name: 'Sam', exact: true }).waitFor()
  await expect('Profile opens without ending the night', await page.getByRole('heading', { name: 'Sam', exact: true }).isVisible())
  await page.getByRole('switch', { name: 'Big-thumb mode' }).check()
  await page.getByRole('navigation', { name: 'Active night navigation' }).getByRole('button', { name: 'Drinks', exact: true }).click()
  await expect('big-thumb mode enlarges drink controls', await page.locator('.quick-drink').first().evaluate((element) => element.getBoundingClientRect().height >= 140))
  await page.waitForTimeout(100)
  await page.screenshot({ path: SHOTS + 'beerify-night-390.png', fullPage: true })
  await page.getByRole('button', { name: 'Choose drink' }).click()
  await expect('drink flow starts with type', await page.getByRole('heading', { name: 'What did you drink?' }).isVisible())
  await page.getByRole('button', { name: /Lager pint/ }).click()
  await expect('drink flow asks for brand', await page.getByRole('heading', { name: 'Which brand?' }).isVisible())
  await expect('brand flow offers known and other brands', await page.getByRole('button', { name: /Stella Artois Lager pint/ }).isVisible() && await page.getByRole('button', { name: /Other brand/ }).isVisible())
  for (const [width, height] of [[320, 568], [375, 667], [430, 932]]) {
    await page.setViewportSize({ width, height })
    const panelFits = await page.locator('.dialog-sheet--tall').evaluate((element) => {
      const rect = element.getBoundingClientRect()
      return rect.top >= 0 && rect.bottom <= window.innerHeight
    })
    await expect(`drink picker fits at ${width}px`, panelFits)
  }
  await page.setViewportSize({ width: 390, height: 664 })
  await page.screenshot({ path: SHOTS + 'beerify-drink-brand-390.png', fullPage: true })
  await page.getByRole('button', { name: 'Close drinks' }).click()
  await page.getByRole('button', { name: 'Log Guinness' }).click()
  await page.getByRole('button', { name: 'Log Stella Artois' }).click()
  await page.clock.fastForward('03:00')
  await page.waitForTimeout(200)
  const value = await page.locator('.meter__value').textContent()
  await expect(`BAC moves after drinks (${value})`, value !== '.000')
  await page.screenshot({ path: SHOTS + 'beerify-night-filled-390.png', fullPage: true })
  await page.getByRole('button', { name: /Water/ }).click()
  await page.getByRole('button', { name: 'End the night' }).click()
  await page.getByRole('button', { name: 'End night and make recap' }).click()
  await page.getByRole('button', { name: /Receipts from previous chaos/ }).click().catch(() => {})
  await expect('history contains the night', await page.getByText(/2 drinks/).isVisible())
  await page.locator('.receipt-list button').first().click()
  await page.getByRole('heading', { name: 'The order' }).waitFor()
  await expect('summary shows the order', await page.getByRole('heading', { name: 'The order' }).isVisible())
  for (const [name, width, height] of [
    ['phone-320', 320, 568],
    ['phone-375', 375, 667],
    ['phone-430', 430, 932],
    ['tablet', 768, 1024],
    ['desktop', 1440, 900],
  ]) {
    await page.setViewportSize({ width, height })
    const noOverflow = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)
    await expect(`${name} has no horizontal overflow`, noOverflow)
    await page.screenshot({ path: `${SHOTS}beerify-summary-${name}.png`, fullPage: true })
  }
  await page.setViewportSize({ width: 390, height: 664 })
  await page.getByRole('button', { name: 'Back to Beerify' }).click()
  await page.getByRole('button', { name: 'Tonight', exact: true }).click()
  await page.getByRole('button', { name: /Sober/ }).click()
  await expect('sober setup hides alcohol target controls', !(await page.getByRole('button', { name: /Blackout/ }).isVisible()))
  await page.getByRole('button', { name: /Start sober mode/ }).click()
  await expect('sober mode locks drink logging', await page.getByText('Alcohol logging is locked for this night. Waters still count.').isVisible() && !(await page.getByRole('button', { name: 'Choose drink' }).isVisible()))
  await page.locator('.water-mode-stage').getByRole('button', { name: 'Log water' }).click()
  await expect('sober mode emphasizes water tracking', await page.locator('.water-mode-stage').getByText('1', { exact: true }).isVisible())
  await page.emulateMedia({ reducedMotion: 'reduce' })
  const reducedMotionApplied = await page.evaluate(
    () => getComputedStyle(document.documentElement).scrollBehavior === 'auto',
  )
  await expect('reduced-motion styles apply', reducedMotionApplied)
} finally {
  await browser.close()
}
if (failures.length) process.exitCode = 1
