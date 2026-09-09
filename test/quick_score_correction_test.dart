import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/main.dart';

/// See `test/widget_test.dart`'s identically-named helper — duplicated
/// here rather than shared, matching this project's existing convention
/// of small, self-contained per-feature test files.
Future<void> _tossAndStart(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tossButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('startMatchButton')));
  await tester.pumpAndSettle();
}

String _pointsText(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  group('Quick score correction (Phase 4M)', () {
    testWidgets(
        'long-pressing the score digit opens the corrector, seeded with '
        "that player's current score", (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await _tossAndStart(tester);

      await tester.tap(find.byKey(const Key('player1Zone')));
      await tester.tap(find.byKey(const Key('player1Zone')));
      await tester.pump(); // player one: 2

      await tester
          .longPress(find.byKey(const Key('player1ScoreCorrectorTrigger')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scoreCorrectorDialog')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('scoreCorrectorValue'))).data,
        '2',
      );
    });

    testWidgets('setting a valid value updates the score correctly',
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await _tossAndStart(tester);

      await tester
          .longPress(find.byKey(const Key('player1ScoreCorrectorTrigger')));
      await tester.pumpAndSettle();

      // Starting from 0, step up to 7.
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byKey(const Key('scoreCorrectorIncrement')));
        await tester.pump();
      }
      expect(
        tester.widget<Text>(find.byKey(const Key('scoreCorrectorValue'))).data,
        '7',
      );

      await tester.tap(find.byKey(const Key('scoreCorrectorConfirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scoreCorrectorDialog')), findsNothing);
      expect(_pointsText(tester, const Key('player1PointsText')), '7');
      expect(_pointsText(tester, const Key('player2PointsText')), '0');
    });

    testWidgets('cancelling the corrector leaves the score unchanged',
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await _tossAndStart(tester);

      await tester.tap(find.byKey(const Key('player2Zone')));
      await tester.pump(); // player two: 1

      await tester
          .longPress(find.byKey(const Key('player2ScoreCorrectorTrigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scoreCorrectorIncrement')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('scoreCorrectorCancel')));
      await tester.pumpAndSettle();

      expect(_pointsText(tester, const Key('player2PointsText')), '1',
          reason: 'cancelling must discard the stepper change entirely');
    });

    testWidgets(
        'rejecting an invalid value: the stepper itself cannot go past '
        'the win-by-2 boundary or below zero', (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await _tossAndStart(tester);

      // Player two stays at 0, so player one's corrector must not be
      // steppable up to (or past) 11 — that would already be a won
      // game. maxCorrectablePoints(Player.one) with other==0 is 10.
      await tester
          .longPress(find.byKey(const Key('player1ScoreCorrectorTrigger')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 15; i++) {
        await tester.tap(find.byKey(const Key('scoreCorrectorIncrement')));
        await tester.pump();
      }
      expect(
        tester.widget<Text>(find.byKey(const Key('scoreCorrectorValue'))).data,
        '10',
        reason: 'must cap at the highest value that is not already a won '
            'game, never reach 11',
      );

      // The floor is equally enforced: can't go negative.
      for (var i = 0; i < 15; i++) {
        await tester.tap(find.byKey(const Key('scoreCorrectorDecrement')));
        await tester.pump();
      }
      expect(
        tester.widget<Text>(find.byKey(const Key('scoreCorrectorValue'))).data,
        '0',
      );

      await tester.tap(find.byKey(const Key('scoreCorrectorConfirm')));
      await tester.pumpAndSettle();
      expect(_pointsText(tester, const Key('player1PointsText')), '0');
    });

    testWidgets(
        'the server indicator recalculates correctly from the corrected '
        'total, not from whatever it was before the correction',
        (tester) async {
      await tester.pumpWidget(const TableTennisScoreboardApp());
      await _tossAndStart(tester);

      // The coin toss decides who serves first at random, so read it
      // off the board at 0-0 (where currentServer == the game's first
      // server) rather than assuming which side it is.
      final p1ServerFinder = find.byKey(const Key('player1ServerIcon'));
      final p2ServerFinder = find.byKey(const Key('player2ServerIcon'));
      final player1ServedFirst = p1ServerFinder.evaluate().isNotEmpty;

      // Correct player one straight to 3 — an odd total pre-deuce (block
      // size 2, block index 1) puts serve on the *opponent* of whoever
      // served first, regardless of who that was.
      await tester
          .longPress(find.byKey(const Key('player1ScoreCorrectorTrigger')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('scoreCorrectorIncrement')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('scoreCorrectorConfirm')));
      await tester.pumpAndSettle();

      final p1ServingAt3 = p1ServerFinder.evaluate().isNotEmpty;
      final p2ServingAt3 = p2ServerFinder.evaluate().isNotEmpty;
      expect(p1ServingAt3 ^ p2ServingAt3, isTrue,
          reason: 'exactly one side must show the server icon');
      expect(p1ServingAt3, !player1ServedFirst,
          reason: '3 total points in, before deuce, is the second '
              '2-point serve block — the opponent of whoever served '
              'first should now be serving');

      // A normal point still advances serve correctly afterward — the
      // correction left no stale serve-tracking state behind (there is
      // none to leave stale: currentServer is always derived fresh from
      // the current point totals, never separately tracked).
      await tester.tap(find.byKey(const Key('player1Zone')));
      await tester.pump(); // total=4, block index 2 (even) -> first server
      expect(p1ServerFinder.evaluate().isNotEmpty, player1ServedFirst);
    });
  });
}
