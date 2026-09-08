import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/doubles_scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';
import 'package:tabletennis_scoreboard/theme/app_theme.dart';

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

/// WCAG relative luminance / contrast ratio, used to check the light and
/// dark palettes both hit a real accessible-contrast bar rather than
/// asserting exact color values — see PHASE4F_THEME_AND_NAMES.md.
double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = channel(c.r);
  final g = channel(c.g);
  final b = channel(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a) + 0.05;
  final lb = _relativeLuminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  group('AppPalette (Phase 4F light theme)', () {
    test('light and dark are genuinely different palettes, not the same '
        'colors twice', () {
      expect(AppPalette.light.background, isNot(AppPalette.dark.background));
      expect(AppPalette.light.scoreText, isNot(AppPalette.dark.scoreText));
      expect(AppPalette.light.accent, isNot(AppPalette.dark.accent));
    });

    test('dark keeps the exact Phase 4B colors unchanged', () {
      expect(AppPalette.dark.background, const Color(0xFF0B0F14));
      expect(AppPalette.dark.scoreText, const Color(0xFFF5F7FA));
      expect(AppPalette.dark.accent, const Color(0xFFFF8A34));
    });

    test('light background is a light color and dark background is a '
        'dark one (not just inverted labels)', () {
      expect(_relativeLuminance(AppPalette.light.background), greaterThan(0.8));
      expect(_relativeLuminance(AppPalette.dark.background), lessThan(0.05));
    });

    test('scoreText hits at least WCAG AAA contrast (7:1) against '
        'background in both palettes — the score must always be legible '
        'at a glance', () {
      expect(
        _contrastRatio(AppPalette.dark.scoreText, AppPalette.dark.background),
        greaterThanOrEqualTo(7.0),
      );
      expect(
        _contrastRatio(
            AppPalette.light.scoreText, AppPalette.light.background),
        greaterThanOrEqualTo(7.0),
      );
    });

    test('accent hits at least WCAG AA contrast (3:1, the large-content/'
        'graphical-object threshold) against background in both palettes '
        '— the light palette deepens the accent specifically for this',
        () {
      expect(
        _contrastRatio(AppPalette.dark.accent, AppPalette.dark.background),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(AppPalette.light.accent, AppPalette.light.background),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('buildAppTheme attaches the matching palette as a ThemeExtension',
        () {
      final dark = buildAppTheme(Brightness.dark);
      final light = buildAppTheme(Brightness.light);
      expect(dark.extension<AppPalette>(), AppPalette.dark);
      expect(light.extension<AppPalette>(), AppPalette.light);
    });
  });

  group('Setup screen: theme menu (Phase 4F)', () {
    testWidgets('shows a theme menu with System/Light/Dark options, '
        'checkmarking the current mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('themeMenuButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('themeOptionSystem')), findsOneWidget);
      expect(find.byKey(const Key('themeOptionLight')), findsOneWidget);
      expect(find.byKey(const Key('themeOptionDark')), findsOneWidget);

      final darkItem = tester.widget<CheckedPopupMenuItem<ThemeMode>>(
          find.byKey(const Key('themeOptionDark')));
      expect(darkItem.checked, isTrue,
          reason: 'dark is the default with nothing persisted yet');
    });

    testWidgets('selecting Light actually switches the rendered theme '
        'brightness', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('themeMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('themeOptionLight')));
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.light);

      final scaffoldContext = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(scaffoldContext).brightness, Brightness.light);
      expect(scaffoldContext.palette, AppPalette.light);
    });

    testWidgets('the chosen theme persists across a simulated app restart',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('themeMenuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('themeOptionLight')));
      await tester.pumpAndSettle();

      // Simulate a fresh cold start: a brand-new app instance reading
      // from the same (mocked) persisted storage.
      await tester.pumpWidget(
        const TableTennisScoreboardApp(key: ValueKey('restarted')),
      );
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.light);
    });

    testWidgets('a fresh install with nothing persisted still defaults to '
        'dark — this feature adds choice, it does not change the default '
        '(PHASE4B_UI_POLISH.md)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.dark);
    });
  });

  // Editing on the scoreboard itself was removed in Phase 4H — names can
  // now only be set on the setup screen, and are locked (plain,
  // uneditable text) once a match starts. The equivalent coverage for
  // that model — a custom name reaching the banner/voice/dialog,
  // independence between slots, overflow safety, and "New match" no
  // longer resetting names — now lives in
  // test/names_sync_and_dialog_test.dart, alongside the new
  // discoverability and locking tests. See
  // PHASE4H_NAME_EDITING_REFINEMENT.md.

  group('Editable names: setup screen doubles preview (Phase 4F)', () {
    testWidgets(
        'renaming a player in the setup screen\'s doubles preview carries '
        'that name into the started match', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Doubles'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('player1PreviewNameText')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const Key('player1PreviewNameField')), 'Alex');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Alex'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('startMatchButton')));
      await tester.tap(find.byKey(const Key('startMatchButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('team1Zone')), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Player 1'), findsNothing);
    });
  });

  group('Receiver icon (Phase 4F)', () {
    testWidgets(
        'the receiver icon reuses the server icon\'s exact shape '
        '(sports_tennis), just dimmed — not a different symbol like '
        'call_received', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      final serverIcon = tester
          .widget<Icon>(find.byKey(const Key('team1Slot0ServerIcon')));
      final receiverIcon = tester
          .widget<Icon>(find.byKey(const Key('team2Slot0ReceiverIcon')));

      expect(serverIcon.icon, Icons.sports_tennis);
      expect(receiverIcon.icon, Icons.sports_tennis,
          reason: 'same shape as the server icon, not a separate glyph');
      expect(receiverIcon.color!.a, lessThan(serverIcon.color!.a),
          reason: 'the receiver icon should read as visually lighter/'
              'dimmer than the solid server icon');
    });

    testWidgets('the receiver tooltip text is unchanged', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DoublesScoreboardScreen(
          bestOf: 5,
          firstServingTeam: Player.one,
          voiceAnnouncer: _silentVoice(),
        ),
      ));

      final receiverIcon = tester.widget<Tooltip>(find.ancestor(
        of: find.byKey(const Key('team2Slot0ReceiverIcon')),
        matching: find.byType(Tooltip),
      ));
      expect(receiverIcon.message, 'Rückschläger');
    });
  });
}
