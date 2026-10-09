import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/screens/help_screen.dart';
import 'package:tabletennis_scoreboard/screens/setup_screen.dart';
import 'package:tabletennis_scoreboard/theme/app_theme.dart';

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

Widget _setupScreen() => SetupScreen(
      currentLocaleOverride: null,
      onLocaleChanged: (_) {},
      themeMode: ThemeMode.dark,
      onThemeModeChanged: (_) {},
    );

void _usePhone(WidgetTester tester, double width, double textScale) {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Asserts the hero band's [title] is drawn on exactly one line, inside
/// the screen, and clear of the orange diagonal.
void _expectSingleLineTitle(
    WidgetTester tester, String title, double screenWidth) {
  expect(tester.takeException(), isNull);

  final titleFinder = find.text(title);
  expect(titleFinder, findsOneWidget);
  final text = tester.widget<Text>(titleFinder);
  expect(text.maxLines, 1);
  expect(
    find.ancestor(of: titleFinder, matching: find.byType(FittedBox)),
    findsOneWidget,
    reason: 'the title must shrink to fit rather than wrap or overflow',
  );

  // One line as actually laid out, not just as requested.
  final paragraph = tester.renderObject<RenderParagraph>(titleFinder);
  expect(paragraph.didExceedMaxLines, isFalse,
      reason: '"$title" was truncated instead of shrunk');
  final lines = paragraph
      .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: title.length))
      .map((box) => box.top.round())
      .toSet();
  expect(lines, hasLength(1),
      reason: '"$title" wrapped onto ${lines.length} '
          'lines');

  // As drawn (after any FittedBox scaling): inside the screen...
  final rect = tester.getRect(titleFinder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(screenWidth));

  // ...and left of where the diagonal's lower edge starts.
  final diagonal = tester.widget<CustomPaint>(find.byWidgetPredicate((widget) =>
      widget is CustomPaint &&
      widget.painter.runtimeType.toString() == '_HeroDiagonalPainter'));
  final wedgeLeft = heroDiagonalBottomX(
    bandWidth: screenWidth,
    titleRight: (diagonal.painter as dynamic).titleRight as double,
  );
  expect(rect.right, lessThanOrEqualTo(wedgeLeft + 0.5),
      reason: '"$title" (right edge ${rect.right}) runs into the diagonal '
          '(starts at $wedgeLeft)');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('hero band title stays on one line', () {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final textScale in [1.0, 1.3]) {
        for (final language in ['en', 'de', 'fr']) {
          final variant = '${width.toInt()}dp, text scale $textScale, '
              '$language';
          final locale = Locale(language);
          final l10n = lookupAppLocalizations(locale);

          testWidgets('setup screen ($variant)', (tester) async {
            _usePhone(tester, width, textScale);
            await tester.pumpWidget(_themedApp(_setupScreen(), locale));
            await tester.pumpAndSettle();

            _expectSingleLineTitle(tester, l10n.newMatchScreenTitle, width);
          });

          testWidgets('help page ($variant)', (tester) async {
            _usePhone(tester, width, textScale);
            await tester.pumpWidget(_themedApp(const HelpScreen(), locale));
            await tester.pumpAndSettle();

            _expectSingleLineTitle(tester, l10n.helpTitle, width);
          });
        }
      }
    }

    testWidgets(
        'the title keeps its full size when there is room, and only '
        'shrinks when it would otherwise reach the diagonal', (tester) async {
      // In the test font every glyph is one em wide, so "Aide" fits the
      // title's share of a 412dp band and "Nouveau match" does not.
      _usePhone(tester, 412, 1.0);
      await tester
          .pumpWidget(_themedApp(const HelpScreen(), const Locale('fr')));
      await tester.pumpAndSettle();
      final fits = tester.getSize(find.text('Aide'));
      expect(
          tester.getRect(find.text('Aide')).height, closeTo(fits.height, 0.5),
          reason: 'a title that fits must not be scaled');

      await tester.pumpWidget(_themedApp(_setupScreen(), const Locale('fr')));
      await tester.pumpAndSettle();
      final long = find.text('Nouveau match');
      expect(tester.getRect(long).height, lessThan(tester.getSize(long).height),
          reason: 'a title too wide for its share must be scaled down');
    });
  });
}
