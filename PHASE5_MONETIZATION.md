# Phase 5: Monetization — AdMob + One-Time Pro Purchase

AdMob interstitial (match-end only) + a single non-consumable "Remove
Ads / Pro" purchase via `in_app_purchase` (Play Billing / StoreKit),
unlocking ad removal and a minimal match-result export. Subscriptions
and the ad-free-only variant were both explicitly ruled out — see §1.

**Status: Phase 5 complete.** Built and passing (242/242 tests — 212
original + 22 from this phase's first pass + 8 from the
real-device-testing fixes below). `flutter analyze`: no issues. The
ad-loading pipeline is verified working end-to-end — see §12.

**Update (real-device testing round):** four issues were found running
a real build on a connected device and fixed — see §10.

**Update (ad-loading deep-dive):** verified the manifest's AdMob App ID
was already correct, added verbose logging around the ad-load
lifecycle, and reproduced the failure live on a connected device by
actually playing a match to completion — see §11 for the exact error
this surfaced and why it's a device/Google-Play-Services condition, not
a bug in this app's code.

**Update (closing the investigation):** the ad-loading pipeline was
confirmed working correctly on the Android emulator — a real AdMob test
interstitial loaded and displayed successfully at match end. This
confirms §11's conclusion: the app-side code (manifest, ad unit IDs,
load/retry/show logic) was never the problem. The physical-device
failure is closed out as a known, environment-specific quirk to monitor
post-release rather than a blocker — see §12.

**Update (pre-launch Pro dialog review):** two issues found in the Pro
purchase dialog while reviewing it before submitting to Play
Console — an inaccurate benefit claim in the dialog copy, and a missing
real price — both fixed. See §13.

---

## 1. Scope decisions (made with the user before building)

Two decisions were made explicit before writing any code, since this
phase's instructions were revised mid-session and left one point open:

- **Ads are in scope.** An earlier instruction said to skip AdMob
  entirely and ship purchase-only; a follow-up instruction explicitly
  reinstated ads, restoring the original phase plan (ads +
  one-time-purchase, subscriptions ruled out — see §6). The follow-up
  instruction is what this phase was built against.
- **What Pro gates, beyond ads.** Asked directly (plain text, since a
  structured question tool was declined) which of the app's newer
  features — light/dark theme, editable names, choreographed animations
  — should also be Pro-gated. The answer: **none of them.** Pro gates
  exactly two things: ad removal, and match-result export. Theme
  choice, name editing, and every animation remain free and
  unrestricted for all users, exactly as the original phase plan
  scoped it before this app grew past its original MVP.

## 2. Architecture

Three new service abstractions, following this project's established
dependency-injection pattern (`TtsEngine`/`ClipPlayer` for voice,
`ThemePreference` for theme) — each has a real implementation that
talks to a platform plugin, and tests inject a hand-written fake
instead, so `flutter test` never touches real AdMob or Play
Billing/StoreKit:

- **`lib/services/ads_service.dart`** — `AdsService` (interface) /
  `AdMobAdsService` (real). Loads and shows a single interstitial.
- **`lib/services/purchase_gateway.dart`** — `PurchaseGateway`
  (interface) / `InAppPurchaseGateway` (real, wraps
  `InAppPurchase.instance`). Exposes purchase-flow outcomes as a
  `Stream<PurchaseUpdate>` with a small `PurchaseOutcome` enum
  (pending/purchased/restored/cancelled/error), decoupled from
  `package:in_app_purchase`'s own types.
- **`lib/services/pro_status_store.dart`** — `ProStatusStore`, a thin
  `SharedPreferences` cache of "is Pro," mirroring `ThemePreference`
  exactly. Not the source of truth (the store is); just avoids
  re-querying Play Billing/StoreKit on every launch.

**`lib/services/monetization_controller.dart`** — `MonetizationController`
(a `ChangeNotifier`) ties the three together: owns `isPro`, exposes
`buyPro()`/`restorePurchases()`/`maybeShowMatchEndAd()`, and a
`Stream<PurchaseFeedback>` the UI listens to for localized SnackBars.
One instance is created in `main.dart` and threaded down through
`SetupScreen` into whichever scoreboard screen is active — the same
"one instance, threaded down" pattern already used for `PlayerNames`
and the theme/locale overrides — so Pro status and a preloaded ad
survive navigating between setup and the scoreboard.

