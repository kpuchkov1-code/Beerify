/**
 * End-to-end smoke test: onboard, start a night, tap drinks, fast-forward the
 * clock, and verify the BAC readout and coach react. Run with the preview
 * server on :4173: node scripts/e2e-check.mjs
 */
import { chromium, devices } from 'playwright'
import { mkdirSync } from 'node:fs'

const BASE = process.env.BASE_URL ?? 'http://localhost:4173'
const SHOTS = new URL('../shots/', import.meta.url).pathname
mkdirSync(SHOTS, { recursive: true })

const browser = await chromium.launch()
const ctx = await browser.newContext({ ...devices['iPhone 13'] })
const page = await ctx.newPage()
await page.clock.install()

const fails = []
async function expect(desc, cond) {
  if (!cond) {
    fails.push(desc)
    console.log(`FAIL  ${desc}`)
  } else {
    console.log(`ok    ${desc}`)
  }
}

await page.goto(BASE)
await page.screenshot({ path: SHOTS + '01-welcome.png' })
await expect('welcome screen shows Beerify', await page.getByRole('heading', { name: 'Beerify' }).isVisible())

await page.getByRole('button', { name: "Let's set you up" }).click()
await page.getByPlaceholder('Your name').fill('Sam')
await page.getByPlaceholder('e.g. 72').fill('80')
await page.getByRole('button', { name: 'Male', exact: true }).click()
await expect(
  'continue disabled until tolerance picked',
  await page.getByRole('button', { name: 'Done, take me in 🍻' }).isDisabled(),
)
await page.getByRole('button', { name: /Sometimes/ }).click()
await page.screenshot({ path: SHOTS + '02-onboarding.png' })
await page.getByRole('button', { name: 'Done, take me in 🍻' }).click()

await expect('home greets Sam', await page.getByRole('heading', { name: /Sam/ }).isVisible())
await expect('five stages listed', (await page.locator('.target-card').count()) === 5)
await page.getByRole('button', { name: /Happily tipsy/ }).click()
await page.screenshot({ path: SHOTS + '03-home.png' })
await page.getByRole('button', { name: 'Start night out 🌙' }).click()

await expect('meter starts at .000', (await page.locator('.meter__value').textContent()) === '.000')

await page.getByRole('button', { name: 'Log one Beer' }).click()
await page.getByRole('button', { name: 'Log one Shot' }).click()

// 3 minutes later the readout must already be moving.
await page.clock.fastForward('03:00')
await page.waitForTimeout(300)
const at3 = await page.locator('.meter__value').textContent()
await expect(`BAC nonzero 3 min after drinks (got ${at3})`, at3 !== '.000')
const coach3 = await page.locator('.coach__text').textContent()
await expect(`coach does not claim zero (got "${coach3}")`, !/zero|sober again/i.test(coach3 ?? ''))
await expect('incoming hint visible', await page.locator('.meter__incoming-hint').isVisible())
await page.screenshot({ path: SHOTS + '04-night-3min.png' })

// After 30 min the two drinks are mostly absorbed.
await page.clock.fastForward('27:00')
await page.waitForTimeout(300)
const at30 = await page.locator('.meter__value').textContent()
await expect(`BAC at 30 min in a sensible range (got ${at30})`, Number('0' + at30) >= 0.02)
await page.screenshot({ path: SHOTS + '05-night-30min.png' })

const units = await page.locator('.night__meta span').first().textContent()
await expect(`meta shows 2 drinks and units (got "${units}")`, /2 drinks · 4 units/.test(units ?? ''))

await page.getByRole('button', { name: 'Log a water' }).click()
await page.getByRole('button', { name: 'End night' }).click()
await page.getByRole('button', { name: /End night, sleep tight/ }).click()

await expect('recap card on home', await page.getByText('Your night recap is ready').isVisible())
await page.getByText('Your night recap is ready').click()
await page.screenshot({ path: SHOTS + '06-summary.png', fullPage: true })
await expect('summary shows units stat', await page.getByText('units of alcohol').isVisible())
await expect('summary shows breakdown', await page.getByText('1× Beer').isVisible())

await browser.close()
if (fails.length) {
  console.error(`\n${fails.length} check(s) failed`)
  process.exit(1)
}
console.log('\nAll e2e checks passed')
