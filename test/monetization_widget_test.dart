import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/screens/setup_screen.dart';
import 'package:tabletennis_scoreboard/services/ads_service.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/consent_service.dart';
import 'package:tabletennis_scoreboard/services/monetization_controller.dart';
import 'package:tabletennis_scoreboard/services/pro_status_store.dart';
import 'package:tabletennis_scoreboard/services/purchase_gateway.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';

/// Never touches real AdMob — see [MonetizationController]'s own tests
/// (test/monetization_controller_test.dart) for the non-UI coverage of
/// this fake's counterpart.
class _FakeAdsService implements AdsService {
  int showMatchEndInterstitialCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadInterstitial() async {}

  @override
  Future<void> showMatchEndInterstitial() async =>
      showMatchEndInterstitialCalls++;

  @override
  void dispose() {}
}

/// Never touches real Play Billing/StoreKit — tests drive outcomes via
/// [emit], and can assert on [buyProCalls]/[restorePurchasesCalls].
class _FakePurchaseGateway implements PurchaseGateway {
  final _controller = StreamController<PurchaseUpdate>.broadcast();
  int buyProCalls = 0;
  int restorePurchasesCalls = 0;

  /// Settable so tests can drive what the Pro dialog shows for the price
  /// — defaults to a price so tests that don't care about it see the
  /// dialog settle into a normal, non-loading state.
  String? queryProPriceResult = r'$1.99';

  /// Set by tests that need to control exactly when the price query
  /// resolves (e.g. via a [Completer]), to assert on the dialog's
  /// loading state in between. Takes priority over [queryProPriceResult].
  Future<String?> Function()? queryProPriceImpl;

  @override
  Stream<PurchaseUpdate> get updates => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> buyPro() async => buyProCalls++;

  @override
  Future<void> restorePurchases() async => restorePurchasesCalls++;

  @override
  Future<String?> queryProPrice() =>
      queryProPriceImpl != null ? queryProPriceImpl!() : Future.value(queryProPriceResult);

  void emit(PurchaseUpdate update) => _controller.add(update);

  @override
  void dispose() => _controller.close();
}

/// Never touches the real UMP SDK — defaults mirror "no consent needed"
/// (outside EEA/UK), matching what most widget tests here don't care
/// about; see test/monetization_controller_test.dart for the dedicated
/// GDPR-gating coverage.
class _FakeConsentService implements ConsentService {
  /// Settable so tests can simulate an EEA/UK user (true) vs. everyone
  /// else (false, the default).
  bool privacyOptionsRequired = false;
  int showPrivacyOptionsFormCalls = 0;

  @override
  Future<void> gatherConsent() async {}

  @override
  Future<bool> canRequestAds() async => true;

  @override
  Future<bool> isPrivacyOptionsRequired() async => privacyOptionsRequired;

  @override
  Future<void> showPrivacyOptionsForm() async => showPrivacyOptionsFormCalls++;
}

