# Phase 7: Monetization Disabled for Initial Launch

**This is a deliberate, temporary product decision — not a bug, not a
rollback, and not a removal of Phase 5/6's work.** The app is launching
free and fully unlocked for everyone, ads-off, purchase-off, to test
market demand before turning monetization back on. Every line of the
ads/purchase/consent implementation from Phase 5 and Phase 6 is intact,
fully wired, and covered by its original tests — it is simply not
switched on for this build. Re-enabling it later is a one-line change.

## 1. The flag

**`lib/config/feature_flags.dart`** — one top-level constant:

```dart
const bool monetizationEnabled = false;
```

`MonetizationController` is the only place that reads it. Flip it back
to `true` and rebuild to re-enable the entire monetization stack; no
other file needs to change.

## 2. What actually happens when it's `false`

All of the following are enforced inside `MonetizationController`
itself (`lib/services/monetization_controller.dart`), not scattered
across call sites — every screen and dialog that uses the controller
keeps calling the exact same methods/getters it always did; they just
resolve differently:

- **`initialize()` returns immediately after loading the persisted Pro
  flag** (kept for when the flag is later re-enabled, so an already-real
  purchase from before this flag existed isn't lost) — it never calls
  `consent.gatherConsent()`, never calls `ads.initialize()`, and never
  calls `ads.loadInterstitial()`. No AdMob SDK call, no UMP consent
  request, of any kind, ever happens.
- **`isPro` reads `true` unconditionally** (`!monetizationEnabled ||
  _isPro`), regardless of the user's actual purchase history. Every
  place in the app that already gated a feature behind `isPro` — ad-free
  play, match-result export — automatically grants full access with no
  changes needed at those call sites.
- **`maybeShowMatchEndAd()` no-ops** (it already returned early once
  `isPro` was true; that now includes the disabled case) — never calls
  `ads.showMatchEndInterstitial()`.
- **`shouldOfferUpsell` is always `false`** — the automatic "Remove Ads"
  post-match prompt never fires, no matter how many matches complete.
- **`proPriceLoading`/`proPrice` resolve immediately to
  not-loading/`null`** — the Play Billing price query added for the Pro
  dialog is never issued, since the dialog that would show it is never
  reachable (next point).
- **`privacyOptionsRequired` stays `false`** — since consent is never
  gathered, there is never a UMP decision to review, so `SetupScreen`'s
  existing `if (_monetization.privacyOptionsRequired)` guard hides the
  "Privacy options" menu entry exactly as it already did for out-of-
  region users in Phase 6. No new logic was needed here — this was
  already conditional on the same underlying state.

**`lib/screens/setup_screen.dart`** — the "Remove Ads / Pro" menu entry
is now wrapped in `if (_monetization.monetizationEnabled)`, so it's
absent from the overflow menu entirely (not just disabled/greyed out)
while the flag is off. Everything else in that menu (Theme, Language,
the always-shown Privacy Policy link) is unaffected.

No other screen needed a code change. `ScoreboardScreen` and
`DoublesScoreboardScreen` already called `maybeShowMatchEndAd()` and
checked `shouldOfferUpsell`/`isPro` purely through the controller's own
API — those call sites don't know or care that the flag exists.

## 3. Why a controller-level flag rather than deleting/commenting out code

The instruction was explicit: disable cleanly, without touching or
deleting the ads/purchase implementation, as a single flip back later.
Gating entirely inside `MonetizationController` (plus the one `if` in
`SetupScreen` for the menu entry) means:

- `AdMobAdsService`, `InAppPurchaseGateway`, `UmpConsentService`,
  `ProDialog`, `match_export.dart` — every real implementation — is
  untouched, still compiles, still has its own passing tests.
- Every screen's existing "optional `MonetizationController` parameter,
  self-constructs a real one if not given" pattern (documented in
  PHASE5_MONETIZATION.md) needed zero changes, since the gating lives
  inside the controller those instances already talk to.
- Turning monetization back on later really is one line
  (`monetizationEnabled = true` in `feature_flags.dart`) with no other
  file to revert.

## 4. Testability: an overridable field, not just the bare constant

`MonetizationController` doesn't read the top-level constant directly
in every method — it has its own `final bool monetizationEnabled` field,
set in the constructor from an optional override parameter that
defaults to the top-level constant:

