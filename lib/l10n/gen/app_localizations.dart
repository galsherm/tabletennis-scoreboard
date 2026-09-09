import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr')
  ];

  /// The application's title, shown in the OS task switcher.
  ///
  /// In en, this message translates to:
  /// **'Table Tennis Scoreboard'**
  String get appTitle;

  /// App bar title on the match-setup screen.
  ///
  /// In en, this message translates to:
  /// **'New match'**
  String get newMatchScreenTitle;

  /// Tooltip on the app-bar overflow (three-dot) icon that opens the consolidated theme/language/Pro menu — see PHASE4I_POLISH_ROUND2.md.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptionsTooltip;

  /// Section label for the language options within the app-bar overflow menu (Phase 4I) — previously this was its own icon button's tooltip, before the theme/language/Pro icons were consolidated into one menu.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageMenuTooltip;

  /// Language-picker option that follows the device's own language setting rather than overriding it.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemOption;

  /// Label above the best-of-N game-count selector.
  ///
  /// In en, this message translates to:
  /// **'Best of'**
  String get bestOfLabel;

  /// Label for one segment of the best-of-N selector — always a bare number, paired with the explanatory word in bestOfLabel above it (the same structural pattern in all three languages). English/French show the raw best-of-N number; German shows the number of *winning* games needed instead (paired with the "Gewinnsätze" heading), which is how German table tennis sources describe match format, e.g. "3 Gewinnsätze im Einzel" for what this app calls best-of-5 — see PHASE3_VERIFICATION.md and PHASE4B_UI_POLISH.md (the word used to live inside this segment label itself, which is what caused it to overflow only for German).
  ///
  /// In en, this message translates to:
  /// **'{bestOf}'**
  String bestOfSegmentLabel(int bestOf, int gamesToWin);

  /// Shown before the coin toss has been used to pick the first server.
  ///
  /// In en, this message translates to:
  /// **'Toss to decide who serves first'**
  String get tossPrompt;

  /// Shown after the coin toss, naming who serves first.
  ///
  /// In en, this message translates to:
  /// **'First server: {player}'**
  String firstServerLabel(String player);

  /// Button that randomly picks the first server.
  ///
  /// In en, this message translates to:
  /// **'Toss coin'**
  String get tossButton;

  /// Button that begins the match with the chosen settings.
  ///
  /// In en, this message translates to:
  /// **'Start match'**
  String get startMatchButton;

  /// App bar title on the live scoreboard screen.
  ///
  /// In en, this message translates to:
  /// **'Table Tennis'**
  String get scoreboardTitle;

  /// Tooltip on the mute button when voice announcements are currently on.
  ///
  /// In en, this message translates to:
  /// **'Mute voice'**
  String get muteTooltip;

  /// Tooltip on the mute button when voice announcements are currently muted.
  ///
  /// In en, this message translates to:
  /// **'Unmute voice'**
  String get unmuteTooltip;

  /// Tooltip on the undo-last-point button.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoTooltip;

  /// Tooltip on the reset-match button.
  ///
  /// In en, this message translates to:
  /// **'Reset match'**
  String get resetTooltip;

  /// Accessibility label on the icon that marks which player is currently serving.
  ///
  /// In en, this message translates to:
  /// **'Serving'**
  String get servingTooltip;

  /// Display name for the first player.
  ///
  /// In en, this message translates to:
  /// **'Player 1'**
  String get player1Label;

  /// Display name for the second player.
  ///
  /// In en, this message translates to:
  /// **'Player 2'**
  String get player2Label;

  /// Display name for the third player (doubles only).
  ///
  /// In en, this message translates to:
  /// **'Player 3'**
  String get player3Label;

  /// Display name for the fourth player (doubles only).
  ///
  /// In en, this message translates to:
  /// **'Player 4'**
  String get player4Label;

  /// Side-level display name for the first side in doubles — used for the toss result and game/match-complete banners, where 'Player 1' would be ambiguous about whether it means one specific individual or the whole side. Not used for the four individual on-court player labels, which stay Player 1-4.
  ///
  /// In en, this message translates to:
  /// **'Team 1'**
  String get team1Label;

  /// Side-level display name for the second side in doubles — see team1Label.
  ///
  /// In en, this message translates to:
  /// **'Team 2'**
  String get team2Label;

  /// Accessibility label on the icon that marks which player is currently receiving serve (doubles only).
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get receivingTooltip;

  /// Singles/doubles mode selector option for a 2-player match.
  ///
  /// In en, this message translates to:
  /// **'Singles'**
  String get modeSinglesOption;

  /// Singles/doubles mode selector option for a 4-player match.
  ///
  /// In en, this message translates to:
  /// **'Doubles'**
  String get modeDoublesOption;

  /// Shows how many games a player has won so far in the match.
  ///
  /// In en, this message translates to:
  /// **'Games: {count}'**
  String gamesCountLabel(int count);

  /// Snackbar shown mid-game, in the deciding game, when a player reaches 5 points (ITTF Law 2.14.2).
  ///
  /// In en, this message translates to:
  /// **'Change ends'**
  String get changeEndsSnackBar;

  /// Snackbar shown when a game is won.
  ///
  /// In en, this message translates to:
  /// **'{player} wins the game — change ends'**
  String gameCompleteMessage(String player);

  /// Title of the dialog shown when the match ends.
  ///
  /// In en, this message translates to:
  /// **'Match complete'**
  String get matchCompleteDialogTitle;

  /// Body text of the dialog shown when the match ends.
  ///
  /// In en, this message translates to:
  /// **'{player} wins the match!'**
  String matchCompleteMessage(String player);

  /// Button on the match-complete dialog that starts a fresh match.
  ///
  /// In en, this message translates to:
  /// **'New match'**
  String get newMatchButton;

  /// Energetic, centered on-screen phrase shown during the brief ball-flyby transition between tapping "Start match" and landing on the scoreboard — see PHASE4E_MATCH_START_TRANSITION.md. Deliberately casual/energetic copy, not official rules terminology.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Play!'**
  String get matchStartCheer;

  /// Tooltip/accessibility hint on a player or team name that can be tapped to rename it for the current match — see PHASE4F_THEME_AND_NAMES.md.
  ///
  /// In en, this message translates to:
  /// **'Tap to rename'**
  String get editNameHint;

  /// Section label for the theme options within the app-bar overflow menu (Phase 4I) — previously this was its own icon button's tooltip, before the theme/language/Pro icons were consolidated into one menu.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMenuTooltip;

  /// Theme-picker option that follows the device's own light/dark setting rather than overriding it.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystemOption;

  /// Theme-picker option that forces the light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLightOption;

  /// Theme-picker option that forces the dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDarkOption;

  /// Tooltip on the app-bar icon that opens the Pro purchase dialog.
  ///
  /// In en, this message translates to:
  /// **'Remove Ads / Pro'**
  String get proMenuTooltip;

  /// Title of the Pro purchase dialog.
  ///
  /// In en, this message translates to:
  /// **'Remove Ads / Pro'**
  String get proDialogTitle;

  /// Body text shown in the Pro dialog when the user has not purchased Pro yet.
  ///
  /// In en, this message translates to:
  /// **'A one-time purchase that removes ads and unlocks exporting your match results.'**
  String get proDialogDescriptionFree;

  /// Heading shown in the Pro dialog once the user already owns Pro.
  ///
  /// In en, this message translates to:
  /// **'You\'re Pro!'**
  String get proDialogAlreadyProTitle;

  /// Body text shown in the Pro dialog once the user already owns Pro.
  ///
  /// In en, this message translates to:
  /// **'Ads are removed and match export is unlocked. Thanks for your support!'**
  String get proDialogAlreadyProBody;

  /// Button that starts the Pro purchase flow. Deliberately short (a longer 'Remove Ads (One-Time Purchase)' overflowed the button, especially in German/French — the dialog's own body text right above already explains it's a one-time purchase) and has no price baked in — the OS purchase sheet shows the real, store-localized price; see PHASE5_MONETIZATION.md for the target ~€2.99 price to configure in Play Console.
  ///
  /// In en, this message translates to:
  /// **'Remove Ads'**
  String get proBuyButton;

  /// Button that re-queries the store for a previous purchase (required by store policy, and essential after a reinstall or device switch).
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get proRestoreButton;

  /// Feedback shown while a purchase is pending (e.g. awaiting parental approval or slow network).
  ///
  /// In en, this message translates to:
  /// **'Purchase pending…'**
  String get proStatusPending;

  /// Feedback shown when a new purchase completes successfully.
  ///
  /// In en, this message translates to:
  /// **'Purchase successful — ads removed!'**
  String get proStatusSuccess;

  /// Feedback shown when Restore purchases finds and reinstates a previous purchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase restored — ads removed!'**
  String get proStatusRestored;

  /// Feedback shown when the user cancels the purchase flow (e.g. dismisses the OS payment sheet).
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled.'**
  String get proStatusCancelled;

  /// Feedback shown when a purchase or restore attempt fails for any reason (network, store unavailable, product misconfigured).
  ///
  /// In en, this message translates to:
  /// **'Something went wrong with the purchase. Please try again.'**
  String get proStatusError;

  /// Feedback shown when Restore purchases finds nothing to restore.
  ///
  /// In en, this message translates to:
  /// **'No previous purchase found.'**
  String get proStatusRestoreNotFound;

  /// Pro-only button on the match-complete dialog that copies a plain-text summary of the match to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Export match result'**
  String get exportMatchButton;

  /// Confirmation shown after exportMatchButton is tapped.
  ///
  /// In en, this message translates to:
  /// **'Match result copied to clipboard'**
  String get exportMatchCopied;

  /// One line per completed game in the exported match-result text.
  ///
  /// In en, this message translates to:
  /// **'Game {number}: {player1Points}-{player2Points}'**
  String exportGameLine(int number, int player1Points, int player2Points);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
