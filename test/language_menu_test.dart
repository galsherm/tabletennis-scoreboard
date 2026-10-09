import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/services/locale_resolution.dart';

/// Simulates the device reporting [locales] as its preferred locale
/// list for one test — see `_setDeviceLocale` in
/// `localization_widget_test.dart` for why both values are set.
void _setDeviceLocales(WidgetTester tester, List<Locale> locales) {
  tester.platformDispatcher.localeTestValue = locales.first;
  tester.platformDispatcher.localesTestValue = locales;
  addTearDown(() {
    tester.platformDispatcher.clearLocaleTestValue();
    tester.platformDispatcher.clearLocalesTestValue();
  });
}

Future<void> _pumpApp(WidgetTester tester, List<Locale> deviceLocales) async {
  SharedPreferences.setMockInitialValues({});
  _setDeviceLocales(tester, deviceLocales);
  await tester.pumpWidget(const TableTennisScoreboardApp());
  await tester.pumpAndSettle();
}

Future<void> _openLanguageMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('overflowMenuButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('languageSubmenu')));
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String optionKey) async {
  await _openLanguageMenu(tester);
  await tester.tap(find.byKey(Key(optionKey)));
  await tester.pumpAndSettle();
}

const _optionKeys = [
  'languageOptionSystem',
  'languageOptionEn',
  'languageOptionDe',
  'languageOptionFr',
];

/// The label text inside one language row.
Finder _labelIn(String optionKey, String text) => find.descendant(
      of: find.byKey(Key(optionKey)),
      matching: find.text(text),
    );

/// Asserts the check mark sits on [checkedKey]'s row and no other.
void _expectOnlyChecked(String checkedKey) {
  for (final key in _optionKeys) {
    expect(
      find.byKey(Key('${key}_check')),
      key == checkedKey ? findsOneWidget : findsNothing,
      reason: '$key should ${key == checkedKey ? '' : 'not '}be checked',
    );
  }
}

