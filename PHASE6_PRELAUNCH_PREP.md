# Phase 6 — Play Console pre-launch prep

Not a new feature phase — this is the infrastructure/compliance work
needed before this app can be uploaded to Play Console at all, even to
an Internal Testing track. (Note: this reuses the "Phase 6" label from
the user's request; it is unrelated to `PHASES.md`'s own Phase 6 —
"Club / federation go-to-market" — which is still a later, separate
phase.)

## Summary: what's done vs. what needs your action

| # | Item | Status |
|---|------|--------|
| 1 | GDPR/EEA ad consent (UMP SDK) | **Done** — code + tests, but see "External action" below: you must configure the consent message in AdMob console before it will actually load. |
| 2 | Application ID (away from `com.example`) | **Done** — draft pick, easy to change before you publish. |
| 3 | Release signing | **Infra done** — you must generate the actual keystore yourself (README.md). |
| 4a | Hosted Privacy Policy (en/de/fr) | **Drafted** — you must host it and give me the URL. |
| 4b | In-app "Privacy Policy" menu item | **Done** — points at a placeholder URL until 4a is hosted. |
| 5 | ASO store listing text (en/de/fr) | **Drafted** in `STORE_LISTING.md` — for your review. |

---

## 1. GDPR/EEA ad consent (Google UMP SDK)

`google_mobile_ads` (already a dependency since Phase 5) bundles
Google's User Messaging Platform (UMP) SDK — no new native dependency
was needed, just new Dart-side integration:

- **`lib/services/consent_service.dart`** — a new `ConsentService`
  abstraction (same pattern as `AdsService`/`PurchaseGateway`): a real
  `UmpConsentService` wraps the actual UMP APIs
  (`ConsentInformation.requestConsentInfoUpdate`,
  `ConsentForm.loadAndShowConsentFormIfRequired`,
  `ConsentInformation.canRequestAds`,
  `ConsentInformation.getPrivacyOptionsRequirementStatus`,
  `ConsentForm.showPrivacyOptionsForm`).
- **`lib/services/monetization_controller.dart`** — `initialize()` now
  calls `consent.gatherConsent()` (which shows Google's consent form
  only if UMP determines it's required — i.e. an EEA/UK user who hasn't
  decided yet; everyone else sees nothing extra) **before** `ads.
  initialize()`/`ads.loadInterstitial()` ever run, and the ad preload
  only proceeds if `consent.canRequestAds()` comes back true. This is
  the actual gate requested: no ad request can happen before consent is
  resolved one way or the other.
- A new `privacyOptionsRequired` flag (set once `gatherConsent()`
  resolves) and `openPrivacyOptionsForm()` method back the "Privacy
  options" menu entry — see below.
- **`SetupScreen`'s overflow menu** gained two items, right below
  "Remove Ads / Pro":
  - **"Privacy options"** — only shown when `privacyOptionsRequired` is
    true (i.e. UMP determined this is an EEA/UK user with a consent
    decision on file). Re-opens the UMP consent form so they can review
    or withdraw consent.
  - **"Privacy Policy"** — always shown; opens the hosted policy URL
    (see §4 below) via `url_launcher` (new dependency).