```dart
MonetizationController({
  required this.ads,
  required this.purchases,
  required this.proStatusStore,
  required this.consent,
  bool? monetizationEnabled,
}) : monetizationEnabled =
          monetizationEnabled ?? feature_flags.monetizationEnabled;
```

Every real call site (`main.dart`, and each screen's self-constructed
fallback instance) leaves the parameter unset, so production behavior
is governed entirely by the single top-level constant. Tests, however,
need to exercise **both** the disabled path (the new launch default)
and the enabled path (regression coverage for Phase 5/6, since that
code must keep working correctly for when the flag flips back) — a bare
`const bool` with no override would make one of those two impossible to
test once the global default changed. Every existing test in
`test/monetization_controller_test.dart` and
`test/monetization_widget_test.dart` was updated to pass
`monetizationEnabled: true` explicitly, so they keep verifying the
enabled behavior regardless of what the global constant is currently
set to.

The same seam was added one level up, to `TableTennisScoreboardApp`
itself (`lib/main.dart`), as an optional `monetization` parameter —
mirroring the exact "optional, self-constructs if omitted" convention
`SetupScreen`/`ScoreboardScreen`/`DoublesScoreboardScreen` already use.
Two pre-existing tests in `test/theme_and_names_test.dart` construct the
whole app widget (not just `SetupScreen`) to check the overflow menu's
structure/styling, including the Pro menu item's appearance — they now
inject an explicitly-enabled `MonetizationController` via this new
parameter, so they keep testing what they always tested rather than
silently asserting on a now-hidden widget. `main()` itself passes
nothing, so real app behavior is unaffected by this parameter's mere
existence.

## 5. New tests for the disabled path

**`test/monetization_controller_test.dart`** — a new
"MonetizationController — monetization disabled (Phase 7, launch)"
group, constructing a `MonetizationController(monetizationEnabled:
false, ...)` directly:

- `initialize()` never calls `ads.initialize()`, `ads.
  loadInterstitial()`, or `consent.gatherConsent()` (asserted via call
  counters on the hand-written fakes).
- `isPro` reads `true` unconditionally, including for a fresh install
  with no persisted purchase at all.
- `privacyOptionsRequired` stays `false` even when the fake consent
  service is set up to report a required decision — proving the
  controller genuinely never asks, rather than asking and discarding
  the answer.
- The price query is never issued (`queryProPrice` call count stays 0)
  and `proPriceLoading` resolves to `false` immediately.
- `maybeShowMatchEndAd()` never calls `ads.showMatchEndInterstitial()`.
- `shouldOfferUpsell` stays `false` across many completed matches (well
  past `upsellIntervalMatches`).

**`test/monetization_widget_test.dart`** — a new "Monetization disabled
for launch (Phase 7)" group, at the full-widget level:

- Playing a match to completion end-to-end with a disabled controller:
  the match-complete dialog's export button is shown and Pro-gated
  features work (full access, as designed), the AdMob fake's
  `showMatchEndInterstitialCalls` stays 0, and `consent.
  gatherConsentCalls` stays 0.
- `SetupScreen`'s overflow menu has no `proMenuButton` and no
  `privacyOptionsMenuButton`, while `privacyPolicyMenuButton` (purely
  informational, unrelated to ads/consent) still appears.
- Playing through `upsellIntervalMatches * 2` matches never shows the
  automatic upsell dialog (`proDialogTitleText` never appears).

`flutter analyze`: no issues. `flutter test`: all 293 tests pass (284
before this phase + 9 new: 6 controller-level, 3 widget-level).

## 6. What re-enabling later actually involves

1. Flip `monetizationEnabled` to `true` in `lib/config/feature_flags.dart`.
2. Nothing else. The Pro menu entry reappears, AdMob initializes and
   requests ads again, UMP consent gathers again where required, the
   automatic upsell resumes its normal cadence, and `isPro` goes back to
   reflecting the user's real purchase/restore state.
3. Reconfirm the pre-release checklist already documented in
   PHASE5_MONETIZATION.md §8/§10.4 (real Play Console product ID,
   pricing, license testers, Play Store–track install for purchase
   testing) still applies at whatever point monetization is actually
   turned back on — none of that changed here, it was simply never
   exercised while the flag was off.
