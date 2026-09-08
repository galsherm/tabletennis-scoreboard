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
  void dispose() => _controller.close();
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

      expect(find.byKey(const Key('proMenuButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('proMenuButton')));
      await tester.pumpAndSettle();

      expect(find.text('Remove Ads / Pro'), findsWidgets);
      expect(
        find.text(
            'A one-time purchase that removes ads and unlocks exporting '
            'your match results.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('proBuyButton')), findsOneWidget);
      expect(find.byKey(const Key('proRestoreButton')), findsOneWidget);
    });

    testWidgets(
        'tapping "Remove Ads" starts the purchase flow, and a successful '
        'purchase switches the dialog to the already-Pro state with a '
        'success SnackBar', (tester) async {
      final purchases = _FakePurchaseGateway();
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: purchases,
        proStatusStore: ProStatusStore(),
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
        'shows a "no previous purchase found" SnackBar, never leaving the '
        'user with no feedback at all', (tester) async {
      final purchases = _FakePurchaseGateway();
      final monetization = MonetizationController(
        ads: _FakeAdsService(),
        purchases: purchases,
        proStatusStore: ProStatusStore(),
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
  });

  group('Match export (Phase 5 — Pro-only)', () {
    Future<void> playToMatchEnd(WidgetTester tester) async {
      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('player1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();
    }

    testWidgets(
        'a free user sees no export button on the match-complete dialog',
        (tester) async {
      final fakeAds = _FakeAdsService();
      final monetization = MonetizationController(
        ads: fakeAds,
        purchases: _FakePurchaseGateway(),
        proStatusStore: ProStatusStore(),
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

      await playToMatchEnd(tester);

      expect(find.byKey(const Key('matchCompleteDialog')), findsOneWidget);
      expect(find.byKey(const Key('exportMatchButton')), findsNothing);
      // The match-end ad path still fires for a free user (Phase 5 scope:
      // Pro gates ad removal + export only).
      expect(fakeAds.showMatchEndInterstitialCalls, 1);
    });

    testWidgets(
        'a Pro user sees the export button, and tapping it copies a match '
        'summary to the clipboard and confirms with a SnackBar',
        (tester) async {
      final fakeAds = _FakeAdsService();
      final purchases = _FakePurchaseGateway();
      final monetization = MonetizationController(
        ads: fakeAds,
        purchases: purchases,
        proStatusStore: ProStatusStore(),
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

      await playToMatchEnd(tester);

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
}
