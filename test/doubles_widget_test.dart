import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/doubles_scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';

class _RecordingTtsEngine implements TtsEngine {
  final List<String> spoken = [];
  @override
  Future<bool> isLanguageAvailable(String language) async => true;
  @override
  Future<void> setLanguage(String language) async {}
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

class _NoopClipPlayer implements ClipPlayer {
  @override
  Future<void> playClip(String assetPath) async {}
  @override
  Future<void> stop() async {}
}

Future<void> _pumpDoublesScoreboard(
  WidgetTester tester, {
  required VoiceAnnouncer voice,
  int bestOf = 5,
  Player firstServingTeam = Player.one,
}) {
  return tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DoublesScoreboardScreen(
      bestOf: bestOf,
      firstServingTeam: firstServingTeam,
      voiceAnnouncer: voice,
    ),
  ));
}

void main() {
  group('setup screen: singles/doubles mode', () {
    testWidgets('defaults to singles mode: no 4-player preview shown',
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('modeSelector')), findsOneWidget);
      expect(find.byKey(const Key('doublesPlayerSlots')), findsNothing);
      expect(find.text('Player 3'), findsNothing);
    });

    testWidgets('selecting Doubles shows all 4 player slots', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doubles'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('doublesPlayerSlots')), findsOneWidget);
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.text('Player 3'), findsOneWidget);
      expect(find.text('Player 4'), findsOneWidget);
    });

    testWidgets('switching back to Singles hides the 4-player preview',
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doubles'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('doublesPlayerSlots')), findsOneWidget);

      await tester.tap(find.text('Singles'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('doublesPlayerSlots')), findsNothing);
    });

    testWidgets('the mode toggle and 4-player slots are localized in German',
        (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('de');
      tester.platformDispatcher.localesTestValue = const [Locale('de')];
      addTearDown(() {
        tester.platformDispatcher.clearLocaleTestValue();
        tester.platformDispatcher.clearLocalesTestValue();
      });

      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.text('Einzel'), findsOneWidget);
      expect(find.text('Doppel'), findsOneWidget);

      await tester.tap(find.text('Doppel'));
      await tester.pumpAndSettle();

      expect(find.text('Spieler 1'), findsOneWidget);
      expect(find.text('Spieler 2'), findsOneWidget);
      expect(find.text('Spieler 3'), findsOneWidget);
      expect(find.text('Spieler 4'), findsOneWidget);
    });

    testWidgets('the mode toggle and 4-player slots are localized in French',
        (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('fr');
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(() {
        tester.platformDispatcher.clearLocaleTestValue();
        tester.platformDispatcher.clearLocalesTestValue();
      });

      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.text('Simple'), findsOneWidget);
      expect(find.text('Double'), findsOneWidget);

      await tester.tap(find.text('Double'));
      await tester.pumpAndSettle();

      expect(find.text('Joueur 1'), findsOneWidget);
      expect(find.text('Joueur 2'), findsOneWidget);
      expect(find.text('Joueur 3'), findsOneWidget);
      expect(find.text('Joueur 4'), findsOneWidget);
    });

    testWidgets('starting a doubles match navigates to the 4-player scoreboard',
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doubles'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      // The doubles team-preview boxes (PHASE4D_TEAM_CLARITY_AND_TRANSITION.md)
      // push "Start match" below the fold on the default test viewport —
      // scroll it into view first, same as a real short screen would need.
      await tester.ensureVisible(find.byKey(const Key('startMatchButton')));
      await tester.tap(find.byKey(const Key('startMatchButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('team1Zone')), findsOneWidget);
      expect(find.byKey(const Key('team2Zone')), findsOneWidget);
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.text('Player 3'), findsOneWidget);
      expect(find.text('Player 4'), findsOneWidget);
    });
  });

  group('DoublesScoreboardScreen: scoring reuses the singles engine', () {
    testWidgets('starts with both teams at 0 and correct game math',
        (tester) async {
      final voice = VoiceAnnouncer(
          ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());
      await _pumpDoublesScoreboard(tester, voice: voice);

      expect(
        tester.widget<Text>(find.byKey(const Key('team1PointsText'))).data,
        '0',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('team2PointsText'))).data,
        '0',
      );
    });

    testWidgets("tapping a team's zone increases only that team's score",
        (tester) async {
      final voice = VoiceAnnouncer(
          ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());
      await _pumpDoublesScoreboard(tester, voice: voice);

      await tester.tap(find.byKey(const Key('team1Zone')));
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const Key('team1PointsText'))).data,
        '1',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('team2PointsText'))).data,
        '0',
      );
    });

    testWidgets('winning the match (best of 3) shows the match-complete dialog',
        (tester) async {
      final voice = VoiceAnnouncer(
          ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());
      await _pumpDoublesScoreboard(tester, voice: voice, bestOf: 3);

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('team1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('matchCompleteDialog')), findsOneWidget);
      // Doubles banners say "Team 1," not "Player 1" — see
      // PHASE4C_TOSS_AND_TEAM_LABELS.md.
      expect(find.text('Team 1 wins the match!'), findsOneWidget);
    });

    testWidgets(
        'scoring announces the score by voice, reusing Phase 2/3\'s '
        'system unchanged', (tester) async {
      final tts = _RecordingTtsEngine();
      final voice =
          VoiceAnnouncer(ttsEngine: tts, clipPlayer: _NoopClipPlayer());
      await _pumpDoublesScoreboard(tester, voice: voice);

      await tester.tap(find.byKey(const Key('team1Zone')));
      await tester.pump();
      await tester.pump();

      expect(tts.spoken, ['1, 0']);
    });

    testWidgets(
        'a doubles match win is announced by voice as "Team 1," matching '
        'the on-screen banner — not "Player 1" (Phase 4D bug fix; see '
        'PHASE4D_TEAM_CLARITY_AND_TRANSITION.md)', (tester) async {
      final tts = _RecordingTtsEngine();
      final voice =
          VoiceAnnouncer(ttsEngine: tts, clipPlayer: _NoopClipPlayer());
      await _pumpDoublesScoreboard(tester, voice: voice, bestOf: 3);

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('team1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();

      expect(tts.spoken.last, contains('Team 1'));
      expect(tts.spoken.last, isNot(contains('Player 1')));
      // Matches the on-screen match-complete dialog exactly.
      expect(find.text('Team 1 wins the match!'), findsOneWidget);
    });
  });

  group('DoublesScoreboardScreen: localized tooltips', () {
    testWidgets(
        'server/receiver tooltips use the German terms Aufschlag '
        'and Rückschläger', (tester) async {
      final voice = VoiceAnnouncer(
          ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: voice,
        ),
      ));
      await tester.pumpAndSettle();

      final serverIcon = tester.widget<Tooltip>(find.ancestor(
        of: find.byKey(const Key('team1Slot0ServerIcon')),
        matching: find.byType(Tooltip),
      ));
      expect(serverIcon.message, 'Aufschlag');

      final receiverIcon = tester.widget<Tooltip>(find.ancestor(
        of: find.byKey(const Key('team2Slot0ReceiverIcon')),
        matching: find.byType(Tooltip),
      ));
      expect(receiverIcon.message, 'Rückschläger');
    });
  });

  group('DoublesScoreboardScreen: server/receiver display', () {
    testWidgets(
        'at the start, team1 slot0 serves to team2 slot0 (A -> C), and no '
        'one else shows a server/receiver icon', (tester) async {
      final voice = VoiceAnnouncer(
          ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());
      await _pumpDoublesScoreboard(tester, voice: voice);

      expect(find.byKey(const Key('team1Slot0ServerIcon')), findsOneWidget);
      expect(find.byKey(const Key('team2Slot0ReceiverIcon')), findsOneWidget);
      expect(find.byKey(const Key('team1Slot1ServerIcon')), findsNothing);
      expect(find.byKey(const Key('team1Slot1ReceiverIcon')), findsNothing);
      expect(find.byKey(const Key('team2Slot0ServerIcon')), findsNothing);
      expect(find.byKey(const Key('team2Slot1ServerIcon')), findsNothing);
      expect(find.byKey(const Key('team2Slot1ReceiverIcon')), findsNothing);
      expect(find.byKey(const Key('team1Slot0ReceiverIcon')), findsNothing);
    });

    testWidgets(
        'after one full 2-point rotation block, server/receiver move to '
        'the next step in the cycle (C -> B)', (tester) async {
      final voice = VoiceAnnouncer(
          ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());
      await _pumpDoublesScoreboard(tester, voice: voice);

      await tester.tap(find.byKey(const Key('team1Zone')));
      await tester.pump(); // total=1, still block 0
      expect(find.byKey(const Key('team1Slot0ServerIcon')), findsOneWidget);

      await tester.tap(find.byKey(const Key('team2Zone')));
      await tester.pump(); // total=2, block 1 -> team2 slot0 serves,
      // team1 slot1 receives

      expect(find.byKey(const Key('team2Slot0ServerIcon')), findsOneWidget);
      expect(find.byKey(const Key('team1Slot1ReceiverIcon')), findsOneWidget);
      expect(find.byKey(const Key('team1Slot0ServerIcon')), findsNothing);
    });

    testWidgets(
        'across a full 4-block cycle, every one of the 4 players shows a '
        'server icon exactly once', (tester) async {
      final voice = VoiceAnnouncer(
          ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());
      await _pumpDoublesScoreboard(tester, voice: voice);

      final serverKeys = [
        'team1Slot0ServerIcon',
        'team2Slot0ServerIcon',
        'team1Slot1ServerIcon',
        'team2Slot1ServerIcon',
      ];

      for (final key in serverKeys) {
        expect(find.byKey(Key(key)), findsOneWidget,
            reason: 'expected $key to be the server at this point');
        // Advance one full 2-point block.
        await tester.tap(find.byKey(const Key('team1Zone')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('team1Zone')));
        await tester.pump();
      }
    });
  });

  group('Quick score correction in doubles (Phase 4M)', () {
    testWidgets(
        "long-pressing a team's score digit opens the corrector, and a "
        "valid correction updates that team's score without touching "
        'the other team', (tester) async {
      final voice = VoiceAnnouncer(
          ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());
      await _pumpDoublesScoreboard(tester,
          voice: voice, firstServingTeam: Player.one);

      await tester
          .longPress(find.byKey(const Key('team1ScoreCorrectorTrigger')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scoreCorrectorDialog')), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('scoreCorrectorIncrement')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('scoreCorrectorConfirm')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('team1PointsText'))).data,
        '4',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('team2PointsText'))).data,
        '0',
      );
    });
  });
}
