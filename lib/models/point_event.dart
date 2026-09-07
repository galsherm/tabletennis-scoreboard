import 'player.dart';

/// Describes what happened as a result of a single point being scored.
///
/// The UI listens to this to decide whether to show a "change ends"
/// prompt, a "game won" banner, or a "match won" dialog. Exactly one of
/// [gameCompleted] / [matchCompleted] / [changeEndsNow] paths should be
/// acted on per point — see [TableTennisScoringEngine.addPoint].
class PointEvent {
  /// True if this point ended the current game.
  final bool gameCompleted;

  /// True if this point ended the whole match.
  final bool matchCompleted;

  /// True if the players must switch ends of the table right now —
  /// either because a game just ended, or because this is the deciding
  /// game of the match and a player just reached 5 points
  /// (ITTF Law 2.14.2).
  final bool changeEndsNow;

  /// Set only when [gameCompleted] is true.
  final Player? gameWinner;

  /// Set only when [matchCompleted] is true.
  final Player? matchWinner;

  const PointEvent({
    this.gameCompleted = false,
    this.matchCompleted = false,
    this.changeEndsNow = false,
    this.gameWinner,
    this.matchWinner,
  });
}
