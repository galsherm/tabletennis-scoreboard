import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/main.dart';

/// Helper: taps the coin-toss button, then starts the match, on whatever
/// screen the app currently shows (assumes SetupScreen is on screen).
///
/// `pumpAndSettle` (not a single `pump`) after the toss tap: Phase 4C
/// added a brief coin-flip animation before the result is actually set,
/// so a single zero-duration `pump()` would catch the screen mid-flip,
/// before `_firstServer` (and therefore "Start match") is enabled.
Future<void> _tossAndStart(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tossButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('startMatchButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Start match button is disabled until the coin has been tossed',
      (tester) async {
    await tester.pumpWidget(const TableTennisScoreboardApp());

    final startButtonFinder = find.byKey(const Key('startMatchButton'));
    ElevatedButton startButton = tester.widget(startButtonFinder);
    expect(startButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('tossButton')));
    await tester.pumpAndSettle();

    startButton = tester.widget(startButtonFinder);
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('scoreboard opens with both players at 0', (tester) async {
    await tester.pumpWidget(const TableTennisScoreboardApp());
    await _tossAndStart(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('player1PointsText'))).data,
      '0',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('player2PointsText'))).data,
      '0',
    );
  });

  testWidgets("tapping a player's zone increases that player's score only",
      (tester) async {
    await tester.pumpWidget(const TableTennisScoreboardApp());
    await _tossAndStart(tester);

    await tester.tap(find.byKey(const Key('player1Zone')));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const Key('player1PointsText'))).data,
      '1',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('player2PointsText'))).data,
      '0',
    );
  });

  testWidgets('undo button reverts the last point and is disabled with no '
      'history', (tester) async {
    await tester.pumpWidget(const TableTennisScoreboardApp());
    await _tossAndStart(tester);

    final undoButtonFinder = find.byKey(const Key('undoButton'));
    IconButton undoButton = tester.widget(undoButtonFinder);
    expect(undoButton.onPressed, isNull); // nothing to undo yet

    await tester.tap(find.byKey(const Key('player1Zone')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('player1PointsText'))).data,
      '1',
    );

    undoButton = tester.widget(undoButtonFinder);
    expect(undoButton.onPressed, isNotNull);

    await tester.tap(undoButtonFinder);
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const Key('player1PointsText'))).data,
      '0',
    );
  });

  testWidgets(
      'winning a game shows a banner and resets the score for the next '
      'game', (tester) async {
    await tester.pumpWidget(const TableTennisScoreboardApp());
    await _tossAndStart(tester); // default best-of-5

    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byKey(const Key('player1Zone')));
      await tester.pump();
    }

    expect(find.byKey(const Key('gameCompleteSnackBar')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('player1PointsText'))).data,
      '0',
    );
    expect(find.text('Games: 1'), findsOneWidget);
  });

  testWidgets('winning the match (best of 3) shows the match-complete '
      'dialog', (tester) async {
    await tester.pumpWidget(const TableTennisScoreboardApp());

    await tester.tap(find.byKey(const Key('tossButton')));
    await tester.pumpAndSettle();
    // switch from the default best-of-5 to best-of-3 for a shorter test
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('startMatchButton')));
    await tester.pumpAndSettle();

    for (var game = 0; game < 2; game++) {
      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('player1Zone')));
        await tester.pump();
      }
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('matchCompleteDialog')), findsOneWidget);
    expect(find.text('Player 1 wins the match!'), findsOneWidget);
  });

  testWidgets(
      'the "New match" button on the match-complete dialog resets the '
      'board', (tester) async {
    await tester.pumpWidget(const TableTennisScoreboardApp());

    await tester.tap(find.byKey(const Key('tossButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('startMatchButton')));
    await tester.pumpAndSettle();

    for (var game = 0; game < 2; game++) {
      for (var i = 0; i < 11; i++) {
        await tester.tap(find.byKey(const Key('player1Zone')));
        await tester.pump();
      }
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('newMatchButton')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('player1PointsText'))).data,
      '0',
    );
    expect(find.text('Games: 0'), findsNWidgets(2));
  });

  testWidgets('the server indicator appears on exactly one side', (tester) async {
    await tester.pumpWidget(const TableTennisScoreboardApp());
    await _tossAndStart(tester);

    final p1Server = find.byKey(const Key('player1ServerIcon'));
    final p2Server = find.byKey(const Key('player2ServerIcon'));

    // Exactly one of the two server icons should be present.
    final p1Present = p1Server.evaluate().isNotEmpty;
    final p2Present = p2Server.evaluate().isNotEmpty;
    expect(p1Present ^ p2Present, isTrue);
  });
}