- All three new user-facing strings (`privacyOptionsMenuItem`,
  `privacyPolicyMenuItem`) are localized in `lib/l10n/app_{en,de,fr}.
  arb`, following this app's existing localization pattern exactly. The
  UMP consent *form* itself is localized automatically by Google's SDK
  (it renders in the device's language) — nothing here controls that
  text.

### A genuinely tricky bug found while building this

`ConsentInformation.requestConsentInfoUpdate` is a callback-based API
(`void`, not `Future<void>`) whose own internal implementation only
catches `PlatformException` — not `MissingPluginException`, which is
exactly what `flutter test`'s environment throws for any platform
channel with no real implementation registered (there's no real UMP
platform plugin available under `flutter test`). Left unguarded, this
would surface as an **unhandled async exception failing whatever test
happened to be running** at the time — a real risk given dozens of
existing widget tests construct `SetupScreen`/`ScoreboardScreen`/
`DoublesScoreboardScreen` without injecting a fake `MonetizationController`,
meaning they exercise the real `UmpConsentService` by default (the same
way they already exercise the real `AdMobAdsService`). `UmpConsentService.
gatherConsent()` wraps this specific call in `runZonedGuarded` to catch
that failure mode; every other UMP method here is a normal
`Future`-returning call, safe to `await` inside an ordinary `try`/`catch`
(same pattern `AdsService` already uses). Confirmed via a full `flutter
test` run — see "Test results" below.

### External action required — configure the consent message in AdMob console

**Integrating the UMP SDK is necessary but not sufficient.** Google
requires you to also create and publish a GDPR message in **AdMob
console → Privacy & messaging → [your app] → GDPR** (or the newer
"Consent Management" flow) before `loadAndShowConsentFormIfRequired`
will actually have anything to show — without it, UMP will simply
report "not required" for everyone, silently, with no error. This is a
one-time setup step in the AdMob web console, not code; it needs your
AdMob account. Follow Google's own current setup flow there — it walks
through choosing an ad-partner message template and publishing it.

---

## 2. Application ID change

Changed away from the default `com.example.tabletennis_scoreboard`,
which Play Console rejects at upload:

- **Android:** `com.kozmokramer.tabletennisscoreboard` — set in
  `android/app/build.gradle.kts` (`namespace` and `applicationId`), and
  `MainActivity.kt` moved to match
  (`android/app/src/main/kotlin/com/kozmokramer/tabletennisscoreboard/`).
- **iOS:** `com.kozmokramer.tabletennisScoreboard` — set in
  `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`,
  both the app target and its test target).

**This is a draft pick** — derived from your own identity (not a
registered domain you necessarily own), not something you asked me to
confirm a specific string for, so I picked a reasonable one rather than
blocking on it. It's trivial to change again now (find/replace the
strings above, rename the `MainActivity.kt` package directory to match)
— but **cannot** be changed after your first real Play Console upload
without becoming an entirely separate app listing (losing any reviews/
install history). Please rename it now, before your first upload, if
you'd rather use something else (e.g. a domain you actually own,
reversed).

The audio-ducking platform-channel name in `MainActivity.kt`
(`"com.example.tabletennis_scoreboard/audio_ducking"`) was deliberately
left unchanged — it's an arbitrary string shared between the Dart and
Kotlin sides, not a real package/bundle identifier, and Google Play
doesn't inspect it.

---

## 3. Release signing

