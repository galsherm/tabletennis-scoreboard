import 'package:flutter/material.dart';

/// The app's design system: a small, deliberate palette and type scale
/// built for courtside use — glanced at quickly, often in bright or
/// uneven gym lighting, not browsed like a typical phone app.
///
/// Dark is the default (not just "supported"): a near-black background
/// reads reliably under variable hall lighting and glare, and gives the
/// score digits the highest achievable contrast. See PHASE4B_UI_POLISH.md
/// for the full rationale.
class AppColors {
  AppColors._();

  /// Near-black, not pure black — a very slightly blue-tinted dark tone
  /// reads as intentional/premium rather than a plain OLED-black void,
  /// and avoids the smearing pure black can show on some panels.
  static const background = Color(0xFF0B0F14);

  /// One step up from [background] — app bar, dividers' surroundings.
  static const surface = Color(0xFF141A21);

  /// The single accent color, used sparingly and only functionally: the
  /// serve/receive indicators and primary call-to-action buttons. A warm
  /// table-tennis-ball orange — distinct from the score's neutral white
  /// so the accent never competes with the score for attention.
  static const accent = Color(0xFFFF8A34);

  /// A darker/deeper variant of [accent] for pressed states and subtle
  /// fills (e.g. the selected segment background).
  static const accentDim = Color(0xFFCC6E29);

  /// Near-white, reserved for the score digits — the one element that
  /// should always read at maximum contrast against [background].
  static const scoreText = Color(0xFFF5F7FA);

  /// Muted foreground for everything that should visually defer to the
  /// score: player labels, games-won counts, headings.
  static const mutedText = Color(0xFFA7B0BC);

  /// Even more muted — secondary hints, disabled-ish states.
  static const faintText = Color(0xFF5B6472);

  static const divider = Color(0xFF232B34);

  static const success = Color(0xFF35C46A);
  static const error = Color(0xFFE5484D);
}

/// Type scale: score digits are the single most important element on
/// screen, so every other role (labels, buttons, headings) is
/// deliberately smaller and lower-contrast, never competing with it.
///
/// [scoreDisplay] is a *base* style meant to be wrapped in a `FittedBox`
/// wherever it's used — the nominal size is intentionally large (it's the
/// dominant element on a scoreboard), and `FittedBox` scales it down only
/// as far as the available half-screen width actually requires, so it's
/// always exactly as big as it can be without ever overflowing.
class AppTypography {
  AppTypography._();

  static const scoreDisplay = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 176,
    height: 1.0,
    fontWeight: FontWeight.w900,
    color: AppColors.scoreText,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: -2,
  );

  static const playerLabel = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 19,
    fontWeight: FontWeight.w600,
    color: AppColors.mutedText,
    letterSpacing: 0.1,
  );

  static const compactPlayerLabel = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.mutedText,
  );

  static const gamesLabel = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.faintText,
    letterSpacing: 0.2,
  );

  /// Short, all-caps-style "eyebrow" heading above a selector (e.g.
  /// "Best of", "Gewinnsätze") — a common pattern for labeling a control
  /// without competing with it visually.
  static const eyebrow = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.mutedText,
    letterSpacing: 1.1,
  );

  /// The energetic "Let's Play!" phrase shown during the match-start
  /// transition (Phase 4E) — large and confident enough to read as the
  /// full-screen moment's one focal point, but well below [scoreDisplay]
  /// since it's a brief flourish, not the score.
  static const transitionHeadline = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 40,
    fontWeight: FontWeight.w900,
    color: AppColors.scoreText,
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

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
    surface: AppColors.surface,
    primary: AppColors.accent,
    onPrimary: Colors.black,
    error: AppColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.divider,
    // Committed explicitly rather than left to Material's default fallback
    // chain, so the app's typeface is the same deliberate choice on every
    // platform instead of drifting toward whatever each OS substitutes.
    fontFamily: 'Roboto',
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.scoreText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize:
            const Size(AppMetrics.minTouchTarget, AppMetrics.minTouchTarget),
        foregroundColor: AppColors.scoreText,
        disabledForegroundColor: AppColors.faintText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
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
        foregroundColor: AppColors.scoreText,
        side: const BorderSide(color: AppColors.divider, width: 1.5),
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
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.mutedText,
        selectedBackgroundColor: AppColors.accent,
        selectedForegroundColor: Colors.black,
        side: const BorderSide(color: AppColors.divider),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(
          fontFamily: 'Roboto', color: AppColors.scoreText, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      actionTextColor: AppColors.accent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      titleTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        color: AppColors.scoreText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
          fontFamily: 'Roboto', color: AppColors.mutedText, fontSize: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        color: Colors.black,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surface,
      textStyle: TextStyle(fontFamily: 'Roboto', color: AppColors.scoreText),
    ),
  );
}
