import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The hero header shared by the setup screen and the help page —
/// introduced for the setup screen (Phase 4P), replacing the previous
/// plain Material `AppBar` — a large bold title sitting at the
/// *bottom*-left of a tall band, with the hamburger menu at its
/// top-left, doesn't fit a standard 56dp toolbar's layout at all. A
/// background with a large orange diagonal shape in the upper-right
/// corner echoes the app icon/feature graphic's own visual language.
/// Deliberately minimal: just [leading] (the setup screen's menu, the
/// help page's back button) and the title, no extra icons or subtitle.
///
/// Theme-aware via `context.palette` (Phase 4Q fix), the same as every
/// other themed surface in the app — it originally hardcoded
/// [AppPalette.dark] unconditionally here, which read fine in Dark mode
/// (the app's own default) but left this band the only element on the
/// setup screen that didn't switch when a user picked Light mode: a
/// dark band with white text sitting above an otherwise light screen.
/// The orange diagonal itself still resolves to `context.palette.accent`
/// rather than a fixed hex — the light palette's accent is already a
/// deepened, more saturated orange specifically so it keeps AA contrast
/// against a light background (see [AppPalette.light]'s doc and
/// PHASE4F_THEME_AND_NAMES.md's contrast tests), so no new color was
/// needed here.
class HeroBand extends StatelessWidget {
  final Widget leading;
  final String title;

  const HeroBand({super.key, required this.leading, required this.title});

  // Deliberately no `color` here — it's theme-dependent (near-white in
  // Dark, near-black in Light, matching `context.palette.scoreText`),
  // applied via `.copyWith` at each of this style's two use sites below
  // rather than baked into this shared base, since it doesn't affect
  // the `TextPainter` measurement either use site needs.
  static const _titleStyle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 32,
    fontWeight: FontWeight.w900,
  );

  @override
  Widget build(BuildContext context) {
    // No local `AnnotatedRegion<SystemUiOverlayStyle>` override here
    // (there used to be one, fixed to light-on-dark) — now that this
    // band's background genuinely follows the active theme, the
    // app-wide default status bar style main.dart already computes from
    // that same theme is correct for this band too, so a duplicate,
    // separately-maintained copy of that isDark logic isn't needed.
    return ColoredBox(
      key: const Key('heroBandBackground'),
      color: context.palette.background,
      child: SafeArea(
        // The scrollable body below has its own SafeArea(top: false) —
        // together they cover the full screen exactly once, with this
        // band owning the top inset (status bar/notch) since it's the
        // one that actually sits under it. Edge-to-edge (main.dart)
        // means this ColoredBox's background now genuinely extends up
        // underneath the status bar instead of stopping below an
        // opaque OS-drawn strip — SafeArea only pushes the *content*
        // (menu icon, title) down to clear it.
        bottom: false,
        child: Padding(
          // Only vertical padding here — the horizontal insets for the
          // menu/title live on the inner `contentPadding` below instead,
          // so `constraints.maxWidth` reflects the band's true full
          // width (edge to edge) rather than a width already shrunk by
          // a right-side inset. The diagonal is sized from this
          // `constraints.maxWidth` (see the `SizedBox`/`Positioned.fill`
          // below), so if this outer `Padding` ever grows a horizontal
          // component again, the wedge's right edge will stop short of
          // the actual screen edge by that amount instead of touching it.
          // Bottom inset trimmed from 20->12 (Phase 4Q): together with
          // the menu-to-title gap below, this is one of the two biggest
          // levers on the band's overall height. Edge-to-edge painting
          // under the status bar (main.dart) made the band noticeably
          // taller, which on shorter screens pushed "Start match" below
          // the fold — see PHASE4Q_FINAL_STORE_SCREENSHOTS.md.
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The menu/title content's own horizontal inset, kept
              // separate from the band's overall width so the diagonal
              // (painted at the band's full `constraints.maxWidth`) can
              // still reach the true right edge of the screen.
              const contentPadding = EdgeInsets.fromLTRB(4, 0, 24, 0);

              // Measured directly (rather than reading the rendered
              // Text's own size after layout) so the diagonal's
              // clearance is known in the very same build/paint pass —
              // no post-frame callback or extra rebuild needed. This is
              // what lets the wedge stay clear of the title in every
              // shipped language: a longer translation (e.g. "Nouveau
              // match") simply pushes the wedge further right instead
              // of running underneath it, which a fixed 55%/40% split
              // could not account for. See the "hero band" section of
              // PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md.
              final titlePainter = TextPainter(
                text: TextSpan(text: title, style: _titleStyle),
                textDirection: Directionality.of(context),
                maxLines: 1,
              )..layout(
                  maxWidth: constraints.maxWidth - contentPadding.horizontal);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HeroDiagonalPainter(
                        color: context.palette.accent,
                        // The text's own left inset offsets where it
                        // actually ends, in the same left-edge-of-band
                        // coordinate space the wedge is painted in.
                        titleRight: contentPadding.left + titlePainter.width,
                      ),
                    ),
                  ),
                  // Without this explicit width, a `Stack` sizes itself
                  // to fit only its non-positioned children when (as
                  // here, inside a `Column`) its own height constraint
                  // is unbounded — so it would shrink-wrap to whichever
                  // of the menu icon or the title text is wider,
                  // nowhere near the band's actual full width. That
                  // starved the `Positioned.fill` diagonal above of
                  // most of its canvas: it was never actually painting
                  // across the true upper-right corner of the screen,
                  // only a corner of this much narrower box — which is
                  // exactly why the diagonal used to visibly cut
                  // through the title's own text (the box was barely
                  // wider than the text itself).
                  SizedBox(
                    width: constraints.maxWidth,
                    child: Padding(
                      padding: contentPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Forces the hamburger's own icon color to
                          // `context.palette.scoreText` — this button
                          // sits directly on the hero band's own
                          // background (now `context.palette.background`
                          // too, see the class doc above), not on
                          // `AppPalette.surface` the way it used to (on
                          // an `AppBar`), so it needs the same
                          // "maximum contrast against background" role
                          // `scoreText` already plays for the score
                          // digits, rather than the theme's default
                          // icon color (derived for `AppPalette.surface`,
                          // a different background). Only affects this
                          // button's own theme-derived default; the
                          // flyout menu it opens still uses the app's
                          // real `AppPalette.surface` (baked into
                          // `_menuStyle`/`_menuItemStyle` explicitly,
                          // before this widget ever sees it), unaffected
                          // by this override.
                          Theme(
                            data: Theme.of(context).copyWith(
                              iconButtonTheme: IconButtonThemeData(
                                style: IconButton.styleFrom(
                                    foregroundColor: context.palette.scoreText),
                              ),
                            ),
                            child: leading,
                          ),
                          // Trimmed from 32->18 (Phase 4Q) to keep the
                          // hero band's overall height in check — see
                          // the outer `Padding`'s comment above.
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: _titleStyle.copyWith(
                                color: context.palette.scoreText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Paints the hero band's orange diagonal — a slanted wedge occupying
/// the band's upper-right corner, the same "dark near-black split by an
/// orange diagonal" motif as the app icon and Play Store feature
/// graphic. A `CustomPainter` (rather than a `ClipPath`/`Container`
/// pair) so the shape always fills exactly this band's actual size,
/// whatever that ends up being, without hand-tuning pixel offsets.
class _HeroDiagonalPainter extends CustomPainter {
  final Color color;
  final double titleRight;

  const _HeroDiagonalPainter({required this.color, required this.titleRight});

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

    final path = Path()
      ..moveTo(topX, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(bottomX, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HeroDiagonalPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.titleRight != titleRight;
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
