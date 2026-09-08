import 'package:flutter/material.dart';

/// The app's design system: a small, deliberate palette and type scale
/// built for courtside use — glanced at quickly, often in bright or
/// uneven gym lighting, not browsed like a typical phone app.
///
/// [AppPalette] bundles every color role as a [ThemeExtension], so the
/// same semantic names (background, surface, accent, ...) resolve to
/// different actual colors depending on [ThemeData.brightness] — see
/// [AppPalette.dark] (the original Phase 4B palette, unchanged) and
/// [AppPalette.light] (Phase 4F: a real light palette designed with the
/// same contrast/role discipline, not just the dark colors inverted).
/// Access it via `context.palette` (the [AppPaletteContext] extension
/// below) rather than a hardcoded `AppColors.xxx` constant.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color accent;
  final Color accentDim;
  final Color scoreText;
  final Color mutedText;
  final Color faintText;
  final Color divider;
  final Color success;
  final Color error;

  /// Foreground for content drawn on top of [accent] (button labels, the
  /// coin's face text) — black in both palettes, since both accent
  /// oranges are light/saturated enough for black to stay the higher-
  /// contrast choice, but kept as its own token rather than hardcoding
  /// `Colors.black` at each call site.
  final Color onAccent;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.accent,
    required this.accentDim,
    required this.scoreText,
    required this.mutedText,
    required this.faintText,
    required this.divider,
    required this.success,
    required this.error,
    required this.onAccent,
  });

  /// The original Phase 4B palette. Dark is the default (not just
  /// "supported"): a near-black background reads reliably under variable
  /// hall lighting and glare, and gives the score digits the highest
  /// achievable contrast. See PHASE4B_UI_POLISH.md.
  static const dark = AppPalette(
    // Near-black, not pure black — a very slightly blue-tinted dark tone
    // reads as intentional/premium rather than a plain OLED-black void,
    // and avoids the smearing pure black can show on some panels.
    background: Color(0xFF0B0F14),
    // One step up from background — app bar, dividers' surroundings.
    surface: Color(0xFF141A21),
    // The single accent color, used sparingly and only functionally: the
    // serve/receive indicators and primary call-to-action buttons. A warm
    // table-tennis-ball orange — distinct from the score's neutral white
    // so the accent never competes with the score for attention.
    accent: Color(0xFFFF8A34),
    accentDim: Color(0xFFCC6E29),
    // Near-white, reserved for the score digits — the one element that
    // should always read at maximum contrast against background.
    scoreText: Color(0xFFF5F7FA),
    // Muted foreground for everything that should visually defer to the
    // score: player labels, games-won counts, headings.
    mutedText: Color(0xFFA7B0BC),
    // Even more muted — secondary hints, disabled-ish states.
    faintText: Color(0xFF5B6472),
    divider: Color(0xFF232B34),
    success: Color(0xFF35C46A),
    error: Color(0xFFE5484D),
    onAccent: Colors.black,
  );

  /// Phase 4F's light palette. Built with the same role discipline as
  /// [dark] — a near-white (not pure white) background for the same
  /// "intentional, not a void" reason dark avoids pure black; a deepened,
  /// more saturated accent orange, since the dark palette's brighter
  /// accent loses contrast against a light background (checked visually
  /// — the dark accent read as washed-out/pastel on white, not vivid);
  /// near-black score text mirroring scoreText's "maximum contrast"
  /// role; and muted/faint/divider tones re-derived for light-background
  /// contrast rather than simply inverted from dark's values.
  static const light = AppPalette(
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFFE06A1F),
    accentDim: Color(0xFFB8580F),
    scoreText: Color(0xFF14181D),
    mutedText: Color(0xFF4B5563),
    faintText: Color(0xFF8B93A0),
    divider: Color(0xFFDEE1E6),
    success: Color(0xFF1B8F4C),
    error: Color(0xFFC22C2C),
    onAccent: Colors.black,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? accent,
    Color? accentDim,
    Color? scoreText,
    Color? mutedText,
    Color? faintText,
    Color? divider,
    Color? success,
    Color? error,
    Color? onAccent,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      accentDim: accentDim ?? this.accentDim,
      scoreText: scoreText ?? this.scoreText,
      mutedText: mutedText ?? this.mutedText,
      faintText: faintText ?? this.faintText,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      error: error ?? this.error,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      scoreText: Color.lerp(scoreText, other.scoreText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      faintText: Color.lerp(faintText, other.faintText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

/// Ergonomic access to the active [AppPalette] — `context.palette.accent`
/// instead of `Theme.of(context).extension<AppPalette>()!.accent`.
///
/// Falls back to [AppPalette.dark] if the ambient `Theme` wasn't built by
/// [buildAppTheme] (and so carries no [AppPalette] extension at all) —
/// notably, a widget test that wraps a screen in a bare `MaterialApp`
/// without an explicit `theme:`. Dark matches the app's own recommended
/// default, so this is a sane fallback rather than a silent behavior
/// change; the real app always goes through [buildAppTheme].
extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}

/// Type scale: score digits are the single most important element on
/// screen, so every other role (labels, buttons, headings) is
/// deliberately smaller and lower-contrast, never competing with it.
///
/// Every style here is a method taking [BuildContext] (not a plain
/// `const` field) specifically so its color resolves from the active
/// [AppPalette] — a hardcoded color baked into a `const TextStyle` can't
/// react to a light/dark switch.
///
/// [scoreDisplay] is a *base* style meant to be wrapped in a `FittedBox`
/// wherever it's used — the nominal size is intentionally large (it's the
/// dominant element on a scoreboard), and `FittedBox` scales it down only
/// as far as the available half-screen width actually requires, so it's
/// always exactly as big as it can be without ever overflowing.
class AppTypography {
  AppTypography._();

  static TextStyle scoreDisplay(BuildContext context) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 176,
        height: 1.0,
        fontWeight: FontWeight.w900,
        color: context.palette.scoreText,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: -2,
      );

  static TextStyle playerLabel(BuildContext context) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: context.palette.mutedText,
        letterSpacing: 0.1,
      );

  static TextStyle compactPlayerLabel(BuildContext context) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: context.palette.mutedText,
      );

  static TextStyle gamesLabel(BuildContext context) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.palette.faintText,
        letterSpacing: 0.2,
      );

  /// Short, all-caps-style "eyebrow" heading above a selector (e.g.
  /// "Best of", "Gewinnsätze") — a common pattern for labeling a control
  /// without competing with it visually.
  static TextStyle eyebrow(BuildContext context) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.palette.mutedText,
        letterSpacing: 1.1,
      );

  /// The energetic "Let's Play!" phrase shown during the match-start
  /// transition (Phase 4E) — large and confident enough to read as the
  /// full-screen moment's one focal point, but well below [scoreDisplay]
  /// since it's a brief flourish, not the score.
  static TextStyle transitionHeadline(BuildContext context) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 40,
        fontWeight: FontWeight.w900,
        color: context.palette.scoreText,
        letterSpacing: 0.3,
      );
}

