import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/commentary_strings.dart';
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

/// Simulates the device reporting [locale] as its preferred locale, for
/// the lifetime of one test. `MaterialApp`'s default locale resolution
/// reads the *list* of preferred locales
/// (`WidgetsBinding.instance.platformDispatcher.locales`), not just the
/// single `.locale` getter, so both are set here for a locale override to
/// actually take effect.
void _setDeviceLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localeTestValue = locale;
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(() {
    tester.platformDispatcher.clearLocaleTestValue();
    tester.platformDispatcher.clearLocalesTestValue();
  });
}

Future<void> _openLanguageMenuAndSelect(
    WidgetTester tester, Key optionKey) async {
  await tester.tap(find.byKey(const Key('languageMenuButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(optionKey));
  await tester.pumpAndSettle();
}

void main() {
  group('device-locale auto-detection', () {
    testWidgets('defaults to English when the device locale is English',
        (tester) async {
      _setDeviceLocale(tester, const Locale('en'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.text('New match'), findsOneWidget);
    });

    testWidgets(
        'auto-detects German from the device locale with no manual override',
        (tester) async {
      _setDeviceLocale(tester, const Locale('de'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.text('Neues Spiel'), findsOneWidget);
      expect(find.text('Münze werfen'), findsOneWidget);
    });

    testWidgets(
        'auto-detects French from the device locale with no manual override',
        (tester) async {
      _setDeviceLocale(tester, const Locale('fr'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.text('Nouveau match'), findsOneWidget);
      expect(find.text('Tirer à pile ou face'), findsOneWidget);
    });

    testWidgets('falls back to English for an unsupported device locale',
        (tester) async {
      _setDeviceLocale(tester, const Locale('es'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.text('New match'), findsOneWidget);
    });

    testWidgets(
        'falls back to English for an unsupported RTL device locale '
        '(Arabic) without crashing or leaving a broken layout',
        (tester) async {
      _setDeviceLocale(tester, const Locale('ar'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('New match'), findsOneWidget);
      expect(find.text('Toss coin'), findsOneWidget);

      // The resolved locale is English, so the UI should render
      // left-to-right — not a half-RTL layout left over from the
      // device's actual (unsupported) locale.
      final directionality = Directionality.of(
        tester.element(find.text('New match')),
      );
      expect(directionality, TextDirection.ltr);

      // The rest of the setup screen (segmented button, toss/start
      // buttons) should be present and tappable, not just the app bar
      // title — i.e. this isn't a partially-broken/blank screen.
      expect(find.byKey(const Key('bestOfSelector')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pump();
      expect(find.byKey(const Key('startMatchButton')), findsOneWidget);
    });
  });

  group('manual language override', () {
    testWidgets('overrides an English device locale to German',
        (tester) async {
      _setDeviceLocale(tester, const Locale('en'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();
      expect(find.text('New match'), findsOneWidget);

      await _openLanguageMenuAndSelect(
          tester, const Key('languageOptionDe'));

      expect(find.text('Neues Spiel'), findsOneWidget);
    });

    testWidgets('overrides an English device locale to French',
        (tester) async {
      _setDeviceLocale(tester, const Locale('en'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await _openLanguageMenuAndSelect(
          tester, const Key('languageOptionFr'));

      expect(find.text('Nouveau match'), findsOneWidget);
    });

    testWidgets('"System default" reverts a manual override back to the '
        'device locale', (tester) async {
      _setDeviceLocale(tester, const Locale('en'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await _openLanguageMenuAndSelect(
          tester, const Key('languageOptionDe'));
      expect(find.text('Neues Spiel'), findsOneWidget);

      await _openLanguageMenuAndSelect(
          tester, const Key('languageOptionSystem'));
      expect(find.text('New match'), findsOneWidget);
    });

    testWidgets(
        'the manual override is still reachable and works after the device '
        'falls back to English from an unsupported (Arabic) locale',
        (tester) async {
      _setDeviceLocale(tester, const Locale('ar'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();
      // Confirm we're actually starting from the fallback-to-English case
      // this test is meant to cover, not accidentally already localized.
      expect(find.text('New match'), findsOneWidget);

      await _openLanguageMenuAndSelect(
          tester, const Key('languageOptionDe'));
      expect(tester.takeException(), isNull);
      expect(find.text('Neues Spiel'), findsOneWidget);

      await _openLanguageMenuAndSelect(
          tester, const Key('languageOptionFr'));
      expect(find.text('Nouveau match'), findsOneWidget);

      // And back to system default, which re-resolves to the (still
      // unsupported) Arabic device locale -> English fallback again.
      await _openLanguageMenuAndSelect(
          tester, const Key('languageOptionSystem'));
      expect(find.text('New match'), findsOneWidget);
    });

    testWidgets('the language menu checks the currently active option',
        (tester) async {
      _setDeviceLocale(tester, const Locale('en'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('languageMenuButton')));
      await tester.pumpAndSettle();

      // The menu's value type is a private enum in setup_screen.dart, so
      // this reads it through `dynamic` rather than naming that type here.
      final systemItem = tester.widget<CheckedPopupMenuItem<dynamic>>(
          find.byKey(const Key('languageOptionSystem')));
      final deItem = tester.widget<CheckedPopupMenuItem<dynamic>>(
          find.byKey(const Key('languageOptionDe')));
      expect(systemItem.checked, isTrue);
      expect(deItem.checked, isFalse);
    });
  });

  group('best-of selector localization (Gewinnsätze)', () {
    testWidgets('English shows the raw best-of-N numbers', (tester) async {
      _setDeviceLocale(tester, const Locale('en'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.textContaining('Gewinnsätze'), findsNothing);
    });

    testWidgets('French shows the raw best-of-N numbers, unchanged',
        (tester) async {
      _setDeviceLocale(tester, const Locale('fr'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.text('Au meilleur de'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets(
        'German shows "2/3/4 Gewinnsätze" (games needed to win) instead '
        'of the raw 3/5/7 best-of-N numbers', (tester) async {
      _setDeviceLocale(tester, const Locale('de'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      expect(find.text('Spielformat'), findsOneWidget);
      expect(find.text('2 Gewinnsätze'), findsOneWidget);
      expect(find.text('3 Gewinnsätze'), findsOneWidget);
      expect(find.text('4 Gewinnsätze'), findsOneWidget);
      // The raw numbers should not appear as standalone segment labels.
      expect(find.text('3'), findsNothing);
      expect(find.text('5'), findsNothing);
      expect(find.text('7'), findsNothing);
    });

    testWidgets(
        'tapping "3 Gewinnsätze" in German starts a match identical to '
        'tapping "5" ("Best of 5") in English', (tester) async {
      _setDeviceLocale(tester, const Locale('de'));
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tossButton')));
      await tester.pump();

      // Select away from the default first, then select "3 Gewinnsätze",
      // so a pass here proves the tap itself drives the engine's bestOf
      // value rather than coincidentally matching the initial default
      // (which also happens to be bestOf=5 / "3 Gewinnsätze").
      await tester.tap(find.text('2 Gewinnsätze'));
      await tester.pump();
      await tester.tap(find.text('3 Gewinnsätze'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('startMatchButton')));
      await tester.pumpAndSettle();

      // Best-of-5 needs exactly 3 games to win (matching English's plain
      // "5" segment, and widget_test.dart's default-best-of-5 behavior):
      // winning 2 games must not end the match yet.
      for (var game = 0; game < 2; game++) {
        for (var i = 0; i < 11; i++) {
          await tester.tap(find.byKey(const Key('player1Zone')));
          await tester.pump();
        }
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('matchCompleteDialog')), findsNothing);

      // A 3rd game should now end the match.
      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('player1Zone')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('matchCompleteDialog')), findsOneWidget);
    });
  });

  group('ScoreboardScreen localization', () {
    testWidgets('shows German tooltips and labels', (tester) async {
      _setDeviceLocale(tester, const Locale('de'));
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 5,
          firstServer: Player.one,
          voiceAnnouncer:
              VoiceAnnouncer(ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer()),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tischtennis'), findsOneWidget); // app bar title
      expect(find.text('Spieler 1'), findsOneWidget);
      expect(find.text('Spieler 2'), findsOneWidget);
      expect(find.text('Sätze: 0'), findsNWidgets(2));

      final undoButton =
          tester.widget<IconButton>(find.byKey(const Key('undoButton')));
      expect(undoButton.tooltip, 'Rückgängig');
      final resetButton =
          tester.widget<IconButton>(find.byKey(const Key('resetButton')));
      expect(resetButton.tooltip, 'Spiel zurücksetzen');
      final muteButton =
          tester.widget<IconButton>(find.byKey(const Key('muteButton')));
      expect(muteButton.tooltip, 'Sprachausgabe stummschalten');
    });

    testWidgets('shows French tooltips and labels', (tester) async {
      _setDeviceLocale(tester, const Locale('fr'));
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 5,
          firstServer: Player.one,
          voiceAnnouncer:
              VoiceAnnouncer(ttsEngine: _RecordingTtsEngine(), clipPlayer: _NoopClipPlayer()),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tennis de table'), findsOneWidget);
      expect(find.text('Joueur 1'), findsOneWidget);
      expect(find.text('Joueur 2'), findsOneWidget);
      expect(find.text('Manches : 0'), findsNWidgets(2));

      final undoButton =
          tester.widget<IconButton>(find.byKey(const Key('undoButton')));
      expect(undoButton.tooltip, 'Annuler');
      final muteButton =
          tester.widget<IconButton>(find.byKey(const Key('muteButton')));
      expect(muteButton.tooltip, 'Couper le son');
    });

    testWidgets(
        'the scoreboard screen picks a VoiceAnnouncer matching the active '
        'locale when none is injected', (tester) async {
      // No voiceAnnouncer override here: this exercises the real
      // didChangeDependencies wiring in ScoreboardScreen, using the real
      // (platform-backed) TTS/clip plugins. Under `flutter test` those
      // plugins have no platform channel, so every call fails and is
      // swallowed — this only asserts that resolving a German locale into
      // a VoiceAnnouncer via CommentaryStrings.forLanguage doesn't crash
      // the screen or block scoring, matching the graceful-degradation
      // design from Phase 2.
      _setDeviceLocale(tester, const Locale('de'));
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(bestOf: 5, firstServer: Player.one),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('player1Zone')));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.byKey(const Key('player1PointsText'))).data,
        '1',
      );
    });
  });

  group('localized voice announcements via the scoreboard screen', () {
    testWidgets('speaks German when configured with German commentary '
        'strings', (tester) async {
      final tts = _RecordingTtsEngine();
      final voice = VoiceAnnouncer(
        ttsEngine: tts,
        clipPlayer: _NoopClipPlayer(),
        strings: CommentaryStrings.de,
      );
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 5,
          firstServer: Player.one,
          voiceAnnouncer: voice,
        ),
      ));

      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('player1Zone')));
        await tester.pump();
      }
      await tester.pump();

      expect(tts.spoken.first, '1, 0');
      expect(tts.spoken.last, 'Satz, Spieler 1. Seitenwechsel.');
    });

    testWidgets('speaks French when configured with French commentary '
        'strings', (tester) async {
      final tts = _RecordingTtsEngine();
      final voice = VoiceAnnouncer(
        ttsEngine: tts,
        clipPlayer: _NoopClipPlayer(),
        strings: CommentaryStrings.fr,
      );
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoreboardScreen(
          bestOf: 5,
          firstServer: Player.one,
          voiceAnnouncer: voice,
        ),
      ));

      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('player1Zone')));
        await tester.pump();
      }
      await tester.pump();

      expect(tts.spoken.first, '1, 0');
      expect(tts.spoken.last, 'Manche, Joueur 1. Changement de côté.');
    });
  });
}
