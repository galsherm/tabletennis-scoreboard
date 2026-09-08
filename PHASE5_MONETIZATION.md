# Phase 5: Monetization — AdMob + One-Time Pro Purchase

AdMob interstitial (match-end only) + a single non-consumable "Remove
Ads / Pro" purchase via `in_app_purchase` (Play Billing / StoreKit),
unlocking ad removal and a minimal match-result export. Subscriptions
and the ad-free-only variant were both explicitly ruled out — see §1.

**Status:** built and passing (234/234 tests — 212 pre-existing,
unchanged, + 22 new for this phase). `flutter analyze`: no issues.

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
