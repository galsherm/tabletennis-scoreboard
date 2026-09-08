// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Tableau de score de tennis de table';

  @override
  String get newMatchScreenTitle => 'Nouveau match';

  @override
  String get languageMenuTooltip => 'Langue';

  @override
  String get languageSystemOption => 'Système';

  @override
  String get bestOfLabel => 'Au meilleur de';

  @override
  String bestOfSegmentLabel(int bestOf, int gamesToWin) {
    return '$bestOf';
  }

  @override
  String get tossPrompt => 'Tirage au sort pour décider qui sert en premier';

  @override
  String firstServerLabel(String player) {
    return 'Premier serveur : $player';
  }

  @override
  String get tossButton => 'Tirer à pile ou face';

  @override
  String get startMatchButton => 'Démarrer le match';

  @override
  String get scoreboardTitle => 'Tennis de table';

  @override
  String get muteTooltip => 'Couper le son';

  @override
  String get unmuteTooltip => 'Activer le son';

  @override
  String get undoTooltip => 'Annuler';

  @override
  String get resetTooltip => 'Réinitialiser le match';

  @override
  String get servingTooltip => 'Service';

  @override
  String get player1Label => 'Joueur 1';

  @override
  String get player2Label => 'Joueur 2';

  @override
  String get player3Label => 'Joueur 3';

  @override
  String get player4Label => 'Joueur 4';

  @override
  String get team1Label => 'Paire 1';

  @override
  String get team2Label => 'Paire 2';

  @override
  String get receivingTooltip => 'Relanceur';

  @override
  String get modeSinglesOption => 'Simple';

  @override
  String get modeDoublesOption => 'Double';

  @override
  String gamesCountLabel(int count) {
    return 'Manches : $count';
  }

  @override
  String get changeEndsSnackBar => 'Changement de côté';

  @override
  String gameCompleteMessage(String player) {
    return '$player remporte la manche — changement de côté';
  }

  @override
  String get matchCompleteDialogTitle => 'Match terminé';

  @override
  String matchCompleteMessage(String player) {
    return '$player remporte le match !';
  }

  @override
  String get newMatchButton => 'Nouveau match';

  @override
  String get matchStartCheer => 'C\'est parti !';

  @override
  String get editNameHint => 'Toucher pour renommer';

  @override
  String get themeMenuTooltip => 'Thème';

  @override
  String get themeSystemOption => 'Système';

  @override
  String get themeLightOption => 'Clair';

  @override
  String get themeDarkOption => 'Sombre';

  @override
  String get proMenuTooltip => 'Supprimer les publicités / Pro';

  @override
  String get proDialogTitle => 'Supprimer les publicités / Pro';

  @override
  String get proDialogDescriptionFree =>
      'Achat unique : supprime les publicités et débloque l\'exportation des résultats de match.';

  @override
  String get proDialogAlreadyProTitle => 'Vous êtes Pro !';

  @override
  String get proDialogAlreadyProBody =>
      'Les publicités sont supprimées et l\'exportation des matchs est débloquée. Merci pour votre soutien !';

  @override
  String get proBuyButton => 'Supprimer les publicités';

  @override
  String get proRestoreButton => 'Restaurer les achats';

  @override
  String get proStatusPending => 'Achat en cours…';

  @override
  String get proStatusSuccess => 'Achat réussi — publicités supprimées !';

  @override
  String get proStatusRestored => 'Achat restauré — publicités supprimées !';

  @override
  String get proStatusCancelled => 'Achat annulé.';

  @override
  String get proStatusError =>
      'Une erreur est survenue lors de l\'achat. Veuillez réessayer.';

  @override
  String get proStatusRestoreNotFound => 'Aucun achat précédent trouvé.';

  @override
  String get exportMatchButton => 'Exporter le résultat du match';

  @override
  String get exportMatchCopied =>
      'Résultat du match copié dans le presse-papiers';

  @override
  String exportGameLine(int number, int player1Points, int player2Points) {
    return 'Manche $number : $player1Points-$player2Points';
  }
}
