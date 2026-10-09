import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
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
  tester.view.physicalSize = Size(width, 780);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

const _topLevelRows = [
  'themeSubmenu',
  'languageSubmenu',
  'helpMenuButton',
  'privacyPolicyMenuButton',
  'rateAppMenuButton',
];
const _themeOptions = [
  'themeOptionSystem',
  'themeOptionLight',
  'themeOptionDark',
];
const _languageOptions = [
  'languageOptionSystem',
  'languageOptionEn',
  'languageOptionDe',
  'languageOptionFr',
];

/// The label `Text`s inside one menu row.
Finder _labelsIn(String rowKey) => find.descendant(
      of: find.byKey(Key(rowKey)),
      matching: find.byType(Text),
    );

/// Asserts every label in [rowKeys] is shown in full: not ellipsized,
/// not clipped by its row, inside the screen, and on at most [maxLines]
/// lines.
void _expectLabelsShownInFull(
  WidgetTester tester,
  List<String> rowKeys,
  double screenWidth, {
  required int maxLines,
}) {
  expect(tester.takeException(), isNull);
  for (final rowKey in rowKeys) {
    final row = tester.getRect(find.byKey(Key(rowKey)));
    expect(row.left, greaterThanOrEqualTo(0), reason: rowKey);
    expect(row.right, lessThanOrEqualTo(screenWidth), reason: rowKey);

    final labels = _labelsIn(rowKey);
    expect(labels, findsWidgets, reason: rowKey);
    for (final element in labels.evaluate()) {
      final text = element.widget as Text;
      final paragraph = element.renderObject! as RenderParagraph;
      final label = '"${text.data}" in $rowKey';

      expect(text.overflow, isNot(TextOverflow.ellipsis), reason: label);
      expect(paragraph.overflow, isNot(TextOverflow.ellipsis), reason: label);
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);

      final lines = paragraph
          .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: text.data!.length))
          .map((box) => box.top.round())
          .toSet();
      expect(lines.length, lessThanOrEqualTo(maxLines),
          reason: '$label takes ${lines.length} lines');

      // Every glyph box lies inside the row, so nothing is clipped off.
      final origin = paragraph.localToGlobal(Offset.zero);
      final drawn = origin & paragraph.size;
      expect(drawn.left, greaterThanOrEqualTo(row.left - 0.5), reason: label);
      expect(drawn.right, lessThanOrEqualTo(row.right + 0.5), reason: label);
      expect(drawn.top, greaterThanOrEqualTo(row.top - 0.5), reason: label);
      expect(drawn.bottom, lessThanOrEqualTo(row.bottom + 0.5), reason: label);
    }
  }
}

/// The on-screen rectangle of a submenu's rows.
Rect _rowsRect(WidgetTester tester, List<String> rowKeys) => rowKeys
    .map((key) => tester.getRect(find.byKey(Key(key))))
    .reduce((a, b) => a.expandToInclude(b));

/// Asserts the open submenu (whose rows are [optionKeys]) sits directly
/// under [triggerKey]'s row at the menu's own width, so that no
/// top-level label is left sticking out from behind its side — the
/// "Politique de c" / "Datenschutzer" effect.
void _expectSubmenuCoversWholeRows(
  WidgetTester tester,
  String triggerKey,
  List<String> optionKeys,
) {
  final trigger = tester.getRect(find.byKey(Key(triggerKey)));
  final submenu = _rowsRect(tester, optionKeys);

  expect(submenu.left, closeTo(trigger.left, 1.5),
      reason: 'the submenu should line up with the menu\'s left edge');
  expect(submenu.width, closeTo(trigger.width, 1.5),
      reason: 'the submenu should be exactly as wide as the menu');
  expect(submenu.top, greaterThanOrEqualTo(trigger.bottom - 0.5),
      reason: 'the submenu should open below its own row, not over it');

  for (final rowKey in _topLevelRows) {
    for (final element in _labelsIn(rowKey).evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final label = paragraph.localToGlobal(Offset.zero) & paragraph.size;
      final beside =
          label.top < submenu.bottom + 8 && label.bottom > submenu.top - 8;
      if (!beside) continue;
      expect(label.left, greaterThanOrEqualTo(submenu.left - 0.5),
          reason: '"${(element.widget as Text).data}" sticks out to the '
              'left of the open submenu');
      expect(label.right, lessThanOrEqualTo(submenu.right + 0.5),
          reason: '"${(element.widget as Text).data}" sticks out to the '
              'right of the open submenu');
    }
  }
}

void main() {
  // The real UI font, so label widths are the ones a phone lays out —
  // the default test font makes every glyph a full em wide.
  setUpAll(() async {
    final loader = FontLoader(AppTypography.uiFamily);
    for (final file in ['Barlow-Medium.ttf', 'Barlow-SemiBold.ttf']) {
      final bytes = await File('assets/fonts/$file').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('setup menu labels are never cut off', () {
    for (final width in [320.0, 360.0]) {
      for (final textScale in [1.0, 1.3]) {
        for (final language in ['en', 'de', 'fr']) {
          // From 360dp up every label fits on one line; on a 320dp
          // phone with a large font the longest may wrap onto a second.
          final maxLines = width >= 360 ? 1 : 2;

          testWidgets('${width.toInt()}dp, text scale $textScale, $language',
              (tester) async {
            _usePhone(tester, width, textScale);
            await tester
                .pumpWidget(_themedApp(_setupScreen(), Locale(language)));
            await tester.pumpAndSettle();

            await tester.tap(find.byKey(const Key('overflowMenuButton')));
            await tester.pumpAndSettle();
            _expectLabelsShownInFull(tester, _topLevelRows, width,
                maxLines: maxLines);

            await tester.tap(find.byKey(const Key('themeSubmenu')));
            await tester.pumpAndSettle();
            _expectLabelsShownInFull(tester, _themeOptions, width,
                maxLines: maxLines);
            _expectSubmenuCoversWholeRows(
                tester, 'themeSubmenu', _themeOptions);

            // The open Theme submenu lies over the Language row; tapping
            // Theme again folds it away.
            await tester.tap(find.byKey(const Key('themeSubmenu')));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('themeOptionDark')), findsNothing);
            _expectLabelsShownInFull(tester, _topLevelRows, width,
                maxLines: maxLines);

            await tester.tap(find.byKey(const Key('languageSubmenu')));
            await tester.pumpAndSettle();
            _expectLabelsShownInFull(tester, _languageOptions, width,
                maxLines: maxLines);
            _expectSubmenuCoversWholeRows(
                tester, 'languageSubmenu', _languageOptions);

            // Still a working menu: choosing an option closes it.
            await tester.tap(find.byKey(const Key('languageOptionDe')));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('languageOptionDe')), findsNothing);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets(
        'the menu is only as wide as its longest row needs, not the '
        'whole screen', (tester) async {
      _usePhone(tester, 412, 1.0);
      await tester.pumpWidget(_themedApp(_setupScreen(), const Locale('en')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('overflowMenuButton')));
      await tester.pumpAndSettle();

      final row = tester.getRect(find.byKey(const Key('helpMenuButton')));
      expect(row.width, lessThan(300));
      expect(row.width, greaterThan(150));
    });
  });
}
