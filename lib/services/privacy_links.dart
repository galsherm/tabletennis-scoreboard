import 'package:flutter/widgets.dart' show Locale;

/// The hosted Privacy Policy pages opened by the "Privacy Policy" entry in
/// `SetupScreen`'s overflow menu (Phase 6), one per supported app language
/// (source drafted in `privacy_policy/`, see PHASE6_PRELAUNCH_PREP.md).
const String privacyPolicyUrlEn =
    'https://galsherm.github.io/tabletennis-scoreboard/privacy-policy-en.html';
const String privacyPolicyUrlDe =
    'https://galsherm.github.io/tabletennis-scoreboard/privacy-policy-de.html';
const String privacyPolicyUrlFr =
    'https://galsherm.github.io/tabletennis-scoreboard/privacy-policy-fr.html';

/// Picks the Privacy Policy URL matching [locale]'s language, falling back
/// to English for any language the policy hasn't been translated into.
String privacyPolicyUrlFor(Locale locale) {
  switch (locale.languageCode) {
    case 'de':
      return privacyPolicyUrlDe;
    case 'fr':
      return privacyPolicyUrlFr;
    default:
      return privacyPolicyUrlEn;
  }
}
