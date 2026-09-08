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

  @override
  void dispose() {
    _subscription?.cancel();
    _feedbackController.close();
    ads.dispose();
    purchases.dispose();
    super.dispose();
  }
}
