import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/main.dart';
import 'package:tabletennis_scoreboard/screens/setup_screen.dart';

/// Regression test for a real layout bug flagged during Phase 4P
/// screenshot review: the setup screen's hero band draws an orange
/// diagonal wedge in its upper-right corner using fixed 55%/40% width
/// fractions, which happened to cut straight through the second word of
/// "New match" — and would only be worse for longer translations like
/// German "Neues Spiel" or French "Nouveau match". Fixed by measuring
/// the title's actual rendered width and pushing the wedge's bottom
/// edge right of it. See PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md,
/// "A real layout regression found and fixed while building this".
void main() {
  group('heroDiagonalBottomX', () {
    test('clears a short title using the original ~40% baseline', () {
      // "New match" at the hero band's 32px bold weight is comfortably
      // under 40% of a typical phone-width band, so short titles should
      // still get the original, purely cosmetic slant.
      final x = heroDiagonalBottomX(bandWidth: 360, titleRight: 80);
      expect(x, 360 * 0.40);
    });

    test('pushes right of a title wide enough to reach the old 40% line', () {
      // This is the exact failure mode from the bug report: a title
      // wide enough that the fixed 40% boundary used to land inside it.
      const titleRight = 200.0;
      final x = heroDiagonalBottomX(bandWidth: 360, titleRight: titleRight);

      expect(x, greaterThanOrEqualTo(titleRight),
          reason: 'the wedge must never start to the left of where the '
              'title text actually ends, or it paints over the text');
    });

    test('still leaves a visible sliver of wedge for a near-full-width title',
        () {
      // A very long translation could in principle nearly fill the
      // band. Even then the brand motif shouldn't vanish entirely.
      final x = heroDiagonalBottomX(bandWidth: 360, titleRight: 355);

      expect(x, lessThan(360),
          reason: 'some part of the wedge must stay on-screen even when '
              'the title leaves almost no room');
    });

    test(
        'scales the clearance check across a range of band widths and '
        'title lengths — the wedge boundary always sits at or right of '
        'the title, for every combination', () {
      for (final bandWidth in [320.0, 360.0, 412.0, 480.0]) {
        for (final titleRight in [60.0, 120.0, 180.0, 240.0, 300.0]) {
          final x =
              heroDiagonalBottomX(bandWidth: bandWidth, titleRight: titleRight);
          if (titleRight <= bandWidth - 32.0) {
            expect(x, greaterThanOrEqualTo(titleRight),
                reason: 'bandWidth=$bandWidth, titleRight=$titleRight: '
                    'wedge boundary $x overlaps the title');
          }
        }
      }
    });
  });

  group('_HeroDiagonalPainter\'s canvas', () {
    testWidgets(
        'spans the full hero band width, not just the title text\'s own '
        'width — a real regression this exact fix introduced and then '
        'caught on a real device: wrapping the title Column in a Stack '
        'without forcing it to the band\'s full width left the Stack '
        '(and so the diagonal\'s canvas) shrink-wrapped to whichever of '
        'the menu icon or the title text was wider, so the wedge painted '
        'across only a sliver tucked behind the text instead of reaching '
        'the screen\'s right edge', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      final diagonalCustomPaint = find.byWidgetPredicate((widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_HeroDiagonalPainter');
      expect(diagonalCustomPaint, findsOneWidget);

      final screenWidth = tester.getSize(find.byType(MaterialApp)).width;
      final canvasWidth = tester.getSize(diagonalCustomPaint).width;

      // The shrink-wrapped bug measured ~0.49 of the screen width for
      // the default "New match" title on a standard test surface;
      // spanning the real band width should land close to ~0.96 (full
      // width minus the band's own small horizontal padding).
      expect(canvasWidth, greaterThan(screenWidth * 0.7),
          reason: 'the diagonal\'s canvas ($canvasWidth) should span '
              'nearly the full band width ($screenWidth), not '
              'shrink-wrap to the title text');
    });

    Future<void> expectDiagonalFlushWithRightEdge(
        WidgetTester tester, Size surfaceSize) async {
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await tester.pumpAndSettle();

      final diagonalCustomPaint = find.byWidgetPredicate((widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_HeroDiagonalPainter');
      expect(diagonalCustomPaint, findsOneWidget);

      final screenWidth = tester.getSize(find.byType(MaterialApp)).width;
      final diagonalRight = tester.getTopRight(diagonalCustomPaint).dx;

      // The wedge's own canvas is `Positioned.fill` inside a `Stack` sized
      // to the band's full width (see the `SizedBox` in `_SetupHeroBand`),
      // so its right edge should land exactly on the true screen edge —
      // not short of it by a fixed/hardcoded offset (the regression this
      // test guards: a horizontal `Padding` around the whole band used to
      // shrink that width by its right inset, leaving a visible gap).
      expect(diagonalRight, closeTo(screenWidth, 0.5),
          reason: 'surface=$surfaceSize: the diagonal\'s right edge '
              '($diagonalRight) should be flush with the true screen edge '
              '($screenWidth), not offset by a fixed padding');
    }

    testWidgets(
        'reaches the true right edge of the screen at a narrow width '
        '(360x800)', (tester) async {
      await expectDiagonalFlushWithRightEdge(tester, const Size(360, 800));
    });

    testWidgets(
        'reaches the true right edge of the screen at a wider width '
        '(480x900), regardless of device width', (tester) async {
      await expectDiagonalFlushWithRightEdge(tester, const Size(480, 900));
    });
  });
}