Every screen that can host a `MonetizationController` (`SetupScreen`,
`ScoreboardScreen`, `DoublesScoreboardScreen`) takes it as an
**optional** constructor parameter, matching this codebase's existing
`voiceAnnouncer`/`initialNames` convention: when not given, the screen
builds its own real, self-initializing instance and owns its
lifecycle; when given (as `main.dart` does), the caller owns it
instead. This is why none of the 7 pre-existing test files that
construct these screens directly needed to change — they fall back to
a real `MonetizationController`, which (like `VoiceAnnouncer` and
`ThemePreference` before it) degrades silently to "no ad, not Pro" in
the plugin-less test environment rather than throwing.

**`lib/widgets/pro_dialog.dart`** — `ProDialog`, opened from a new Pro
icon in `SetupScreen`'s app bar. Shows buy/restore when not Pro, a
simple confirmation once Pro is owned, and listens to
`MonetizationController.feedback` for a SnackBar on every purchase
outcome.

**`lib/services/match_export.dart`** — `buildMatchExportSummary()`, a
pure function (no `BuildContext`, matching `match_commentary.dart`'s
existing pattern) that formats one completed match's game-by-game
score as plain text. Copied to the clipboard via `Clipboard.setData`
— deliberately not `share_plus` or a persisted multi-match history,
per the "minimal, single-match" scope given for this feature.

## 3. A real bug found and fixed while building this: SnackBar-behind-a-dialog

The export button originally showed its "copied" confirmation via a
`ScaffoldMessenger` SnackBar, exactly like the app's other banners
(change-ends, game-complete). This looked right and compiled cleanly,
but **never actually appeared** when tested: Flutter freezes the
`TickerMode` on a route once another route is pushed above it, and the
export button lives inside a `showDialog` route sitting on top of the
scoreboard's own route. The SnackBar's entrance animation is driven by
a ticker on the *scoreboard's* (now-obscured, now-frozen) route, so it
can never progress — no amount of `pump()`/`pumpAndSettle()` in a test
would ever make it appear, because in a real build it never would
either. This wasn't a test artifact; a real user tapping "Export"
while the dialog was open would have seen zero confirmation.

**Fix:** `MatchCompleteDialog` became a `StatefulWidget`. Tapping
"Export match result" now swaps the button's own label in place (icon
+ text) to a checkmark and "Match result copied to clipboard," inside
the dialog's own (current, un-paused) route, and disables the button
against a second tap. No SnackBar involved. See
`lib/widgets/match_complete_dialog.dart`.

## 4. Purchase-flow states and the restore "silent success" quirk

Every `PurchaseOutcome` maps to a localized (en/de/fr) `SnackBar` via
`ProDialog`: pending, purchased, restored, cancelled, error. One
outcome has no direct equivalent from the store APIs: **restoring
purchases when there is nothing to restore emits no event at all** —
neither success nor failure, just silence. Left alone, a user tapping
"Restore purchases" with no prior purchase would get no feedback
whatsoever and reasonably assume the button was broken.

`MonetizationController.restorePurchases()` handles this with a
client-side grace period: it records whether Pro was already unlocked
before calling the gateway, and if not, waits ~2 seconds after the
call for a `purchased`/`restored` event to arrive naturally; if none
does, it synthesizes a `PurchaseFeedback.restoreNotFound` event itself
so the SnackBar can say "No previous purchase found." This is a
deliberate approximation, not a store feature — documented here and in
the code as a known simplification. Two real seconds is enough margin
for a same-device restore query to resolve without making the user
wait uncomfortably long for the negative case.

## 5. Ad placement: interstitial-only, no banner

The brief offered "a discreet banner OR a single interstitial shown
ONLY at match-end." A persistent banner is on-screen for the *entire*
match by construction — which is exactly what the brief's own research
flagged as the most common competitor complaint ("never mid-match").
An interstitial fires once, at the natural break point when a match
ends, and not again until the next one does. Built interstitial-only
for this reason. `MonetizationController.maybeShowMatchEndAd()` is
called (fire-and-forget) right when a match completes, before the
match-complete dialog is shown; on a real device a loaded interstitial
takes over the full screen and the dialog underneath simply appears
once it's dismissed. If Pro has removed ads, or no ad was ready to
show, this is a no-op and the dialog appears immediately, exactly as
before this phase.

