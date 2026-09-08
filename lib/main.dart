import 'package:flutter/material.dart';

import 'l10n/gen/app_localizations.dart';
import 'screens/setup_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TableTennisScoreboardApp());
}

class TableTennisScoreboardApp extends StatefulWidget {
  const TableTennisScoreboardApp({super.key});

  @override
  State<TableTennisScoreboardApp> createState() =>
      _TableTennisScoreboardAppState();
}

class _TableTennisScoreboardAppState extends State<TableTennisScoreboardApp> {
  /// Manual language override; null follows the device's own locale
  /// (Phase 3: auto-detected from device locale, with this manual
  /// override available in the setup screen's app bar).
  Locale? _localeOverride;

  void _setLocaleOverride(Locale? locale) {
    setState(() => _localeOverride = locale);
  }

  /// Matches the device's preferred locales against the languages this
  /// app actually ships (by language code, ignoring region), defaulting
  /// to English for anything else.
  ///
  /// This is deliberately explicit rather than relying on Flutter's
  /// default fallback (`supportedLocales.first`): `AppLocalizations.
  /// supportedLocales` is generated in alphabetical order (de, en, fr), so
  /// that default would silently fall back to German — not English, the
  /// app's original/home language — for any unsupported device locale.
  Locale _resolveDeviceLocale(
    List<Locale>? deviceLocales,
    Iterable<Locale> supportedLocales,
  ) {
    if (deviceLocales != null) {
      for (final deviceLocale in deviceLocales) {
        for (final supported in supportedLocales) {
          if (supported.languageCode == deviceLocale.languageCode) {
            return supported;
          }
        }
      }
    }
    return const Locale('en');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: _localeOverride,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: _resolveDeviceLocale,
      // Dark is the committed default, not just a supported alternative —
      // this app is read at a glance courtside, often in bright or
      // uneven gym lighting, where a near-black background with a
      // high-contrast score reads far more reliably than a light theme.
      // See PHASE4B_UI_POLISH.md.
      themeMode: ThemeMode.dark,
      darkTheme: buildAppTheme(),
      theme: buildAppTheme(),
      home: SetupScreen(
        currentLocaleOverride: _localeOverride,
        onLocaleChanged: _setLocaleOverride,
      ),
    );
  }
}
