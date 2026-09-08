import '../models/player.dart';

/// Which language the voice layer speaks in.
enum CommentaryLanguage {
  en,
  de,
  fr;

  /// Resolves a Flutter locale's `languageCode` (e.g. `"de"`) to the closest
  /// supported [CommentaryLanguage], falling back to English for anything
  /// else — matching the app's `supportedLocales`, which currently only
  /// offers en/de/fr (Phase 3; see PHASES.md).
  static CommentaryLanguage fromLanguageCode(String languageCode) {
    switch (languageCode) {
      case 'de':
        return CommentaryLanguage.de;
      case 'fr':
        return CommentaryLanguage.fr;
      default:
        return CommentaryLanguage.en;
    }
  }
}

/// The phrase templates [match_commentary.dart] needs to announce a point in
/// one language, plus the device-TTS locale tag and bundled-clip subfolder
/// that go with it. Deliberately Flutter-widget-free (no `BuildContext`,
/// no `Locale`) so it stays trivially unit-testable, like the rest of the
/// voice layer.
class CommentaryStrings {
  /// BCP-47 tag requested from the device TTS engine, e.g. `"de-DE"`.
  final String ttsLocale;

  /// Bundled-clip subfolder under `assets/audio/`, e.g. `"de"`.
  final String clipFolder;

  final String Function(int serverPoints, int receiverPoints) score;
  final String deuce;
  final String Function(String winnerLabel) gameWon;

  /// Appended after a score announcement in the deciding game once a
  /// player reaches 5 points (ITTF Law 2.14.2), e.g. `". Change ends."`.
  final String changeEndsSuffix;

  final String Function(String winnerLabel) matchWon;

  /// Appended after a score announcement when the next point could win
  /// the match, e.g. `". Match point."`.
  final String matchPointSuffix;

  final String Function(Player player) playerLabel;

  const CommentaryStrings({
    required this.ttsLocale,
    required this.clipFolder,
    required this.score,
    required this.deuce,
    required this.gameWon,
    required this.changeEndsSuffix,
    required this.matchWon,
    required this.matchPointSuffix,
    required this.playerLabel,
  });

  static CommentaryStrings forLanguage(CommentaryLanguage language) {
    switch (language) {
      case CommentaryLanguage.de:
        return de;
      case CommentaryLanguage.fr:
        return fr;
      case CommentaryLanguage.en:
        return en;
    }
  }

  static const en = CommentaryStrings(
    ttsLocale: 'en-US',
    clipFolder: 'en',
    score: _scoreEn,
    deuce: 'Deuce',
    gameWon: _gameWonEn,
    changeEndsSuffix: '. Change ends.',
    matchWon: _matchWonEn,
    matchPointSuffix: '. Match point.',
    playerLabel: _playerLabelEn,
  );

  static const de = CommentaryStrings(
    ttsLocale: 'de-DE',
    clipFolder: 'de',
    score: _scoreDe,
    deuce: 'Gleichstand',
    gameWon: _gameWonDe,
    changeEndsSuffix: '. Seitenwechsel.',
    matchWon: _matchWonDe,
    matchPointSuffix: '. Matchball.',
    playerLabel: _playerLabelDe,
  );

  static const fr = CommentaryStrings(
    ttsLocale: 'fr-FR',
    clipFolder: 'fr',
    score: _scoreFr,
    deuce: 'Égalité',
    gameWon: _gameWonFr,
    changeEndsSuffix: '. Changement de côté.',
    matchWon: _matchWonFr,
    matchPointSuffix: '. Balle de match.',
    playerLabel: _playerLabelFr,
  );
}

// Score numbers read the same way in every language, so one function
// covers all three — kept per-language below anyway so each locale's
// template set is self-contained and independently swappable.
String _scoreEn(int s, int r) => '$s, $r';
String _scoreDe(int s, int r) => '$s, $r';
String _scoreFr(int s, int r) => '$s, $r';

String _gameWonEn(String w) => 'Game, $w. Change ends.';
String _gameWonDe(String w) => 'Satz, $w. Seitenwechsel.';
String _gameWonFr(String w) => 'Manche, $w. Changement de côté.';

String _matchWonEn(String w) => 'Match. $w wins the match.';
String _matchWonDe(String w) => 'Spiel. $w gewinnt das Spiel.';
String _matchWonFr(String w) => 'Match. $w gagne le match.';

String _playerLabelEn(Player p) => p == Player.one ? 'Player 1' : 'Player 2';
String _playerLabelDe(Player p) => p == Player.one ? 'Spieler 1' : 'Spieler 2';
String _playerLabelFr(Player p) => p == Player.one ? 'Joueur 1' : 'Joueur 2';
