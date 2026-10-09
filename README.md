# Table Tennis Scoreboard

A courtside scoring app for real, physical table tennis matches, built with
Flutter and published on Google Play as
`com.kozmokramer.tabletennisscoreboard`.

- **Singles and doubles**, best of 3, 5 or 7, following the ITTF laws for
  games to 11, deuce, serve rotation (including the doubles
  server/receiver cycle) and change of ends.
- **Two-tap scoring**: tap a side to score, with undo, long-press score
  correction, and a coin toss for who serves first.
- **Voice announcements** of the score and key events (deuce, match point,
  game, change ends), using the device's own voice or a bundled English
  clip set, with a mute toggle.
- **English, German and French**, auto-detected from the device and
  switchable in the menu. Light, dark and system themes.
- **"How to use"** help page in the menu: one scrolling page of short
  illustrated cards (`lib/screens/help_screen.dart`).
- **"Rate this app"** in the menu, plus a one-time review request after
  the third completed match (see below).

Ads and the "Remove Ads / Pro" purchase are implemented but switched off
for launch by one flag; see `PHASE7_MONETIZATION_DISABLED_FOR_LAUNCH.md`.

`PHASES.md` has the overall plan, and each `PHASE*_*.md` file documents
one phase's decisions in detail.

## How to run it

```bash
flutter pub get
flutter run
```

After editing any `lib/l10n/*.arb` file, regenerate the (committed)
localization classes with `flutter gen-l10n`.

## How to run the tests

```bash
flutter analyze
flutter test                                  # everything
flutter test test/scoring_engine_test.dart    # one file
```

The tests need no device or plugins: every platform plugin sits behind an
interface whose real implementation fails silently, and tests inject
fakes.

## Rating the app

Built on the `in_app_review` package, behind the `ReviewService` interface
in `lib/services/review_service.dart`.

- **Menu item.** "Rate this app" opens the Play Store listing directly.
  It never uses the in-app review sheet: Google quota-limits that sheet
  and may silently show nothing, so it must not be tied to a button.
- **Automatic request.** After the third completed match, once the match
  result has been dismissed, the app asks for the review sheet a single
  time. It never asks during a match, never again on the same install,
  and never if the menu item was already used. It only ever requests the
  in-app sheet (no store redirect), so it is easy to ignore.

The rules live in the pure function `shouldAutoPromptReview` in
`lib/services/review_prompter.dart`; the counters and flags are stored
with `shared_preferences`. The review sheet only appears in a build
installed from Google Play (an internal testing track is enough).

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

1. ~~Create a real AdMob app (one for Android, one for iOS) in the
   [AdMob console](https://apps.admob.com/), linked to your Play Console /
   App Store Connect listing.~~ **Done for Android** (Phase 6) — the iOS
   app still needs to be created once there's an App Store Connect
   listing to link it to.
2. Replace the test **App ID** in:
   - ~~`android/app/src/main/AndroidManifest.xml` — the
     `com.google.android.gms.ads.APPLICATION_ID` meta-data value~~ **Done**
     — now the real Android App ID, `ca-app-pub-6492606197522712~9507845967`.
   - `ios/Runner/Info.plist` — the `GADApplicationIdentifier` value
     (currently `ca-app-pub-3940256099942544~1458002511`, Google's
     published iOS test App ID) — **still pending**, no iOS AdMob app
     exists yet.
3. Create a real **interstitial ad unit** (one per platform) and replace the
   test ad unit IDs in `lib/services/ads_service.dart`
   (`_interstitialAdUnitId`):
   - ~~Android: currently `ca-app-pub-3940256099942544/1033173712`,
     Google's published test interstitial unit~~ **Done** — now the real
     unit, `ca-app-pub-6492606197522712/3632702751`.
   - iOS: currently `ca-app-pub-3940256099942544/4411468910`, Google's
     published test interstitial unit — **still pending**.
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

4. **Sanity-check that a release build actually launches, on a real
   device, before uploading.** A real release APK (`flutter build apk
   --release`) was once found crashing immediately on launch with
   `Failed to create an instance of androidx.work.impl.WorkDatabase` —
   R8 (only enabled for release builds, never debug/profile) was
   stripping pieces of WorkManager's Room-generated database with no
   ProGuard keep rule protecting it. **Already fixed** —
   `android/app/proguard-rules.pro` now keeps `androidx.work.**`/Room
   classes, wired into the release build type's `proguardFiles` — but
   since `flutter test`/`flutter run` (debug) never exercise R8 at all,
   any *future* release-only crash of this kind would go unnoticed the
   same way until an actual release build is installed and opened.
   Before every Play Console upload:

   ```bash
   flutter build apk --release
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

   then actually open the app on the device and play a few points —
   don't rely on `flutter build` succeeding alone, since a build that
   compiles fine can still crash at runtime under R8.

### Privacy Policy hosting

`lib/services/privacy_links.dart` currently points the in-app "Privacy
Policy" menu item at a placeholder URL. Once you've hosted the drafted
policy (`privacy_policy/`, see `PHASE6_PRELAUNCH_PREP.md`) — e.g. via a
free GitHub Pages site — update that one constant with the real URL,
and paste the same URL into Play Console's Store Listing → Privacy
Policy field (Google requires it there too, separately from the in-app
link).
