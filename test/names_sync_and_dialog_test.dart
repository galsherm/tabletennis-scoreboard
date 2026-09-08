import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/models/player_names.dart';
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

/// Only meaningful on the *setup* screen since Phase 4H — the only place
/// names are still editable.
Future<void> _renameField(
    WidgetTester tester, Key textKey, Key fieldKey, String newName) async {
  await tester.tap(find.byKey(textKey));
  await tester.pump();
  await tester.enterText(find.byKey(fieldKey), newName);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

bool _hasDashedUnderline(Text text) =>
    text.style?.decoration == TextDecoration.underline &&
    text.style?.decorationStyle == TextDecorationStyle.dashed;

void main() {
  group('Name editing affordance (Phase 4H: dashed underline, setup-only)',
      () {
    testWidgets(
        'setup screen (singles): the two preview names show a dashed '
        'underline — not an icon', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(
        _hasDashedUnderline(tester
            .widget<Text>(find.byKey(const Key('player1PreviewNameText')))),
        isTrue,
      );
      expect(
        _hasDashedUnderline(tester
            .widget<Text>(find.byKey(const Key('player2PreviewNameText')))),
        isTrue,
      );
      expect(find.byIcon(Icons.edit), findsNothing,
          reason: 'the pencil icon was replaced by the underline in '
              'PHASE4H_NAME_EDITING_REFINEMENT.md');
    });

    testWidgets(
        'setup screen (doubles): all 4 player names and both team '
        'headings show the dashed underline', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Doubles'));
      await tester.pumpAndSettle();

      for (final key in [
        'player1PreviewNameText',
        'player2PreviewNameText',
        'player3PreviewNameText',
        'player4PreviewNameText',
        'team1PreviewHeading',
        'team2PreviewHeading',
      ]) {
        expect(
          _hasDashedUnderline(tester.widget<Text>(find.byKey(Key(key)))),
          isTrue,
          reason: '$key should show the dashed-underline affordance',
        );
      }
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets(
        'scoreboard (singles): names show no edit affordance at all, and '
        'tapping one does nothing', (tester) async {
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
        _hasDashedUnderline(
            tester.widget<Text>(find.byKey(const Key('player1NameText')))),
        isFalse,
      );
      expect(find.byIcon(Icons.edit), findsNothing);

      await tester.tap(find.byKey(const Key('player1NameText')));
      await tester.pump();
      expect(find.byType(TextField), findsNothing,
          reason: 'tapping a name during a match must not start editing');
      expect(find.text('Player 1'), findsOneWidget);
    });

    testWidgets(
        'scoreboard (doubles): all 4 names and both team headings show no '
        'edit affordance, and tapping does nothing', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      for (final key in [
        'player1NameText',
        'player2NameText',
        'player3NameText',
        'player4NameText',
        'team1Heading',
        'team2Heading',
      ]) {
        expect(
          _hasDashedUnderline(tester.widget<Text>(find.byKey(Key(key)))),
          isFalse,
          reason: '$key must not show the editable underline in-match',
        );
      }
      expect(find.byIcon(Icons.edit), findsNothing);

      await tester.tap(find.byKey(const Key('team1Heading')));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Team 1'), findsOneWidget);
    });
  });

  group('Singles name editing on the setup screen (Phase 4H)', () {
    testWidgets(
        'singles mode shows an editable Player 1/Player 2 preview by '
        'default — this step did not exist before Phase 4H',
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('singlesPlayerNames')), findsOneWidget);
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
    });

    testWidgets('tapping a singles preview name reveals an editable field '
        'pre-filled with the current name', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('player1PreviewNameText')));
      await tester.pump();

      final field = tester
          .widget<TextField>(find.byKey(const Key('player1PreviewNameField')));
      expect(field.controller!.text, 'Player 1');
    });

    testWidgets(
        'renaming a singles player on setup carries into the started '
        'match, where it is then locked', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await _renameField(tester, const Key('player1PreviewNameText'),
          const Key('player1PreviewNameField'), 'Alex');
      expect(find.text('Alex'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('startMatchButton')));
      await tester.pumpAndSettle();

      expect(find.text('Alex'), findsOneWidget);
      // Locked: tapping it on the scoreboard does nothing.
      await tester.tap(find.byKey(const Key('player1NameText')));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('clearing a singles name on setup reverts it to the '
        'default before the match even starts', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await _renameField(tester, const Key('player1PreviewNameText'),
          const Key('player1PreviewNameField'), 'Alex');
      expect(find.text('Alex'), findsOneWidget);

      await _renameField(tester, const Key('player1PreviewNameText'),
          const Key('player1PreviewNameField'), '   ');
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Alex'), findsNothing);
    });
  });

  group('Names are locked once a match starts (Phase 4H)', () {
    testWidgets('singles: a name set before the match displays correctly '
        'and cannot be edited on the scoreboard', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 5,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..set(1, 'Alex'),
        ),
      ));

      expect(find.text('Alex'), findsOneWidget);
      await tester.tap(find.byKey(const Key('player1NameText')));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('singles: a custom name appears in the game-complete '
        'banner', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 5,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..set(1, 'Alex'),
        ),
      ));

      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('player1Zone')));
        await tester.pump();
      }

      expect(find.textContaining('Alex wins the game'), findsOneWidget);
    });

    testWidgets('singles: a custom name is spoken by voice for a match '
        'win', (tester) async {
      final tts = _RecordingTtsEngine();
      final voice =
          VoiceAnnouncer(ttsEngine: tts, clipPlayer: _NoopClipPlayer());
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 3,
          firstServer: Player.one,
          voiceAnnouncer: voice,
          initialNames: PlayerNames()..set(1, 'Alex'),
        ),
      ));

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('player1Zone')));
          await tester.pump();
        }
      }
      await tester.pump();

      expect(tts.spoken.last, contains('Alex'));
      expect(tts.spoken.last, isNot(contains('Player 1')));
    });

    testWidgets(
        'singles: "New match" keeps the custom name — it can no longer '
        'be re-edited from the scoreboard, so clearing it would lose it '
        'permanently', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 3,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..set(1, 'Alex'),
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

      expect(find.text('Alex'), findsOneWidget);
    });

    testWidgets('singles: a maximum-length name renders without overflow',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 5,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..set(1, 'A' * PlayerNames.maxLength),
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('doubles: a name set for one slot only shows in that slot',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..set(1, 'Alex'),
        ),
      ));

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.text('Player 3'), findsOneWidget);
      expect(find.text('Player 4'), findsOneWidget);
    });

    testWidgets(
        'doubles: an individual custom name never changes the "Team 1" '
        'match-complete banner', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 3,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..set(1, 'Alex'),
        ),
      ));

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('team1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();

      expect(find.text('Team 1 wins the match!'), findsOneWidget);
    });

    testWidgets('doubles: a 16-character name renders without overflow',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..set(1, 'A' * PlayerNames.maxLength),
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('doubles: "New match" keeps custom names', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 3,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..set(1, 'Alex'),
        ),
      ));

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('team1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('newMatchButton')));
      await tester.pumpAndSettle();

      expect(find.text('Alex'), findsOneWidget);
    });
  });

  group('Optional custom team name (setup-only per Phase 4H)', () {
    testWidgets('with no custom team name, the heading still shows the '
        'generic "Team 1"/"Team 2" default, exactly as before',
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
      expect(find.text('Team 1'), findsOneWidget);
      expect(find.text('Team 2'), findsOneWidget);
    });

    testWidgets('setting a custom team name on the setup screen updates '
        'its preview heading immediately', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Doubles'));
      await tester.pumpAndSettle();

      await _renameField(tester, const Key('team1PreviewHeading'),
          const Key('team1PreviewHeadingField'), 'The Smashers');

      expect(find.text('The Smashers'), findsOneWidget);
      expect(find.text('Team 1'), findsNothing);
      expect(find.text('Team 2'), findsOneWidget,
          reason: 'team 2 is unaffected');
    });

    testWidgets(
        'a custom team name does not change either individual player '
        'name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 3,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..setTeam(1, 'The Smashers'),
        ),
      ));

      expect(find.text('The Smashers'), findsOneWidget);
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
    });

    testWidgets('a custom team name appears in the game-complete banner',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 3,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..setTeam(1, 'The Smashers'),
        ),
      ));

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
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 3,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..setTeam(1, 'The Smashers'),
        ),
      ));

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
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 3,
          firstServingTeam: Player.one,
          voiceAnnouncer: voice,
          initialNames: PlayerNames()..setTeam(1, 'The Smashers'),
        ),
      ));

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

    testWidgets('a custom team name is SPOKEN by voice for a game win too',
        (tester) async {
      final tts = _RecordingTtsEngine();
      final voice =
          VoiceAnnouncer(ttsEngine: tts, clipPlayer: _NoopClipPlayer());
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: voice,
          initialNames: PlayerNames()..setTeam(1, 'The Smashers'),
        ),
      ));

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

    testWidgets(
        '"New match" keeps a custom team name — it can no longer be '
        're-edited from the scoreboard', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 3,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
          initialNames: PlayerNames()..setTeam(1, 'The Smashers'),
        ),
      ));

      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('team1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('newMatchButton')));
      await tester.pumpAndSettle();

      expect(find.text('The Smashers'), findsOneWidget);
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
