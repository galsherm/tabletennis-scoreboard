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
        'before any toss, the coin shows its idle tap-affordance icon, '
        'not a face', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('coinIdleIcon')), findsOneWidget);
      expect(find.byKey(const Key('coinFaceLabel')), findsNothing);
    });

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
      // One frame to apply the tap's setState and start the flip
      // controller at t=0, then jump nearly a full second — comfortably
      // past the 850ms spin+bounce duration — and one more frame to let
      // the completion-triggered setState's rebuild land.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump();

      final startButton = tester
          .widget<ElevatedButton>(find.byKey(const Key('startMatchButton')));
      expect(startButton.onPressed, isNotNull);
    });

    testWidgets(
        'partial, unsettled pumps through the flip never throw — one '
        'coin, continuously mounted, never two faces at once (see '
        'PHASE4B_UI_POLISH.md and PHASE4I_POLISH_ROUND2.md)',
        (tester) async {
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

    testWidgets(
        'tapping the coin again while a flip is still in progress is a '
        'no-op — it never overlaps two flips', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pump(const Duration(milliseconds: 100));
      // Tapping again mid-flip must not throw or restart the animation
      // from scratch.
      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pump(const Duration(milliseconds: 100));
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
            tossSequence: 1,
            onTap: () {},
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
            tossSequence: 1,
            onTap: () {},
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
            tossSequence: 1,
            onTap: () {},
            onComplete: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(_coinFaceText(tester), 'Team 2');
    });

    testWidgets('with no winner yet, shows the idle icon regardless of '
        'tossSequence', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoinFlipIndicator(
            player1Label: 'Player 1',
            player2Label: 'Player 2',
            winner: null,
            tossSequence: 0,
            onTap: () {},
            onComplete: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('coinIdleIcon')), findsOneWidget);
      expect(find.byKey(const Key('coinFaceLabel')), findsNothing);
    });

    testWidgets('tapping the coin calls onTap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoinFlipIndicator(
            player1Label: 'Player 1',
            player2Label: 'Player 2',
            winner: null,
            tossSequence: 0,
            onTap: () => tapped++,
            onComplete: () {},
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('tossButton')));
      expect(tapped, 1);
    });
  });

  group('custom names on the toss result (Phase 4I)', () {
    testWidgets(
        'a custom singles player name appears on the coin instead of '
        '"Player 1" — the coin used to always show the generic label even '
        'after renaming', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle(); // singles is the default mode

      await tester.tap(find.byKey(const Key('player1PreviewNameText')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const Key('player1PreviewNameField')), 'Alex');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Alex'), findsOneWidget);

      // The toss winner is random — retoss (bounded, so a real regression
      // fails cleanly instead of hanging) until player one's side wins,
      // to deterministically observe the custom name on the coin rather
      // than depending on which side happens to come up first. "Player 2"
      // showing its own generic label is expected and not the case under
      // test here.
      String label = '';
      for (var attempt = 0; attempt < 20 && label != 'Alex'; attempt++) {
        await tester.tap(find.byKey(const Key('tossButton')));
        await tester.pumpAndSettle();
        label = _coinFaceText(tester);
        expect(label, anyOf('Alex', 'Player 2'),
            reason: 'a renamed side must never fall back to its generic '
                'default label');
      }

      expect(label, 'Alex',
          reason: 'player one won at least once in 20 tosses with '
              'overwhelming probability; if this fails, the coin is not '
              'reading the custom name at all');
    });

    testWidgets(
        'a custom doubles team name appears on the coin instead of "Team '
        '1"', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doubles'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('team1PreviewHeading')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const Key('team1PreviewHeadingField')), 'Thunderbolts');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Thunderbolts'), findsOneWidget);

      String label = '';
      for (var attempt = 0;
          attempt < 20 && label != 'Thunderbolts';
          attempt++) {
        await tester.tap(find.byKey(const Key('tossButton')));
        await tester.pumpAndSettle();
        label = _coinFaceText(tester);
        expect(label, anyOf('Thunderbolts', 'Team 2'),
            reason: 'a renamed team must never fall back to its generic '
                'default label');
      }

      expect(label, 'Thunderbolts',
          reason: 'team one won at least once in 20 tosses with '
              'overwhelming probability; if this fails, the coin is not '
              'reading the custom team name at all');
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