void main() {
  group('resolveDeviceLocale', () {
    const supported = AppLocalizations.supportedLocales;

    test('matches on language code, ignoring region', () {
      expect(resolveDeviceLocale([const Locale('de', 'AT')], supported),
          const Locale('de'));
    });

    test('takes the first device locale the app ships', () {
      expect(
        resolveDeviceLocale(
            [const Locale('es'), const Locale('fr'), const Locale('de')],
            supported),
        const Locale('fr'),
      );
    });

    test('falls back to English, not the alphabetically first locale', () {
      expect(resolveDeviceLocale([const Locale('es')], supported),
          const Locale('en'));
      expect(resolveDeviceLocale(null, supported), const Locale('en'));
      expect(resolveDeviceLocale(const [], supported), const Locale('en'));
    });
  });

  group('language menu: rows', () {
    testWidgets(
        'shows Automatic with the detected language, then English, '
        'Deutsch, Français — each in its own language, in that order',
        (tester) async {
      await _pumpApp(tester, [const Locale('en')]);
      await _openLanguageMenu(tester);

      expect(_labelIn('languageOptionSystem', 'Automatic (English)'),
          findsOneWidget);
      expect(_labelIn('languageOptionEn', 'English'), findsOneWidget);
      expect(_labelIn('languageOptionDe', 'Deutsch'), findsOneWidget);
      expect(_labelIn('languageOptionFr', 'Français'), findsOneWidget);

      final tops = [
        for (final key in _optionKeys)
          tester.getTopLeft(find.byKey(Key(key))).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()),
          reason: 'Automatic first, then English, Deutsch, Français');
      expect(tops.toSet(), hasLength(_optionKeys.length));

      _expectOnlyChecked('languageOptionSystem');
    });

    testWidgets(
        'on a German device the row reads "Automatisch (Deutsch)" — the '
        'word follows the UI language, the name is in its own language',
        (tester) async {
      await _pumpApp(tester, [const Locale('de', 'DE')]);
      await _openLanguageMenu(tester);

      expect(_labelIn('languageOptionSystem', 'Automatisch (Deutsch)'),
          findsOneWidget);
      // The three languages are never translated.
      expect(_labelIn('languageOptionEn', 'English'), findsOneWidget);
      expect(_labelIn('languageOptionDe', 'Deutsch'), findsOneWidget);
      expect(_labelIn('languageOptionFr', 'Français'), findsOneWidget);
      _expectOnlyChecked('languageOptionSystem');
    });

    testWidgets('on a French device the row reads "Automatique (Français)"',
        (tester) async {
      await _pumpApp(tester, [const Locale('fr', 'FR')]);
      await _openLanguageMenu(tester);

      expect(_labelIn('languageOptionSystem', 'Automatique (Français)'),
          findsOneWidget);
      _expectOnlyChecked('languageOptionSystem');
    });

    testWidgets(
        'an unsupported device language resolves to English, so the row '
        'reads "Automatic (English)"', (tester) async {
      await _pumpApp(tester, [const Locale('es', 'ES')]);
      await _openLanguageMenu(tester);

      expect(_labelIn('languageOptionSystem', 'Automatic (English)'),
          findsOneWidget);
      _expectOnlyChecked('languageOptionSystem');
    });

    testWidgets(
        'the detected language is the first supported one in the device\'s '
        'locale list, not just its primary locale', (tester) async {
      await _pumpApp(tester, [const Locale('es'), const Locale('fr')]);
      await _openLanguageMenu(tester);

      expect(find.text('Nouveau match'), findsOneWidget);
      expect(_labelIn('languageOptionSystem', 'Automatique (Français)'),
          findsOneWidget);
    });
  });

  group('language menu: selecting', () {
    testWidgets(
        'each language applies, moves the check to its own row only, and '
        'leaves the Automatic row naming the device language', (tester) async {
      await _pumpApp(tester, [const Locale('en')]);

      await _select(tester, 'languageOptionDe');
      expect(find.text('Neues Spiel'), findsOneWidget);
      await _openLanguageMenu(tester);
      _expectOnlyChecked('languageOptionDe');
      // "Automatic" is now written in German; what it would pick is
      // still the device's English.
      expect(_labelIn('languageOptionSystem', 'Automatisch (English)'),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('languageOptionFr')));
      await tester.pumpAndSettle();

      expect(find.text('Nouveau match'), findsOneWidget);
      await _openLanguageMenu(tester);
      _expectOnlyChecked('languageOptionFr');
      expect(_labelIn('languageOptionSystem', 'Automatique (English)'),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('languageOptionEn')));
      await tester.pumpAndSettle();

      expect(find.text('New match'), findsOneWidget);
      await _openLanguageMenu(tester);
      _expectOnlyChecked('languageOptionEn');
      expect(_labelIn('languageOptionSystem', 'Automatic (English)'),
          findsOneWidget);
    });

    testWidgets(
        'choosing the device\'s own language manually is still a manual '
        'choice: the check is on that row, not on Automatic', (tester) async {
      await _pumpApp(tester, [const Locale('de')]);

      await _select(tester, 'languageOptionDe');
      expect(find.text('Neues Spiel'), findsOneWidget);
      await _openLanguageMenu(tester);
      _expectOnlyChecked('languageOptionDe');
    });

    testWidgets(
        'Automatic after a manual choice returns to the device-resolved '
        'language', (tester) async {
      await _pumpApp(tester, [const Locale('fr')]);
      expect(find.text('Nouveau match'), findsOneWidget);

      await _select(tester, 'languageOptionEn');
      expect(find.text('New match'), findsOneWidget);

      await _select(tester, 'languageOptionSystem');
      expect(find.text('Nouveau match'), findsOneWidget);
      await _openLanguageMenu(tester);
      _expectOnlyChecked('languageOptionSystem');
      expect(_labelIn('languageOptionSystem', 'Automatique (Français)'),
          findsOneWidget);
    });

    testWidgets(
        'Automatic on an unsupported device language returns to English',
        (tester) async {
      await _pumpApp(tester, [const Locale('ja')]);

      await _select(tester, 'languageOptionDe');
      expect(find.text('Neues Spiel'), findsOneWidget);

      await _select(tester, 'languageOptionSystem');
      expect(find.text('New match'), findsOneWidget);
    });

    testWidgets('dismissing the menu without choosing changes nothing',
        (tester) async {
      await _pumpApp(tester, [const Locale('en')]);
      await _select(tester, 'languageOptionDe');
      expect(find.text('Neues Spiel'), findsOneWidget);

      await _openLanguageMenu(tester);
      // A tap outside the menu, on the bottom edge of the screen.
      final screen = tester.getSize(find.byType(MaterialApp));
      await tester.tapAt(Offset(screen.width / 2, screen.height - 2));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('languageOptionEn')), findsNothing,
          reason: 'the menu should have closed');
      expect(find.text('Neues Spiel'), findsOneWidget);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale, const Locale('de'));

      await _openLanguageMenu(tester);
      _expectOnlyChecked('languageOptionDe');
    });

    testWidgets('dismissing the menu while on Automatic leaves no override set',
        (tester) async {
      await _pumpApp(tester, [const Locale('fr')]);

      await _openLanguageMenu(tester);
      final screen = tester.getSize(find.byType(MaterialApp));
      await tester.tapAt(Offset(screen.width / 2, screen.height - 2));
      await tester.pumpAndSettle();

      expect(find.text('Nouveau match'), findsOneWidget);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale, isNull);
    });
  });
}
