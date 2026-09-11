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
  String get moreOptionsTooltip => 'Weitere Optionen';

  @override
  String get languageMenuTooltip => 'Sprache';

  @override
  String get languageSystemOption => 'Systemstandard';

  @override
  String get bestOfLabel => 'Gewinnsätze';

  @override
  String bestOfSegmentLabel(int bestOf, int gamesToWin) {
    return '$gamesToWin';
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
  String get player3Label => 'Spieler 3';

  @override
  String get player4Label => 'Spieler 4';

  @override
  String get team1Label => 'Team 1';

  @override
  String get team2Label => 'Team 2';

  @override
  String get receivingTooltip => 'Rückschläger';

  @override
  String get modeSinglesOption => 'Einzel';

  @override
  String get modeDoublesOption => 'Doppel';

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

  @override
  String get matchStartCheer => 'Auf geht\'s!';

  @override
  String get editNameHint => 'Zum Umbenennen tippen';

  @override
  String get themeMenuTooltip => 'Design';

  @override
  String get themeSystemOption => 'Systemstandard';

  @override
  String get themeLightOption => 'Hell';

  @override
  String get themeDarkOption => 'Dunkel';

  @override
  String get proMenuTooltip => 'Werbung entfernen / Pro';

  @override
  String get proDialogTitle => 'Werbung entfernen / Pro';

  @override
  String get proDialogDescriptionFree => 'Einmaliger Kauf: entfernt Werbung.';

  @override
  String get proDialogAlreadyProTitle => 'Du bist Pro!';

  @override
  String get proDialogAlreadyProBody =>
      'Werbung ist entfernt. Danke für deine Unterstützung!';

  @override
  String get proBuyButton => 'Werbung entfernen';

  @override
  String get proPriceLoading => 'Preis wird geladen …';

  @override
  String get proRestoreButton => 'Käufe wiederherstellen';

  @override
  String get proStatusPending => 'Kauf wird bearbeitet …';

  @override
  String get proStatusSuccess => 'Kauf erfolgreich — Werbung entfernt!';

  @override
  String get proStatusRestored => 'Kauf wiederhergestellt — Werbung entfernt!';

  @override
  String get proStatusCancelled => 'Kauf abgebrochen.';

  @override
  String get proStatusError =>
      'Beim Kauf ist ein Fehler aufgetreten. Bitte versuche es erneut.';

  @override
  String get proStatusRestoreNotFound => 'Kein vorheriger Kauf gefunden.';

  @override
  String get exportMatchButton => 'Spielergebnis exportieren';

  @override
  String get exportMatchCopied => 'Spielergebnis in die Zwischenablage kopiert';

  @override
  String exportGameLine(int number, int player1Points, int player2Points) {
    return 'Satz $number: $player1Points-$player2Points';
  }

  @override
  String get correctScoreHint => 'Zum Korrigieren halten';

  @override
  String correctScoreDialogTitle(String player) {
    return 'Punktestand von $player korrigieren';
  }

  @override
  String get correctScoreCancelButton => 'Abbrechen';

  @override
  String get correctScoreConfirmButton => 'Übernehmen';

  @override
  String get privacyOptionsMenuItem => 'Datenschutzoptionen';

  @override
  String get privacyPolicyMenuItem => 'Datenschutzerklärung';
}
