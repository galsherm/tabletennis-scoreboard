import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/gen/app_localizations.dart';
import 'screens/setup_screen.dart';
import 'services/ads_service.dart';
import 'services/consent_service.dart';
import 'services/monetization_controller.dart';
import 'services/pro_status_store.dart';
import 'services/purchase_gateway.dart';
import 'services/theme_preference.dart';
import 'theme/app_theme.dart';

void main() {
  // Edge-to-edge: the app draws its own background underneath the status
  // bar and navigation bar, rather than the OS reserving an opaque strip
  // above/below the app's content. Without this, Flutter's Android
  // embedding leaves the platform's own (usually opaque, theme-agnostic)
  // system bar backgrounds in place, which is exactly the "hard
  // boundary" this app no longer wants. Must run before `runApp` — it's
  // a one-time window-mode switch, not something any widget sets per
  // frame.
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const TableTennisScoreboardApp());
}

class TableTennisScoreboardApp extends StatefulWidget {
  /// Optional, matching the `voiceAnnouncer`/`initialNames` convention
  /// already used by `SetupScreen` and the scoreboard screens (see
  /// PHASE5_MONETIZATION.md): when omitted (every real call site,
  /// including `main()`), this widget builds and owns its own real
  /// instance. Exists so tests can inject one with a specific
  /// `monetizationEnabled` override rather than being stuck with
  /// whatever the app-wide `feature_flags.monetizationEnabled` constant
  /// currently is.
  final MonetizationController? monetization;

  const TableTennisScoreboardApp({super.key, this.monetization});

  @override
  State<TableTennisScoreboardApp> createState() =>
      _TableTennisScoreboardAppState();
}

class _TableTennisScoreboardAppState extends State<TableTennisScoreboardApp> {
  /// Manual language override; null follows the device's own locale
  /// (Phase 3: auto-detected from device locale, with this manual
  /// override available in the setup screen's app bar).
  Locale? _localeOverride;

  /// Light/Dark/System theme choice (Phase 4F). Dark until the persisted
  /// preference (if any) loads — matching the "dark is the default"
  /// stance from PHASE4B_UI_POLISH.md for the brief window before
  /// [_themePreference] resolves.
  ThemeMode _themeMode = ThemeMode.dark;
  final _themePreference = ThemePreference();

  /// Whether voice/sound is muted — lifted up here (rather than living
  /// only inside whichever [VoiceAnnouncer] the current match owns) so
  /// it survives navigating back to [SetupScreen] for the next match,
  /// and so the setup screen's own coin-flip landing sound (added after
  /// [VoiceAnnouncer] already existed) has a mute setting to check
  /// before any match — and its [VoiceAnnouncer] — exists yet. Not
  /// persisted to disk: this mirrors [VoiceAnnouncer]'s own existing
  /// (session-only) mute behavior, just shared across screens instead of
  /// reset per match.
  bool _muted = false;

  /// Owns ads + purchases + the persisted Pro flag for the app's entire
  /// lifetime (Phase 5) — one instance, created here and threaded down
  /// through [SetupScreen] into whichever scoreboard screen is active, so
  /// Pro status and a preloaded ad survive navigating between them. See
  /// PHASE5_MONETIZATION.md.
  late final MonetizationController _monetization;
  late final bool _ownsMonetization;

  @override
  void initState() {
    super.initState();
    _monetization = widget.monetization ??
        MonetizationController(
          ads: AdMobAdsService(),
          purchases: InAppPurchaseGateway(),
          proStatusStore: ProStatusStore(),
          consent: UmpConsentService(),
        );
    _ownsMonetization = widget.monetization == null;
    _themePreference.load().then((mode) {
      if (mounted) setState(() => _themeMode = mode);
    });
    _monetization.initialize();
  }

  @override
  void dispose() {
    if (_ownsMonetization) _monetization.dispose();
    super.dispose();
  }

  void _setLocaleOverride(Locale? locale) {
    setState(() => _localeOverride = locale);
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _themePreference.save(mode);
  }

  void _setMuted(bool muted) {
    setState(() => _muted = muted);
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

  /// Resolves [_themeMode] to the actual [Brightness] currently on
  /// screen, following the platform's own setting for [ThemeMode.system]
  /// — same rule [MaterialApp] itself uses to pick between [theme] and
  /// [darkTheme].
  Brightness get _effectiveBrightness => switch (_themeMode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };

  @override
  Widget build(BuildContext context) {
    // App-wide edge-to-edge default: transparent system bars (so the
    // screen's own background shows through, rather than an opaque OS
    // strip) with icon/text brightness that reads against whichever
    // theme is actually active. This is a *default* — it covers every
    // screen that doesn't specify its own (e.g. the scoreboard screens'
    // AppBar already computes its own overlay style from its real
    // background), and is overridden specifically by the setup screen's
    // hero band, which stays dark regardless of app theme and so needs
    // light icons even in Light mode.
    final isDark = _effectiveBrightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: MaterialApp(
        // Store screenshots are taken from real device builds, not just
        // release builds where this defaults to false anyway — belt and
        // suspenders so a debug-mode capture never leaks the red "DEBUG"
        // ribbon into a listing asset.
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        locale: _localeOverride,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: _resolveDeviceLocale,
        // Dark remains the recommended default (see PHASE4B_UI_POLISH.md's
        // courtside-legibility reasoning), but Phase 4F adds a genuine
        // Light/Dark/System choice, persisted via [_themePreference].
        themeMode: _themeMode,
        darkTheme: buildAppTheme(Brightness.dark),
        theme: buildAppTheme(Brightness.light),
        home: SetupScreen(
          currentLocaleOverride: _localeOverride,
          onLocaleChanged: _setLocaleOverride,
          themeMode: _themeMode,
          onThemeModeChanged: _setThemeMode,
          monetization: _monetization,
          muted: _muted,
          onMutedChanged: _setMuted,
        ),
      ),
    );
  }
}
