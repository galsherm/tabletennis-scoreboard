// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Tischtennis-Anzeigetafel';

  @override
  String get newMatchScreenTitle => 'Neues Spiel';

  @override
  String get languageMenuTooltip => 'Sprache';

  @override
  String get languageSystemOption => 'Systemstandard';

  @override
  String get bestOfLabel => 'Spielformat';

  @override
  String bestOfSegmentLabel(int bestOf, int gamesToWin) {
    return '$gamesToWin Gewinnsätze';
  }

  @override
  String get tossPrompt => 'Münzwurf, um zu entscheiden, wer zuerst aufschlägt';

  @override
  String firstServerLabel(String player) {
    return 'Zuerst am Aufschlag: $player';
  }

  @override
  String get tossButton => 'Münze werfen';

  @override
  String get startMatchButton => 'Spiel starten';

  @override
  String get scoreboardTitle => 'Tischtennis';

  @override
  String get muteTooltip => 'Sprachausgabe stummschalten';

  @override
  String get unmuteTooltip => 'Stummschaltung aufheben';

  @override
  String get undoTooltip => 'Rückgängig';

  @override
  String get resetTooltip => 'Spiel zurücksetzen';

  @override
  String get servingTooltip => 'Aufschlag';

  @override
  String get player1Label => 'Spieler 1';

  @override
  String get player2Label => 'Spieler 2';

  @override
  String gamesCountLabel(int count) {
    return 'Sätze: $count';
  }

  @override
  String get changeEndsSnackBar => 'Seitenwechsel';

  @override
  String gameCompleteMessage(String player) {
    return '$player gewinnt den Satz — Seitenwechsel';
  }

  @override
  String get matchCompleteDialogTitle => 'Spiel beendet';

  @override
  String matchCompleteMessage(String player) {
    return '$player gewinnt das Spiel!';
  }

  @override
  String get newMatchButton => 'Neues Spiel';
}
