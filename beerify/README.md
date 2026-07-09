# 🍺 Beerify

**Your friendly AI drinking buddy.** Pick how merry you want to get, tap giant emoji
buttons as you drink, and Beerify's coach keeps you right in your sweet spot — not
past it. The next morning it hands you a sunny recap of your units.

Built mobile-first for iPhone. Works great added to the Home Screen (PWA manifest +
apple touch icon included).

## Features

- **Vibe picker**: choose your target zone from five stages: Light glow 🙂,
  Gentle buzz 😊, Happily tipsy 😄, Properly merry 🥳, or Big night 🤪. Each maps
  to an estimated BAC band.
- **Night Out mode**: huge one-tap buttons for 🍺 Beer, 🥃 Shot, 🍷 Wine and
  🍹 Cocktail (plus 💧 Water breaks), with haptic feedback and undo.
- **Animated beer mug**: an SVG mug that fills as your estimated BAC rises, with
  a rolling wave surface, foam, bubbles, your target zone drawn on the glass, and
  a ghost fill for alcohol that is still absorbing.
- **Live AI coach**: a rule-based assistant reads your estimated BAC curve, your
  pacing, and your hydration, then tells you whether to sip, cruise, or switch to
  water. If you go far past your zone it pauses drink logging entirely.
- **Rooms**: create a room, share the 4-character code, and see how merry your
  friends are (status, drink count, units, and a mini mug) all night. Backed by a
  serverless API on Vercel Edge Config; no accounts needed.
- **Morning-after summary**: total units, drink breakdown, peak BAC and when it
  happened, water breaks, an estimated all-clear time, and a friendly verdict on
  how well you held your zone.
- **History**: past nights with their unit totals, all stored locally on-device
  (`localStorage`).

## The science-ish bits

- Estimates use the **Widmark formula** with ease-out per-drink absorption
  windows, personalised by weight, body type, and drinking frequency collected at
  onboarding (regular drinkers clear alcohol faster: elimination is tuned from
  0.012 to 0.020 %BAC/hour by tolerance).
- Units are **UK units** (1 unit = 8 g / 10 ml of pure ethanol).
- These are population-average estimates for pacing yourself, **never** a legal or
  medical measurement. Never drink and drive.

## Rooms backend

`api/room.ts` is a Vercel serverless function storing room state in **Vercel
Edge Config**: reads go through the unlimited data-plane endpoint, writes through
the management API (rate-limit tolerant; each member only writes their own key,
so squad updates never clobber each other). It needs these project env vars:

| Var | Value |
| --- | --- |
| `EDGE_CONFIG_ID` | Edge Config store id (`ecfg_...`) |
| `EC_READ_TOKEN` | Edge Config read access token |
| `EC_API_TOKEN` | Vercel API token (for writes) |
| `EC_TEAM_ID` | Vercel team id |

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
