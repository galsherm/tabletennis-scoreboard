import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/models/point_event.dart';
import 'package:tabletennis_scoreboard/models/scoring_engine.dart';

void main() {
  group('Basic point scoring', () {
    test("a point increases the scorer's points by one", () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.one);
      expect(engine.player1Points, 1);
      expect(engine.player2Points, 0);
    });

    test('reaching 11 with a 2-point lead wins the game', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one);
      }
      expect(engine.completedGames.length, 1);
      expect(engine.completedGames.first.winner, Player.one);
      expect(engine.completedGames.first.player1Points, 11);
      expect(engine.completedGames.first.player2Points, 0);
      // score resets for the next game
      expect(engine.player1Points, 0);
      expect(engine.player2Points, 0);
    });

    test('11-10 does not win the game (must lead by 2)', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 10; i++) {
        engine.addPoint(Player.one);
        engine.addPoint(Player.two);
      }
      engine.addPoint(Player.one); // 11-10
      expect(engine.completedGames.length, 0);
      expect(engine.player1Points, 11);
      expect(engine.player2Points, 10);
    });

    test('a deuce game is only won with a 2-point lead beyond 11', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 10; i++) {
        engine.addPoint(Player.one);
        engine.addPoint(Player.two);
      }
      engine.addPoint(Player.one); // 11-10
      expect(engine.completedGames.length, 0);
      engine.addPoint(Player.two); // 11-11
      expect(engine.completedGames.length, 0);
      engine.addPoint(Player.one); // 12-11
      expect(engine.completedGames.length, 0);
      engine.addPoint(Player.one); // 13-11
      expect(engine.completedGames.length, 1);
      expect(engine.completedGames.first.winner, Player.one);
      expect(engine.completedGames.first.player1Points, 13);
      expect(engine.completedGames.first.player2Points, 11);
    });
  });

  group('Serve rotation (ITTF Law 2.13.3)', () {
    test('server changes every 2 points before deuce', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      expect(engine.currentServer, Player.one); // 0-0, total=0
      engine.addPoint(Player.one); // 1-0, total=1
      expect(engine.currentServer, Player.one);
      engine.addPoint(Player.two); // 1-1, total=2
      expect(engine.currentServer, Player.two);
      engine.addPoint(Player.two); // 1-2, total=3
      expect(engine.currentServer, Player.two);
      engine.addPoint(Player.two); // 1-3, total=4
      expect(engine.currentServer, Player.one);
    });

    test('server changes every single point once both reach 10 (deuce)', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 10; i++) {
        engine.addPoint(Player.one);
        engine.addPoint(Player.two);
      }
      // 10-10, total=20 -> blockSize=1, blockIndex=20 (even) -> first server
      expect(engine.currentServer, Player.one);
      engine.addPoint(Player.one); // 11-10, total=21 (odd) -> opponent
      expect(engine.currentServer, Player.two);
      engine.addPoint(Player.two); // 11-11, total=22 (even) -> first server
      expect(engine.currentServer, Player.one);
    });

    test(
        "the next game's first server is this game's first receiver "
        '(Law 2.13.3)', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      expect(engine.currentServer, Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one); // player one wins game 1, 11-0
      }
      // Player two received first in game 1, so serves first in game 2.
      expect(engine.currentServer, Player.two);
    });
  });

  group('Change of ends (ITTF Law 2.14)', () {
    test('changeEndsNow is true on the point that completes a game', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      PointEvent? lastEvent;
      for (var i = 0; i < 11; i++) {
        lastEvent = engine.addPoint(Player.one);
      }
      expect(lastEvent!.gameCompleted, isTrue);
      expect(lastEvent.changeEndsNow, isTrue);
    });

    test('changeEndsNow is false on an ordinary point in a non-deciding game',
        () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      final event = engine.addPoint(Player.one); // game 1 of 5 (not deciding)
      expect(event.changeEndsNow, isFalse);
    });

    test(
        'changeEndsNow fires exactly once, when a player reaches 5 '
        'in the deciding game', () {
      // best of 3: after 1-1 in games, game 3 is the deciding game.
      final engine =
          TableTennisScoringEngine(bestOf: 3, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one); // player one wins game 1, 11-0
      }
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.two); // player two wins game 2, 11-0
      }
      expect(engine.isDecidingGame, isTrue);

      PointEvent? event;
      for (var i = 0; i < 4; i++) {
        event = engine.addPoint(Player.one); // 1-0 ... 4-0
        expect(event.changeEndsNow, isFalse);
      }

      event = engine.addPoint(Player.one); // 5-0 -> fires once
      expect(event.changeEndsNow, isTrue);
      expect(event.gameCompleted, isFalse);

      event = engine.addPoint(Player.two); // 5-1 -> must not re-fire
      expect(event.changeEndsNow, isFalse);
    });

    test('mid-game changeEndsNow does not fire in a non-deciding game', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      PointEvent? event;
      for (var i = 0; i < 5; i++) {
        event = engine.addPoint(Player.one); // 1-0 ... 5-0, game 1 of 5
      }
      expect(engine.isDecidingGame, isFalse);
      expect(event!.changeEndsNow, isFalse);
    });
  });

  group('Match completion', () {
    test('best of 3 ends after either player wins 2 games', () {
      final engine =
          TableTennisScoringEngine(bestOf: 3, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one);
      }
      expect(engine.isMatchOver, isFalse);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one);
      }
      expect(engine.isMatchOver, isTrue);
      expect(engine.matchWinner, Player.one);
    });

    test('best of 7 requires 4 games to win', () {
      final engine =
          TableTennisScoringEngine(bestOf: 7, firstServer: Player.one);
      for (var game = 0; game < 3; game++) {
        for (var i = 0; i < 11; i++) {
          engine.addPoint(Player.one);
        }
      }
      expect(engine.isMatchOver, isFalse); // 3 games won, needs 4
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one);
      }
      expect(engine.isMatchOver, isTrue);
      expect(engine.player1Games, 4);
    });

    test('no further points can be scored after the match ends', () {
      final engine =
          TableTennisScoringEngine(bestOf: 3, firstServer: Player.one);
      for (var i = 0; i < 22; i++) {
        engine.addPoint(Player.one); // wins games 1 and 2, match over
      }
      expect(engine.isMatchOver, isTrue);
      expect(engine.canScore, isFalse);

      final pointsBefore = engine.player1Points;
      final event = engine.addPoint(Player.one);

      expect(engine.player1Points, pointsBefore); // unchanged
      expect(event.gameCompleted, isFalse);
      expect(event.matchCompleted, isFalse);
    });
  });

  group('Undo', () {
    test('undo reverts the last point scored', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.one);
      engine.addPoint(Player.one);
      expect(engine.player1Points, 2);
      engine.undo();
      expect(engine.player1Points, 1);
    });

    test('undo across a game boundary restores the previous game state', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one);
      }
      expect(engine.completedGames.length, 1);
      engine.undo();
      expect(engine.completedGames.length, 0);
      expect(engine.player1Points, 10);
      expect(engine.player2Points, 0);
    });

    test('undo restores the server correctly after an ordinary point', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.one); // total=1: still within P1's first block
      expect(engine.currentServer, Player.one);
      engine.addPoint(Player.one); // total=2: service now switches to P2
      expect(engine.currentServer, Player.two);

      engine.undo(); // back to total=1
      expect(engine.currentServer, Player.one);
    });

    test('undo also restores the correct server across a game boundary', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one);
      }
      // after game 1, player two serves first in game 2
      expect(engine.currentServer, Player.two);
      engine.undo(); // back into game 1 at 10-0
      // Service rotates every 2 points regardless of who is scoring
      // (ITTF Law 2.13.3) — with P1 as first server, the blocks are
      // [P1,P1][P2,P2][P1,P1][P2,P2][P1,P1] for points 1–10, so the
      // server about to serve the (undone) 11th point is P2, not P1.
      expect(engine.currentServer, Player.two);
      expect(engine.completedGames, isEmpty);
      expect(engine.player1Points, 10);
    });

    test('undo with no history is a safe no-op', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      expect(engine.canUndo, isFalse);
      expect(() => engine.undo(), returnsNormally);
      expect(engine.player1Points, 0);
    });

    test('canUndo is false immediately after resetMatch', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.one);
      engine.resetMatch();
      expect(engine.canUndo, isFalse);
      expect(engine.player1Points, 0);
      expect(engine.completedGames, isEmpty);
    });
  });

  group('Manual score correction (Phase 4M)', () {
    test('sets a valid value correctly', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.one); // 1-0, so there's something to correct
      final applied = engine.correctScore(Player.one, 7);
      expect(applied, isTrue);
      expect(engine.player1Points, 7);
      expect(engine.player2Points, 0);
    });

    test('rejects a negative value — engine state is left unchanged', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.one); // 1-0
      final applied = engine.correctScore(Player.one, -1);
      expect(applied, isFalse);
      expect(engine.player1Points, 1, reason: 'unchanged, not clamped to 0');
    });

    test(
        'rejects a value that would already be a won game against the '
        "other player's current total", () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      // Player two sits at 0; setting player one to 11 would already be
      // an 11-0 won game, which must go through addPoint's own win
      // detection (and the game/reset/next-server flow that comes with
      // it), never be conjured directly by a "correction."
      final applied = engine.correctScore(Player.one, 11);
      expect(applied, isFalse);
      expect(engine.player1Points, 0);
      expect(engine.completedGames, isEmpty);
    });

    test(
        'in deuce territory, the win-by-2 boundary is exactly where '
        'maxCorrectablePoints says it is', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 10; i++) {
        engine.addPoint(Player.one);
        engine.addPoint(Player.two);
      }
      // 10-10. Player one can be corrected up to 11 (11-10 isn't won
      // yet) but not 12 (12-10 would already be won).
      expect(engine.maxCorrectablePoints(Player.one), 11);
      expect(engine.correctScore(Player.one, 12), isFalse);
      expect(engine.correctScore(Player.one, 11), isTrue);
      expect(engine.player1Points, 11);
      expect(engine.completedGames, isEmpty, reason: '11-10 is not a won game');
    });

    test(
        'below 11, any value up to 10 is always correctable regardless '
        "of the other player's score", () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.two); // player two: 1
      expect(engine.maxCorrectablePoints(Player.one), 10);
      expect(engine.correctScore(Player.one, 10), isTrue);
      expect(engine.player1Points, 10);
      expect(engine.completedGames, isEmpty);
    });

    test(
        'a no-op once the match is over — the lock-during-play gate '
        'addPoint already uses', () {
      final engine =
          TableTennisScoringEngine(bestOf: 3, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one); // wins game 1
      }
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one); // wins game 2 -> wins the match
      }
      expect(engine.isMatchOver, isTrue);
      final applied = engine.correctScore(Player.one, 3);
      expect(applied, isFalse);
      expect(engine.player1Points, 0,
          reason: 'reset after the match-ending game');
    });

    test(
        'currentServer recalculates correctly from the corrected total — '
        'it is derived, not separately tracked state', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      // Correct player one straight to 3 (total points = 3, an odd
      // block boundary pre-deuce: blockIndex = 3~/2 = 1, odd -> the
      // opponent of whoever served first is serving).
      engine.correctScore(Player.one, 3);
      expect(engine.currentServer, Player.two);

      // Now correct into deuce territory directly and confirm the
      // single-point-per-serve-change rule is honored immediately,
      // with no leftover state from before the correction.
      engine.correctScore(Player.two, 10); // 3-10 -> correct player one too
      engine.correctScore(Player.one, 10); // 10-10, total=20, block=1
      expect(engine.currentServer, Player.one);
    });

    test(
        'a correction to exactly 5 in the deciding game does not retrigger '
        'changeEndsNow a second time on the next ordinary point', () {
      final engine =
          TableTennisScoringEngine(bestOf: 3, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one);
      }
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.two);
      }
      expect(engine.isDecidingGame, isTrue);

      // Jump straight to 5 via a correction rather than playing through
      // it — the mid-game change-of-ends prompt is tied to addPoint's
      // own before/after comparison, so a direct correction doesn't
      // (and isn't expected to) raise it itself; what matters is that
      // it doesn't get "confused" and mis-fire afterward either.
      expect(engine.correctScore(Player.one, 5), isTrue);
      final next = engine.addPoint(Player.one); // 6-0
      expect(next.changeEndsNow, isFalse);
    });

    test(
        'a correction clears the undo stack rather than trying to '
        'preserve it', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.one);
      engine.addPoint(Player.two);
      expect(engine.canUndo, isTrue);

      engine.correctScore(Player.one, 4);
      expect(engine.canUndo, isFalse);
    });
  });

  group('Configuration', () {
    test('rejects an invalid bestOf value', () {
      expect(
        () => TableTennisScoringEngine(bestOf: 4, firstServer: Player.one),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
