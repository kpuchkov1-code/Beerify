# 🍺 Beerify

**Your friendly AI drinking buddy.** Pick how merry you want to get, tap giant emoji
buttons as you drink, and Beerify's coach keeps you right in your sweet spot — not
past it. The next morning it hands you a sunny recap of your units.

Built mobile-first for iPhone. Works great added to the Home Screen (PWA manifest +
apple touch icon included).

## Features

- **Vibe picker** — choose your target zone: Gentle buzz 😊, Happily tipsy 😄, or
  Properly merry 🥳. Each maps to an estimated BAC band.
- **Night Out mode** — huge one-tap buttons for 🍺 Beer, 🥃 Shot, 🍷 Wine and
  🍹 Cocktail (plus 💧 Water breaks), with haptic feedback and undo.
- **Live AI coach** — a rule-based assistant reads your estimated BAC curve
  (Widmark formula with gradual absorption), your pacing, and your hydration, then
  tells you whether to sip, cruise, or switch to water. If you go far past your
  zone it pauses drink logging entirely.
- **BAC gauge** — a live dial showing where you are relative to your chosen zone.
- **Morning-after summary** — total units, drink breakdown, peak BAC and when it
  happened, water breaks, an estimated all-clear time, and a friendly verdict on
  how well you held your zone.
- **History** — past nights with their unit totals, all stored locally on-device
  (`localStorage`). Nothing leaves your phone.

## The science-ish bits

- Estimates use the **Widmark formula** with per-drink linear absorption windows
  and a constant elimination rate of 0.015 %BAC/hour, personalised by weight and
  body type collected at onboarding.
- Units are **UK units** (1 unit = 8 g / 10 ml of pure ethanol).
- These are population-average estimates for pacing yourself — **never** a legal or
  medical measurement. Never drink and drive.

## Development

```bash
npm install
npm run dev      # local dev server
npm run build    # type-check + production build
npm run lint     # oxlint
npx tsx scripts/sanity-check.ts   # spot-check the BAC engine numbers
```

Stack: React 19 + TypeScript + Vite. No backend, no accounts, no tracking.

## Regenerating the app icon

`public/icon.png` is generated (dependency-free) by:

```bash
node scripts/gen-icon.mjs
```
