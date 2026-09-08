import 'player.dart';

/// One of the four individual players in a doubles match: a specific
/// [slot] (0 or 1) on a specific [team]. [team] matches the underlying
/// [TableTennisScoringEngine]'s side identity (`Player.one`/`Player.two`
/// score exactly as they do in singles — doubles adds player identity on
/// top, it doesn't change how points/games/the match are scored).
class DoublesSeat {
  final Player team;

  /// 0 or 1 — which of the team's two partners this is.
  final int slot;

  const DoublesSeat(this.team, this.slot)
      : assert(slot == 0 || slot == 1, 'slot must be 0 or 1');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DoublesSeat && other.team == team && other.slot == slot);

  @override
  int get hashCode => Object.hash(team, slot);

  @override
  String toString() => 'DoublesSeat($team, slot $slot)';
}

/// Who serves and who receives right now, in a doubles match — exactly
/// two of the four players (see `lib/services/doubles_rotation.dart` for
/// how this is computed).
class DoublesServingState {
  final DoublesSeat server;
  final DoublesSeat receiver;

  const DoublesServingState({required this.server, required this.receiver});
}
