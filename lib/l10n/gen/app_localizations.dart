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

  /// Tooltip on the language-picker icon button.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageMenuTooltip;

  /// Language-picker option that follows the device's own language setting rather than overriding it.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemOption;

  /// Label above the 3/5/7 best-of-N game-count selector.
  ///
  /// In en, this message translates to:
  /// **'Best of'**
  String get bestOfLabel;

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
