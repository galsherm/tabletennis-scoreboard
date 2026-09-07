import 'game_result.dart';
import 'player.dart';
import 'point_event.dart';

/// A private, immutable snapshot of engine state, used to implement undo.
class _Snapshot {
  final int p1;
  final int p2;
  final Player firstServerThisGame;
  final List<GameResult> completedGames;

  const _Snapshot({
    required this.p1,
    required this.p2,
    required this.firstServerThisGame,
    required this.completedGames,
  });
}

/// Core singles scoring engine for a table tennis match, following the
/// ITTF Laws of Table Tennis relevant to a courtside scoreboard:
///
///  - A game is won by the first player to reach 11 points with at least
///    a 2-point lead (Law 2.11).
///  - Service changes every 2 points; once both players reach 10 points
///    ("deuce"), service changes every 1 point (Law 2.13.3).
///  - Players change ends after every game, and additionally in the
///    deciding game of the match, as soon as either player reaches
///    5 points (Law 2.14).
///  - The player who served first in this game receives first in the
///    next game (Law 2.13.3) — so the next game's first server is the
///    opponent of this game's first server.
///
/// Deliberately NOT implemented in this phase (see MVP doc §5):
/// the expedite system, toweling-down breaks, doubles rotation,
/// time-outs. Those are later phases.
class TableTennisScoringEngine {
  /// Number of games in the match: must be 3, 5, or 7 (best-of-N).
  final int bestOf;

  final List<GameResult> _completedGames = [];
  int _p1 = 0;
  int _p2 = 0;
  Player _firstServerThisGame;
  final List<_Snapshot> _undoStack = [];

  TableTennisScoringEngine({
    required this.bestOf,
    required Player firstServer,
  })  : assert(
          bestOf == 3 || bestOf == 5 || bestOf == 7,
          'bestOf must be 3, 5, or 7',
        ),
        _firstServerThisGame = firstServer;

  // ---------------------------------------------------------------------
  // Read-only state
  // ---------------------------------------------------------------------

  /// Completed games so far this match, in order.
  List<GameResult> get completedGames => List.unmodifiable(_completedGames);

  int get player1Points => _p1;
  int get player2Points => _p2;

  /// Number of games a player must win to win the match.
  int get gamesToWin => (bestOf ~/ 2) + 1;

  int get player1Games =>
      _completedGames.where((g) => g.winner == Player.one).length;

  int get player2Games =>
      _completedGames.where((g) => g.winner == Player.two).length;

  bool get isMatchOver =>
      player1Games >= gamesToWin || player2Games >= gamesToWin;

  /// Null until the match is over.
  Player? get matchWinner {
    if (!isMatchOver) return null;
    return player1Games >= gamesToWin ? Player.one : Player.two;
  }

  /// True if the *next* (or current, in-progress) game is the last one
  /// the match can possibly go to — e.g. game 5 of a best-of-5, or
  /// game 7 of a best-of-7. This is when the mid-game change-of-ends
  /// rule (Law 2.14.2) applies.
  bool get isDecidingGame =>
      !isMatchOver && _completedGames.length == bestOf - 1;

  /// Whether the match can still accept points.
  bool get canScore => !isMatchOver;

  /// The player who serves the current point, derived deterministically
  /// from the total points played in the current game and who served
  /// first in this game.
  Player get currentServer {
    final deuce = _p1 >= 10 && _p2 >= 10;
    final blockSize = deuce ? 1 : 2;
    final totalPoints = _p1 + _p2;
    final blockIndex = totalPoints ~/ blockSize;
    final firstServerIsServing = blockIndex.isEven;
    return firstServerIsServing
        ? _firstServerThisGame
        : _firstServerThisGame.opponent;
  }

  bool get canUndo => _undoStack.isNotEmpty;

  // ---------------------------------------------------------------------
  // Mutating operations
  // ---------------------------------------------------------------------

  bool _isGameWon(int a, int b) => a >= 11 && (a - b) >= 2;

  /// Records a point for [scorer]. Returns a [PointEvent] describing
  /// anything the UI needs to react to (change ends, game won, match
  /// won). If the match is already over, this is a no-op and returns
  /// an empty [PointEvent].
  PointEvent addPoint(Player scorer) {
    if (!canScore) {
      return const PointEvent();
    }

    _pushSnapshot();

    final wasP1AtFive = _p1 == 5;
    final wasP2AtFive = _p2 == 5;

    if (scorer == Player.one) {
      _p1++;
    } else {
      _p2++;
    }

    // Mid-game change of ends: only relevant in the deciding game, and
    // must fire exactly once — the point at which a player's score
    // *becomes* 5 while the other is still below 5.
    bool midGameChangeEnds = false;
    if (isDecidingGame) {
      final nowP1AtFive = _p1 == 5 && _p2 < 5;
      final nowP2AtFive = _p2 == 5 && _p1 < 5;
      if ((nowP1AtFive && !wasP1AtFive) || (nowP2AtFive && !wasP2AtFive)) {
        midGameChangeEnds = true;
      }
    }

    if (_isGameWon(_p1, _p2) || _isGameWon(_p2, _p1)) {
      final gameWinner = _p1 > _p2 ? Player.one : Player.two;
      _completedGames.add(GameResult(
        player1Points: _p1,
        player2Points: _p2,
        winner: gameWinner,
      ));

      final matchIsNowOver = isMatchOver;

      // Reset the running score for the next game. The player who
      // received first in the game just finished serves first next.
      _p1 = 0;
      _p2 = 0;
      _firstServerThisGame = _firstServerThisGame.opponent;

      return PointEvent(
        gameCompleted: true,
        matchCompleted: matchIsNowOver,
        changeEndsNow: true, // players always change ends after a game
        gameWinner: gameWinner,
        matchWinner: matchIsNowOver ? gameWinner : null,
      );
    }

    return PointEvent(changeEndsNow: midGameChangeEnds);
  }

  /// Reverts the most recent [addPoint] call. Safe to call with no
  /// history — it's then a no-op.
  void undo() {
    if (_undoStack.isEmpty) return;
    final snap = _undoStack.removeLast();
    _p1 = snap.p1;
    _p2 = snap.p2;
    _firstServerThisGame = snap.firstServerThisGame;
    _completedGames
      ..clear()
      ..addAll(snap.completedGames);
  }

  /// Starts a brand new match, optionally with a new first server.
  /// Clears all history — this cannot be undone.
  void resetMatch({Player? newFirstServer}) {
    _p1 = 0;
    _p2 = 0;
    _completedGames.clear();
    _undoStack.clear();
    if (newFirstServer != null) {
      _firstServerThisGame = newFirstServer;
    }
  }

  void _pushSnapshot() {
    _undoStack.add(_Snapshot(
      p1: _p1,
      p2: _p2,
      firstServerThisGame: _firstServerThisGame,
      completedGames: List<GameResult>.from(_completedGames),
    ));
  }
}