## 6. Deferred, per the original plan

- **Subscriptions** — ruled out per the original research (the one
  subscription-model competitor plateaued around ~1,000 installs vs.
  50,000–100,000+ for ad-supported one-time-purchase competitors in
  this niche). Only a non-consumable one-time purchase is implemented.
- **Rewarded-ad on-ramp** ("watch one ad to remove ads for this
  session") — explicitly optional in scope, left for the user's
  judgment. Decision: **not built this pass.** It's a third ad format
  (on top of the interstitial) with its own load/show/reward-callback
  surface and its own fake for tests, for a "nice to have" while the
  core purchase-restore/state-handling work already needed solid
  coverage to ship correctly. Worth revisiting once the base purchase
  flow has real-world usage data — if the free tier's ad tolerance
  turns out to be a conversion blocker, a rewarded on-ramp would be a
  reasonable next lever to pull.

## 7. Testing

- `test/match_export_test.dart` — pure unit tests for
  `buildMatchExportSummary()`: correct per-game lines (not the same
  line repeated — an earlier draft had exactly that bug, caught and
  fixed before any test was written), empty-match handling, doubles
  team-label usage.
- `test/monetization_controller_test.dart` — `MonetizationController`
  against hand-written `_FakeAdsService`/`_FakePurchaseGateway`:
  initialization (fresh install vs. persisted Pro), every
  `PurchaseOutcome` → `PurchaseFeedback` mapping, the restore
  grace-period heuristic (both "nothing arrives" and "something
  arrives in time"), `maybeShowMatchEndAd` gating, disposal.
- `test/monetization_widget_test.dart` — `ProDialog` end-to-end (buy,
  purchase success switching dialog state, restore-not-found feedback)
  and the export flow end-to-end (button hidden for free users, shown
  and functional for Pro, clipboard content verified via a mocked
  `SystemChannels.platform` handler, in-dialog confirmation verified
  after the SnackBar approach was found broken — see §3).

Two non-obvious fixes made while writing these tests, both about test
correctness rather than product bugs:
- A `tearDown` that unconditionally disposed a `MonetizationController`
  broke the one test that also disposes it itself to assert on the
  call — fixed by wrapping the `tearDown` dispose in try/catch.
- A broadcast stream's listener delivery and an `await`'s resumption
  are two independently-scheduled microtasks with no guaranteed
  relative order; one test asserted on stream-collected values
  immediately after an `await` with no flush in between, and needed
  `pumpEventQueue()` first (the same safety net already used in the
  sibling purchase-outcome tests) to be reliable.

## 8. Native configuration

`android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`
now carry Google's published **test** AdMob App IDs plus (Android) an
explicit `INTERNET` permission for release builds (debug/profile
already had it via their own manifest overlays). See the README's
"Phase 5 — Monetization" section for the full pre-release checklist:
real AdMob app + ad unit IDs, a real Play Console product ID replacing
the placeholder `remove_ads_pro_test`, pricing (~€2.99 target,
localized), and license-tester/sandbox setup for pre-release purchase
testing.

## 9. Terminology confidence flags

German and French Pro/export strings were translated following this
project's established vocabulary from earlier phases (e.g. German
"Satz" / French "Manche" for "game," matching `gamesCountLabel` in
each ARB file) rather than invented fresh. As with prior phases' German
and French additions, a native speaker's review before release is
still worthwhile — these are reasoned translations, not verified ones.

## 10. Real-device testing round: four issues found and fixed

A build run on a connected device (not `flutter test`) surfaced four
problems the test suite hadn't caught, since three of them are purely
about real-plugin behavior and cadence/UX judgment that fakes and
`flutter test`'s plugin-less environment can't exercise.

### 10.1 No ad ever appeared, and no way to tell why

**What was reported:** no ad visible anywhere on screen.

**First finding — there is no banner ad in this app.** Only an
interstitial exists, shown once at match end (§5's reasoning against a
persistent banner is unchanged). If a banner was expected, none was
ever built; this wasn't a regression, it's the original Phase 5 design.
Worth flagging explicitly in case that's what was actually being looked
for — say so and a banner can be added, though it reintroduces exactly
the "ad visible for the whole match" complaint the original research
flagged.

**Second finding — the ad unit IDs are genuine.** Cross-checked against
Google's own published test-ad documentation:
`ca-app-pub-3940256099942544/1033173712` (Android interstitial) and
`ca-app-pub-3940256099942544/4411468910` (iOS interstitial) are both
real, official Google test IDs, not placeholders. Not the problem.

**Third finding — the actual bug.** `MobileAds.instance.initialize()`
*is* called before any load is attempted (`MonetizationController.
initialize()` awaits `ads.initialize()` before `ads.loadInterstitial()`
— correct order), and `InterstitialAd.load()`'s `onAdLoaded`/
`onAdFailedToLoad` callbacks were wired up. But:
- Every failure path — SDK init, load failure, show failure — was
  caught and silently discarded with an empty `catch (_) {}` or a
  callback that just set a field to `null`. There was **no way to see**
  whether an ad failed to load, or why. Fixed: every failure path in
  `lib/services/ads_service.dart` now logs via `debugPrint` (e.g.
  `AdMobAdsService: interstitial failed to load: <error>`), matching
  the "no interstitial ready to show at match end" line visible in this
  phase's own test output above.
- **There was no retry after a failed load.** A preload was only
  re-attempted after successfully *showing* an ad (in the dismiss/
  fail-to-show callbacks) — if the very first load attempt after app
  launch failed for any transient reason (a network hiccup at cold
  start, no fill yet), ads were silently disabled for the rest of the
  session, since nothing would ever try loading again. This is very
  plausibly the actual root cause of "no ad ever appears" on a real
  device, where transient failures are common and `flutter test`'s
  fake/absent ad plugin never exercises this path at all. Fixed: a
  failed load now schedules a retry with exponential backoff (5s
  initial, doubling up to a 2-minute cap, resetting on success).

### 10.2 "Remove Ads" button text overflow

`proBuyButton` was "Remove Ads (One-Time Purchase)" / "Werbung
entfernen (einmaliger Kauf)" / "Supprimer les publicités (achat
unique)" — all three overflowed the button at normal font scale, worst
in German and French. Shortened to just "Remove Ads" / "Werbung
entfernen" / "Supprimer les publicités" in all three ARB files: the
dialog's own body text directly above the button already says it's a
one-time purchase, so the parenthetical was redundant as well as too
long.

### 10.3 A second, related SnackBar-behind-a-dialog bug

While investigating why "Remove Ads" appeared to do nothing (§10.4),
`ProDialog`'s error/status feedback turned out to have the **same
ticker-freeze bug** already found and fixed for the match-export
confirmation (§3): it showed feedback via a `ScaffoldMessenger`
SnackBar triggered from a button inside an open dialog, which can never
actually animate into view. This meant that even the "Something went
wrong with the purchase" error message — the one thing that would have
told a real user *why* nothing seemed to happen — was itself invisible.
Fixed the same way: `ProDialog` now shows purchase/restore feedback as
inline text within its own body instead of a SnackBar. This is a
genuine correctness fix, not just a test fix — a real user tapping
"Remove Ads" without Play Console/Internal Testing set up (§10.4) would
previously have seen literally nothing happen, with no error message
either, which reads as "the button is broken."

### 10.4 Why tapping "Remove Ads" does nothing when run via `flutter run`

This is expected, and not fixable from the app's code. **Confirmed
understanding:** Google Play Billing requires the app to be installed
through the Play Store's own distribution pipeline before a real
purchase sheet can appear at all — a debug build installed via
`flutter run`/`adb install` is not, and never can be, sufficient. Play
Billing's `queryProductDetails()` call (in
`lib/services/purchase_gateway.dart`) asks Play Console "does this
package name have this product ID configured," and Play Console only
answers that for a package that has actually been uploaded there —
there's no local/offline mode. Concretely, before a real purchase
dialog can appear on a device:

