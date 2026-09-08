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
