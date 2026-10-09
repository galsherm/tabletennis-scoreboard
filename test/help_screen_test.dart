import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/screens/help_screen.dart';
import 'package:tabletennis_scoreboard/screens/setup_screen.dart';
import 'package:tabletennis_scoreboard/theme/app_theme.dart';

/// A real themed `MaterialApp` built from [buildAppTheme] — a bare
/// default `ThemeData` would leave `context.palette` falling back to the
/// dark palette regardless of [themeMode]. See `_themedApp` in
/// `theme_parity_test.dart`.
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

Widget _setupScreen(Locale locale) => SetupScreen(
      currentLocaleOverride: locale,
      onLocaleChanged: (_) {},
      themeMode: ThemeMode.dark,
      onThemeModeChanged: (_) {},
    );

const _titles = {'en': 'How to use', 'de': 'Anleitung', 'fr': 'Aide'};
const _cardCount = 8;

AppPalette _paletteFor(ThemeMode mode) =>
    mode == ThemeMode.light ? AppPalette.light : AppPalette.dark;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Help page', () {
    for (final language in _titles.keys) {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets(
            'the menu item opens it and it renders without overflow '
            '($language, ${themeMode.name})', (tester) async {
          final locale = Locale(language);
          await tester.pumpWidget(
              _themedApp(_setupScreen(locale), themeMode, locale));

          await tester.tap(find.byKey(const Key('overflowMenuButton')));
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byKey(const Key('helpMenuButton')),
              matching: find.text(_titles[language]!),
            ),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('helpMenuButton')));
          await tester.pumpAndSettle();

          expect(find.byType(HelpScreen), findsOneWidget);
          expect(find.text(_titles[language]!), findsOneWidget);
          expect(find.byKey(const Key('helpCard')), findsNWidgets(_cardCount));
          expect(tester.takeException(), isNull);

          // Cards read their colors from the active palette, not a
          // hardcoded one — they must differ between Light and Dark.
          final palette = _paletteFor(themeMode);
          final card = tester.widget<Container>(
              find.byKey(const Key('helpCard')).first);
          final decoration = card.decoration! as BoxDecoration;
          expect(decoration.color, palette.surface);
          expect(
            tester
                .widget<ColoredBox>(
                    find.byKey(const Key('heroBandBackground')))
                .color,
            palette.background,
          );

          // The last card is reachable by scrolling.
          await tester.scrollUntilVisible(
            find.byKey(const Key('helpCard')).last,
            200,
            scrollable: find.descendant(
              of: find.byKey(const Key('helpScrollView')),
              matching: find.byType(Scrollable),
            ),
          );
          expect(tester.takeException(), isNull);

          // Back returns to the setup screen.
          await tester.tap(find.byKey(const Key('helpBackButton')));
          await tester.pumpAndSettle();
          expect(find.byType(HelpScreen), findsNothing);
          expect(find.byKey(const Key('startMatchButton')), findsOneWidget);
        });

        testWidgets(
            'does not overflow on a small phone with a large system font '
            '($language, ${themeMode.name})', (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = 2.0;
          addTearDown(tester.view.reset);
          addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue);

          final locale = Locale(language);
          await tester.pumpWidget(
              _themedApp(const HelpScreen(), themeMode, locale));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('helpCard')), findsNWidgets(_cardCount));
          expect(tester.takeException(), isNull);

          await tester.drag(
              find.byKey(const Key('helpScrollView')), const Offset(0, -5000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Every card stays within the screen's width.
          for (final element
              in find.byKey(const Key('helpCard')).evaluate()) {
            final box = element.renderObject! as RenderBox;
            final left = box.localToGlobal(Offset.zero).dx;
            expect(left, greaterThanOrEqualTo(0));
            expect(left + box.size.width, lessThanOrEqualTo(320));
          }
        });
      }
    }

    testWidgets('never opens on its own', (tester) async {
      const locale = Locale('en');
      await tester.pumpWidget(
          _themedApp(_setupScreen(locale), ThemeMode.dark, locale));
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen), findsNothing);
    });
  });
}
