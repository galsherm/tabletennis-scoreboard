import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/models/game_result.dart';
import 'package:tabletennis_scoreboard/models/player.dart';
import 'package:tabletennis_scoreboard/services/match_export.dart';

void main() {
  group('buildMatchExportSummary (Phase 5 — minimal match export)', () {
    String gameLine(int number, int p1, int p2) => 'Game $number: $p1-$p2';

    test('includes the app title, player labels, best-of, every completed '
        'game (in order, with real per-game scores), and the winner '
        'message', () {
      final summary = buildMatchExportSummary(
        appTitle: 'Table Tennis Scoreboard',
        player1Label: 'Player 1',
        player2Label: 'Player 2',
        completedGames: const [
          GameResult(player1Points: 11, player2Points: 7, winner: Player.one),
          GameResult(player1Points: 9, player2Points: 11, winner: Player.two),
          GameResult(player1Points: 11, player2Points: 5, winner: Player.one),
        ],
        bestOf: 5,
        gameLine: gameLine,
        winnerMessage: 'Player 1 wins the match!',
      );

      expect(summary, contains('Table Tennis Scoreboard'));
      expect(summary, contains('Player 1 – Player 2 (5)'));
      expect(summary, contains('Game 1: 11-7'));
      expect(summary, contains('Game 2: 9-11'));
      expect(summary, contains('Game 3: 11-5'));
      expect(summary, contains('Player 1 wins the match!'));

      // The three game lines must be genuinely distinct (each game's own
      // score), not the same line repeated — a real bug caught and fixed
      // before this test was ever written (an earlier draft looped over
      // completedGames printing one pre-formatted string for every game).
      final lines = summary.split('\n');
      final gameLines = lines.where((l) => l.startsWith('Game ')).toList();
      expect(gameLines.toSet().length, 3);
    });

    test('produces no game lines for a match with no completed games', () {
      final summary = buildMatchExportSummary(
        appTitle: 'Table Tennis Scoreboard',
        player1Label: 'Player 1',
        player2Label: 'Player 2',
        completedGames: const [],
        bestOf: 3,
        gameLine: gameLine,
        winnerMessage: 'Player 1 wins the match!',
      );
      expect(summary, isNot(contains('Game 1')));
      expect(summary, contains('Player 1 wins the match!'));
    });

    test('uses team labels as-is when called for a doubles match', () {
      final summary = buildMatchExportSummary(
        appTitle: 'Table Tennis Scoreboard',
        player1Label: 'Team 1',
        player2Label: 'Team 2',
        completedGames: const [
          GameResult(player1Points: 11, player2Points: 3, winner: Player.one),
        ],
        bestOf: 3,
        gameLine: gameLine,
        winnerMessage: 'Team 1 wins the match!',
      );
      expect(summary, contains('Team 1 – Team 2 (3)'));
      expect(summary, contains('Team 1 wins the match!'));
    });
  });
}
