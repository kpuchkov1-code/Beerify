import { chromium, devices, webkit } from 'playwright'
import { mkdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const BASE = process.env.BASE_URL ?? 'http://localhost:4173'
const SHOTS = fileURLToPath(new URL('../output/playwright/', import.meta.url))
mkdirSync(SHOTS, { recursive: true })
const browser = await (process.env.BROWSER === 'webkit' ? webkit : chromium).launch()
const page = await browser.newPage({ ...devices['iPhone 13'] })
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
  await page.getByRole('button', { name: 'Enter Beerify' }).click()
  await expect('home greets Sam', await page.getByText('Alright, Sam?').isVisible())
  await expect('Lightweight is the default', await page.getByRole('button', { name: /Lightweight/ }).getAttribute('aria-pressed') === 'true')
  await expect('meal choices use two columns', (await page.locator('.meal-picker > div').evaluate((element) => getComputedStyle(element).gridTemplateColumns.split(' ').length)) === 2)
  await page.screenshot({ path: SHOTS + 'beerify-home-390.png', fullPage: true })
  await page.setViewportSize({ width: 320, height: 568 })
  await expect('favourites fit at 320px', await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth))
  await page.screenshot({ path: SHOTS + 'beerify-home-320.png', fullPage: true })
  await page.setViewportSize({ width: 390, height: 664 })
  await page.getByRole('button', { name: 'Crew', exact: true }).click()
  await expect('leaderboard choices are Drinks, Social and Chaos', await page.getByRole('button', { name: 'Drinks', exact: true }).isVisible() && await page.getByRole('button', { name: 'Social', exact: true }).isVisible() && await page.getByRole('button', { name: 'Chaos', exact: true }).isVisible())
  await page.screenshot({ path: SHOTS + 'beerify-room-entry-390.png', fullPage: true })
  await page.getByRole('button', { name: 'Tonight', exact: true }).click()
  await page.getByRole('button', { name: /Pissed/ }).click()
  await page.getByRole('button', { name: 'Start the night →' }).click()
  await expect('active night navigation shows Drinks, Crew and More', await page.getByRole('navigation', { name: 'Active night navigation' }).getByRole('button').count() === 3)
  await expect('meter starts at zero', await page.locator('.meter__value').getByText('.000', { exact: true }).isVisible())
  await page.getByRole('button', { name: 'Crew', exact: true }).click()
  await expect('Crew stays available during an active solo night', await page.getByRole('heading', { name: 'Crew', exact: true }).isVisible() && await page.getByRole('button', { name: 'Create room' }).isVisible())
  await page.getByRole('navigation', { name: 'Active night navigation' }).getByRole('button', { name: 'Drinks', exact: true }).click()
  await page.getByRole('button', { name: 'More', exact: true }).click()
  await page.screenshot({ path: SHOTS + 'beerify-night-more-390.png' })
  await page.getByRole('button', { name: /History Past nights and recaps/ }).click()
  await expect('History opens without ending the night', await page.getByRole('heading', { name: 'Receipts from previous chaos' }).isVisible())
  await expect('More closes after choosing History', !(await page.locator('#active-night-more').isVisible()))
  await page.getByRole('button', { name: 'More', exact: true }).click()
  await page.getByRole('button', { name: /Profile Details and preferences/ }).click()
  await expect('Profile opens without ending the night', await page.getByRole('heading', { name: 'Sam', exact: true }).isVisible())
  await page.getByRole('navigation', { name: 'Active night navigation' }).getByRole('button', { name: 'Drinks', exact: true }).click()
  await page.waitForTimeout(100)
  await page.screenshot({ path: SHOTS + 'beerify-night-390.png', fullPage: true })
  await page.getByRole('button', { name: 'Choose drink' }).click()
  await expect('drink flow starts with type', await page.getByRole('heading', { name: 'What did you drink?' }).isVisible())
  await page.getByRole('button', { name: /Lager pint/ }).click()
  await expect('drink flow asks for brand', await page.getByRole('heading', { name: 'Which brand?' }).isVisible())
  await expect('brand flow offers known and other brands', await page.getByRole('button', { name: /Stella Artois Lager pint/ }).isVisible() && await page.getByRole('button', { name: /Other brand/ }).isVisible())
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
  await page.emulateMedia({ reducedMotion: 'reduce' })
  const reducedMotionApplied = await page.evaluate(
    () => getComputedStyle(document.documentElement).scrollBehavior === 'auto',
  )
  await expect('reduced-motion styles apply', reducedMotionApplied)
} finally {
  await browser.close()
}
if (failures.length) process.exitCode = 1
