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

    test('server changes every single point once both reach 10 (deuce)',
        () {
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

    test('undo also restores the correct server across a game boundary',
        () {
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

  group('Configuration', () {
    test('rejects an invalid bestOf value', () {
      expect(
        () => TableTennisScoringEngine(bestOf: 4, firstServer: Player.one),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
