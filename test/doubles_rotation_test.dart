import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/models/doubles_seat.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/models/scoring_engine.dart';
import 'package:tabletennis_scoreboard/services/doubles_rotation.dart';

// Seat shorthand for readability in expectations below, matching the
// A/B/C/D convention used in doubles_rotation.dart's doc comment:
// A = firstTeam slot 0, B = firstTeam slot 1,
// C = otherTeam slot 0, D = otherTeam slot 1.
const _a = DoublesSeat(Player.one, 0);
const _b = DoublesSeat(Player.one, 1);
const _c = DoublesSeat(Player.two, 0);
const _d = DoublesSeat(Player.two, 1);

void main() {
  group('basic rotation (pre-deuce, every 2 points)', () {
    test('follows the fixed A->C, C->B, B->D, D->A sequence, 2 points per '
        'step', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);

      // Points 0 and 1 (block 0): A serves to C.
      var state = currentDoublesServingState(engine);
      expect(state.server, _a);
      expect(state.receiver, _c);

      engine.addPoint(Player.one); // total=1, still block 0
      state = currentDoublesServingState(engine);
      expect(state.server, _a);
      expect(state.receiver, _c);

      engine.addPoint(Player.two); // total=2, block 1 begins
      state = currentDoublesServingState(engine);
      expect(state.server, _c);
      expect(state.receiver, _b);

      engine.addPoint(Player.one); // total=3, still block 1
      state = currentDoublesServingState(engine);
      expect(state.server, _c);
      expect(state.receiver, _b);

      engine.addPoint(Player.two); // total=4, block 2 begins
      state = currentDoublesServingState(engine);
      expect(state.server, _b);
      expect(state.receiver, _d);

      engine.addPoint(Player.one); // total=5, still block 2
      state = currentDoublesServingState(engine);
      expect(state.server, _b);
      expect(state.receiver, _d);

      engine.addPoint(Player.two); // total=6, block 3 begins
      state = currentDoublesServingState(engine);
      expect(state.server, _d);
      expect(state.receiver, _a);

      engine.addPoint(Player.one); // total=7, still block 3
      state = currentDoublesServingState(engine);
      expect(state.server, _d);
      expect(state.receiver, _a);
    });

    test('the cycle repeats: block 4 (total 8-9) is identical to block 0',
        () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 8; i++) {
        engine.addPoint(i.isEven ? Player.one : Player.two);
      }
      expect(engine.player1Points + engine.player2Points, 8);

      final state = currentDoublesServingState(engine);
      expect(state.server, _a);
      expect(state.receiver, _c);
    });

    test('every player serves exactly once and receives exactly once per '
        'full 4-block cycle', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      final servers = <DoublesSeat>{};
      final receivers = <DoublesSeat>{};
      for (var block = 0; block < 4; block++) {
        final state = currentDoublesServingState(engine);
        servers.add(state.server);
        receivers.add(state.receiver);
        engine.addPoint(Player.one);
        engine.addPoint(Player.two);
      }
      expect(servers, {_a, _b, _c, _d});
      expect(receivers, {_a, _b, _c, _d});
    });
  });

  group('deuce rotation (every 1 point)', () {
    test('rotates every single point once both sides reach 10', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 10; i++) {
        engine.addPoint(Player.one);
        engine.addPoint(Player.two);
      }
      // 10-10, total=20, blockSize=1 (deuce), blockIndex=20,
      // cycleIndex=20%4=0 -> back to A serving C, same as block 0.
      var state = currentDoublesServingState(engine);
      expect(state.server, _a);
      expect(state.receiver, _c);

      engine.addPoint(Player.one); // 11-10, total=21, blockIndex=21, cycle 1
      state = currentDoublesServingState(engine);
      expect(state.server, _c);
      expect(state.receiver, _b);

      engine.addPoint(Player.two); // 11-11, total=22, blockIndex=22, cycle 2
      state = currentDoublesServingState(engine);
      expect(state.server, _b);
      expect(state.receiver, _d);

      engine.addPoint(Player.one); // 12-11, total=23, blockIndex=23, cycle 3
      state = currentDoublesServingState(engine);
      expect(state.server, _d);
      expect(state.receiver, _a);

      engine.addPoint(Player.two); // 12-12, total=24, blockIndex=24, cycle 0
      state = currentDoublesServingState(engine);
      expect(state.server, _a);
      expect(state.receiver, _c);
    });

    test('the transition into deuce lands on the correct cycle step '
        '(not reset to block 0 early)', () {
      // 9 points each (9-9, total=18) is still pre-deuce (blockSize=2 the
      // whole way there since neither side has reached 10 yet).
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 9; i++) {
        engine.addPoint(Player.one);
        engine.addPoint(Player.two);
      }
      // total=18, blockSize=2, blockIndex=9, cycleIndex=9%4=1 -> C serves B.
      final state = currentDoublesServingState(engine);
      expect(state.server, _c);
      expect(state.receiver, _b);
    });
  });

  group('rule verification: previous receiver becomes server, previous '
      "server's partner becomes receiver", () {
    test('holds across every transition in two full cycles', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      DoublesServingState? previous;
      for (var block = 0; block < 8; block++) {
        final current = currentDoublesServingState(engine);
        if (previous != null) {
          expect(current.server, previous.receiver,
              reason: 'block $block: new server should be the previous '
                  'receiver');
          final previousServerPartner =
              DoublesSeat(previous.server.team, 1 - previous.server.slot);
          expect(current.receiver, previousServerPartner,
              reason: 'block $block: new receiver should be the previous '
                  "server's partner");
        }
        previous = current;
        engine.addPoint(Player.one);
        engine.addPoint(Player.two);
      }
    });
  });

  group('across a game boundary', () {
    test('resets to the new game\'s first-serving side, slot 0 serving '
        'to the opponent\'s slot 0', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one); // wins game 1, 11-0
      }
      // Singles' existing rule (reused unchanged): the next game's first
      // server is the opponent of this game's first server.
      expect(engine.firstServerThisGame, Player.two);

      final state = currentDoublesServingState(engine);
      expect(state.server, _c); // Player.two's slot 0 (now firstTeam)
      expect(state.receiver, _a); // Player.one's slot 0 (now secondTeam)
    });

    test('the full 4-cycle repeats correctly in the second game with the '
        'sides swapped', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one); // wins game 1
      }
      // Game 2: Player.two serves first now.
      var state = currentDoublesServingState(engine);
      expect(state.server, const DoublesSeat(Player.two, 0));
      expect(state.receiver, const DoublesSeat(Player.one, 0));

      engine.addPoint(Player.two); // 1-0 in game 2, still block 0
      state = currentDoublesServingState(engine);
      expect(state.server, const DoublesSeat(Player.two, 0));
      expect(state.receiver, const DoublesSeat(Player.one, 0));

      engine.addPoint(Player.one); // 1-1, block 1
      state = currentDoublesServingState(engine);
      expect(state.server, const DoublesSeat(Player.one, 0));
      expect(state.receiver, const DoublesSeat(Player.two, 1));
    });
  });

  group('undo compatibility', () {
    test('recomputes correctly after undoing across a rotation boundary',
        () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.one); // total=1, block 0
      engine.addPoint(Player.two); // total=2, block 1
      var state = currentDoublesServingState(engine);
      expect(state.server, _c);
      expect(state.receiver, _b);

      engine.undo(); // back to total=1, block 0
      state = currentDoublesServingState(engine);
      expect(state.server, _a);
      expect(state.receiver, _c);
    });

    test('recomputes correctly after undoing across a game boundary', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one); // wins game 1
      }
      expect(currentDoublesServingState(engine).server, _c);

      engine.undo(); // back into game 1 at 10-0
      expect(engine.completedGames, isEmpty);
      final state = currentDoublesServingState(engine);
      // 10 points in, block 5, cycleIndex=5%4=1 -> C serves B.
      expect(state.server, _c);
      expect(state.receiver, _b);
    });
  });

  group('symmetry: starting with Player.two as the first-serving side',
      () {
    test('produces the mirrored sequence', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.two);

      var state = currentDoublesServingState(engine);
      expect(state.server, const DoublesSeat(Player.two, 0));
      expect(state.receiver, const DoublesSeat(Player.one, 0));

      engine.addPoint(Player.one);
      engine.addPoint(Player.two); // total=2, block 1
      state = currentDoublesServingState(engine);
      expect(state.server, const DoublesSeat(Player.one, 0));
      expect(state.receiver, const DoublesSeat(Player.two, 1));
    });
  });
}
