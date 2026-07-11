# Beerify

Beerify is a mobile-first social app for nights out. Open a private room, share a six-character code or QR link, log the order, react to friends, organise rounds and publish a recap when the tab closes.

## What ships

- Five pub-slang vibe bands on a vertical slider: Lightweight, Buzzing, Pissed, Battered and Blackout.
- Searchable built-in drinks, ten popular beer presets, and custom brand, serving-size and ABV presets.
- Live rooms with member status, moments, reactions, synchronized cheers and a round-order rota.
- Immutable local night history, BAC projections and shareable canvas recap images.
- Guest-first use with optional passwordless Supabase sync.
- Original drink pictograms plus web-fetched brand marks with text fallbacks; trademark files are not bundled.
- A playful pub-experience persona personalises shortcuts and coach copy without changing BAC maths.

## Development

```bash
npm install
npm run dev
npm run check
npm run build
npm run preview
```

`npm run check` runs oxlint, client and API TypeScript checks, and the focused BAC/storage tests. With a preview server on port 4173, run `npm run e2e`. The deployed two-user room flow is `BASE_URL=https://your-app.example npm run e2e:rooms`.

## iPhone application

The generated Capacitor iOS project lives in `ios/App`. Run `npm run ios:sync` after web changes, then open and sign it on macOS with `npm run ios:open`. The complete TestFlight and App Store handoff is in [IOS_RELEASE.md](IOS_RELEASE.md).

## Expo Go

Install Expo Go, keep the phone and this PC on the same Wi-Fi, and run `npm run expo:go`. Scan Expo's QR code to open the SDK 54 shell from `expo-go/`; it loads the same Beerify app from the local Vite server, so changes stay in sync.

To use a deployed build instead, start Expo from `expo-go/` with `EXPO_PUBLIC_BEERIFY_URL` set to its HTTPS URL.

## Upstash Redis rooms

Rooms use Upstash Redis rather than Edge Config because they are write-heavy and ephemeral. Connect an Upstash Redis database to the Vercel project and provide:

During `npm run dev`, the same `/api/room` handler uses an in-memory store when Upstash variables are absent. Local rooms work across browser tabs but reset when the dev server restarts.

| Variable | Purpose |
| --- | --- |
| `UPSTASH_REDIS_REST_URL` | Serverless Redis REST endpoint |
| `UPSTASH_REDIS_REST_TOKEN` | Server-side Redis token |

Room metadata, members and the latest 50 events expire 24 hours after the last activity. Member tokens are generated in the browser and stored hashed on the server.

## Optional Supabase accounts

Guests do not need an account. To enable passwordless sync, create a Supabase project, run the SQL migration in `supabase/migrations`, configure the authentication redirect URL, and add:

| Variable | Visibility | Purpose |
| --- | --- | --- |
| `VITE_SUPABASE_URL` | Browser | Supabase project URL |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Browser | RLS-protected publishable key |
| `SUPABASE_URL` | Server | Project URL used for account deletion |
| `SUPABASE_SERVICE_ROLE_KEY` | Server only | Deletes an authenticated account; never expose to Vite |

Without these variables the Profile screen stays in guest mode and all personal data remains in `localStorage`.

## Browser checks

Install Playwright's Chromium once if needed:

```bash
npx playwright install chromium
```

The application uses native dialogs, visible keyboard focus, reduced-motion fallbacks and 44px minimum interactive targets. Verify the final build at 320px, 375px, 430px and desktop widths before deployment.

## Estimation model

UK units use 10ml / 8g of ethanol. BAC is a conservative Widmark-based estimate with gradual per-drink absorption and a fixed `0.012% BAC/hour` elimination rate. It is entertainment and pacing context, not a legal measurement.