class _RecordingTtsEngine implements TtsEngine {
  @override
  Future<bool> isLanguageAvailable(String language) async => true;
  @override
  Future<void> setLanguage(String language) async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

class _NoopClipPlayer implements ClipPlayer {
  @override
  Future<void> playClip(String assetPath) async {}
  @override
  Future<void> stop() async {}
}

VoiceAnnouncer _silentVoice() =>
    VoiceAnnouncer(ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());

/// Plays a straight-2-0 best-of-3 match to completion on whichever
/// scoreboard screen is currently showing (player1Zone taps throughout),
/// leaving the match-complete dialog on screen.
Future<void> _playMatchToCompletion(WidgetTester tester) async {
  for (var game = 0; game < 2; game++) {
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byKey(const Key('player1Zone')));
      await tester.pump();
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Pro dialog (Phase 5)', () {
    testWidgets(
        'the setup screen shows a Pro app-bar icon that opens the purchase '
        'dialog with buy/restore buttons when not yet Pro', (tester) async {
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: _FakePurchaseGateway(),
        proStatusStore: ProStatusStore(),
        consent: _FakeConsentService(),
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupScreen(
          currentLocaleOverride: null,
          onLocaleChanged: (_) {},
          themeMode: ThemeMode.dark,
          onThemeModeChanged: (_) {},
          monetization: monetization,
        ),
      ));

      // The theme/language/Pro icons were consolidated into one app-bar
      // overflow menu in Phase 4I — see PHASE4I_POLISH_ROUND2.md.
      expect(find.byKey(const Key('overflowMenuButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proMenuButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('proMenuButton')));
      await tester.pumpAndSettle();

      expect(find.text('Remove Ads / Pro'), findsWidgets);
      expect(
        find.text('A one-time purchase that removes ads.'),
        findsOneWidget,
      );
      // Regression check (a real Play Console review caught this): match
      // export is a real, Pro-gated feature (see the "Match export" group
      // below), but the dialog must not advertise it as a purchase
      // benefit — see PHASE5_MONETIZATION.md.
      expect(find.textContaining('export'), findsNothing);
      expect(find.byKey(const Key('proBuyButton')), findsOneWidget);
      expect(find.byKey(const Key('proRestoreButton')), findsOneWidget);
    });

    testWidgets(
        'tapping "Remove Ads" starts the purchase flow, and a successful '
        'purchase switches the dialog to the already-Pro state with an '
        'inline success message', (tester) async {
      final purchases = _FakePurchaseGateway();
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: purchases,
        proStatusStore: ProStatusStore(),
        consent: _FakeConsentService(),
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupScreen(
          currentLocaleOverride: null,
          onLocaleChanged: (_) {},
          themeMode: ThemeMode.dark,
          onThemeModeChanged: (_) {},
          monetization: monetization,
        ),
      ));

      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proBuyButton')));
      await tester.pump();

      expect(purchases.buyProCalls, 1);

      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.purchased,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Purchase successful — ads removed!'), findsOneWidget);
      expect(find.text("You're Pro!"), findsOneWidget);
      expect(find.byKey(const Key('proBuyButton')), findsNothing);
    });

    testWidgets(
        'tapping "Restore purchases" with nothing to restore eventually '
        'shows an inline "no previous purchase found" message, never '
        'leaving the user with no feedback at all', (tester) async {
      final purchases = _FakePurchaseGateway();
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: purchases,
        proStatusStore: ProStatusStore(),
        consent: _FakeConsentService(),
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupScreen(
          currentLocaleOverride: null,
          onLocaleChanged: (_) {},
          themeMode: ThemeMode.dark,
          onThemeModeChanged: (_) {},
          monetization: monetization,
        ),
      ));

      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proRestoreButton')));
      await tester.pump();

      expect(purchases.restorePurchasesCalls, 1);

