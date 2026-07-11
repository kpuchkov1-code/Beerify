# Beerify for iPhone

Beerify is packaged with Capacitor 8 as a native iOS application. The React UI is bundled inside the app; room and account requests use the deployed HTTPS API.

## What is already implemented

- Xcode project in `ios/App` with bundle identifier `app.beerify.mobile`.
- Opaque 1024px App Store icon and native launch screen assets.
- Light iOS status-bar content over Beerify's bottle-green shell.
- Native impact haptics for drink and water logging.
- Native share sheet for room invitations.
- `beerify://join?room=ABC234` deep links and HTTPS invite-page fallback.
- CORS support for the native app's room and account API calls.
- iOS 15 minimum deployment target and Capacitor Swift Package Manager integration.

## Build on a Mac

Apple builds and signs iPhone apps only through macOS/Xcode. On a Mac with Node 22 and Xcode 26 or newer:

```bash
npm ci
cp .env.ios.example .env.production.local
npm run ios:sync
npm run ios:open
```

In Xcode:

1. Select the `App` target, then **Signing & Capabilities**.
2. Choose the Apple Developer team and change `app.beerify.mobile` if that identifier is unavailable.
3. Select an iPhone or simulator and run the app.
4. For TestFlight, choose **Product → Archive**, validate, then upload to App Store Connect.

`npm run ios:sync` is the repeatable update command after any React change. It rebuilds the web bundle, copies it into the native project, updates plugins, and normalizes Windows-generated Swift paths.

## Before TestFlight

- Deploy the current server functions first; the iOS build needs their native CORS responses.
- Configure production Upstash variables so Crew rooms survive server restarts.
- Add `beerify://auth/callback` to Supabase Auth's allowed redirect URLs before testing native magic links.
- Add working privacy-policy and support URLs in App Store Connect.
- Complete Apple's current alcohol-related age-rating questions.
- Test room creation, joining, invite sharing, background/resume, account magic links, recap sharing, and offline error states on a real iPhone.
- In review notes, explain that accounts are optional and that BAC figures are estimates rather than legal or medical measurements.

Apple requires current submissions to be built with Xcode 26 and the iOS 26 SDK. App Review also expects more than a simple website wrapper; Beerify's native haptics, share sheet, deep links, local history, live rooms, rounds, and recap generation provide the app-specific functionality.
