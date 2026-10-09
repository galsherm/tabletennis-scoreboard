import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The hero header shared by the setup screen and the help page —
/// introduced for the setup screen (Phase 4P), replacing the previous
/// plain Material `AppBar` — a large title sitting at the *bottom*-left
/// of a tall band, with the hamburger menu at its top-left, doesn't fit
/// a standard 56dp toolbar's layout at all. A background with a large
/// orange diagonal shape in the upper-right corner echoes the app
/// icon/feature graphic's own visual language. Deliberately minimal:
/// just [leading] (the setup screen's menu, the help page's back
/// button) and the title, no extra icons or subtitle.
///
/// The "Arena" pass added two purely decorative layers around that: a
/// thin accent bar across the very top of the screen, and a soft accent
/// glow radiating from the top-right corner, which is allowed to spill
/// past the band's own bottom edge so it fades out over the screen
/// below instead of being cut off in a hard line.
///
/// Theme-aware via `context.palette` (Phase 4Q fix), the same as every
/// other themed surface in the app — it originally hardcoded
/// [AppPalette.dark] unconditionally here, which read fine in Dark mode
/// (the app's own default) but left this band the only element on the
/// setup screen that didn't switch when a user picked Light mode. The
/// orange diagonal resolves to `context.palette.accent` rather than a
/// fixed hex — the light palette's accent is already a deepened, more
/// saturated orange specifically so it keeps AA contrast against a
/// light background (see [AppPalette.light]'s doc and
/// PHASE4F_THEME_AND_NAMES.md's contrast tests).
class HeroBand extends StatelessWidget {
  final Widget leading;
  final String title;

  const HeroBand({super.key, required this.leading, required this.title});

  // Deliberately no `color` here — it's theme-dependent (near-white in
  // Dark, near-black in Light, matching `context.palette.scoreText`),
  // applied via `.copyWith` where the title is built rather than baked
  // into this shared base, since it doesn't affect the `TextPainter`
  // measurement.
  static const _titleStyle = TextStyle(
    fontFamily: AppTypography.uiFamily,
    fontSize: 46,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
  );

  /// The title may wrap onto a second line, but never further.
  static const _titleMaxLines = 2;

  /// How much of the band's width the title may take before wrapping —
  /// the rest is the diagonal's.
  static const _titleWidthFraction = 0.62;

  /// The diagonal covers the top of the band only; a two-line title
  /// makes the band taller, not the wedge.
  static const _wedgeMaxHeight = 114.0;

  static const _accentBarHeight = 4.0;

  /// Lays the title out within [maxWidth], shrinking the font only as
  /// far as needed for its longest single word to fit on a line — a
  /// large system font or a long translated word then gets a smaller
  /// title instead of one broken mid-word.
  static TextPainter _layoutTitle(
    String title,
    double maxWidth,
    TextScaler textScaler,
    TextDirection textDirection,
  ) {
    TextPainter paint(String text, TextStyle style, {int? maxLines}) =>
        TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: textDirection,
          textScaler: textScaler,
          maxLines: maxLines,
        );

