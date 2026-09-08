import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/services/ads_service.dart';
import 'package:tabletennis_scoreboard/services/monetization_controller.dart';
import 'package:tabletennis_scoreboard/services/pro_status_store.dart';
import 'package:tabletennis_scoreboard/services/purchase_gateway.dart';

/// Hand-written fake — never touches real AdMob, and lets tests assert on
/// exactly what [MonetizationController] asked of it.
class _FakeAdsService implements AdsService {
  int initializeCalls = 0;
  int loadInterstitialCalls = 0;
  int showMatchEndInterstitialCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<void> loadInterstitial() async => loadInterstitialCalls++;

  @override
  Future<void> showMatchEndInterstitial() async =>
      showMatchEndInterstitialCalls++;

  @override
  void dispose() => disposeCalls++;
}

/// Hand-written fake — never touches real Play Billing/StoreKit. Tests
/// drive purchase-flow outcomes by calling [emit] directly, standing in
/// for what a real store would push through `purchaseStream`.
class _FakePurchaseGateway implements PurchaseGateway {
  final _controller = StreamController<PurchaseUpdate>.broadcast();
  int buyProCalls = 0;
  int restorePurchasesCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<PurchaseUpdate> get updates => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> buyPro() async => buyProCalls++;

  @override
  Future<void> restorePurchases() async => restorePurchasesCalls++;

  void emit(PurchaseUpdate update) => _controller.add(update);

  @override
  void dispose() {
    disposeCalls++;
    _controller.close();
  }
}

