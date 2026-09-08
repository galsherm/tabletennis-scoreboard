import '../models/game_result.dart';

/// Builds a plain-text summary of one completed match — the minimal
/// "match-history export" scoped for Phase 5 (a single match's result,
/// not a saved history across matches). Copied to the clipboard by the
/// Pro-only "Export match result" button on `MatchCompleteDialog`. See
/// PHASE5_MONETIZATION.md.
///
/// Takes a [gameLine] callback rather than depending on
/// `AppLocalizations` directly, so this stays a plain, widget-free
/// function (unit-testable with no `BuildContext`), matching this
/// project's established pattern for pure decision/formatting logic
/// (e.g. `match_commentary.dart`).
String buildMatchExportSummary({
  required String appTitle,
  required String player1Label,
  required String player2Label,
  required List<GameResult> completedGames,
  required int bestOf,
  required String Function(int gameNumber, int p1Points, int p2Points)
      gameLine,
  required String winnerMessage,
}) {
  final buffer = StringBuffer()
    ..writeln(appTitle)
    ..writeln('$player1Label – $player2Label ($bestOf)')
    ..writeln();
  for (var i = 0; i < completedGames.length; i++) {
    final g = completedGames[i];
    buffer.writeln(gameLine(i + 1, g.player1Points, g.player2Points));
  }
  buffer
    ..writeln()
    ..writeln(winnerMessage);
  return buffer.toString();
}
