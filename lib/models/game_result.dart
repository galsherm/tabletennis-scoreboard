import 'player.dart';

/// The final score of one completed game within a match.
class GameResult {
  final int player1Points;
  final int player2Points;
  final Player winner;

  const GameResult({
    required this.player1Points,
    required this.player2Points,
    required this.winner,
  });

  @override
  String toString() => '$player1Points-$player2Points (winner: $winner)';
}
