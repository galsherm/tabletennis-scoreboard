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

  /// The side that served first in the current game. [currentServer]
  /// already answers "who serves next" for singles; doubles rotation
  /// (`lib/services/doubles_rotation.dart`) additionally needs this to
  /// know which specific individual on that side is serving.
  Player get firstServerThisGame => _firstServerThisGame;

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

  /// The highest value [player] could be manually corrected to right
  /// now (see [correctScore]) without that alone already being a
  /// game-winning score against the other player's current total.
  ///
  /// Below 11 there's no such ceiling from the other player's total
  /// alone — any value 0-10 is always a legal (unfinished) game state
  /// regardless of what the other side has. At or above 11, the
  /// win-by-2 rule (Law 2.11) caps it: [player] can be corrected up to
  /// (but not past) one more point than the other side, since anything
  /// past that would already be a won game — e.g. with the other side
  /// at 10, 11 is fine (11-10 isn't won yet) but 12 isn't (12-10 is).
  int maxCorrectablePoints(Player player) {
    final other = player == Player.one ? _p2 : _p1;
    return other < 10 ? 10 : other + 1;
  }

  /// Directly sets [player]'s current-game point total to [newValue] —
  /// a quick manual correction for an accidental or missed tap (see
  /// PHASE4M_QUICK_SCORE_CORRECTION.md), not a way to skip playing:
  /// this only ever changes the running point count, never anything
  /// else (games/serve/ends are all still derived exactly as before —
  /// see [currentServer]'s doc comment).
  ///
  /// Returns `false` (a no-op — the engine's state is left completely
  /// unchanged) if the match is already over, [newValue] is negative,
  /// or [newValue] exceeds [maxCorrectablePoints] and so would already
  /// be a won game. Returns `true` once the correction is applied.
  ///
  /// A successful correction clears the undo stack rather than trying
  /// to preserve/rewrite it against an edit that didn't go through
  /// [addPoint] — simpler, and a manual correction is itself the
  /// "undo" for whatever tap it's fixing.
  bool correctScore(Player player, int newValue) {
    if (!canScore) return false;
    if (newValue < 0) return false;
    if (newValue > maxCorrectablePoints(player)) return false;

    if (player == Player.one) {
      _p1 = newValue;
    } else {
      _p2 = newValue;
    }
    _undoStack.clear();
    return true;
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
