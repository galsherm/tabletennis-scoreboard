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
import 'package:tabletennis_scoreboard/widgets/match_start_transition.dart';

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

  group('match-start transition choreography math (Phase 4E)', () {
    test('the ball is exactly centered (dx=0, dy=0) at the impact moment',
        () {
      expect(matchStartBallDx(matchStartImpactT), closeTo(0, 1e-9));
      expect(matchStartBallDy(matchStartImpactT), closeTo(0, 1e-9));
    });

    test('the ball travels from off-left to off-right over the full '
        'timeline', () {
      expect(matchStartBallDx(0), lessThan(-1));
      expect(matchStartBallDx(1), greaterThan(1));
    });

    test(
        'the text stays completely undeformed before impact, then jumps '
        'to full deformation exactly at impact', () {
      expect(matchStartTextEnvelope(0), 0);
      expect(matchStartTextEnvelope(matchStartImpactT - 0.01), 0);
      expect(matchStartTextEnvelope(matchStartImpactT), 1);
    });

    test('the text deformation decays smoothly to near-zero by the end '
        '(it has sprung back before the ball is off-screen)', () {
      expect(matchStartTextEnvelope(1), lessThan(0.01));
    });

    test('the ball-impact squash peaks exactly at impact and fades within '
        'a small window either side', () {
      expect(matchStartImpactProximity(matchStartImpactT), 1);
      expect(matchStartImpactProximity(matchStartImpactT - 0.2), 0);
      expect(matchStartImpactProximity(matchStartImpactT + 0.2), 0);
    });

    test(
        'the deformation is localized to characters near the impact point '
        '— not a uniform whole-word effect', () {
      const impactIndex = 5.0;
      final atImpact = matchStartCharFalloff(5, impactIndex);
      final oneAway = matchStartCharFalloff(4, impactIndex);
      final farAway = matchStartCharFalloff(0, impactIndex);

      expect(atImpact, 1);
      expect(oneAway, lessThan(atImpact));
      expect(farAway, lessThan(0.01),
          reason: 'a character 5 slots from impact should barely deform');
    });
  });

  group('match-start transition (Phase 4E)', () {
    testWidgets('renders the full phrase, split across per-character '
        'widgets, in English', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MatchStartTransition(
            text: "Let's Play!",
            onComplete: () {},
          ),
        ),
      ));
      await tester.pump();

      final rendered = tester
          .widgetList<Text>(find.descendant(
            of: find.byKey(const Key('matchStartTextRow')),
            matching: find.byType(Text),
          ))
          .map((w) => w.data)
          .join();
      expect(rendered, "Let's Play!");
    });

    testWidgets('onComplete fires exactly once, at the end of the sequence',
        (tester) async {
      var completions = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MatchStartTransition(
            text: 'Test',
            onComplete: () => completions++,
          ),
        ),
      ));

      await tester.pump(); // mount, animation starts
      expect(completions, 0);

      await tester.pump(const Duration(milliseconds: 1150)); // past duration
      expect(completions, 1);

      await tester.pump(); // let the completed state settle
      expect(completions, 1, reason: 'onComplete must fire exactly once');
    });

    testWidgets(
        'partial, unsettled pumps through the whole sequence never throw '
        '— one clean AnimationController mount, no AnimatedSwitcher-style '
        'double mount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MatchStartTransition(text: "Let's Play!", onComplete: () {}),
        ),
      ));

      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the localized cheer text is correct in German and French',
        (tester) async {
      for (final entry in {
        'de': 'Auf geht\'s!',
        'fr': 'C\'est parti !',
      }.entries) {
        _setDeviceLocale(tester, Locale(entry.key));
        // A fresh ValueKey per iteration forces a real remount instead of
        // updating the previous iteration's still-navigated-to-scoreboard
        // app instance in place (the same reused-State pitfall noted in
        // PHASE4B_UI_POLISH.md's screenshot tooling).
        await tester.pumpWidget(TableTennisScoreboardApp(
          key: ValueKey('app-${entry.key}'),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tossButton')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('startMatchButton')));
        await tester.tap(find.byKey(const Key('startMatchButton')));
        await tester.pump();
        await tester.pump(); // route attaches (see notes below)

        final rendered = tester
            .widgetList<Text>(find.descendant(
              of: find.byKey(const Key('matchStartTextRow')),
              matching: find.byType(Text),
            ))
            .map((w) => w.data)
            .join();
        expect(rendered, entry.value, reason: 'locale ${entry.key}');

        await tester.pumpAndSettle();
      }
    });

    testWidgets(
        'tapping "Start match" plays the match-start transition, then '
        'lands on the singles scoreboard — the transition screen never '
        'lingers on the back stack', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startMatchButton')));
      await tester.tap(find.byKey(const Key('startMatchButton')));
      // Two frames: the first applies the tap's Navigator.push, the
      // second actually builds the newly pushed route's widget subtree
      // (a one-pump gap that shows up whenever a route is pushed from an
      // onPressed callback) — after that, the transition is showing, and
      // the destination scoreboard is not yet built.
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('transitionBall')), findsOneWidget);
      expect(find.byKey(const Key('matchStartTextRow')), findsOneWidget);
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
