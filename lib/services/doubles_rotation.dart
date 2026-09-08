import '../models/doubles_seat.dart';
import '../models/player.dart';
import '../models/scoring_engine.dart';

/// One step of the fixed 4-step doubles rotation cycle: which side serves
/// (the game's first-serving side, or the other one) and which slot (0 or
/// 1) on each side is involved.
typedef _CycleStep = ({bool serverIsFirstTeam, int serverSlot, int receiverSlot});

/// The fixed rotation for one game (ITTF Law 2.13.6): if the first-serving
/// team's slot 0 and slot 1 are A and B, and the other team's slot 0 and
/// slot 1 are C and D, the sequence of (server, receiver) pairs is
/// A→C, C→B, B→D, D→A, then repeats. Each step holds for one "service
/// block" — 2 points before deuce, 1 point at deuce, exactly like
/// singles' existing server rotation.
///
/// Derived from (and only from) the rule "the previous receiver becomes
/// the new server, and the previous server's partner becomes the new
/// receiver": starting at A→C, the next server is C (previous receiver),
/// and the next receiver is A's partner, B — giving C→B; repeating gives
/// B→D, then D→A, then back to A→C. See PHASE4_VERIFICATION.md for the
/// full derivation and how it was checked against the standard ITTF
/// doubles sequence.
const List<_CycleStep> _rotationCycle = [
  (serverIsFirstTeam: true, serverSlot: 0, receiverSlot: 0), // A -> C
  (serverIsFirstTeam: false, serverSlot: 0, receiverSlot: 1), // C -> B
  (serverIsFirstTeam: true, serverSlot: 1, receiverSlot: 1), // B -> D
  (serverIsFirstTeam: false, serverSlot: 1, receiverSlot: 0), // D -> A
];

/// Who serves and who receives right now, for a doubles match using
/// [engine] for scoring (unchanged from singles — [engine] only knows
/// about two *sides*, not four individual players).
///
/// This assumes each side's serving order is fixed for the whole match —
/// that side's slot 0 serves first whenever that side serves first in a
/// game, and the opposing side's slot 0 receives first — rather than
/// letting players re-choose who serves/receives first at the start of
/// each game (which real ITTF rules allow but which this scoreboard app
/// doesn't prompt for). See PHASE4_VERIFICATION.md for why.
///
/// A pure function of [engine]'s current score and
/// [TableTennisScoringEngine.firstServerThisGame] — like
/// `announcementForPoint`, there's no extra rotation state to track
/// across points; the whole 4-cycle is recomputed from scratch every
/// time, so it's automatically correct across undo and game boundaries
/// too (both already reset/restore the score and first-server state that
/// this reads).
DoublesServingState currentDoublesServingState(TableTennisScoringEngine engine) {
  final deuce = engine.player1Points >= 10 && engine.player2Points >= 10;
  final blockSize = deuce ? 1 : 2;
  final totalPoints = engine.player1Points + engine.player2Points;
  final blockIndex = totalPoints ~/ blockSize;
  final cycleIndex = blockIndex % 4;

  final firstTeam = engine.firstServerThisGame;
  final secondTeam = firstTeam.opponent;

  final step = _rotationCycle[cycleIndex];
  final serverTeam = step.serverIsFirstTeam ? firstTeam : secondTeam;
  final receiverTeam = serverTeam.opponent;

  return DoublesServingState(
    server: DoublesSeat(serverTeam, step.serverSlot),
    receiver: DoublesSeat(receiverTeam, step.receiverSlot),
  );
}
