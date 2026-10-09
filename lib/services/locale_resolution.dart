import 'dart:ui';

/// Matches the device's preferred locales against the languages this
/// app actually ships (by language code, ignoring region), defaulting
/// to English for anything else.
///
/// This is deliberately explicit rather than relying on Flutter's
/// default fallback (`supportedLocales.first`): `AppLocalizations.
/// supportedLocales` is generated in alphabetical order (de, en, fr), so
/// that default would silently fall back to German — not English, the
/// app's original/home language — for any unsupported device locale.
///
/// A plain function so the one rule serves both `MaterialApp`'s
/// `localeListResolutionCallback` and the language menu's "Automatic"
/// row, which names the language this resolves to.
Locale resolveDeviceLocale(
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

/// A shipped language's name in that language itself — never
/// translated, so a reader can find their own language whatever the UI
/// currently displays.
String nativeLanguageName(Locale locale) => switch (locale.languageCode) {
      'de' => 'Deutsch',
      'fr' => 'Français',
      _ => 'English',
    };
