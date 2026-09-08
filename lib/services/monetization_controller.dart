import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ads_service.dart';
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

  MonetizationController({
    required this.ads,
    required this.purchases,
    required this.proStatusStore,
  });

  bool _isPro = false;
  bool get isPro => _isPro;

  StreamSubscription<PurchaseUpdate>? _subscription;
  final _feedbackController = StreamController<PurchaseFeedback>.broadcast();

  /// Emits once per purchase/restore state change — the UI listens to
  /// show localized SnackBars.
  Stream<PurchaseFeedback> get feedback => _feedbackController.stream;

  Future<void> initialize() async {
    _isPro = await proStatusStore.load();
    notifyListeners();

    _subscription = purchases.updates.listen(_onPurchaseUpdate);

    await ads.initialize();
    if (!_isPro) {
      await ads.loadInterstitial();
    }
  }

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

  /// Shows the match-end interstitial, unless Pro has removed ads. Safe
  /// to call unconditionally from a match-complete handler.
  Future<void> maybeShowMatchEndAd() async {
    if (_isPro) return;
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
  /// shown right now — never while Pro is already owned, never more than
  /// once per [upsellIntervalMatches] completed matches, and never again
  /// this session once the user has closed it without buying (see
  /// [dismissUpsell]). Only ever checked at match-end, never mid-match.
  bool get shouldOfferUpsell =>
      !_isPro &&
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
