import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// The one product this app sells — a single non-consumable unlock. See
/// PHASE5_MONETIZATION.md for what it's currently set to (a test/sandbox
/// ID) and what to change before release.
const proProductId = 'remove_ads_pro_test';

/// What happened to a purchase or restore attempt, decoupled from
/// `package:in_app_purchase`'s own [PurchaseStatus] so the rest of the
/// app (and tests) don't need to depend on real store types — mirrors
/// the [VoiceAnnouncer]/[TtsEngine] pattern already used for TTS.
enum PurchaseOutcome { pending, purchased, restored, cancelled, error }

class PurchaseUpdate {
  final String productId;
  final PurchaseOutcome outcome;
  final String? errorMessage;

  const PurchaseUpdate({
    required this.productId,
    required this.outcome,
    this.errorMessage,
  });
}

/// Everything [MonetizationController] needs from a purchase backend —
/// implemented for real by [InAppPurchaseGateway] (wrapping
/// `package:in_app_purchase`) and by a hand-written fake in tests, which
/// never touch real Play Billing/StoreKit.
abstract class PurchaseGateway {
  /// Fires once per purchase-flow state change — pending, purchased,
  /// restored, cancelled, or error.
  Stream<PurchaseUpdate> get updates;

  Future<bool> isAvailable();

  /// Starts the purchase flow for [proProductId]. Outcomes arrive via
  /// [updates], not this method's return value — buying is inherently
  /// asynchronous and can also be initiated by the OS (e.g. a purchase
  /// already pending from a previous session).
  Future<void> buyPro();

  /// Re-queries previously-made purchases (required by both Play Store
  /// and App Store policy, and essential after a reinstall/device
  /// switch). Outcomes for anything found arrive via [updates]; finding
  /// nothing produces no event at all, which is a real quirk of the
  /// underlying store APIs — see [MonetizationController.restorePurchases]
  /// for how that's handled gracefully.
  Future<void> restorePurchases();

  /// The store's own localized price string for [proProductId] (e.g.
  /// "$1.99", already formatted for the user's currency/locale by Play
  /// Billing/StoreKit), or `null` if the store is unavailable or the
  /// product wasn't found. Never hardcode a price in the UI — this is
  /// the only source of truth for it.
  Future<String?> queryProPrice();

  void dispose();
}

/// The real implementation, wrapping `InAppPurchase.instance`. Never
/// constructed in tests — see `test/monetization_controller_test.dart`'s
/// `_FakePurchaseGateway` instead.
class InAppPurchaseGateway implements PurchaseGateway {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _updatesController = StreamController<PurchaseUpdate>.broadcast();

  InAppPurchaseGateway() {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseDetails,
      onError: (Object error) {
        _updatesController.add(PurchaseUpdate(
          productId: proProductId,
          outcome: PurchaseOutcome.error,
          errorMessage: error.toString(),
        ));
      },
    );
  }

  @override
  Stream<PurchaseUpdate> get updates => _updatesController.stream;

  void _onPurchaseDetails(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _updatesController.add(PurchaseUpdate(
            productId: purchase.productID,
            outcome: PurchaseOutcome.pending,
          ));
        case PurchaseStatus.purchased:
          _updatesController.add(PurchaseUpdate(
            productId: purchase.productID,
            outcome: PurchaseOutcome.purchased,
          ));
          _complete(purchase);
        case PurchaseStatus.restored:
          _updatesController.add(PurchaseUpdate(
            productId: purchase.productID,
            outcome: PurchaseOutcome.restored,
          ));
          _complete(purchase);
        case PurchaseStatus.canceled:
          _updatesController.add(PurchaseUpdate(
            productId: purchase.productID,
            outcome: PurchaseOutcome.cancelled,
          ));
        case PurchaseStatus.error:
          _updatesController.add(PurchaseUpdate(
            productId: purchase.productID,
            outcome: PurchaseOutcome.error,
            errorMessage: purchase.error?.message,
          ));
      }
    }
  }

  void _complete(PurchaseDetails purchase) {
    if (purchase.pendingCompletePurchase) {
      _iap.completePurchase(purchase);
    }
  }

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<void> buyPro() async {
    try {
      if (!await _iap.isAvailable()) {
        _updatesController.add(const PurchaseUpdate(
          productId: proProductId,
          outcome: PurchaseOutcome.error,
          errorMessage: 'store unavailable',
        ));
        return;
      }
      final response = await _iap.queryProductDetails({proProductId});
      if (response.productDetails.isEmpty) {
        _updatesController.add(const PurchaseUpdate(
          productId: proProductId,
          outcome: PurchaseOutcome.error,
          errorMessage: 'product not found',
        ));
        return;
      }
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
      );
    } catch (e) {
      _updatesController.add(PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.error,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _updatesController.add(PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.error,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<String?> queryProPrice() async {
    try {
      if (!await _iap.isAvailable()) return null;
      final response = await _iap.queryProductDetails({proProductId});
      if (response.productDetails.isEmpty) return null;
      return response.productDetails.first.price;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _updatesController.close();
  }
}
