import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/models/player_names.dart';
import 'package:tabletennis_scoreboard/screens/doubles_scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/screens/scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/screens/setup_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';
import 'package:tabletennis_scoreboard/theme/app_theme.dart';
import 'package:tabletennis_scoreboard/widgets/animated_score_text.dart';
import 'package:tabletennis_scoreboard/widgets/scoreboard_decor.dart';

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

/// A real themed `MaterialApp` built from [buildAppTheme] — see
/// `_themedApp` in `theme_parity_test.dart` for why a bare one won't do.
Widget _themedApp(Widget child, ThemeMode themeMode, Locale locale) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
      home: child,
    );

Widget _setupScreen() => SetupScreen(
      currentLocaleOverride: null,
      onLocaleChanged: (_) {},
      themeMode: ThemeMode.dark,
      onThemeModeChanged: (_) {},
    );

/// A narrow phone (360dp wide) at [textScale].
void _useNarrowPhone(WidgetTester tester, double textScale) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// The widget under [finder] sits within the screen's width as actually
/// drawn (`getRect` applies any `FittedBox` scaling) — an overflow that
/// Flutter's own overflow check can't see (a child painting past a
/// `Clip.none` parent) still fails this.
void _expectWithinScreenWidth(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(-0.5));
  expect(rect.right, lessThanOrEqualTo(360.5));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const longNames = ['Maximilian-Alexander', 'Jean-Christophe B.'];

  for (final themeMode in [ThemeMode.dark, ThemeMode.light]) {
    for (final textScale in [1.0, 1.5]) {
      final variant = '${themeMode.name}, text scale $textScale';

      group('narrow phone smoke ($variant)', () {
        for (final language in ['en', 'de', 'fr']) {
          testWidgets('setup screen lays out without overflow ($language)',
              (tester) async {
            _useNarrowPhone(tester, textScale);
            await tester.pumpWidget(
                _themedApp(_setupScreen(), themeMode, Locale(language)));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            for (final key in const [
              'modeSelector',
              'singlesPlayerNames',
              'bestOfSelector',
              'tossPromptText',
              'tossButton',
              'startMatchButton',
            ]) {
              _expectWithinScreenWidth(tester, find.byKey(Key(key)));
            }

            // Doubles shows the two team tiles instead.
            final l10n = lookupAppLocalizations(Locale(language));
            await tester.tap(find.text(l10n.modeDoublesOption));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            _expectWithinScreenWidth(
                tester, find.byKey(const Key('doublesPlayerSlots')));

            // Tossing enables "Start match", which swaps its styling.
            await tester.ensureVisible(find.byKey(const Key('tossButton')));
            await tester.tap(find.byKey(const Key('tossButton')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester
                .ensureVisible(find.byKey(const Key('startMatchButton')));
            await tester.pumpAndSettle();
            final start = tester.widget<ElevatedButton>(
                find.byKey(const Key('startMatchButton')));
            expect(start.onPressed, isNotNull);
            _expectWithinScreenWidth(
                tester, find.byKey(const Key('startMatchButton')));
            expect(tester.takeException(), isNull);
          });
        }

        testWidgets('singles scoreboard lays out without overflow',
            (tester) async {
          _useNarrowPhone(tester, textScale);
          final names = PlayerNames()
            ..set(1, longNames[0])
            ..set(2, longNames[1]);
          await tester.pumpWidget(_themedApp(
            ScoreboardScreen(
              bestOf: 7,
              firstServer: Player.one,
              voiceAnnouncer: _silentVoice(),
              initialNames: names,
            ),
            themeMode,
            const Locale('de'),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Two-digit scores on both sides, and the serve changing
          // sides along the way.
          for (var i = 0; i < 10; i++) {
            await tester.tap(find.byKey(const Key('player1Zone')));
            await tester.pump();
            await tester.tap(find.byKey(const Key('player2Zone')));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final key in const ['player1PointsText', 'player2PointsText']) {
            _expectWithinScreenWidth(tester, find.byKey(Key(key)));
          }
        });

        testWidgets('doubles scoreboard lays out without overflow',
            (tester) async {
          _useNarrowPhone(tester, textScale);
          final names = PlayerNames()
            ..set(1, longNames[0])
            ..set(2, longNames[1])
            ..set(3, longNames[1])
            ..set(4, longNames[0])
            ..setTeam(1, 'TTC Musterstadt 1908')
            ..setTeam(2, 'Les Raquettes Volantes');
          await tester.pumpWidget(_themedApp(
            DoublesScoreboardScreen(
              bestOf: 7,
              firstServingTeam: Player.two,
              voiceAnnouncer: _silentVoice(),
              initialNames: names,
            ),
            themeMode,
            const Locale('fr'),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          for (var i = 0; i < 10; i++) {
            await tester.tap(find.byKey(const Key('team1Zone')));
            await tester.pump();
            await tester.tap(find.byKey(const Key('team2Zone')));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final key in const [
            'team1PointsText',
            'team2PointsText',
            'player1NameText',
            'player3NameText',
          ]) {
            _expectWithinScreenWidth(tester, find.byKey(Key(key)));
          }
        });
      });
    }
  }

  group('serving side marking', () {
    ServingSideBackdrop backdropOf(WidgetTester tester, String zoneKey) =>
        tester.widget<ServingSideBackdrop>(find.ancestor(
          of: find.byKey(Key(zoneKey)).first,
          matching: find.byType(ServingSideBackdrop),
        ));

    bool glows(WidgetTester tester, String pointsKey) => tester
        .widget<AnimatedScoreText>(find.ancestor(
          of: find.byKey(Key(pointsKey)),
          matching: find.byType(AnimatedScoreText),
        ))
        .glow;

    testWidgets(
        'singles: the backdrop and digit glow sit on the server\'s half, '
        'and follow the serve when it changes sides and back on undo',
        (tester) async {
      await tester.pumpWidget(_themedApp(
        ScoreboardScreen(
          bestOf: 5,
          firstServer: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
        ThemeMode.dark,
        const Locale('en'),
      ));
      await tester.pumpAndSettle();

      void expectServer(Player server) {
        final oneServes = server == Player.one;
        expect(backdropOf(tester, 'player1PointsText').serving, oneServes);
        expect(backdropOf(tester, 'player2PointsText').serving, !oneServes);
        expect(glows(tester, 'player1PointsText'), oneServes);
        expect(glows(tester, 'player2PointsText'), !oneServes);
        // The existing indicator still agrees with the new marking.
        expect(find.byKey(const Key('player1ServerIcon')),
            oneServes ? findsOneWidget : findsNothing);
        expect(find.byKey(const Key('player2ServerIcon')),
            oneServes ? findsNothing : findsOneWidget);
      }

      expectServer(Player.one);

      // Serve changes every two points.
      await tester.tap(find.byKey(const Key('player1Zone')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('player1Zone')));
      await tester.pumpAndSettle();
      expectServer(Player.two);

      await tester.tap(find.byKey(const Key('undoButton')));
      await tester.pumpAndSettle();
      expectServer(Player.one);
    });

    testWidgets(
        'singles: the digits are the same color on both halves — the '
        'server is marked by the glow, not by a different digit color',
        (tester) async {
      await tester.pumpWidget(_themedApp(
        ScoreboardScreen(
          bestOf: 5,
          firstServer: Player.two,
          voiceAnnouncer: _silentVoice(),
        ),
        ThemeMode.light,
        const Locale('en'),
      ));
      await tester.pumpAndSettle();

      final receiver =
          tester.widget<Text>(find.byKey(const Key('player1PointsText')));
      final server =
          tester.widget<Text>(find.byKey(const Key('player2PointsText')));
      expect(server.style?.color, AppPalette.light.scoreText);
      expect(receiver.style?.color, AppPalette.light.scoreText);
      expect(server.style?.shadows, isNotEmpty);
      expect(receiver.style?.shadows, isNull);
    });

    testWidgets('doubles: the serving team\'s half is the one marked',
        (tester) async {
      await tester.pumpWidget(_themedApp(
        DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.two,
          voiceAnnouncer: _silentVoice(),
        ),
        ThemeMode.dark,
        const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(backdropOf(tester, 'team1PointsText').serving, isFalse);
      expect(backdropOf(tester, 'team2PointsText').serving, isTrue);
      expect(glows(tester, 'team1PointsText'), isFalse);
      expect(glows(tester, 'team2PointsText'), isTrue);

      await tester.tap(find.byKey(const Key('team1Zone')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('team1Zone')));
      await tester.pumpAndSettle();

      expect(backdropOf(tester, 'team1PointsText').serving, isTrue);
      expect(backdropOf(tester, 'team2PointsText').serving, isFalse);
    });
  });

  group('game pips', () {
    int filledPips(WidgetTester tester, Finder pips) => tester
        .widgetList<Container>(
            find.descendant(of: pips, matching: find.byType(Container)))
        .where((c) => (c.decoration! as BoxDecoration).color != null)
        .length;

    testWidgets(
        'one pip per game needed to win (best of 3/5/7 -> 2/3/4), filled '
        'per game won, alongside the unchanged "Games: N" caption',
        (tester) async {
      for (final (bestOf, toWin) in const [(3, 2), (5, 3), (7, 4)]) {
        await tester.pumpWidget(_themedApp(
          ScoreboardScreen(
            key: ValueKey(bestOf),
            bestOf: bestOf,
            firstServer: Player.one,
            voiceAnnouncer: _silentVoice(),
          ),
          ThemeMode.dark,
          const Locale('en'),
        ));
        await tester.pumpAndSettle();

        final pips = find.byType(GamePips);
        expect(pips, findsNWidgets(2));
        for (final element in pips.evaluate()) {
          expect((element.widget as GamePips).toWin, toWin);
        }
        expect(filledPips(tester, pips.first), 0);
        expect(find.text('Games: 0'), findsNWidgets(2));
      }

      // Best of 7 is still on screen: win one game for player 1.
      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('player1Zone')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(filledPips(tester, find.byType(GamePips).first), 1);
      expect(filledPips(tester, find.byType(GamePips).last), 0);
      expect(find.text('Games: 1'), findsOneWidget);
      expect(find.text('Games: 0'), findsOneWidget);
    });
  });
}
