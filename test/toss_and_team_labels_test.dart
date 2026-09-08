import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/doubles_scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';

class _NoopTts implements TtsEngine {
  @override
  Future<bool> isLanguageAvailable(String language) async => false;
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
    VoiceAnnouncer(ttsEngine: _NoopTts(), clipPlayer: _NoopClipPlayer());

void _setDeviceLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localeTestValue = locale;
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(() {
    tester.platformDispatcher.clearLocaleTestValue();
    tester.platformDispatcher.clearLocalesTestValue();
  });
}

void main() {
  group('coin flip animation', () {
    testWidgets(
        'the result is withheld until the flip settles — a single frame '
        "after tapping toss isn't enough", (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pump(); // one frame only — flip still in progress

      expect(find.byKey(const Key('firstServerLabel')), findsNothing);
      final startButton = tester
          .widget<ElevatedButton>(find.byKey(const Key('startMatchButton')));
      expect(startButton.onPressed, isNull,
          reason: 'the result should not be revealed mid-flip');

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('firstServerLabel')), findsOneWidget);
      final startButtonAfter = tester
          .widget<ElevatedButton>(find.byKey(const Key('startMatchButton')));
      expect(startButtonAfter.onPressed, isNotNull);
    });

    testWidgets('settles well under 1 second', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      // One frame to apply the tap's setState and mount the
      // TweenAnimationBuilder (starting its ticker at t=0), then jump
      // nearly a full second — comfortably past the 700ms flip duration —
      // and one more frame to let the onEnd-triggered setState's rebuild
      // land.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump();

      expect(find.byKey(const Key('firstServerLabel')), findsOneWidget);
    });

    testWidgets(
        'partial, unsettled pumps through the flip never throw — one clean '
        'TweenAnimationBuilder mount, no AnimatedSwitcher-style double '
        'mount (see PHASE4B_UI_POLISH.md)', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('firstServerLabel')), findsOneWidget);
    });

    testWidgets('tossing again after a result restarts the flip cleanly',
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('firstServerLabel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pump(); // mid second flip
      expect(find.byKey(const Key('firstServerLabel')), findsNothing);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('firstServerLabel')), findsOneWidget);
    });
  });

  group('doubles team-label wording', () {
    testWidgets(
        'the toss result says "Team 1"/"Team 2" in doubles mode, not '
        '"Player 1"/"Player 2"', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doubles'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();

      final label = tester
          .widget<Text>(find.byKey(const Key('firstServerLabel')))
          .data!;
      expect(label, anyOf(contains('Team 1'), contains('Team 2')));
      expect(label, isNot(contains('Player 1')));
      expect(label, isNot(contains('Player 2')));
    });

    testWidgets(
        'the toss result still says "Player 1"/"Player 2" in singles mode '
        '(unchanged)', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle(); // singles is the default mode

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();

      final label = tester
          .widget<Text>(find.byKey(const Key('firstServerLabel')))
          .data!;
      expect(label, anyOf(contains('Player 1'), contains('Player 2')));
      expect(label, isNot(contains('Team 1')));
      expect(label, isNot(contains('Team 2')));
    });

    testWidgets(
        'switching from singles to doubles after tossing updates the same '
        'result to team wording', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      final singlesLabel = tester
          .widget<Text>(find.byKey(const Key('firstServerLabel')))
          .data!;
      expect(singlesLabel, contains('Player'));

      await tester.tap(find.text('Doubles'));
      await tester.pumpAndSettle();

      final doublesLabel = tester
          .widget<Text>(find.byKey(const Key('firstServerLabel')))
          .data!;
      expect(doublesLabel, contains('Team'));
      // Same side that was picked, just relabeled.
      final expectedSide = singlesLabel.contains('Player 1') ? '1' : '2';
      expect(doublesLabel, contains('Team $expectedSide'));
    });

    testWidgets('the doubles game-complete banner says "Team 1"/"Team 2"',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('team1Zone')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('Team 1 wins the game'), findsOneWidget);
    });

    testWidgets(
        'individual on-court labels stay Player 1-4 in doubles, unaffected '
        'by the team wording used for the toss/banners', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.text('Player 3'), findsOneWidget);
      expect(find.text('Player 4'), findsOneWidget);
      expect(find.text('Team 1'), findsNothing);
      expect(find.text('Team 2'), findsNothing);
    });

    testWidgets('German doubles toss result says "Team 1"/"Team 2"',
        (tester) async {
      _setDeviceLocale(tester, const Locale('de'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doppel'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();

      final label = tester
          .widget<Text>(find.byKey(const Key('firstServerLabel')))
          .data!;
      expect(label, anyOf(contains('Team 1'), contains('Team 2')));
    });

    testWidgets('French doubles toss result says "Paire 1"/"Paire 2"',
        (tester) async {
      _setDeviceLocale(tester, const Locale('fr'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Double'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();

      final label = tester
          .widget<Text>(find.byKey(const Key('firstServerLabel')))
          .data!;
      expect(label, anyOf(contains('Paire 1'), contains('Paire 2')));
    });
  });
}
