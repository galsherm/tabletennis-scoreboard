import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/screens/doubles_scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/screens/scoreboard_screen.dart';
import 'package:tabletennis_scoreboard/services/clip_player.dart';
import 'package:tabletennis_scoreboard/services/tts_engine.dart';
import 'package:tabletennis_scoreboard/services/voice_announcer.dart';
import 'package:tabletennis_scoreboard/theme/app_theme.dart';

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
Widget _themedApp(Widget child, Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: child,
    );

void _usePhone(WidgetTester tester, double width, double textScale) {
  tester.view.physicalSize = Size(width, 780);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Asserts the scoreboard's app-bar [title] is shown in full: one line,
/// not ellipsized, between the back button and the first action icon.
void _expectFullTitle(WidgetTester tester, String title) {
  expect(tester.takeException(), isNull);

  final titleFinder = find.descendant(
    of: find.byType(AppBar),
    matching: find.text(title),
  );
  expect(titleFinder, findsOneWidget);
  expect(
    find.ancestor(of: titleFinder, matching: find.byType(FittedBox)),
    findsOneWidget,
    reason: 'the title must shrink to fit rather than be cut off',
  );

  // Laid out without running out of room: an ellipsized title is one
  // whose paragraph was given less width than its text needs.
  final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(
    paragraph.size.width,
    greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5),
    reason: '"$title" was laid out narrower than its text, so it is '
        'truncated',
  );
  final lines = paragraph
      .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: title.length))
      .map((box) => box.top.round())
      .toSet();
  expect(lines, hasLength(1));

  // As drawn (after scaling): clear of the first action icon.
  final rect = tester.getRect(titleFinder);
  final firstAction = tester.getRect(find.byKey(const Key('muteButton')));
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(firstAction.left + 0.5),
      reason: '"$title" (right edge ${rect.right}) runs under the mute '
          'button (starts at ${firstAction.left})');
  expect(rect.height, greaterThan(8), reason: 'scaled down too far to read');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('scoreboard app-bar title is never truncated', () {
    for (final width in [320.0, 360.0]) {
      for (final textScale in [1.0, 1.3]) {
        for (final language in ['fr', 'de', 'en']) {
          final variant = '${width.toInt()}dp, text scale $textScale, '
              '$language';
          final locale = Locale(language);
          final title = lookupAppLocalizations(locale).scoreboardTitle;

          testWidgets('singles ($variant)', (tester) async {
            _usePhone(tester, width, textScale);
            await tester.pumpWidget(_themedApp(
              ScoreboardScreen(
                bestOf: 5,
                firstServer: Player.one,
                voiceAnnouncer: _silentVoice(),
              ),
              locale,
            ));
            await tester.pumpAndSettle();

            _expectFullTitle(tester, title);
          });

          testWidgets('doubles ($variant)', (tester) async {
            _usePhone(tester, width, textScale);
            await tester.pumpWidget(_themedApp(
              DoublesScoreboardScreen(
                bestOf: 5,
                firstServingTeam: Player.one,
                voiceAnnouncer: _silentVoice(),
              ),
              locale,
            ));
            await tester.pumpAndSettle();

            _expectFullTitle(tester, title);
          });
        }
      }
    }

    test('the French title is still "Tennis de table"', () {
      expect(lookupAppLocalizations(const Locale('fr')).scoreboardTitle,
          'Tennis de table');
    });
  });
}
