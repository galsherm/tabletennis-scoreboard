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
  String get moreOptionsTooltip => 'More options';

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
  String get team1Label => 'Team 1';

  @override
  String get team2Label => 'Team 2';

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

  @override
  String get matchStartCheer => 'Let\'s Play!';

  @override
  String get editNameHint => 'Tap to rename';

  @override
  String get themeMenuTooltip => 'Theme';

  @override
  String get themeSystemOption => 'System default';

  @override
  String get themeLightOption => 'Light';

  @override
  String get themeDarkOption => 'Dark';

  @override
  String get proMenuTooltip => 'Remove Ads / Pro';

  @override
  String get proDialogTitle => 'Remove Ads / Pro';

  @override
  String get proDialogDescriptionFree =>
      'A one-time purchase that removes ads and unlocks exporting your match results.';

  @override
  String get proDialogAlreadyProTitle => 'You\'re Pro!';

  @override
  String get proDialogAlreadyProBody =>
      'Ads are removed and match export is unlocked. Thanks for your support!';

  @override
  String get proBuyButton => 'Remove Ads';

  @override
  String get proRestoreButton => 'Restore purchases';

  @override
  String get proStatusPending => 'Purchase pending…';

  @override
  String get proStatusSuccess => 'Purchase successful — ads removed!';

  @override
  String get proStatusRestored => 'Purchase restored — ads removed!';

  @override
  String get proStatusCancelled => 'Purchase cancelled.';

  @override
  String get proStatusError =>
      'Something went wrong with the purchase. Please try again.';

  @override
  String get proStatusRestoreNotFound => 'No previous purchase found.';

  @override
  String get exportMatchButton => 'Export match result';

  @override
  String get exportMatchCopied => 'Match result copied to clipboard';

  @override
  String exportGameLine(int number, int player1Points, int player2Points) {
    return 'Game $number: $player1Points-$player2Points';
  }

  @override
  String get correctScoreHint => 'Hold to correct';

  @override
  String correctScoreDialogTitle(String player) {
    return 'Correct $player\'s score';
  }

  @override
  String get correctScoreCancelButton => 'Cancel';

  @override
  String get correctScoreConfirmButton => 'Set score';

  @override
  String get privacyOptionsMenuItem => 'Privacy options';

  @override
  String get privacyPolicyMenuItem => 'Privacy Policy';
}
