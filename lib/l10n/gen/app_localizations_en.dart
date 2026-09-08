// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Table Tennis Scoreboard';

  @override
  String get newMatchScreenTitle => 'New match';

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get languageSystemOption => 'System default';

  @override
  String get bestOfLabel => 'Best of';

  @override
  String bestOfSegmentLabel(int bestOf, int gamesToWin) {
    return '$bestOf';
  }

  @override
  String get tossPrompt => 'Toss to decide who serves first';

  @override
  String firstServerLabel(String player) {
    return 'First server: $player';
  }

  @override
  String get tossButton => 'Toss coin';

  @override
  String get startMatchButton => 'Start match';

  @override
  String get scoreboardTitle => 'Table Tennis';

  @override
  String get muteTooltip => 'Mute voice';

  @override
  String get unmuteTooltip => 'Unmute voice';

  @override
  String get undoTooltip => 'Undo';

  @override
  String get resetTooltip => 'Reset match';

  @override
  String get servingTooltip => 'Serving';

  @override
  String get player1Label => 'Player 1';

  @override
  String get player2Label => 'Player 2';

  @override
  String get player3Label => 'Player 3';

  @override
  String get player4Label => 'Player 4';

  @override
  String get receivingTooltip => 'Receiving';

  @override
  String get modeSinglesOption => 'Singles';

  @override
  String get modeDoublesOption => 'Doubles';

  @override
  String gamesCountLabel(int count) {
    return 'Games: $count';
  }

  @override
  String get changeEndsSnackBar => 'Change ends';

  @override
  String gameCompleteMessage(String player) {
    return '$player wins the game — change ends';
  }

  @override
  String get matchCompleteDialogTitle => 'Match complete';

  @override
  String matchCompleteMessage(String player) {
    return '$player wins the match!';
  }

  @override
  String get newMatchButton => 'New match';
}
