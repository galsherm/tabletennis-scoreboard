import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/feature_flags.dart' as feature_flags;
import 'ads_service.dart';
import 'consent_service.dart';
import 'pro_status_store.dart';
import 'purchase_gateway.dart';

/// User-facing feedback for one purchase/restore attempt — always
/// localized at the call site (`AppLocalizations`), never hardcoded
/// English, since this reaches the user directly as a SnackBar/dialog
/// message. See PHASE5_MONETIZATION.md.
enum PurchaseFeedback {
  pending,
  purchased,
  restored,
  cancelled,
  error,

  /// [PurchaseGateway.restorePurchases] finding nothing is a real quirk
  /// of the underlying store APIs: no event at all is emitted for "no
  /// purchases to restore," so this is synthesized locally after a short
  /// grace period — see [MonetizationController.restorePurchases].
  restoreNotFound,
}

/// Owns ads + purchases + the persisted Pro flag for the whole app —
/// one instance, created in `main.dart` and threaded down to
/// `SetupScreen` (for the purchase/restore UI) and both scoreboard
/// screens (for the match-end ad and export gating), the same way
/// `PlayerNames`/`ThemeMode` are already threaded through this app.
class MonetizationController extends ChangeNotifier {
  final AdsService ads;
  final PurchaseGateway purchases;
  final ProStatusStore proStatusStore;
  final ConsentService consent;

  /// Whether the monetization stack (ads, consent, purchases) is
  /// active for this instance — defaults to the app-wide
  /// `feature_flags.monetizationEnabled` switch. Overridable only so
  /// tests can exercise both the enabled and disabled paths side by
  /// side; every real call site (`main.dart` and each screen's
  /// self-constructed fallback instance) leaves this unset, so the
  /// single top-level constant remains the one place to flip for a
  /// real build. See PHASE7_MONETIZATION_DISABLED_FOR_LAUNCH.md.
  final bool monetizationEnabled;

  MonetizationController({
    required this.ads,
    required this.purchases,
    required this.proStatusStore,
    required this.consent,
    bool? monetizationEnabled,
  }) : monetizationEnabled =
            monetizationEnabled ?? feature_flags.monetizationEnabled;

  bool _isPro = false;

  /// Whether the user should see full, unlocked access — either a real
  /// purchase/restore has unlocked it, or monetization is switched off
  /// entirely for this build, in which case every user gets full
  /// access for free by design (see [monetizationEnabled]).
  bool get isPro => !monetizationEnabled || _isPro;

  /// The store's localized price for [proProductId] (e.g. "$1.99"), or
  /// `null` while it's still loading or if the store couldn't provide
  /// one. Check [proPriceLoading] to tell those two apart — the dialog
  /// must never show blank/missing price text as if there simply were
  /// no price, while a real query is still in flight.
  String? _proPrice;
  String? get proPrice => _proPrice;

  bool _proPriceLoading = true;
  bool get proPriceLoading => _proPriceLoading;

  /// Whether UMP requires a "Privacy options" entry point for this user
  /// (EEA/UK) — resolved once [initialize] has gathered consent; false
  /// (hidden) until then and on any failure to determine it. Drives
  /// whether `SetupScreen`'s overflow menu shows its "Privacy options"
  /// item at all. See PHASE6_PRELAUNCH_PREP.md.
  bool _privacyOptionsRequired = false;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  StreamSubscription<PurchaseUpdate>? _subscription;
  final _feedbackController = StreamController<PurchaseFeedback>.broadcast();

  /// Emits once per purchase/restore state change — the UI listens to
  /// show localized SnackBars.
  Stream<PurchaseFeedback> get feedback => _feedbackController.stream;

  Future<void> initialize() async {
    _isPro = await proStatusStore.load();
    notifyListeners();

    _subscription = purchases.updates.listen(_onPurchaseUpdate);

    if (!monetizationEnabled) {
      // Monetization is switched off for this build (see
      // PHASE7_MONETIZATION_DISABLED_FOR_LAUNCH.md): no price to show
      // (the Pro dialog is hidden entirely), no GDPR/UMP consent to
      // gather (nothing to consent to with no ads ever requested), and
      // no AdMob initialization/ad request of any kind. `isPro` already
      // reads `true` unconditionally regardless of `_isPro` above, so
      // every Pro-gated feature behaves as already unlocked.
      _proPriceLoading = false;
      notifyListeners();
      return;
    }

    if (!_isPro) {
      unawaited(_loadProPrice());
    } else {
      _proPriceLoading = false;
    }

    // GDPR/UK consent (Phase 6) must be gathered — and, outside the
    // EEA/UK, confirmed not required — before any ad request. This runs
    // regardless of Pro status so the "Privacy options" menu entry stays
    // available even if the user later restores/loses Pro.
    await consent.gatherConsent();
    _privacyOptionsRequired = await consent.isPrivacyOptionsRequired();
    notifyListeners();

    await ads.initialize();
    if (!_isPro && await consent.canRequestAds()) {
      await ads.loadInterstitial();
    }
  }