/// Touch targets sized for quick, imprecise courtside taps rather than
/// careful phone-in-hand browsing.
class AppMetrics {
  AppMetrics._();

  static const minTouchTarget = 56.0;
  static const iconButtonSize = 26.0;
}

/// Builds the app's [ThemeData] for one [brightness] — [AppPalette.dark]
/// or [AppPalette.light] — with that palette attached as a
/// [ThemeExtension] so [AppTypography] and any widget using
/// `context.palette` picks up the right colors. See
/// PHASE4F_THEME_AND_NAMES.md for why this became parameterized instead
/// of the single hardcoded dark theme from Phase 4B.
ThemeData buildAppTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: brightness,
    surface: palette.surface,
    primary: palette.accent,
    onPrimary: palette.onAccent,
    error: palette.error,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    dividerColor: palette.divider,
    // Committed explicitly rather than left to Material's default fallback
    // chain, so the app's typeface is the same deliberate choice on every
    // platform instead of drifting toward whatever each OS substitutes.
    fontFamily: 'Roboto',
    splashFactory: InkRipple.splashFactory,
    extensions: [palette],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      foregroundColor: palette.scoreText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize:
            const Size(AppMetrics.minTouchTarget, AppMetrics.minTouchTarget),
        foregroundColor: palette.scoreText,
        disabledForegroundColor: palette.faintText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        minimumSize: const Size.fromHeight(AppMetrics.minTouchTarget),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.scoreText,
        side: BorderSide(color: palette.divider, width: 1.5),
        minimumSize: const Size.fromHeight(AppMetrics.minTouchTarget),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize:
            const Size(AppMetrics.minTouchTarget, AppMetrics.minTouchTarget),
        backgroundColor: palette.surface,
        foregroundColor: palette.mutedText,
        selectedBackgroundColor: palette.accent,
        selectedForegroundColor: palette.onAccent,
        side: BorderSide(color: palette.divider),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surface,
      contentTextStyle: TextStyle(
          fontFamily: 'Roboto', color: palette.scoreText, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      actionTextColor: palette.accent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: palette.scoreText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
          fontFamily: 'Roboto', color: palette.mutedText, fontSize: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(
        fontFamily: 'Roboto',
        color: palette.onAccent,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      textStyle: TextStyle(fontFamily: 'Roboto', color: palette.scoreText),
    ),
  );
}
