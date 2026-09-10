# Table Tennis Scoreboard — Phase 1

Core scoring engine + basic UI, per the MVP plan (Phase 1 of 6). Singles only.

## What's in this phase

- `lib/models/scoring_engine.dart` — the scoring state machine (pure Dart,
  no Flutter dependency): points → games (11, win-by-2, deuce) → match
  (best-of-3/5/7), serve rotation, change-of-ends (including the deciding-game
  5-point rule), undo, reset.
- `lib/screens/setup_screen.dart` — pick best-of format, "toss" for who
  serves first.
- `lib/screens/scoreboard_screen.dart` — the two-tap scoring UI: tap either
  side to score, undo button, reset button, server indicator, banners for
  game/match completion.
- `test/scoring_engine_test.dart` — unit tests for the scoring logic.
- `test/widget_test.dart` — automated UI tests that drive the actual app
  (tap zones, undo, game/match completion, the "new match" flow).

**Deliberately NOT in this phase** (see the MVP doc, §4 and §9): voice
announcements, localization, doubles, monetization, the expedite system,
time-outs, toweling-down breaks. Those are later phases.

## How to run it

This repo only contains the Dart/Flutter source (`lib/`, `test/`,
`pubspec.yaml`) — not the generated platform scaffolding
(`android/`, `windows/`, `web/`, etc.), which Flutter needs in order to
actually launch on a device. Generate it once, then run:

```bash
flutter create .
flutter pub get
flutter run
```

`flutter create .` only adds the missing platform folders — it will not
overwrite `lib/`, `test/`, or `pubspec.yaml`. You only need to run it once
per machine/checkout.

## How to run the tests

```bash
flutter test
```

This runs both `test/scoring_engine_test.dart` (logic) and
`test/widget_test.dart` (UI).

## Important: I could not execute these tests myself