    var style = _titleStyle;
    var widestWord = 0.0;
    for (final word in title.split(RegExp(r'\s+'))) {
      final painter = paint(word, style)..layout();
      widestWord = max(widestWord, painter.width);
      painter.dispose();
    }
    if (widestWord > maxWidth && widestWord > 0) {
      style = style.copyWith(
          fontSize: _titleStyle.fontSize! * maxWidth / widestWord);
    }
    return paint(title, style, maxLines: _titleMaxLines)
      ..layout(maxWidth: maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowRadius = MediaQuery.sizeOf(context).width * 0.95;

    // No local `AnnotatedRegion<SystemUiOverlayStyle>` override here
    // (there used to be one, fixed to light-on-dark) — now that this
    // band's background genuinely follows the active theme, the
    // app-wide default status bar style main.dart already computes from
    // that same theme is correct for this band too.
    return ColoredBox(
      key: const Key('heroBandBackground'),
      color: palette.background,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Centered on the screen's top-right corner and larger than
          // the band, so (with `Clip.none` above) its lower part falls
          // on the screen below the band. Nothing below paints an
          // opaque background over it — only its own content.
          Positioned(
            top: -glowRadius,
            right: -glowRadius,
            width: glowRadius * 2,
            height: glowRadius * 2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      palette.accent.withValues(alpha: isDark ? 0.28 : 0.16),
                      palette.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _accentBarHeight,
            child: ColoredBox(color: palette.accent),
          ),
          SafeArea(
            // The scrollable body below has its own SafeArea(top: false)
            // — together they cover the full screen exactly once, with
            // this band owning the top inset (status bar/notch) since
            // it's the one that actually sits under it. Edge-to-edge
            // (main.dart) means this band's background genuinely extends
            // up underneath the status bar — SafeArea only pushes the
            // *content* (menu icon, title) down to clear it.
            bottom: false,
            child: Padding(
              // Only vertical padding here — the horizontal insets for
              // the menu/title live on the inner paddings below instead,
              // so `constraints.maxWidth` reflects the band's true full
              // width (edge to edge). The diagonal is sized from this
              // `constraints.maxWidth`, so if this outer `Padding` ever
              // grows a horizontal component again, the wedge's right
              // edge will stop short of the actual screen edge by that
              // amount instead of touching it.
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The hamburger's own icon padding already insets it,
                  // so it gets a small one; the title lines up with the
                  // body content below (24).
                  const leadingInset = 4.0;
                  const titleInset = 24.0;

                  // Measured directly (rather than reading the rendered
                  // Text's own size after layout) so the diagonal's
                  // clearance is known in the very same build/paint pass
                  // — no post-frame callback or extra rebuild needed.
                  // This is what lets the wedge stay clear of the title
                  // in every shipped language. See the "hero band"
                  // section of PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md.
                  final titleMaxWidth = max(0.0,
                      constraints.maxWidth * _titleWidthFraction - titleInset);
                  final titlePainter = _layoutTitle(
                    title,
                    titleMaxWidth,
                    MediaQuery.textScalerOf(context),
                    Directionality.of(context),
                  );
                  final titleStyle = titlePainter.text!.style!;
                  final titleWidth = titlePainter.width;
                  titlePainter.dispose();

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _HeroDiagonalPainter(
                            color: palette.accent,
                            // The text's own left inset offsets where it
                            // actually ends, in the same
                            // left-edge-of-band coordinate space the
                            // wedge is painted in.
                            titleRight: titleInset + titleWidth,
                            maxHeight: _wedgeMaxHeight,
                          ),
                        ),
                      ),
                      // Without this explicit width, a `Stack` sizes
                      // itself to fit only its non-positioned children
                      // when (as here, inside a `Column`) its own height
                      // constraint is unbounded — so it would
                      // shrink-wrap to whichever of the menu icon or the
                      // title text is wider, starving the
                      // `Positioned.fill` diagonal above of most of its
                      // canvas.
                      SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Forces the leading button's icon color to
                            // `scoreText` — it sits directly on this
                            // band's background, so it takes the same
                            // "maximum contrast against background" role
                            // as the title, rather than the toolbar
                            // icons' quieter default. Only affects this
                            // button; the flyout menu it opens has its
                            // own explicit styles.
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: leadingInset),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  iconButtonTheme: IconButtonThemeData(
                                    style: IconButton.styleFrom(
                                        foregroundColor: palette.scoreText),
                                  ),
                                ),
                                child: leading,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.only(left: titleInset),
                              // The same width limit the measurement
                              // above used, so the text wraps exactly
                              // as measured.
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxWidth: titleMaxWidth),
                                child: Text(
                                  title,
                                  maxLines: _titleMaxLines,
                                  style: titleStyle.copyWith(
                                      color: palette.scoreText),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the hero band's orange diagonal — a slanted wedge occupying
/// the band's upper-right corner, the same "dark near-black split by an
/// orange diagonal" motif as the app icon and Play Store feature
/// graphic. A `CustomPainter` (rather than a `ClipPath`/`Container`
/// pair) so the shape always follows this band's actual size without
/// hand-tuning pixel offsets.
class _HeroDiagonalPainter extends CustomPainter {
  final Color color;
  final double titleRight;

  /// The wedge stops this far down even when the band itself is taller.
  final double maxHeight;

  const _HeroDiagonalPainter({
    required this.color,
    required this.titleRight,
    required this.maxHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bottomX =
        heroDiagonalBottomX(bandWidth: size.width, titleRight: titleRight);
    // The top edge trails the bottom edge by a fixed offset so the wedge
    // keeps the same slanted look as before when there's no title to
    // dodge, but never crosses to the *left* of the (now possibly
    // pushed-right) bottom edge.
    final topLower = size.width * 0.55;
    final topUpper = max(topLower, size.width - 16.0);
    final topX = (bottomX + size.width * 0.15).clamp(topLower, topUpper);
    final bottomY = min(size.height, maxHeight);

    final path = Path()
      ..moveTo(topX, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, bottomY)
      ..lineTo(bottomX, bottomY)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HeroDiagonalPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.titleRight != titleRight ||
      oldDelegate.maxHeight != maxHeight;
}

/// The hero band diagonal's bottom-edge x-coordinate: how far right the
/// wedge's lower corner sits, given the band's own width and how far
/// right the title text actually extends (`titleRight`, measured from
/// the same left edge the wedge and the title share).
///
/// Kept clamped between two bounds so the fix for one problem doesn't
/// create another: it never sits left of the title text plus a small
/// clearance (that was the original overlap bug — see the "hero band"
/// section of PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md), but it also
/// never crosses all the way to the band's right edge, so even a title
/// that fills almost the entire band width still leaves a visible sliver
/// of the wedge — the brand motif never fully disappears.
///
/// A plain top-level function (rather than folded into
/// [_HeroDiagonalPainter]'s paint method) so this clearance invariant is
/// directly unit-testable without pumping a widget or rendering a frame.
double heroDiagonalBottomX({
  required double bandWidth,
  required double titleRight,
}) {
  const clearance = 16.0;
  const minWedgeWidth = 32.0;
  final lowerBound = bandWidth * 0.40;
  final upperBound = max(0.0, bandWidth - minWedgeWidth);
  if (lowerBound >= upperBound) return upperBound;
  return (titleRight + clearance).clamp(lowerBound, upperBound);
}