void main() {
  late _FakeAdsService ads;
  late _FakePurchaseGateway purchases;
  late MonetizationController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ads = _FakeAdsService();
    purchases = _FakePurchaseGateway();
    controller = MonetizationController(
      ads: ads,
      purchases: purchases,
      proStatusStore: ProStatusStore(),
    );
  });

  tearDown(() {
    // Several tests dispose `controller` themselves to assert on the
    // dispose call — guard against disposing twice, which throws.
    try {
      controller.dispose();
    } catch (_) {}
  });

  group('MonetizationController.initialize', () {
    test('starts as not-Pro, initializes ads, and preloads an interstitial '
        'when no purchase has been persisted', () async {
      await controller.initialize();
      expect(controller.isPro, isFalse);
      expect(ads.initializeCalls, 1);
      expect(ads.loadInterstitialCalls, 1);
    });

    test('loads persisted Pro status and skips preloading an ad when Pro '
        'was already purchased in a previous session', () async {
      SharedPreferences.setMockInitialValues({'is_pro': true});
      final proController = MonetizationController(
        ads: ads,
        purchases: purchases,
        proStatusStore: ProStatusStore(),
      );
      await proController.initialize();
      expect(proController.isPro, isTrue);
      expect(ads.initializeCalls, 1);
      expect(ads.loadInterstitialCalls, 0);
      proController.dispose();
    });
  });

  group('MonetizationController.buyPro', () {
    test('delegates to the purchase gateway', () async {
      await controller.initialize();
      await controller.buyPro();
      expect(purchases.buyProCalls, 1);
    });
  });

  group('purchase-flow state handling', () {
    test('a purchased update unlocks Pro, persists it, and emits success '
        'feedback', () async {
      await controller.initialize();
      final feedback = <PurchaseFeedback>[];
      controller.feedback.listen(feedback.add);

      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.purchased,
      ));
      await pumpEventQueue();

      expect(controller.isPro, isTrue);
      expect(feedback, [PurchaseFeedback.purchased]);
      expect(await ProStatusStore().load(), isTrue);
    });

    test('a restored update unlocks Pro and emits restored feedback',
        () async {
      await controller.initialize();
      final feedback = <PurchaseFeedback>[];
      controller.feedback.listen(feedback.add);

      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.restored,
      ));
      await pumpEventQueue();

      expect(controller.isPro, isTrue);
      expect(feedback, [PurchaseFeedback.restored]);
    });

    test('a pending update emits pending feedback without unlocking Pro',
        () async {
      await controller.initialize();
      final feedback = <PurchaseFeedback>[];
      controller.feedback.listen(feedback.add);

      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.pending,
      ));
      await pumpEventQueue();

      expect(controller.isPro, isFalse);
      expect(feedback, [PurchaseFeedback.pending]);
    });

    test('a cancelled update emits cancelled feedback without unlocking '
        'Pro or crashing', () async {
      await controller.initialize();
      final feedback = <PurchaseFeedback>[];
      controller.feedback.listen(feedback.add);

      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.cancelled,
      ));
      await pumpEventQueue();

      expect(controller.isPro, isFalse);
      expect(feedback, [PurchaseFeedback.cancelled]);
    });

    test('an error update emits error feedback without unlocking Pro or '
        'crashing', () async {
      await controller.initialize();
      final feedback = <PurchaseFeedback>[];
      controller.feedback.listen(feedback.add);

      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.error,
        errorMessage: 'network unreachable',
      ));
      await pumpEventQueue();

      expect(controller.isPro, isFalse);
      expect(feedback, [PurchaseFeedback.error]);
    });
  });

  group('MonetizationController.restorePurchases', () {
    test('emits restoreNotFound if nothing arrives from the gateway — the '
        'store APIs emit no event at all for "nothing to restore," so '
        'this has to be synthesized client-side', () async {
      await controller.initialize();
      final feedback = <PurchaseFeedback>[];
      controller.feedback.listen(feedback.add);

      await controller.restorePurchases();
      // The feedback stream's own listener delivery and this test's await
      // resumption are two independently-scheduled microtasks with no
      // guaranteed relative order — pumpEventQueue flushes both before
      // asserting, the same safety net the purchase-outcome tests above
      // rely on.
      await pumpEventQueue();

      expect(purchases.restorePurchasesCalls, 1);
      expect(controller.isPro, isFalse);
      expect(feedback, [PurchaseFeedback.restoreNotFound]);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('does not emit restoreNotFound when a restored purchase actually '
        'arrives in time', () async {
      await controller.initialize();
      final feedback = <PurchaseFeedback>[];
      controller.feedback.listen(feedback.add);

      final restoreFuture = controller.restorePurchases();
      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.restored,
      ));
      await restoreFuture;

      expect(controller.isPro, isTrue);
      expect(feedback, [PurchaseFeedback.restored]);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('is a no-op (no restoreNotFound) when Pro was already unlocked '
        'before restoring', () async {
      await controller.initialize();
      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.purchased,
      ));
      await pumpEventQueue();
      expect(controller.isPro, isTrue);

      final feedback = <PurchaseFeedback>[];
      controller.feedback.listen(feedback.add);
      await controller.restorePurchases();

      expect(feedback, isEmpty);
    });
  });

  group('MonetizationController.maybeShowMatchEndAd', () {
    test('shows the interstitial when the user is not Pro', () async {
      await controller.initialize();
      await controller.maybeShowMatchEndAd();
      expect(ads.showMatchEndInterstitialCalls, 1);
    });

    test('never shows an ad once Pro is unlocked', () async {
      await controller.initialize();
      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.purchased,
      ));
      await pumpEventQueue();

      await controller.maybeShowMatchEndAd();
      expect(ads.showMatchEndInterstitialCalls, 0);
    });
  });

  group('MonetizationController.shouldOfferUpsell (ad-prompt cadence)', () {
    test('is false until upsellIntervalMatches matches have completed',
        () async {
      await controller.initialize();
      expect(controller.shouldOfferUpsell, isFalse);
      for (var i = 0; i < MonetizationController.upsellIntervalMatches - 1;
          i++) {
        controller.recordMatchCompleted();
      }
      expect(controller.shouldOfferUpsell, isFalse);
    });

    test('becomes true once upsellIntervalMatches matches have completed',
        () async {
      await controller.initialize();
      for (var i = 0; i < MonetizationController.upsellIntervalMatches; i++) {
        controller.recordMatchCompleted();
      }
      expect(controller.shouldOfferUpsell, isTrue);
    });

    test('markUpsellShown resets the count, so the next offer waits '
        'another full interval', () async {
      await controller.initialize();
      for (var i = 0; i < MonetizationController.upsellIntervalMatches; i++) {
        controller.recordMatchCompleted();
      }
      expect(controller.shouldOfferUpsell, isTrue);

      controller.markUpsellShown();
      expect(controller.shouldOfferUpsell, isFalse);

      for (var i = 0; i < MonetizationController.upsellIntervalMatches - 1;
          i++) {
        controller.recordMatchCompleted();
      }
      expect(controller.shouldOfferUpsell, isFalse);
      controller.recordMatchCompleted();
      expect(controller.shouldOfferUpsell, isTrue);
    });

    test('dismissUpsell suppresses further offers for the rest of the '
        'session, even after another full interval passes', () async {
      await controller.initialize();
      for (var i = 0; i < MonetizationController.upsellIntervalMatches; i++) {
        controller.recordMatchCompleted();
      }
      controller.dismissUpsell();
      expect(controller.shouldOfferUpsell, isFalse);

      for (var i = 0; i < MonetizationController.upsellIntervalMatches; i++) {
        controller.recordMatchCompleted();
      }
      expect(controller.shouldOfferUpsell, isFalse);
    });

    test('never offers the upsell once Pro is purchased, regardless of '
        'match count', () async {
      await controller.initialize();
      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.purchased,
      ));
      await pumpEventQueue();

      for (var i = 0; i < MonetizationController.upsellIntervalMatches; i++) {
        controller.recordMatchCompleted();
      }
      expect(controller.shouldOfferUpsell, isFalse);
    });
  });

  group('MonetizationController.dispose', () {
    test('disposes both the ads service and the purchase gateway', () async {
      await controller.initialize();
      controller.dispose();
      expect(ads.disposeCalls, 1);
      expect(purchases.disposeCalls, 1);
    });
  });
}
