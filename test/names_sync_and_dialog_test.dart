import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/doubles_scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/screens/scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';
import 'package:tabletennis_scoreboard/widgets/match_complete_dialog.dart';

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

VoiceAnnouncer _silentVoice() =>
    VoiceAnnouncer(ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());

Future<void> _renameField(
    WidgetTester tester, Key textKey, Key fieldKey, String newName) async {
  await tester.tap(find.byKey(textKey));
  await tester.pump();
  await tester.enterText(find.byKey(fieldKey), newName);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  group('Name editing discoverability (Phase 4G)', () {
    testWidgets('every editable name in singles shows a visible edit icon '
        '— not just a tooltip that only appears on long-press/hover',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 5,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      expect(
        find.descendant(
          of: find.byKey(const Key('player1Zone')),
          matching: find.byIcon(Icons.edit),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('player2Zone')),
          matching: find.byIcon(Icons.edit),
        ),
        findsOneWidget,
      );
    });

    testWidgets('every editable name in doubles shows a visible edit icon '
        '— all 4 player names plus both team headings', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      // 2 player names + 1 team heading per side = 3 edit icons per zone.
      expect(
        find.descendant(
          of: find.byKey(const Key('team1Zone')),
          matching: find.byIcon(Icons.edit),
        ),
        findsNWidgets(3),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('team2Zone')),
          matching: find.byIcon(Icons.edit),
        ),
        findsNWidgets(3),
      );
    });
  });

  group('Optional custom team name (Phase 4G)', () {
    Future<void> pumpDoubles(WidgetTester tester, {VoiceAnnouncer? voice}) {
      return tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 3,
          firstServingTeam: Player.one,
          voiceAnnouncer: voice ?? _silentVoice(),
        ),
      ));
    }

    testWidgets('with no custom team name, the heading still shows the '
        'generic "Team 1"/"Team 2" default, exactly as before',
        (tester) async {
      await pumpDoubles(tester);
      expect(find.text('Team 1'), findsOneWidget);
      expect(find.text('Team 2'), findsOneWidget);
    });

    testWidgets('setting a custom team name updates the heading '
        'immediately', (tester) async {
      await pumpDoubles(tester);

      await _renameField(tester, const Key('team1Heading'),
          const Key('team1HeadingField'), 'The Smashers');

      expect(find.text('The Smashers'), findsOneWidget);
      expect(find.text('Team 1'), findsNothing);
      expect(find.text('Team 2'), findsOneWidget,
          reason: 'team 2 is unaffected');
    });

    testWidgets('a custom team name does not change either individual '
        'player name, and renaming a player does not change the team '
        'name', (tester) async {
      await pumpDoubles(tester);

      await _renameField(tester, const Key('team1Heading'),
          const Key('team1HeadingField'), 'The Smashers');
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);

      await _renameField(tester, const Key('player1NameText'),
          const Key('player1NameField'), 'Alex');
      expect(find.text('The Smashers'), findsOneWidget,
          reason: 'renaming a player must not touch the team name');
    });

    testWidgets('a custom team name appears in the game-complete banner',
        (tester) async {
      await pumpDoubles(tester);

      await _renameField(tester, const Key('team1Heading'),
          const Key('team1HeadingField'), 'The Smashers');

      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('team1Zone')));
        await tester.pump();
      }

      expect(find.textContaining('The Smashers wins the game'),
          findsOneWidget);
    });

    testWidgets(
        'a custom team name appears in the match-complete dialog message',
        (tester) async {
      await pumpDoubles(tester);

      await _renameField(tester, const Key('team1Heading'),
          const Key('team1HeadingField'), 'The Smashers');

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('team1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();

      expect(find.text('The Smashers wins the match!'), findsOneWidget);
    });

    testWidgets(
        'a custom team name is SPOKEN by voice for a match win — not just '
        'shown in the visual banner (the exact desync class of bug found '
        'in PHASE4D_TEAM_CLARITY_AND_TRANSITION.md)', (tester) async {
      final tts = _RecordingTtsEngine();
      final voice =
          VoiceAnnouncer(ttsEngine: tts, clipPlayer: _NoopClipPlayer());
      await pumpDoubles(tester, voice: voice);

      await _renameField(tester, const Key('team1Heading'),
          const Key('team1HeadingField'), 'The Smashers');

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('team1Zone')));
          await tester.pump();
        }
      }
      await tester.pump();

      expect(tts.spoken.last, contains('The Smashers'));
      expect(tts.spoken.last, isNot(contains('Team 1')));
    });

    testWidgets(
        'a custom team name is SPOKEN by voice for a game win too',
        (tester) async {
      final tts = _RecordingTtsEngine();
      final voice =
          VoiceAnnouncer(ttsEngine: tts, clipPlayer: _NoopClipPlayer());
      await pumpDoubles(tester, voice: voice);

      await _renameField(tester, const Key('team1Heading'),
          const Key('team1HeadingField'), 'The Smashers');

      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('team1Zone')));
        await tester.pump();
      }
      await tester.pump();

      expect(tts.spoken.last, contains('The Smashers'));
    });

    testWidgets('renaming in the setup screen\'s doubles preview carries '
        'the custom team name into the started match', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doubles'));
      await tester.pumpAndSettle();

      await _renameField(tester, const Key('team1PreviewHeading'),
          const Key('team1PreviewHeadingField'), 'The Smashers');
      expect(find.text('The Smashers'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startMatchButton')));
      await tester.tap(find.byKey(const Key('startMatchButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('team1Zone')), findsOneWidget);
      expect(find.text('The Smashers'), findsOneWidget);
    });

    testWidgets('"New match" resets a custom team name back to the '
        'generic default', (tester) async {
      await pumpDoubles(tester);

      await _renameField(tester, const Key('team1Heading'),
          const Key('team1HeadingField'), 'The Smashers');
      expect(find.text('The Smashers'), findsOneWidget);

      await tester.tap(find.byKey(const Key('resetButton')));
      await tester.pump();

      expect(find.text('Team 1'), findsOneWidget);
      expect(find.text('The Smashers'), findsNothing);
    });
  });

  group('Redesigned match-complete dialog (Phase 4G)', () {
    testWidgets('singles: uses the new MatchCompleteDialog with a trophy '
        'icon and a large, bold winner announcement', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 3,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('player1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();

      expect(find.byType(MatchCompleteDialog), findsOneWidget);
      expect(find.byKey(const Key('matchCompleteTrophyIcon')), findsOneWidget);

      final messageStyle = tester
          .widget<Text>(find.byKey(const Key('matchCompleteMessageText')))
          .style!;
      expect(messageStyle.fontSize, greaterThanOrEqualTo(24));
      expect(messageStyle.fontWeight, FontWeight.w800);
      expect(find.text('Player 1 wins the match!'), findsOneWidget);
    });

    testWidgets('doubles: same redesigned dialog, with the team label',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 3,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('team1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();

      expect(find.byType(MatchCompleteDialog), findsOneWidget);
      expect(find.byKey(const Key('matchCompleteTrophyIcon')), findsOneWidget);
      expect(find.text('Team 1 wins the match!'), findsOneWidget);
    });

    testWidgets('"New match" still works exactly as before — resets the '
        'board and closes the dialog', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 3,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('player1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('newMatchButton')));
      await tester.pumpAndSettle();

      expect(find.byType(MatchCompleteDialog), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('player1PointsText'))).data,
        '0',
      );
    });
  });
}