I don't have the Flutter/Dart SDK available in the sandbox I write code in,
and it can't reach pub.dev to install one — so **I have not run `flutter
pub get` or `flutter test` against this code.** I wrote and reasoned through
every test by hand, tracing the exact state transitions the engine goes
through (e.g. working out `currentServer` and the deciding-game 5-point
switch by hand for each assertion), but "I checked it carefully" is not the
same as "it compiles and passes."

**Please run `flutter test` yourself before trusting this as correct**, and
if anything fails, send me the output — I'll fix it immediately. Given you
said you want this to be perfect, treat this as a strong first draft that
needs one real test run to confirm, not a finished, verified artifact.

A few specific things worth double-checking once you can run it:
- The `SegmentedButton` widget (used for best-of selection) has had minor
  API differences across Flutter versions — if `flutter test` complains
  about it, it's likely a version mismatch, not a logic bug.
- The deciding-game change-of-ends test (the trickiest piece of logic here)
  is the one I'd re-read most carefully if something breaks.

## Design decisions worth knowing about

- **Undo** is implemented as a snapshot stack (each point pushes a snapshot
  before applying itself), rather than trying to algebraically reverse a
  point. This is simpler to get right and cheap at this data size.
- **`currentServer`** is computed on demand from total points scored and
  who served first in the game — not stored as separate mutable state — so
  it can never drift out of sync with the score.
- **Change of ends** and **game/match completion** are reported back to the
  UI as one `PointEvent` per point, rather than the UI polling engine state
  after every tap. A completed game always implies a change of ends, so the
  UI shows one banner per point, never two stacked ones.

## Phase 5 — Monetization: what to configure before release

See `PHASE5_MONETIZATION.md` for the full design writeup. This section is
just the release checklist — everything here currently points at
Google/Apple's published **test** IDs, which work out of the box for
development but must never ship to a real store listing.

### AdMob

1. Create a real AdMob app (one for Android, one for iOS) in the
   [AdMob console](https://apps.admob.com/), linked to your Play Console /
   App Store Connect listing.
2. Replace the test **App ID** in:
   - `android/app/src/main/AndroidManifest.xml` — the
     `com.google.android.gms.ads.APPLICATION_ID` meta-data value (currently
     `ca-app-pub-3940256099942544~3347511713`, Google's published Android
     test App ID).
   - `ios/Runner/Info.plist` — the `GADApplicationIdentifier` value
     (currently `ca-app-pub-3940256099942544~1458002511`, Google's
     published iOS test App ID).
3. Create a real **interstitial ad unit** (one per platform) and replace the
   test ad unit IDs in `lib/services/ads_service.dart`
   (`_testInterstitialAdUnitId`) — currently
   `ca-app-pub-3940256099942544/1033173712` (Android) and
   `ca-app-pub-3940256099942544/4411468910` (iOS), Google's published test
   interstitial units.
4. iOS only: before a real (non-test) ad unit can serve personalized ads,
   Apple requires `SKAdNetworkItems` entries in `Info.plist` (a list Google
   publishes and updates) and, if you want personalized ads at all, an App
   Tracking Transparency prompt (`NSUserTrackingUsageDescription` +
   `AppTrackingTransparency.requestTrackingAuthorization`) — neither is
   implemented yet, since it isn't needed for test ads. Non-personalized
   ads (`AdRequest(nonPersonalizedAds: true)`) are simpler and avoid this
   entirely if you'd rather skip it.

### Google Play Billing (in-app purchase)

1. In Play Console, create a non-consumable **in-app product** with a real
   product ID and set its price (the design target was **~€2.99**,
   localized per store — Play Console handles per-country pricing).
2. Replace `proProductId` in `lib/services/purchase_gateway.dart` (currently
   the placeholder `remove_ads_pro_test`) with that real product ID.
3. For testing real purchases before release, add license testers in Play
   Console (Setup → License testing) — test-track purchases by license
   testers don't charge real money.
   **Important:** a purchase dialog cannot appear at all in a debug build
   installed via `flutter run`/`adb install`, no matter how correctly
   everything above is configured — Play Billing only works for a build
   installed through the Play Store itself. Upload a build to at least an
   Internal Testing track and install it via that track's Play Store
   opt-in link before testing purchases. See PHASE5_MONETIZATION.md §10.4
   for the full explanation.
4. iOS: create the matching non-consumable In-App Purchase in App Store
   Connect with the **same product ID** used in
   `purchase_gateway.dart` (the `in_app_purchase` plugin uses one product ID
   across both stores) and use a Sandbox tester account for pre-release
   testing.

### What's already handled

- Ads never show mid-match — only a single interstitial at match end, and
  never at all once Pro is purchased.
- Purchases restore via "Restore purchases" in the Pro dialog (setup
  screen's app-bar icon), with localized (en/de/fr) feedback for every
  outcome: pending, success, restored, cancelled, error, and "nothing to
  restore."
- Nothing in `lib/services/ads_service.dart` or
  `lib/services/purchase_gateway.dart` can crash the app if the platform
  plugin is unavailable (e.g. running in `flutter test`, or on a platform
  without Play Services) — every real call is wrapped and degrades to "no
  ad" / "not Pro" silently, the same pattern already used for
  `VoiceAnnouncer` and `ThemePreference`.

## Phase 6 — Play Console pre-launch prep

See `PHASE6_PRELAUNCH_PREP.md` for the full write-up (GDPR/UMP consent
gating, the application ID change, and what's still a draft for you to
review: the hosted Privacy Policy text and the ASO store-listing copy).
This section is just the two things that need **your** action with a
real secret or account, not just code.

### Release signing (required before any Play Console upload)

Play Console rejects a debug-signed build outright — every release
upload needs a real keystore. Generate one **once**, on your own
machine, and keep it (and its passwords) somewhere safe *outside* this
repo: Google cannot recover a lost signing key, and losing it means you
can never publish an update to the same app listing again.

1. **Generate the keystore** (needs a JDK — `keytool` ships with it;
   the same JDK 17 Flutter/Android already require works fine):

   ```bash
   keytool -genkey -v -keystore /path/to/somewhere/safe/tabletennis-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias tabletennis
   ```

   `keytool` will prompt for a keystore password, your name/organization
   details (shown on the certificate, not in the app), and a key
   password (entering the same value as the keystore password is fine).
   Store the resulting `.jks` file and both passwords somewhere durable
   and private — a password manager or encrypted backup, **never this
   git repo** (see `.gitignore`, which already excludes `*.jks`,
   `*.keystore`, and `android/key.properties`).

2. **Create `android/key.properties`** (this exact path/filename — it's
   already git-ignored) with:

   ```properties
   storePassword=<the keystore password you chose>
   keyPassword=<the key password you chose>
   keyAlias=tabletennis
   storeFile=/path/to/somewhere/safe/tabletennis-release.jks
   ```

   Use an absolute path for `storeFile` so the build finds it regardless
   of where you run `flutter build` from.

3. **That's it.** `android/app/build.gradle.kts` already reads this file
   and signs release builds with it automatically whenever it's present
   — falling back to debug signing (today's behavior) whenever it's
   missing, so this repo keeps building for anyone who hasn't set this
   up yet. Build the release bundle for Play Console with:

   ```bash
   flutter build appbundle
   ```

### Privacy Policy hosting

`lib/services/privacy_links.dart` currently points the in-app "Privacy
Policy" menu item at a placeholder URL. Once you've hosted the drafted
policy (`privacy_policy/`, see `PHASE6_PRELAUNCH_PREP.md`) — e.g. via a
free GitHub Pages site — update that one constant with the real URL,
and paste the same URL into Play Console's Store Listing → Privacy
Policy field (Google requires it there too, separately from the in-app
link).