  /// Re-opens the UMP consent form so the user can review or change
  /// their choice — wired to "Privacy options" in `SetupScreen`'s
  /// overflow menu.
  Future<void> openPrivacyOptionsForm() => consent.showPrivacyOptionsForm();

  Future<void> _onPurchaseUpdate(PurchaseUpdate update) async {
    switch (update.outcome) {
      case PurchaseOutcome.pending:
        _feedbackController.add(PurchaseFeedback.pending);
      case PurchaseOutcome.purchased:
      case PurchaseOutcome.restored:
        _isPro = true;
        await proStatusStore.save(true);
        notifyListeners();
        _feedbackController.add(update.outcome == PurchaseOutcome.purchased
            ? PurchaseFeedback.purchased
            : PurchaseFeedback.restored);
      case PurchaseOutcome.cancelled:
        _feedbackController.add(PurchaseFeedback.cancelled);
      case PurchaseOutcome.error:
        _feedbackController.add(PurchaseFeedback.error);
    }
  }

  /// Queries the store for [proProductId]'s localized price, run
  /// fire-and-forget from [initialize] so it never delays ads/consent
  /// startup — the buy button itself works with or without a price to
  /// display, since the store shows its own price at checkout regardless.
  Future<void> _loadProPrice() async {
    final price = await purchases.queryProPrice();
    _proPrice = price;
    _proPriceLoading = false;
    notifyListeners();
  }

  Future<void> buyPro() => purchases.buyPro();

  /// Triggers a re-query of past purchases. If nothing arrives within a
  /// short grace period, synthesizes [PurchaseFeedback.restoreNotFound]
  /// — the store APIs simply emit no event at all for "nothing to
  /// restore," so there's no other way to tell the user that plainly.
  Future<void> restorePurchases() async {
    final wasProBefore = _isPro;
    await purchases.restorePurchases();
    if (wasProBefore) return; // already unlocked; nothing to report
    await Future.delayed(const Duration(seconds: 2));
    if (!_isPro) {
      _feedbackController.add(PurchaseFeedback.restoreNotFound);
    }
  }

  /// Shows the match-end interstitial, unless Pro has removed ads (or
  /// monetization is switched off entirely — see [monetizationEnabled],
  /// which [isPro] already folds in). Safe to call unconditionally from
  /// a match-complete handler.
  Future<void> maybeShowMatchEndAd() async {
    if (isPro) return;
    await ads.showMatchEndInterstitial();
  }

  /// How many completed matches must pass before the occasional,
  /// unprompted "Remove Ads" upsell is offered again — real-device
  /// testing found it appearing after *every* match felt naggy. This
  /// only gates the automatic offer; the purchase flow itself (via
  /// [ProDialog]) always stays reachable at any time through the setup
  /// screen's persistent app-bar icon, match count notwithstanding.
  static const upsellIntervalMatches = 3;

  int _matchesSinceLastUpsell = 0;
  bool _upsellDismissedThisSession = false;

  /// Whether the automatic post-match "Remove Ads" upsell should be
  /// shown right now — never while Pro is already owned (or
  /// monetization is switched off entirely, which [isPro] already folds
  /// in), never more than once per [upsellIntervalMatches] completed
  /// matches, and never again this session once the user has closed it
  /// without buying (see [dismissUpsell]). Only ever checked at
  /// match-end, never mid-match.
  bool get shouldOfferUpsell =>
      !isPro &&
      !_upsellDismissedThisSession &&
      _matchesSinceLastUpsell >= upsellIntervalMatches;

  /// Call once per completed match, regardless of whether an ad was
  /// shown for it — the upsell cadence is measured in matches played,
  /// not ads seen.
  void recordMatchCompleted() {
    _matchesSinceLastUpsell++;
  }

  /// Call right before actually presenting the automatic upsell, so the
  /// next offer waits another [upsellIntervalMatches] matches regardless
  /// of what the user does with this one.
  void markUpsellShown() {
    _matchesSinceLastUpsell = 0;
  }

  /// Call once the automatic upsell dialog has closed without the user
  /// having purchased Pro — suppresses further automatic offers for the
  /// rest of this session. Has no effect on the manually-opened purchase
  /// dialog, which is unaffected by this and always available.
  void dismissUpsell() {
    _upsellDismissedThisSession = true;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _feedbackController.close();
    ads.dispose();
    purchases.dispose();
    super.dispose();
  }
}