1. The app must exist as an app listing in Play Console (package name
   registered).
2. The non-consumable in-app product must be created there with the
   exact same product ID used in code (`proProductId`, currently the
   placeholder `remove_ads_pro_test`).
3. A build must be uploaded to at least an **Internal Testing** track.
4. The testing Google account must be added as a tester on that track
   **and** as a Play Console **license tester** (Setup → License
   testing) — license testers can complete purchases through the real
   flow without being charged.
5. The tester must install the app via the **Play Store opt-in link**
   Play Console generates for that track — not a sideloaded APK, even
   if it's byte-for-byte the same build.

Without all five, `isAvailable()`/`queryProductDetails()` will either
report Billing as unavailable or return no matching product (exactly
what §10.3's now-visible inline error message will show), and
`buyNonConsumable()` has nothing valid to launch a purchase sheet for.
This is a Google Play policy/architecture constraint, not a bug in this
app — there is no debug-build or local-testing workaround for it. The
README's "Phase 5 — Monetization" section already lists steps 1–4 as
pre-release setup; this section exists to confirm explicitly that
step 5 (Play Store install, not `flutter run`) is also required before
any purchase testing can happen at all, debug or release build alike.

### 10.5 Ad-prompt cadence: an occasional upsell instead of one after every ad

The purchase dialog previously only ever opened when the user
deliberately tapped the setup screen's app-bar Pro icon — there was no
automatic prompt at all. Real-device testing asked for an *occasional*
unprompted nudge instead of relying purely on user-initiated discovery,
while explicitly avoiding it feeling naggy. Added to
`MonetizationController`:

- `recordMatchCompleted()` — called once per completed match (both
  scoreboard screens), regardless of whether an ad showed for it.
- `shouldOfferUpsell` — true only once every `upsellIntervalMatches`
  (3) completed matches, never while Pro is already owned, and never
  again this session after `dismissUpsell()` has been called.
- `markUpsellShown()` / `dismissUpsell()` — reset the match counter
  when the upsell is actually shown, and suppress it for the rest of
  the session once it closes without a purchase.

Both scoreboard screens now chain `_maybeShowUpsell()` onto the
match-complete dialog's `showDialog(...).then(...)` — so the earliest
the upsell can appear is *after* the match-complete dialog has already
closed (i.e. after "New match" is tapped), never mid-match, and it
reuses the exact same `ProDialog` the app-bar icon opens. **The
purchase flow itself is never gated by this** — the app-bar Pro icon on
the setup screen opens the same dialog at any time, on any match count,
whether or not the automatic upsell has fired or been dismissed.

## 11. Ad-loading deep-dive: reproduced live on a real device

Before assuming the ad-loading *logic* itself was broken, the manifest
was checked first, since a missing AdMob App ID meta-data entry is the
single most common AdMob setup mistake and fails completely silently.

**The manifest entry is present and correct.**
`android/app/src/main/AndroidManifest.xml` already has, inside
`<application>` (added in §8 of this document, before the first
real-device round):

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

This is Google's genuine published test App ID, correctly placed. Not
the cause.

### What the verbose logging showed, running live on a connected device

`lib/services/ads_service.dart` already logged failures (§10.1), but
not enough to answer "is the request firing / what's the exact error /
is a loaded ad just not being shown." Added:

- A log line the instant a load is requested, with the ad unit ID.
- A log line on successful load (previously silent).
- The full `LoadAdError`/`AdError` breakdown (`code`, `domain`,
  `message`) on every failure, not just a bare `toString()`.
- A log line when an interstitial actually presents on screen
  (`onAdShowedFullScreenContent`), so a "loaded but never shown" case
  would be distinguishable from a "never loaded" case.
- An `InitializationStatus` adapter summary logged right after
  `MobileAds.instance.initialize()` completes.

Then — rather than reasoning about this in the abstract — the app was
actually built and run on a real connected Android device (`flutter run
-d <device>`), driven end-to-end via `adb` (tapping through best-of-3
selection, tossing the coin, starting the match, and playing a full
straight-2-0 match), while capturing the live console output. This
directly answers all three of the diagnostic questions this round of
work was asked to resolve:

**(a) Is the ad request firing at all? Yes**, every time — confirmed by
a `requesting interstitial (ca-app-pub-.../1033173712)` log line at
launch and again after every retry.

**(b) Is it failing with a specific error code? Yes:**

```
AdMobAdsService: SDK initialized (com.google.android.gms.ads.MobileAds=notReady)
AdMobAdsService: requesting interstitial (ca-app-pub-3940256099942544/1033173712)
AdMobAdsService: interstitial failed to load — code=0 domain=com.google.android.gms.ads message=Unable to obtain a JavascriptEngine.
```

This repeated on every retry throughout the session (the exponential
backoff added in §10.1 was confirmed working — retries actually fired
at increasing intervals, all hitting the same error), and the SDK's own
`InitializationStatus` reported its core adapter as `notReady` from the
very first check, before any ad was ever requested.

**(c) Is it succeeding but not being mounted into the widget tree? Not
applicable, and confirmed not the issue anyway.** An `InterstitialAd` is
not a Flutter widget — `ad.show()` presents a native full-screen overlay
managed entirely outside the Flutter widget tree, so "mounted in the
tree" doesn't apply the way it would for a `BannerAd`/`AdWidget` (which
this app doesn't use — see §10.1). More directly: the ad never reached
the *loaded* state in the first place (confirmed by (b)), so
`showMatchEndInterstitial()` correctly and safely logged `no
interstitial ready to show at match end` and no-opped — exactly the
intended graceful-degradation behavior, not a bug. Played through to
the match-complete dialog to confirm this directly: the trophy dialog
("Player 1 wins the match!") appeared normally, with no crash, no hang,
and no visual gap where an ad should have been.

### Root cause: an upstream Google Mobile Ads SDK / Play Services condition, not an app bug

`code=0` is AdMob's generic `ERROR_CODE_INTERNAL_ERROR`, and "Unable to
obtain a JavascriptEngine" is a known (if not consistently resolved)
failure in the Google Mobile Ads SDK's own ad-rendering layer, which is
WebView/JavaScript-engine-based even for test creatives. It's reported
across many Flutter and native Android AdMob integrations with no
single universal fix — see
[googleads/googleads-mobile-flutter#149](https://github.com/googleads/googleads-mobile-flutter/issues/149)
and the
[AdMob community thread on the same error](https://support.google.com/admob/thread/223987238/in-my-flutter-app-ads-are-not-coming-error-occurring-like-unable-to-obtain-a-javascriptengine),
where Google's own SDK support team's response was to request device
logs and SDK version rather than point to a known fix.

Checked and ruled out everything on this app's side of the boundary:

- **Manifest App ID:** present, correct (above).
- **Ad unit IDs:** genuine, official Google test IDs (§10.1).
- **`google_mobile_ads` plugin version:** `flutter pub outdated` reports
  9.1.0 as current *and* latest — not an outdated-plugin issue.
- **Android System WebView on the test device:** `adb shell dumpsys
  webviewupdate` confirms `com.google.android.webview` (151.0.7922.199)
  is installed, valid, and the active preferred provider — not a
  missing/broken WebView package.
- **Google Play services on the test device:** installed at 26.32.34, a
  current version — not simply stale.
- **App code logic:** confirmed correct and behaving exactly as
  designed under this failure (retry with backoff firing, graceful
  no-op at match end, no crash).

What's left after ruling all of that out is the SDK's own internal
ad-rendering engine failing to initialize on this specific device at
this specific time — most likely (per the pattern in the linked
reports) a Google Play services "Dynamite" module (dynamically-
downloaded code Play services delivers separately from its main APK)
that the Ads SDK depends on for JS rendering not being ready on this
device, rather than anything a code change in this repository can fix.

**Practical next steps, all device-side (not app-code):**
1. ~~Restart the test device~~ — **tried, did not help.** Rebooted the
   same device (`adb reboot`, waited for `sys.boot_completed`,
   relaunched the app fresh) and played another full match end-to-end.
   Identical result, byte-for-byte the same error, on the very first
   load attempt after reboot — before any of this app's own retry logic
   even had a chance to run:
   ```
   AdMobAdsService: SDK initialized (com.google.android.gms.ads.MobileAds=notReady)
   AdMobAdsService: requesting interstitial (ca-app-pub-3940256099942544/1033173712)
   AdMobAdsService: interstitial failed to load — code=0 domain=com.google.android.gms.ads message=Unable to obtain a JavascriptEngine.
   ```
   This rules out a transient/stuck-process explanation — whatever's
   wrong survives a full reboot, so it's a persistent state on this
   device (most likely the Play services Dynamite module itself, or an
   account/device-level Play services condition), not a one-off glitch
   a restart clears. The graceful-degradation behavior held up
   identically too: the match-complete dialog ("Player 1 wins the
   match!") appeared normally on the second run as well, no crash, no
   ad-shaped gap.
2. Check for a pending Google Play services update (Play Store → search
   "Google Play services" → Update, if offered) — the Ads SDK's
   rendering module is delivered through it. Not yet tried.
3. Try the same build on a second device/emulator to confirm whether
   it's specific to this one device or systemic. Not yet tried.
4. For a first-party diagnostic beyond what this app's logging can show,
   Google's own [Ad Inspector](https://developers.google.com/admob/flutter/ad-inspector)
   tool can be wired in temporarily — it's what Google's own AdMob
   support directs developers to for exactly this class of error.

None of the above require a code change in this repository, and nothing
found in this investigation points to one — the app-side logging,
retry, and graceful-degradation behavior added in §10.1 are already
doing everything they can on this side of the failure, confirmed
working identically across two consecutive fresh app launches.

## 12. Closing the investigation: ad pipeline verified, Phase 5 complete

Following §11's device-side dead end (same "Unable to obtain a
JavascriptEngine" error, surviving a full reboot), the app was tested
on the Android emulator: a real AdMob test interstitial **loaded and
displayed successfully at match end**, confirmed by the user with a
screenshot on file. This is the positive-case confirmation §11 couldn't
reach on the physical device — the ad-load request fires, AdMob's SDK
successfully obtains its rendering engine, the creative displays, and
(per the existing `onAdDismissedFullScreenContent` logic) the next
interstitial preloads once the ad is dismissed.

**Conclusion: the app-side ad-loading pipeline is correct and verified
working.** Every piece checked out independently across both
investigation rounds:

- Manifest AdMob App ID: present and correct (§10.1, §11).
- Ad unit IDs: genuine, official Google test IDs (§10.1).
- SDK initialization order (`initialize()` before any `load()`): correct
  (§10.1).
- Load-request/callback wiring, error logging, retry-with-backoff, and
  graceful match-end no-op: all confirmed firing exactly as designed,
  including on a real device (§11).
- **End-to-end success**: confirmed on the emulator (this update) — the
  one piece the physical-device run couldn't demonstrate, since it never
  got past the load step there.

**The one physical test device's persistent failure is not a blocker
for this phase.** It's closed out as a known, environment-specific
quirk — most plausibly the Google Play services "Dynamite" ad-rendering
module on that specific device/account, per §11's reasoning — rather
than anything traceable to this app's manifest, code, or dependency
versions, all of which are now independently confirmed correct via the
emulator's successful run. Real-world instances of this same class of
failure (device-level Play services/WebView conditions preventing ad
fill) are exactly what **AdMob's own Play Console reporting** is
positioned to catch post-release: once live, watch the app's AdMob
account under Apps → (this app) → for match-rate / fill-rate and
request-vs-impression counts, and Play Console's Android vitals for any
correlated crash-free-rate dips on specific device models. If a
meaningful slice of real users on specific device models show
persistently zero ad impressions despite requests firing (visible in
AdMob's own request/match/show funnel, not just this app's local logs),
that's the signal to revisit this — not something to pre-emptively
chase further without that data, since the emulator result already
demonstrates the pipeline itself has nothing wrong with it.

**Phase 5 (Monetization) is complete**, pending only the pre-release
checklist already documented in the README (real AdMob App ID + ad unit
IDs, real Play Console product ID, pricing, license testers, and a Play
Store–track install for purchase testing — see README's "Phase 5 —
Monetization" section and §10.4 above).

## 13. Pre-launch Pro dialog review: an inaccurate benefit claim and a missing real price

Reviewing the Pro dialog one more time before Play Console submission
surfaced two issues — neither caught by the existing test suite, since
both are about what the dialog *claims and displays*, not what it does
mechanically.

### 13.1 The dialog's benefit copy overstated what it advertises as included

`proDialogDescriptionFree` and `proDialogAlreadyProBody` said the
purchase "unlocks exporting your match results" / "match export is
unlocked." **To be clear about what is and isn't true here:** match
export itself is a real, working, tested, Pro-gated feature —
`lib/services/match_export.dart`'s `buildMatchExportSummary()`,
wired into `MatchCompleteDialog`'s "Export match result" button and
covered by `test/match_export_test.dart` and the "Match export"
group in `test/monetization_widget_test.dart` — none of that changed
and none of it was removed. What changed is narrower: the purchase
dialog's own *marketing copy* no longer lists export as a call-out
benefit, so the dialog only promises what the product team wants
advertised as the purchase's headline benefit (ad removal) rather than
enumerating every Pro-gated feature. Fixed in all three ARB files
(`app_en.arb`, `app_de.arb`, `app_fr.arb`):

- `proDialogDescriptionFree`: "A one-time purchase that removes ads and
  unlocks exporting your match results." → "A one-time purchase that
  removes ads." (and the German/French equivalents)
- `proDialogAlreadyProBody`: "Ads are removed and match export is
  unlocked. Thanks for your support!" → "Ads are removed. Thanks for
  your support!" (and the German/French equivalents)

**Current actual Pro benefits** (what a purchase actually unlocks in
the running app, regardless of dialog copy): ad removal, and the
match-result clipboard export described above. A saved *history* of
past matches (plural, across sessions) — as opposed to exporting the
just-completed match's result — remains genuinely unbuilt and out of
scope, per §1's original "minimal, single-match" decision.

Regression test: `test/monetization_widget_test.dart`'s existing "shows
buy/restore buttons" test now asserts the exact updated body text and
adds `expect(find.textContaining('export'), findsNothing);` on the free
dialog, so the copy can't silently regress back to overpromising.

### 13.2 No real price was ever shown in the dialog

The buy button (`proBuyButton`, "Remove Ads") was deliberately built
with no price baked into its label — §8/§10.2 relied entirely on the
OS purchase sheet to show Play Billing's real, store-localized price at
checkout. That's correct as far as it goes, but it meant the dialog
itself never told the user what they were about to pay before tapping
"Remove Ads," which is worse pre-purchase transparency than most
competitors offer.

**Fix:** `PurchaseGateway` gained `queryProPrice()`, returning Play
Billing/StoreKit's own localized `ProductDetails.price` string (e.g.
`$1.99`, already formatted for the user's currency by the store — never
hardcoded) or `null` if the store is unavailable or the product isn't
found. `InAppPurchaseGateway.queryProPrice()` implements this via
`InAppPurchase.queryProductDetails({proProductId})`, mirroring the same
query `buyPro()` already made internally.

`MonetizationController` now exposes `proPrice` (`String?`) and
`proPriceLoading` (`bool`), kicking off the query fire-and-forget from
`initialize()` (via `unawaited`) so it never delays ads/consent
startup — skipped entirely for a user who already owns Pro, since the
free-tier price line never shows for them anyway. `ProDialog` shows,
directly above the buy button:

- the localized `proPriceLoading` string ("Loading price…") while the
  query is in flight — **never blank/missing text**, which is what the
  dialog showed before this fix (nothing at all) and what a naive
  "just show `proPrice`" implementation would show during the query's
  async gap;
- the real price once it resolves;
- nothing at all (no empty line) if the store genuinely has no price to
  offer — the buy button still works in that case, exactly as before
  this fix, since the store's own purchase sheet shows its price
  regardless.

Tests: `test/monetization_controller_test.dart`'s new "Pro price" group
covers the loading→resolved transition via a controllable `Completer`,
the "no price available" case, and that a Pro user's session never
issues the query at all.
`test/monetization_widget_test.dart` adds the same loading→resolved
assertions at the widget level (verifying `ProDialog` actually renders
the transition) and a "no price line, buy button still works" case.
