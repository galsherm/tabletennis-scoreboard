import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/doubles_scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';
import 'package:tabletennis_scoreboard/widgets/coin_flip_indicator.dart';

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

/// Reads whatever's currently on the (single, hard-cut) visible coin face.
String _coinFaceText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('coinFaceLabel'))).data!;

void main() {
  group('coin flip animation', () {
    testWidgets(
        'the coin (with the result on its face) is withheld until the '
        "flip settles — a single frame after tapping toss isn't enough",
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pump(); // one frame only — flip still in progress

      final startButton = tester
          .widget<ElevatedButton>(find.byKey(const Key('startMatchButton')));
      expect(startButton.onPressed, isNull,
          reason: 'the result should not be usable mid-flip');

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('coinFaceLabel')), findsOneWidget);
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

      final startButton = tester
          .widget<ElevatedButton>(find.byKey(const Key('startMatchButton')));
      expect(startButton.onPressed, isNotNull);
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
        // At every point in the flip, exactly one coin face is mounted —
        // never both heads and tails at once.
        expect(find.byKey(const Key('coinFaceLabel')), findsOneWidget);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('coinFaceLabel')), findsOneWidget);
    });

    testWidgets('tossing again after a result restarts the flip cleanly',
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('coinFaceLabel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pump(); // mid second flip
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('coinFaceLabel')), findsOneWidget);
    });
  });

  group('coin face content', () {
    testWidgets('lands heads-up showing player1Label when player one wins',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoinFlipIndicator(
            player1Label: 'Player 1',
            player2Label: 'Player 2',
            winner: Player.one,
            onComplete: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(_coinFaceText(tester), 'Player 1');
    });

    testWidgets('lands tails-up showing player2Label when player two wins',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoinFlipIndicator(
            player1Label: 'Player 1',
            player2Label: 'Player 2',
            winner: Player.two,
            onComplete: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(_coinFaceText(tester), 'Player 2');
    });

    testWidgets('shows doubles team labels instead of player labels',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoinFlipIndicator(
            player1Label: 'Team 1',
            player2Label: 'Team 2',
            winner: Player.two,
            onComplete: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(_coinFaceText(tester), 'Team 2');
    });
  });

  group('toss result on the coin (via SetupScreen)', () {
    testWidgets(
        'the toss shows "Team 1"/"Team 2" on the coin in doubles mode, not '
        '"Player 1"/"Player 2"', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doubles'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();

      final label = _coinFaceText(tester);
      expect(label, anyOf('Team 1', 'Team 2'));
    });

    testWidgets(
        'the toss still shows "Player 1"/"Player 2" on the coin in singles '
        'mode (unchanged)', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle(); // singles is the default mode

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();

      final label = _coinFaceText(tester);
      expect(label, anyOf('Player 1', 'Player 2'));
    });

    testWidgets(
        'switching from singles to doubles after tossing relabels the same '
        'already-decided side on the coin', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      final singlesLabel = _coinFaceText(tester);
      final side = singlesLabel == 'Player 1' ? '1' : '2';

      await tester.tap(find.text('Doubles'));
      await tester.pumpAndSettle();

      expect(_coinFaceText(tester), 'Team $side');
    });

    testWidgets('the doubles game-complete banner still says "Team 1"/'
        '"Team 2" (unaffected by the coin-face change)', (tester) async {
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
        'individual on-court labels stay Player 1-4 in doubles, grouped '
        'under (not replaced by) a Team 1/Team 2 heading — see '
        'PHASE4D_TEAM_CLARITY_AND_TRANSITION.md', (tester) async {
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
      // Exactly one heading per side — not duplicated per player.
      expect(find.byKey(const Key('team1Heading')), findsOneWidget);
      expect(find.byKey(const Key('team2Heading')), findsOneWidget);
      expect(find.text('Team 1'), findsOneWidget);
      expect(find.text('Team 2'), findsOneWidget);
    });

    testWidgets('German doubles toss shows "Team 1"/"Team 2" on the coin',
        (tester) async {
      _setDeviceLocale(tester, const Locale('de'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doppel'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();

      expect(_coinFaceText(tester), anyOf('Team 1', 'Team 2'));
    });

    testWidgets('French doubles toss shows "Paire 1"/"Paire 2" on the coin',
        (tester) async {
      _setDeviceLocale(tester, const Locale('fr'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Double'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();

      expect(_coinFaceText(tester), anyOf('Paire 1', 'Paire 2'));
    });
  });
}