Infrastructure is in place in `android/app/build.gradle.kts`: it reads
`android/key.properties` (git-ignored) if present and signs release
builds with that real keystore, falling back to debug signing
(today's behavior) if the file doesn't exist yet — so this repo keeps
building for anyone who hasn't set it up.

**You still need to generate the actual keystore yourself** — this
involves a secret only you should hold, not something this session can
or should create on your behalf. Full step-by-step keytool instructions
are in **README.md's "Release signing" section**. `.gitignore` now also
excludes `*.jks`, `*.keystore`, and `android/key.properties` so the
keystore/passwords can never be accidentally committed.

---

## 4. Privacy Policy

### 4a. Hosted policy (draft, en/de/fr)

Drafted in `privacy_policy/privacy-policy-{en,de,fr}.md` — plain
Markdown, ready to host anywhere (GitHub Pages is the easiest free
option: enable Pages on this repo pointed at that folder, or copy the
rendered text into any static host). Each covers:
- What's collected: AdMob advertising ID, GDPR/UMP consent choice,
  Google Play Billing purchase confirmation.
- Explicitly **no** personal account/profile data (no sign-up exists).
- Why it's collected, and that AdMob/Play Billing handle their own data
  under their own policies (with links).
- User choices (Privacy options, Restore purchases, device-level ad-ID
  controls), a children's-privacy statement, and a contact placeholder.

**These are drafts for you to review, not final legal text** — in
particular, replace every `[PLACEHOLDER]` (date, contact email) before
publishing, and consider having a lawyer glance at it if you want real
legal certainty, especially for GDPR.

### 4b. In-app link

`lib/services/privacy_links.dart` holds one constant, `privacyPolicyUrl`
— currently a placeholder (`https://example.com/...`). The "Privacy
Policy" menu item (see §1) opens whatever URL is there via
`url_launcher`. **Once you've hosted 4a, update just that one constant**
— nothing else needs to change. Also paste the same URL into Play
Console's Store Listing → Privacy Policy field; Google requires it
there too, separately from the in-app link.

---

## 5. Store listing text (ASO)

Drafted in **`STORE_LISTING.md`**: title (+ an alt to A/B test), short
description, and full description, in English, German, and French,
built around the keyword research already done for this app (German:
"Tischtennis Anzeigetafel", "Tischtennis Punkte zählen"; French:
"compteur tennis de table", "tableau de score tennis de table").
**Draft copy for your review** — adjust tone/claims as you see fit
before pasting into Play Console.

---

## Code changes made

- `pubspec.yaml` — added `url_launcher: ^6.3.2`.
- `lib/services/consent_service.dart` — new; `ConsentService` +
  `UmpConsentService`.
- `lib/services/privacy_links.dart` — new; the swappable placeholder
  URL.
- `lib/services/monetization_controller.dart` — new required `consent`
  constructor param; consent-gated ad preloading; `privacyOptionsRequired`
  getter; `openPrivacyOptionsForm()`.
- `lib/main.dart`, `lib/screens/setup_screen.dart`,
  `lib/screens/scoreboard_screen.dart`,
  `lib/screens/doubles_scoreboard_screen.dart` — wired
  `consent: UmpConsentService()` into each screen's own
  `MonetizationController` construction (matching the existing
  `ads`/`purchases` pattern).
- `lib/screens/setup_screen.dart` — two new overflow-menu items
  ("Privacy options", "Privacy Policy").
- `lib/l10n/app_{en,de,fr}.arb` (+ regenerated `lib/l10n/gen/*`) — two
  new localized strings.
- `android/app/build.gradle.kts` — new `applicationId`/`namespace`,
  and real release-signing config (reads `android/key.properties`).
- `android/app/src/main/kotlin/.../MainActivity.kt` — moved to the new
  package path.
- `ios/Runner.xcodeproj/project.pbxproj` — new
  `PRODUCT_BUNDLE_IDENTIFIER`.
- `.gitignore` — excludes keystore/`key.properties`.
- `README.md` — new "Phase 6" section: release-signing steps, privacy
  policy hosting note.
- `test/monetization_controller_test.dart` — updated to inject a
  `_FakeConsentService`; added a new test group (6 tests) covering the
  consent gate (ads never load before `canRequestAds()` says yes;
  `privacyOptionsRequired` reflects UMP's own determination;
  `openPrivacyOptionsForm()` delegates correctly).
- `test/monetization_widget_test.dart` — updated to inject a
  `_FakeConsentService`; added a new test group (2 tests) covering the
  "Privacy options"/"Privacy Policy" menu entries (hidden/shown
  correctly, tapping each is safe and does what it should).
- New: `privacy_policy/privacy-policy-{en,de,fr}.md`,
  `STORE_LISTING.md`, this file.

## Test results

```
flutter analyze
No issues found! (ran in 3.4s)

flutter test
00:27 +279: All tests passed!
```

Full suite (279 tests — the pre-existing 271, plus 6 new consent-gating
tests and 2 new menu-entry widget tests) passes with no failures and no
unhandled/leaked exceptions — verified by grepping the full test run's
output, since the async-exception risk described in §1 wouldn't
necessarily fail the specific test it leaked into in an obvious way.
