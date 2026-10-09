import 'package:flutter/material.dart';

/// The app's design system: a small, deliberate palette and type scale
/// built for courtside use — glanced at quickly, often in bright or
/// uneven gym lighting, not browsed like a typical phone app.
///
/// [AppPalette] bundles every color role as a [ThemeExtension], so the
/// same semantic names (background, surface, accent, ...) resolve to
/// different actual colors depending on [ThemeData.brightness] — see
/// [AppPalette.dark] (the default "Arena" look) and
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
  /// coin's face text) — near-black in both palettes, since both accent
  /// oranges are light/saturated enough for a dark label to stay the
  /// higher-contrast choice.
  final Color onAccent;

  /// A lighter tint of [accent] for accent-coloured *text* (the serving
  /// side's name on the scoreboard), where the full-strength accent
  /// reads too heavy at small sizes.
  final Color accentSoft;

  /// The lit spot on the toss coin's face — [accent] catching the light.
  final Color accentHighlight;

  /// Toolbar icons (back, mute, undo, reset) — a step below [scoreText]
  /// so they sit back from the score.
  final Color icon;

  /// A quiet structural neutral: Player 1's field bar, and the outline
  /// of a game pip not yet won.
  final Color neutralBar;

  /// Label and fill of a disabled primary button ("Start match" before
  /// the toss).
  final Color disabledText;
  final Color disabledFill;

  /// The wash behind the serving half of the scoreboard, at its
  /// strongest (top) — it fades to transparent down the half.
  final Color serverGlow;

  /// The soft halo behind the serving side's score digits.
  final Color scoreGlow;

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
    required this.accentSoft,
    required this.accentHighlight,
    required this.icon,
    required this.neutralBar,
    required this.disabledText,
    required this.disabledFill,
    required this.serverGlow,
    required this.scoreGlow,
  });

  /// The "Arena" palette: near-black, one orange accent. Dark is the
  /// default (not just "supported"): a near-black background reads
  /// reliably under variable hall lighting and glare, and gives the
  /// score digits the highest achievable contrast. See
  /// PHASE4B_UI_POLISH.md for that reasoning; the values themselves were
  /// retuned for the Arena redesign.
  static const dark = AppPalette(
    // Near-black, not pure black — a very slightly blue-tinted dark tone
    // reads as intentional rather than a plain OLED-black void.
    background: Color(0xFF07090D),
    // One step up from background — cards, fields, selector tiles.
    surface: Color(0xFF10141B),
    // The single accent color: the serving side, the selected option,
    // the primary call to action.
    accent: Color(0xFFFF8A34),
    accentDim: Color(0xFFCC6E29),
    // Near-white, for the score digits and primary text.
    scoreText: Color(0xFFF5F7FA),
    // Secondary text: player labels, prompts.
    mutedText: Color(0xFF8B95A3),
    // Tertiary text: small labels and captions.
    faintText: Color(0xFF5E6978),
    // Surface borders and hairlines.
    divider: Color(0xFF232A35),
    success: Color(0xFF35C46A),
    error: Color(0xFFE5484D),
    onAccent: Color(0xFF07090D),
    accentSoft: Color(0xFFFFB27A),
    accentHighlight: Color(0xFFFFB27A),
    icon: Color(0xFFC9D1DB),
    neutralBar: Color(0xFF3A4350),
    disabledText: Color(0xFF4A5362),
    disabledFill: Color(0xFF141920),
    serverGlow: Color(0x38FF8A34),
    scoreGlow: Color(0x8CFF8A34),
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
    onAccent: Color(0xFF07090D),
    // On a light background the soft variant has to go *darker* than the
    // accent to stay readable as text, not lighter.
    accentSoft: Color(0xFFB8580F),
    accentHighlight: Color(0xFFF59A5C),
    icon: Color(0xFF3A4350),
    neutralBar: Color(0xFFB4BBC6),
    disabledText: Color(0xFF9AA2AE),
    disabledFill: Color(0xFFE9ECF0),
    serverGlow: Color(0x2EE06A1F),
    scoreGlow: Color(0x4DE06A1F),
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
    Color? accentSoft,
    Color? accentHighlight,
    Color? icon,
    Color? neutralBar,
    Color? disabledText,
    Color? disabledFill,
    Color? serverGlow,
    Color? scoreGlow,
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
      accentSoft: accentSoft ?? this.accentSoft,
      accentHighlight: accentHighlight ?? this.accentHighlight,
      icon: icon ?? this.icon,
      neutralBar: neutralBar ?? this.neutralBar,
      disabledText: disabledText ?? this.disabledText,
      disabledFill: disabledFill ?? this.disabledFill,
      serverGlow: serverGlow ?? this.serverGlow,
      scoreGlow: scoreGlow ?? this.scoreGlow,
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
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentHighlight: Color.lerp(accentHighlight, other.accentHighlight, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
      neutralBar: Color.lerp(neutralBar, other.neutralBar, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      disabledFill: Color.lerp(disabledFill, other.disabledFill, t)!,
      serverGlow: Color.lerp(serverGlow, other.serverGlow, t)!,
      scoreGlow: Color.lerp(scoreGlow, other.scoreGlow, t)!,
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
/// Two bundled families (see `pubspec.yaml`, `assets/fonts/`): Barlow
/// for all UI text, in exactly two weights — 500 and 600 — and Barlow
/// Condensed 900 for the score digits only. UI text is sentence case
/// with next to no tracking; nothing here is all-caps.
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

  static const uiFamily = 'Barlow';
  static const scoreFamily = 'BarlowCondensed';

  static TextStyle scoreDisplay(BuildContext context) => TextStyle(
        fontFamily: scoreFamily,
        fontSize: 250,
        height: 1.0,
        fontWeight: FontWeight.w900,
        color: context.palette.scoreText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle playerLabel(BuildContext context) => TextStyle(
        fontFamily: uiFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: context.palette.mutedText,
        letterSpacing: 0.4,
      );

  static TextStyle compactPlayerLabel(BuildContext context) => TextStyle(
        fontFamily: uiFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: context.palette.mutedText,
      );

  static TextStyle gamesLabel(BuildContext context) => TextStyle(
        fontFamily: uiFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.palette.faintText,
      );

  /// A small label above a control or group (e.g. "Best of",
  /// "Gewinnsätze", a doubles team's name) — names it without competing
  /// with it.
  static TextStyle eyebrow(BuildContext context) => TextStyle(
        fontFamily: uiFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.palette.faintText,
      );

  /// A sentence of guidance next to the control it refers to (the toss
  /// prompt).
  static TextStyle prompt(BuildContext context) => TextStyle(
        fontFamily: uiFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: context.palette.mutedText,
      );

  /// The name inside a setup-screen player field.
  static TextStyle fieldName(BuildContext context) => TextStyle(
        fontFamily: uiFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: context.palette.scoreText,
      );

  /// The energetic "Let's Play!" phrase shown during the match-start
  /// transition (Phase 4E) — large and confident enough to read as the
  /// full-screen moment's one focal point, but well below [scoreDisplay]
  /// since it's a brief flourish, not the score.
  static TextStyle transitionHeadline(BuildContext context) => TextStyle(
        fontFamily: uiFamily,
        fontSize: 40,
        fontWeight: FontWeight.w600,
        color: context.palette.scoreText,
      );
}

/// Touch targets sized for quick, imprecise courtside taps rather than
/// careful phone-in-hand browsing.
class AppMetrics {
  AppMetrics._();

  static const minTouchTarget = 56.0;

  /// The scoreboard toolbar's icons and their hit targets.
  static const iconButtonSize = 24.0;
  static const toolbarTouchTarget = 44.0;
}

/// Builds the app's [ThemeData] for one [brightness] — [AppPalette.dark]
/// or [AppPalette.light] — with that palette attached as a
/// [ThemeExtension] so [AppTypography] and any widget using
/// `context.palette` picks up the right colors. See
/// PHASE4F_THEME_AND_NAMES.md for why this became parameterized instead
/// of the single hardcoded dark theme from Phase 4B.
ThemeData buildAppTheme(Brightness brightness) {
  final palette =
      brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

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
    fontFamily: AppTypography.uiFamily,
    splashFactory: InkRipple.splashFactory,
    extensions: [palette],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.scoreText,
      iconTheme:
          IconThemeData(color: palette.icon, size: AppMetrics.iconButtonSize),
      titleTextStyle: TextStyle(
        fontFamily: AppTypography.uiFamily,
        color: palette.scoreText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize:
            const Size(AppMetrics.minTouchTarget, AppMetrics.minTouchTarget),
        foregroundColor: palette.icon,
        disabledForegroundColor: palette.disabledText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        disabledBackgroundColor: palette.disabledFill,
        disabledForegroundColor: palette.disabledText,
        elevation: 0,
        minimumSize: const Size.fromHeight(AppMetrics.minTouchTarget),
        textStyle: const TextStyle(
            fontFamily: AppTypography.uiFamily,
            fontSize: 17,
            fontWeight: FontWeight.w600),
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
            fontFamily: AppTypography.uiFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600),
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
            fontFamily: AppTypography.uiFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surface,
      contentTextStyle: TextStyle(
          fontFamily: AppTypography.uiFamily,
          color: palette.scoreText,
          fontSize: 16,
          fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.divider),
      ),
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      actionTextColor: palette.accent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: AppTypography.uiFamily,
        color: palette.scoreText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: TextStyle(
          fontFamily: AppTypography.uiFamily,
          color: palette.mutedText,
          fontSize: 16,
          fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(
        fontFamily: AppTypography.uiFamily,
        color: palette.onAccent,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(
          fontFamily: AppTypography.uiFamily, color: palette.scoreText),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
