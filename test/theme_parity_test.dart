import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/doubles_scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/screens/scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';
import 'package:tabletennis_scoreboard/theme/app_theme.dart';

class _RecordingTtsEngine implements TtsEngine {
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
    ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer());

/// Wraps [child] in a real themed `MaterialApp` — `theme`/`darkTheme` built
/// from the app's actual [buildAppTheme] (not a bare default `ThemeData`,
/// which would leave `context.palette` silently falling back to
/// [AppPalette.dark] regardless of [themeMode] — see
/// `AppPaletteContext.palette`'s own doc for why that fallback exists and
/// how it would mask exactly the kind of bug this file guards against).
Widget _themedApp(Widget child, ThemeMode themeMode) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
      home: child,
    );

/// This class of bug — a screen element that reads correctly in whichever
/// theme a developer happened to eyeball it in, but was quietly hardcoded
/// rather than actually theme-aware, so it silently breaks in the *other*
/// theme — isn't caught by any existing test: `theme_and_names_test.dart`
/// confirms the app-wide `ThemeMode`/`AppPalette` extension itself switches
/// correctly, but never checks that a given screen's own widgets actually
/// *read* from it rather than a hardcoded constant. That gap is exactly how
/// the setup screen's hero band shipped with a permanently dark background
/// and white title text, even after Light mode was added and every other
/// element on the same screen correctly switched — see
/// PHASE4Q_FINAL_STORE_SCREENSHOTS.md's hero-band-theming fix.
///
/// The fix for that specific bug is `_SetupHeroBand` reading
/// `context.palette` like everything else; the tests below both pin that
/// fix in place and establish the broader "renders differently, and
/// correctly, in each theme" check as a reusable pattern for other screens
/// (applied here to both scoreboard screens' own background) rather than a
/// one-off assertion that only happens to cover the hero band.
void main() {
  group('Setup screen hero band: theme parity (Phase 4Q)', () {
    testWidgets(
        'the hero band\'s background, diagonal accent, and title color all '
        'actually differ between Light and Dark, and each matches the '
        'correct AppPalette rather than a hardcoded constant', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      // Starts in Dark (the app's own default — see PHASE4B_UI_POLISH.md).
      final darkBackground = tester
          .widget<ColoredBox>(find.byKey(const Key('heroBandBackground')));
      final darkDiagonal = tester
          .widget<CustomPaint>(find.byWidgetPredicate((widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() == '_HeroDiagonalPainter'))
          .painter as dynamic;
      final darkTitleColor =
          tester.widget<Text>(find.text('New match')).style?.color;

      expect(darkBackground.color, AppPalette.dark.background,
          reason: 'the hero band should start in this app\'s Dark default');
      expect(darkDiagonal.color, AppPalette.dark.accent);
      expect(darkTitleColor, AppPalette.dark.scoreText);

      // Switch to Light via the real menu — the same user-facing path a
      // Light-mode bug would actually be seen through, not a shortcut that
      // pokes theme state directly.
      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('themeSubmenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('themeOptionLight')));
      await tester.pumpAndSettle();

      final lightBackground = tester
          .widget<ColoredBox>(find.byKey(const Key('heroBandBackground')));
      final lightDiagonal = tester
          .widget<CustomPaint>(find.byWidgetPredicate((widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() == '_HeroDiagonalPainter'))
          .painter as dynamic;
      final lightTitleColor =
          tester.widget<Text>(find.text('New match')).style?.color;

      expect(lightBackground.color, AppPalette.light.background);
      expect(lightDiagonal.color, AppPalette.light.accent);
      expect(lightTitleColor, AppPalette.light.scoreText);

      // The actual regression guard: these must genuinely differ, not
      // coincidentally match because both themes were reading the same
      // hardcoded value.
      expect(lightBackground.color, isNot(darkBackground.color));
      expect(lightDiagonal.color, isNot(darkDiagonal.color));
      expect(lightTitleColor, isNot(darkTitleColor));
    });
  });

  group('Scoreboard screens: theme parity (broader pattern, Phase 4Q)', () {
    // The score digit itself, rather than `Scaffold.backgroundColor` (which
    // is `null` on the widget whenever a screen leaves it to the ambient
    // `Theme.scaffoldBackgroundColor`, as both scoreboard screens do here —
    // asserting against it would just be checking `null == null` in both
    // themes and pass even if the screen ignored the theme entirely). The
    // score text's color is set explicitly from `context.palette.scoreText`
    // (`AppTypography.scoreDisplay`), so it actually exercises the same
    // "does this widget really read from the active theme" question the
    // hero band test above does.
    testWidgets(
        'ScoreboardScreen\'s (singles) score text color differs between '
        'Light and Dark and matches the correct AppPalette', (tester) async {
      final voice = _silentVoice();

      await tester.pumpWidget(_themedApp(
        ScoreboardScreen(
            bestOf: 5, firstServer: Player.one, voiceAnnouncer: voice),
        ThemeMode.dark,
      ));
      await tester.pumpAndSettle();
      final darkColor = tester
          .widget<Text>(find.byKey(const Key('player1PointsText')))
          .style
          ?.color;
      expect(darkColor, AppPalette.dark.scoreText);

      await tester.pumpWidget(_themedApp(
        ScoreboardScreen(
            bestOf: 5, firstServer: Player.one, voiceAnnouncer: voice),
        ThemeMode.light,
      ));
      await tester.pumpAndSettle();
      final lightColor = tester
          .widget<Text>(find.byKey(const Key('player1PointsText')))
          .style
          ?.color;
      expect(lightColor, AppPalette.light.scoreText);

      expect(lightColor, isNot(darkColor));
    });

    testWidgets(
        'DoublesScoreboardScreen\'s score text color differs between Light '
        'and Dark and matches the correct AppPalette', (tester) async {
      final voice = _silentVoice();

      await tester.pumpWidget(_themedApp(
        DoublesScoreboardScreen(
            bestOf: 5, firstServingTeam: Player.one, voiceAnnouncer: voice),
        ThemeMode.dark,
      ));
      await tester.pumpAndSettle();
      final darkColor = tester
          .widget<Text>(find.byKey(const Key('team1PointsText')))
          .style
          ?.color;
      expect(darkColor, AppPalette.dark.scoreText);

      await tester.pumpWidget(_themedApp(
        DoublesScoreboardScreen(
            bestOf: 5, firstServingTeam: Player.one, voiceAnnouncer: voice),
        ThemeMode.light,
      ));
      await tester.pumpAndSettle();
      final lightColor = tester
          .widget<Text>(find.byKey(const Key('team1PointsText')))
          .style
          ?.color;
      expect(lightColor, AppPalette.light.scoreText);

      expect(lightColor, isNot(darkColor));
    });
  });
}
