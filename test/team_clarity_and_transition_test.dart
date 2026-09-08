import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/doubles_scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/screens/match_transition_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';
import 'package:tabletennis_scoreboard/widgets/ball_flyby_indicator.dart';

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

Future<void> _goDoublesAndToss(WidgetTester tester, {String label = 'Doubles'}) async {
  await tester.pumpWidget(const TableTennisScoreboardApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  group('team clarity: setup screen preview headings', () {
    testWidgets(
        'the 4-player preview groups Player 1/2 under a "Team 1" heading '
        'and Player 3/4 under "Team 2" (not just two unlabeled rows) — see '
        'PHASE4D_TEAM_CLARITY_AND_TRANSITION.md', (tester) async {
      await _goDoublesAndToss(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const Key('team1PreviewHeading')))
            .data,
        'Team 1',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('team2PreviewHeading')))
            .data,
        'Team 2',
      );
      // The individual player names are still shown underneath.
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.text('Player 3'), findsOneWidget);
      expect(find.text('Player 4'), findsOneWidget);
    });

    testWidgets('preview headings are localized in German ("Team")',
        (tester) async {
      _setDeviceLocale(tester, const Locale('de'));
      await _goDoublesAndToss(tester, label: 'Doppel');

      expect(
        tester
            .widget<Text>(find.byKey(const Key('team1PreviewHeading')))
            .data,
        'Team 1',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('team2PreviewHeading')))
            .data,
        'Team 2',
      );
    });

    testWidgets('preview headings are localized in French ("Paire")',
        (tester) async {
      _setDeviceLocale(tester, const Locale('fr'));
      await _goDoublesAndToss(tester, label: 'Double');

      expect(
        tester
            .widget<Text>(find.byKey(const Key('team1PreviewHeading')))
            .data,
        'Paire 1',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('team2PreviewHeading')))
            .data,
        'Paire 2',
      );
    });

    testWidgets('singles mode shows no team preview headings at all',
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('team1PreviewHeading')), findsNothing);
      expect(find.byKey(const Key('team2PreviewHeading')), findsNothing);
    });
  });

  group('team clarity: doubles scoreboard headings', () {
    testWidgets(
        'each side shows a team heading above its two player names',
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

      expect(
        tester.widget<Text>(find.byKey(const Key('team1Heading'))).data,
        'Team 1',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('team2Heading'))).data,
        'Team 2',
      );

      // The heading sits inside the same tap zone as its two players —
      // grouped together, not floating separately.
      expect(
        find.descendant(
          of: find.byKey(const Key('team1Zone')),
          matching: find.byKey(const Key('team1Heading')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('team1Zone')),
          matching: find.text('Player 1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('doubles scoreboard headings are localized in French',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      expect(
        tester.widget<Text>(find.byKey(const Key('team1Heading'))).data,
        'Paire 1',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('team2Heading'))).data,
        'Paire 2',
      );
    });
  });

  group('ball-flyby transition animation', () {
    testWidgets('onComplete fires once, well under a second', (tester) async {
      var completions = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BallFlybyIndicator(onComplete: () => completions++),
        ),
      ));

      await tester.pump(); // mount, animation starts
      expect(completions, 0);

      await tester.pump(const Duration(milliseconds: 900)); // past duration
      expect(completions, 1);

      await tester.pump(); // let the completed state settle
      expect(completions, 1, reason: 'onEnd must fire exactly once');
    });

    testWidgets(
        'partial, unsettled pumps through the flyby never throw — one '
        'clean TweenAnimationBuilder mount, no AnimatedSwitcher-style '
        'double mount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BallFlybyIndicator(onComplete: () {}),
        ),
      ));

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'tapping "Start match" plays the ball transition, then lands on '
        'the singles scoreboard — the transition screen never lingers on '
        'the back stack', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('startMatchButton')));
      // Two frames: the first applies the tap's Navigator.push, the
      // second actually builds the newly pushed route's widget subtree
      // (a one-pump gap that shows up whenever a route is pushed from an
      // onPressed callback) — after that, the ball transition is
      // showing, and the destination scoreboard is not yet built.
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('ballFlybyIndicator')), findsOneWidget);
      expect(find.byKey(const Key('player1Zone')), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player1Zone')), findsOneWidget);
      expect(find.byType(MatchTransitionScreen), findsNothing);

      // Back from the scoreboard goes straight to setup, not to a
      // leftover blank transition frame.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('modeSelector')), findsOneWidget);
      expect(find.byType(MatchTransitionScreen), findsNothing);
    });

    testWidgets(
        'tapping "Start match" in doubles lands on the 4-player scoreboard '
        'after the transition', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doubles'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startMatchButton')));
      await tester.tap(find.byKey(const Key('startMatchButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('team1Zone')), findsOneWidget);
      expect(find.byKey(const Key('team2Zone')), findsOneWidget);
    });
  });
}
