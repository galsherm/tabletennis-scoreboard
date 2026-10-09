import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/doubles_scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/screens/scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/screens/setup_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/review_prompt_store.dart';
import 'package:tabletennis_scoreboard/services/review_prompter.dart';
import 'package:tabletennis_scoreboard/services/review_service.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';

class _FakeReviewService implements ReviewService {
  bool throwOnRequest = false;
  bool throwOnOpenStoreListing = false;

  int requestReviewCalls = 0;
  int openStoreListingCalls = 0;

  @override
  Future<void> requestReview() async {
    requestReviewCalls++;
    if (throwOnRequest) throw StateError('no review plugin');
  }

  @override
  Future<bool> openStoreListing() async {
    openStoreListingCalls++;
    if (throwOnOpenStoreListing) throw StateError('no store');
    return true;
  }
}

class _SilentTtsEngine implements TtsEngine {
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

VoiceAnnouncer _silentVoice() => VoiceAnnouncer(
    ttsEngine: _SilentTtsEngine(), clipPlayer: _NoopClipPlayer());

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// Flushes the prompter's fire-and-forget store/service round-trips.
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// Plays a straight-2-0 best-of-3 match on whichever scoreboard screen
/// is showing, leaving the match-complete dialog on screen.
Future<void> _playMatchToCompletion(WidgetTester tester, String zone) async {
  for (var i = 0; i < 22; i++) {
    await tester.tap(find.byKey(Key(zone)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _startNewMatch(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('newMatchButton')));
  await tester.pumpAndSettle();
  await _flush(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('shouldAutoPromptReview', () {
    bool eligible({
      required int completedMatches,
      bool autoPrompted = false,
      bool manualUsed = false,
      bool matchInProgress = false,
    }) =>
        shouldAutoPromptReview(
          completedMatches: completedMatches,
          autoPrompted: autoPrompted,
          manualUsed: manualUsed,
          matchInProgress: matchInProgress,
        );

    test('not before the 3rd completed match', () {
      expect(eligible(completedMatches: 0), isFalse);
      expect(eligible(completedMatches: 1), isFalse);
      expect(eligible(completedMatches: 2), isFalse);
    });

    test('on the 3rd completed match', () {
      expect(eligible(completedMatches: 3), isTrue);
    });

    test('still due later if the 3rd match itself had to be skipped', () {
      expect(eligible(completedMatches: 4), isTrue);
    });

    test('only once', () {
      expect(eligible(completedMatches: 3, autoPrompted: true), isFalse);
      expect(eligible(completedMatches: 10, autoPrompted: true), isFalse);
    });

    test('never mid-match', () {
      expect(eligible(completedMatches: 3, matchInProgress: true), isFalse);
    });

    test('never after the manual menu item was used', () {
      expect(eligible(completedMatches: 3, manualUsed: true), isFalse);
    });
  });

  group('ReviewPrompter', () {
    late _FakeReviewService service;
    late ReviewPrompter prompter;

    setUp(() {
      service = _FakeReviewService();
      prompter = ReviewPrompter(service: service);
    });

    Future<bool> completeMatch() async {
      prompter.recordMatchCompleted();
      return prompter.maybePromptAfterMatch(matchInProgress: false);
    }

    test('requests a review after the 3rd completed match, and only then',
        () async {
      expect(await completeMatch(), isFalse);
      expect(await completeMatch(), isFalse);
      expect(service.requestReviewCalls, 0);

      expect(await completeMatch(), isTrue);
      expect(service.requestReviewCalls, 1);
    });

    test('never requests a second time, including after a restart', () async {
      for (var i = 0; i < 3; i++) {
        await completeMatch();
      }
      expect(await completeMatch(), isFalse);

      final afterRestart = ReviewPrompter(service: service);
      afterRestart.recordMatchCompleted();
      expect(
        await afterRestart.maybePromptAfterMatch(matchInProgress: false),
        isFalse,
      );
      expect(service.requestReviewCalls, 1);
    });

    test('holds off mid-match, then asks once the match is no longer in play',
        () async {
      for (var i = 0; i < 3; i++) {
        await prompter.recordMatchCompleted();
      }
      expect(await prompter.maybePromptAfterMatch(matchInProgress: true),
          isFalse);
      expect(service.requestReviewCalls, 0);

      expect(await prompter.maybePromptAfterMatch(matchInProgress: false),
          isTrue);
      expect(service.requestReviewCalls, 1);
    });

    test('the automatic prompt never opens the store listing', () async {
      for (var i = 0; i < 3; i++) {
        await completeMatch();
      }
      expect(service.requestReviewCalls, 1);
      expect(service.openStoreListingCalls, 0);
    });

    test('a failed request still uses up the one automatic attempt',
        () async {
      service.throwOnRequest = true;
      for (var i = 0; i < 3; i++) {
        await completeMatch();
      }
      expect(service.requestReviewCalls, 1);
      service.throwOnRequest = false;
      expect(await completeMatch(), isFalse);
      expect(service.requestReviewCalls, 1);
    });

    test('the manual item suppresses the automatic prompt for good', () async {
      await prompter.rateManually();

      for (var i = 0; i < 5; i++) {
        expect(await completeMatch(), isFalse);
      }
      expect(service.requestReviewCalls, 0);
    });

    test('the manual item opens the store listing, never the review sheet',
        () async {
      await prompter.rateManually();
      await prompter.rateManually();
      expect(service.openStoreListingCalls, 2);
      expect(service.requestReviewCalls, 0);
    });

    test('the manual item still works after the automatic prompt fired',
        () async {
      for (var i = 0; i < 3; i++) {
        await completeMatch();
      }
      await prompter.rateManually();
      expect(service.requestReviewCalls, 1);
      expect(service.openStoreListingCalls, 1);
    });

    test('a failing review service never throws into the caller', () async {
      service.throwOnRequest = true;
      service.throwOnOpenStoreListing = true;
      await prompter.rateManually();
      for (var i = 0; i < 3; i++) {
        await prompter.recordMatchCompleted();
      }
      expect(await prompter.maybePromptAfterMatch(matchInProgress: false),
          isFalse);
    });
  });

  group('ReviewPromptStore', () {
    test('starts empty and persists the count and both flags', () async {
      final store = ReviewPromptStore();
      expect(
        await store.load(),
        (completedMatches: 0, autoPrompted: false, manualUsed: false),
      );

      await store.incrementCompletedMatches();
      await store.incrementCompletedMatches();
      await store.markAutoPrompted();
      await store.markManualUsed();

      expect(
        await ReviewPromptStore().load(),
        (completedMatches: 2, autoPrompted: true, manualUsed: true),
      );
    });
  });

  group('"Rate this app" menu item', () {
    Future<void> openMenu(WidgetTester tester, ReviewPrompter prompter,
        {Locale? locale}) async {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupScreen(
          currentLocaleOverride: locale,
          onLocaleChanged: (_) {},
          themeMode: ThemeMode.dark,
          onThemeModeChanged: (_) {},
          reviewPrompter: prompter,
        ),
      ));
      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();
    }

    testWidgets('opens the store listing and records the manual use',
        (tester) async {
      final service = _FakeReviewService();
      await openMenu(tester, ReviewPrompter(service: service));

      expect(find.text('Rate this app'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rateAppMenuButton')));
      await tester.pumpAndSettle();
      await _flush(tester);

      expect(service.openStoreListingCalls, 1);
      expect(service.requestReviewCalls, 0);
      expect((await ReviewPromptStore().load()).manualUsed, isTrue);
    });

    testWidgets('is localized in German and French', (tester) async {
      final prompter = ReviewPrompter(service: _FakeReviewService());
      await openMenu(tester, prompter, locale: const Locale('de'));
      expect(find.text('App bewerten'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await openMenu(tester, prompter, locale: const Locale('fr'));
      expect(find.text("Noter l'application"), findsOneWidget);
    });

    testWidgets('never crashes with the real, plugin-less review service',
        (tester) async {
      await openMenu(tester, ReviewPrompter());
      await tester.tap(find.byKey(const Key('rateAppMenuButton')));
      await tester.pumpAndSettle();
    });
  });

  group('automatic prompt on the scoreboard screens', () {
    Future<void> runThreeMatches(
      WidgetTester tester,
      _FakeReviewService service,
      String zone,
    ) async {
      for (var match = 1; match <= 3; match++) {
        await _playMatchToCompletion(tester, zone);
        await _flush(tester);
        // Never while the result is still on screen.
        expect(find.byKey(const Key('matchCompleteDialog')), findsOneWidget);
        expect(service.requestReviewCalls, 0);

        await _startNewMatch(tester);
        expect(service.requestReviewCalls, match == 3 ? 1 : 0);
      }

      // A 4th match never asks again.
      await _playMatchToCompletion(tester, zone);
      await _startNewMatch(tester);
      expect(service.requestReviewCalls, 1);
      expect(service.openStoreListingCalls, 0);
    }

    testWidgets('singles: once, after the 3rd result is dismissed',
        (tester) async {
      final service = _FakeReviewService();
      await tester.pumpWidget(_app(ScoreboardScreen(
        bestOf: 3,
        firstServer: Player.one,
        voiceAnnouncer: _silentVoice(),
        reviewPrompter: ReviewPrompter(service: service),
      )));
      await runThreeMatches(tester, service, 'player1Zone');
    });

    testWidgets('doubles: once, after the 3rd result is dismissed',
        (tester) async {
      final service = _FakeReviewService();
      await tester.pumpWidget(_app(DoublesScoreboardScreen(
        bestOf: 3,
        firstServingTeam: Player.one,
        voiceAnnouncer: _silentVoice(),
        reviewPrompter: ReviewPrompter(service: service),
      )));
      await runThreeMatches(tester, service, 'team1Zone');
    });

    testWidgets('not after the manual menu item was already used',
        (tester) async {
      final service = _FakeReviewService();
      final prompter = ReviewPrompter(service: service);
      await prompter.rateManually();

      await tester.pumpWidget(_app(ScoreboardScreen(
        bestOf: 3,
        firstServer: Player.one,
        voiceAnnouncer: _silentVoice(),
        reviewPrompter: prompter,
      )));
      for (var match = 0; match < 3; match++) {
        await _playMatchToCompletion(tester, 'player1Zone');
        await _startNewMatch(tester);
      }
      expect(service.requestReviewCalls, 0);
    });
  });
}
