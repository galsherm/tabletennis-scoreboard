import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/l10n/gen/app_localizations.dart';
import 'package:tabletennis_scoreboard/widgets/coin_flip_indicator.dart';

/// Explicit, per-language verification for the idle coin's "TAP TO
/// TOSS" hint label (Phase 4P) — not just eyeballed in English, since
/// German/French translations of a short English phrase are routinely
/// longer and are exactly the case that would silently wrap or get
/// scaled down to illegibility without this check. See
/// PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md.
void main() {
  group('coin idle label (Phase 4P)', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets(
          'renders on a single line at the coin\'s actual size in '
          '${locale.languageCode}', (tester) async {
        // CoinFlipIndicator takes the resolved string directly (see its
        // idleLabel doc comment) rather than reaching for
        // AppLocalizations itself, so this resolves it the same way
        // SetupScreen does — via a real AppLocalizations instance for
        // the language under test — without needing a fully-localized
        // MaterialApp around it.
        final l10n = lookupAppLocalizations(locale);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CoinFlipIndicator(
              player1Label: 'Player 1',
              player2Label: 'Player 2',
              winner: null,
              tossSequence: 0,
              onTap: () {},
              onComplete: () {},
              idleLabel: l10n.tapToTossLabel,
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final labelFinder = find.byKey(const Key('coinIdleLabel'));
        expect(labelFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(labelFinder);
        // Regression guard: this is what structurally guarantees a
        // single line in the first place — a `RenderParagraph` given
        // unbounded width (which is exactly what `FittedBox` gives its
        // child) never wraps regardless of text length, so wrapping
        // becomes possible again the moment either half of this pair
        // (this, or the `FittedBox` checked below) is removed.
        expect(textWidget.maxLines, 1,
            reason: 'without maxLines: 1, a long enough translation could '
                'wrap onto a second line instead of shrinking to fit.');
        expect(
          find.ancestor(
            of: labelFinder,
            matching: find.byType(FittedBox),
          ),
          findsWidgets,
          reason: 'without a FittedBox(fit: BoxFit.scaleDown) ancestor, a '
              'long enough translation would overflow the coin instead of '
              'shrinking to fit on its single line.',
        );

        // Sanity floor: the maxLines+FittedBox pair above guarantees
        // "fits on one line," not "still legible" — catch a translation
        // so long it gets scaled down to near-nothing.
        final renderedHeight = tester.getSize(labelFinder).height;
        expect(renderedHeight, greaterThan(6.0),
            reason: '"${textWidget.data}" (${locale.languageCode}) was '
                'scaled down to $renderedHeight logical px tall — too '
                'small to read.');
      });
    }
  });
}
