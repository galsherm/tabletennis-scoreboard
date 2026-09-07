import '../models/player.dart';
import '../models/point_event.dart';
import '../models/scoring_engine.dart';

/// What the voice layer should say for a single point.
///
/// Deciding *what* to announce is pure domain logic — it only reads
/// [TableTennisScoringEngine] state, so it's unit-testable without any
/// TTS or audio mocking. [VoiceAnnouncer] is the layer that turns this
/// into actual sound.
class Announcement {
  /// Sentence for live device TTS, e.g. `"5, 3"`, `"Deuce"`,
  /// `"Game, Player 1. Change ends."`.
  final String speech;

  /// Bundled clip keys to play in order as a fallback for [speech], e.g.
  /// `['number_5', 'number_3']`. A key not present in
  /// [VoiceAnnouncer.bundledClipKeys] (a score above the bundled 0–21
  /// range, or an event with no matching clip) is simply skipped by the
  /// player rather than announced — see PHASES.md Phase 2 on graceful
  /// fallback.
  final List<String> clipKeys;

  const Announcement(this.speech, this.clipKeys);
}

String _playerLabel(Player p) => p == Player.one ? 'Player 1' : 'Player 2';

String numberClipKey(int n) => 'number_$n';

/// Whether [player] would win the match by winning the very next point,
/// i.e. they already hold enough games that this game is match-deciding
/// for them, and they are one point from winning it.
bool _isMatchPointFor(TableTennisScoringEngine engine, Player player) {
  final points =
      player == Player.one ? engine.player1Points : engine.player2Points;
  final oppPoints =
      player == Player.one ? engine.player2Points : engine.player1Points;
  final games =
      player == Player.one ? engine.player1Games : engine.player2Games;
  if (games != engine.gamesToWin - 1) return false;
  final nextScore = points + 1;
  return nextScore >= 11 && (nextScore - oppPoints) >= 2;
}

/// Decides what to announce for the point just scored, where [server] is
/// whoever served that point (read *before* [TableTennisScoringEngine.
/// addPoint] was called) and [event] is what that call returned. Reads
/// [engine] state *after* the point has been applied.
Announcement announcementForPoint({
  required TableTennisScoringEngine engine,
  required PointEvent event,
  required Player server,
}) {
  if (event.matchCompleted) {
    final winner = _playerLabel(event.matchWinner!);
    return Announcement('Match. $winner wins the match.', const []);
  }

  if (event.gameCompleted) {
    final winner = _playerLabel(event.gameWinner!);
    return Announcement(
      'Game, $winner. Change ends.',
      const ['game', 'change_ends'],
    );
  }

  final serverPoints =
      server == Player.one ? engine.player1Points : engine.player2Points;
  final receiverPoints =
      server == Player.one ? engine.player2Points : engine.player1Points;

  final isDeuce = serverPoints >= 10 && serverPoints == receiverPoints;

  final Announcement score = isDeuce
      ? const Announcement('Deuce', ['deuce'])
      : Announcement(
          '$serverPoints, $receiverPoints',
          [numberClipKey(serverPoints), numberClipKey(receiverPoints)],
        );

  if (event.changeEndsNow) {
    return Announcement(
      '${score.speech}. Change ends.',
      [...score.clipKeys, 'change_ends'],
    );
  }

  Player? matchPointPlayer;
  for (final p in Player.values) {
    if (_isMatchPointFor(engine, p)) {
      matchPointPlayer = p;
      break;
    }
  }

  if (matchPointPlayer != null) {
    return Announcement(
      '${score.speech}. Match point.',
      [...score.clipKeys, 'match_point'],
    );
  }

  return score;
}
