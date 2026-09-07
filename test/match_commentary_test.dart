import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/models/scoring_engine.dart';
import 'package:tabletennis_scoreboard/services/match_commentary.dart';

void main() {
  group('ordinary points', () {
    test('announces the score as "server, receiver"', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      final server = engine.currentServer; // Player.one, 0-0
      final event = engine.addPoint(Player.one); // 1-0
      final announcement =
          announcementForPoint(engine: engine, event: event, server: server);

      expect(announcement.speech, '1, 0');
      expect(announcement.clipKeys, ['number_1', 'number_0']);
    });

    test('orders the numbers by server first, not by who just scored', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.one); // 1-0, server still Player.one
      final server = engine.currentServer;
      final event = engine.addPoint(Player.two); // 1-1
      final announcement =
          announcementForPoint(engine: engine, event: event, server: server);

      final expectedServer =
          server == Player.one ? engine.player1Points : engine.player2Points;
      final expectedReceiver =
          server == Player.one ? engine.player2Points : engine.player1Points;
      expect(announcement.speech, '$expectedServer, $expectedReceiver');
    });
  });

  group('deuce', () {
    test('says "Deuce" instead of numbers once tied at 10 or more', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 9; i++) {
        engine.addPoint(Player.one);
        engine.addPoint(Player.two);
      }
      engine.addPoint(Player.one); // 10-9
      final server = engine.currentServer;
      final event = engine.addPoint(Player.two); // 10-10
      final announcement =
          announcementForPoint(engine: engine, event: event, server: server);

      expect(announcement.speech, 'Deuce');
      expect(announcement.clipKeys, ['deuce']);
    });

    test('does not say "Deuce" for a tie below 10', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      engine.addPoint(Player.one); // 1-0
      final server = engine.currentServer;
      final event = engine.addPoint(Player.two); // 1-1, tied but < 10
      final announcement =
          announcementForPoint(engine: engine, event: event, server: server);

      expect(announcement.speech, isNot('Deuce'));
    });
  });

  group('game completed', () {
    test('announces the winner and that ends must change', () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 10; i++) {
        engine.addPoint(Player.one);
      }
      final server = engine.currentServer;
      final event = engine.addPoint(Player.one); // 11-0, wins game 1
      final announcement =
          announcementForPoint(engine: engine, event: event, server: server);

      expect(announcement.speech, 'Game, Player 1. Change ends.');
      expect(announcement.clipKeys, ['game', 'change_ends']);
    });
  });

  group('match completed', () {
    test('announces the match winner without a change-ends phrase', () {
      final engine =
          TableTennisScoringEngine(bestOf: 3, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one); // wins game 1
      }
      for (var i = 0; i < 10; i++) {
        engine.addPoint(Player.one); // 10-0 in game 2
      }
      final server = engine.currentServer;
      final event = engine.addPoint(Player.one); // 11-0, wins game 2 + match
      final announcement =
          announcementForPoint(engine: engine, event: event, server: server);

      expect(announcement.speech, 'Match. Player 1 wins the match.');
      expect(announcement.clipKeys, isEmpty);
    });
  });

  group('mid-game change of ends (deciding game, ITTF Law 2.14.2)', () {
    test('is appended to the ordinary score announcement', () {
      final engine =
          TableTennisScoringEngine(bestOf: 3, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one); // wins game 1
      }
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.two); // wins game 2 -> game 3 is deciding
      }
      for (var i = 0; i < 4; i++) {
        engine.addPoint(Player.one); // 4-0 in the deciding game
      }
      final server = engine.currentServer;
      final event = engine.addPoint(Player.one); // 5-0 -> mid-game change

      final announcement =
          announcementForPoint(engine: engine, event: event, server: server);
      final expectedServer =
          server == Player.one ? engine.player1Points : engine.player2Points;
      final expectedReceiver =
          server == Player.one ? engine.player2Points : engine.player1Points;

      expect(
        announcement.speech,
        '$expectedServer, $expectedReceiver. Change ends.',
      );
      expect(announcement.clipKeys, [
        numberClipKey(expectedServer),
        numberClipKey(expectedReceiver),
        'change_ends',
      ]);
    });
  });

  group('match point', () {
    test('is appended when the next point could win the match', () {
      final engine =
          TableTennisScoringEngine(bestOf: 3, firstServer: Player.one);
      for (var i = 0; i < 11; i++) {
        engine.addPoint(Player.one); // wins game 1 -> 1 game banked
      }
      for (var i = 0; i < 9; i++) {
        engine.addPoint(Player.one); // 9-0 in game 2
      }
      final server = engine.currentServer;
      final event = engine.addPoint(Player.one); // 10-0: one point from match

      final announcement =
          announcementForPoint(engine: engine, event: event, server: server);
      final expectedServer =
          server == Player.one ? engine.player1Points : engine.player2Points;
      final expectedReceiver =
          server == Player.one ? engine.player2Points : engine.player1Points;

      expect(
        announcement.speech,
        '$expectedServer, $expectedReceiver. Match point.',
      );
      expect(announcement.clipKeys, [
        numberClipKey(expectedServer),
        numberClipKey(expectedReceiver),
        'match_point',
      ]);
    });

    test('is not appended when winning the game would not win the match',
        () {
      final engine =
          TableTennisScoringEngine(bestOf: 5, firstServer: Player.one);
      for (var i = 0; i < 9; i++) {
        engine.addPoint(Player.one);
      }
      final server = engine.currentServer;
      // 10-0 in game 1 of a best-of-5 with no games banked yet.
      final event = engine.addPoint(Player.one);
      final announcement =
          announcementForPoint(engine: engine, event: event, server: server);

      expect(announcement.speech, isNot(contains('Match point')));
    });
  });
}