      // The grace-period heuristic waits ~2 seconds before concluding
      // nothing was found — advance the (fake, test-controlled) clock
      // past that without a real-time wait.
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('No previous purchase found.'), findsOneWidget);
    });

    testWidgets(
        'shows a loading state for the price while the store query is '
        'still in flight, then the real localized price once it resolves',
        (tester) async {
      final priceCompleter = Completer<String?>();
      final purchases = _FakePurchaseGateway()
        ..queryProPriceImpl = () => priceCompleter.future;
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: purchases,
        proStatusStore: ProStatusStore(),
        consent: _FakeConsentService(),
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupScreen(
          currentLocaleOverride: null,
          onLocaleChanged: (_) {},
          themeMode: ThemeMode.dark,
          onThemeModeChanged: (_) {},
          monetization: monetization,
        ),
      ));

      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proMenuButton')));
      await tester.pumpAndSettle();

      // Never blank/missing while the query is in flight.
      expect(find.byKey(const Key('proPriceText')), findsOneWidget);
      expect(find.text('Loading price…'), findsOneWidget);
      expect(find.text(r'$1.99'), findsNothing);

      priceCompleter.complete(r'$1.99');
      await tester.pumpAndSettle();

      expect(find.text('Loading price…'), findsNothing);
      expect(find.text(r'$1.99'), findsOneWidget);
    });

    testWidgets(
        'shows no price line (but still a working buy button) when the '
        'store has no price to offer', (tester) async {
      final purchases = _FakePurchaseGateway()..queryProPriceResult = null;
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: purchases,
        proStatusStore: ProStatusStore(),
        consent: _FakeConsentService(),
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupScreen(
          currentLocaleOverride: null,
          onLocaleChanged: (_) {},
          themeMode: ThemeMode.dark,
          onThemeModeChanged: (_) {},
          monetization: monetization,
        ),
      ));

      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proMenuButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('proPriceText')), findsNothing);
      expect(find.byKey(const Key('proBuyButton')), findsOneWidget);
    });
  });

  group('Match export (Phase 5 — Pro-only)', () {
    testWidgets(
        'a free user sees no export button on the match-complete dialog',
        (tester) async {
      final fakeAds = _FakeAdsService();
      final monetization = MonetizationController(
        ads: fakeAds,
        purchases: _FakePurchaseGateway(),
        proStatusStore: ProStatusStore(),
        consent: _FakeConsentService(),
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 3,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
          monetization: monetization,
        ),
      ));

      await _playMatchToCompletion(tester);

      expect(find.byKey(const Key('matchCompleteDialog')), findsOneWidget);
      expect(find.byKey(const Key('exportMatchButton')), findsNothing);
      // The match-end ad path still fires for a free user (Phase 5 scope:
      // Pro gates ad removal + export only).
      expect(fakeAds.showMatchEndInterstitialCalls, 1);
    });

    testWidgets(
        'a Pro user sees the export button, and tapping it copies a match '
        'summary to the clipboard and confirms inline',
        (tester) async {
      final fakeAds = _FakeAdsService();
      final purchases = _FakePurchaseGateway();
      final monetization = MonetizationController(
        ads: fakeAds,
        purchases: purchases,
        proStatusStore: ProStatusStore(),
        consent: _FakeConsentService(),
      );
      await monetization.initialize();
      purchases.emit(const PurchaseUpdate(
        productId: proProductId,
        outcome: PurchaseOutcome.purchased,
      ));
      // Not just a single pump(): the purchase-update handler awaits
      // ProStatusStore.save (its own SharedPreferences round-trip) before
      // setting isPro, which can take more than one microtask turn to
      // resolve.
      await tester.pumpAndSettle();
      expect(monetization.isPro, isTrue);

      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      });

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 3,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
          monetization: monetization,
        ),
      ));

      await _playMatchToCompletion(tester);

      expect(find.byKey(const Key('matchCompleteDialog')), findsOneWidget);
      // Pro removes ads — the match-end ad path must not fire.
      expect(fakeAds.showMatchEndInterstitialCalls, 0);

      expect(find.byKey(const Key('exportMatchButton')), findsOneWidget);
      expect(find.text('Export match result'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exportMatchButton')));
      await tester.pump();

      expect(copiedText, isNotNull);
      expect(copiedText, contains('Table Tennis Scoreboard'));
      expect(copiedText, contains('Game 1: 11-0'));
      expect(copiedText, contains('Game 2: 11-0'));
      expect(copiedText, contains('Player 1 wins the match!'));
      // The confirmation replaces the button's own label in-place (a
      // SnackBar can't be used here — see MatchCompleteDialog's doc
      // comment for why one triggered from inside an open dialog never
      // actually animates into view).
      expect(
        find.text('Match result copied to clipboard'),
        findsOneWidget,
      );
      expect(find.text('Export match result'), findsNothing);

      final exportButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('exportMatchButton')),
      );
      expect(exportButton.onPressed, isNull,
          reason: 'tapping export again should be a no-op once confirmed');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('Ad-removal upsell cadence (Phase 5 real-device fix)', () {
    testWidgets(
        'the automatic "Remove Ads" upsell does not appear after the '
        '1st or 2nd completed match, only the 3rd', (tester) async {
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: _FakePurchaseGateway(),
        proStatusStore: ProStatusStore(),
        consent: _FakeConsentService(),
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 3,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
          monetization: monetization,
        ),
      ));

      // Match 1: complete it, dismiss via "New match" — no upsell.
      await _playMatchToCompletion(tester);
      await tester.tap(find.byKey(const Key('newMatchButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proDialogTitleText')), findsNothing);

      // Match 2: same — still no upsell.
      await _playMatchToCompletion(tester);
      await tester.tap(find.byKey(const Key('newMatchButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proDialogTitleText')), findsNothing);

      // Match 3: the upsell should now appear automatically.
      await _playMatchToCompletion(tester);
      await tester.tap(find.byKey(const Key('newMatchButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proDialogTitleText')), findsOneWidget);
      // The purchase flow inside it is the same reachable-anytime dialog.
      expect(find.byKey(const Key('proBuyButton')), findsOneWidget);
    });

    testWidgets(
        'once dismissed without buying, the upsell never reappears again '
        'this session even after another full interval of matches',
        (tester) async {
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: _FakePurchaseGateway(),
        proStatusStore: ProStatusStore(),
        consent: _FakeConsentService(),
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 3,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
          monetization: monetization,
        ),
      ));

      for (var match = 0; match < 3; match++) {
        await _playMatchToCompletion(tester);
        await tester.tap(find.byKey(const Key('newMatchButton')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('proDialogTitleText')), findsOneWidget);

      // Dismiss it by tapping the modal barrier (a corner well outside
      // the centered dialog card) without buying.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proDialogTitleText')), findsNothing);
      expect(monetization.isPro, isFalse);

      // Another full interval of matches should NOT bring it back.
      for (var match = 0; match < 3; match++) {
        await _playMatchToCompletion(tester);
        await tester.tap(find.byKey(const Key('newMatchButton')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('proDialogTitleText')), findsNothing);
    });

    testWidgets(
        'the purchase flow stays reachable via the app-bar icon even '
        'when the automatic upsell has not (yet) triggered', (tester) async {
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: _FakePurchaseGateway(),
        proStatusStore: ProStatusStore(),
        consent: _FakeConsentService(),
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupScreen(
          currentLocaleOverride: null,
          onLocaleChanged: (_) {},
          themeMode: ThemeMode.dark,
          onThemeModeChanged: (_) {},
          monetization: monetization,
        ),
      ));

      expect(monetization.shouldOfferUpsell, isFalse);
      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proMenuButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proBuyButton')), findsOneWidget);
    });
  });

  group('GDPR "Privacy options" / "Privacy Policy" menu entries (Phase 6)',
      () {
    testWidgets(
        '"Privacy options" is hidden when UMP says no consent decision '
        'exists for this user (outside the EEA/UK)', (tester) async {
      final consent = _FakeConsentService()..privacyOptionsRequired = false;
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: _FakePurchaseGateway(),
        proStatusStore: ProStatusStore(),
        consent: consent,
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupScreen(
          currentLocaleOverride: null,
          onLocaleChanged: (_) {},
          themeMode: ThemeMode.dark,
          onThemeModeChanged: (_) {},
          monetization: monetization,
        ),
      ));

      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('privacyOptionsMenuButton')), findsNothing);
      // The Privacy Policy link is unconditional — shown regardless of
      // region, since it's just informational.
      expect(find.byKey(const Key('privacyPolicyMenuButton')), findsOneWidget);

      // Tapping it must never crash, even though `flutter test` has no
      // real url_launcher platform implementation to actually open a
      // browser with — the failure is caught and only logged, the same
      // best-effort stance as every other optional action in this app.
      await tester.tap(find.byKey(const Key('privacyPolicyMenuButton')));
      await tester.pumpAndSettle();
    });

    testWidgets(
        '"Privacy options" is shown and re-opens the UMP consent form when '
        'UMP says this user (EEA/UK) has a consent decision on file',
        (tester) async {
      final consent = _FakeConsentService()..privacyOptionsRequired = true;
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: _FakePurchaseGateway(),
        proStatusStore: ProStatusStore(),
        consent: consent,
      );
      await monetization.initialize();

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupScreen(
          currentLocaleOverride: null,
          onLocaleChanged: (_) {},
          themeMode: ThemeMode.dark,
          onThemeModeChanged: (_) {},
          monetization: monetization,
        ),
      ));

      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('privacyOptionsMenuButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('privacyOptionsMenuButton')));
      await tester.pumpAndSettle();
      expect(consent.showPrivacyOptionsFormCalls, 1);
    });
  });
}
