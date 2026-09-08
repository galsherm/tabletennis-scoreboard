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
}
