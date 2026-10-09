import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The score digit, with a brief scale-in "pop" whenever [points] changes
/// — the one deliberate motion moment in the app (see
/// PHASE4B_UI_POLISH.md): tasteful, quick, and only for a real state
/// change, not decorative.
///
/// Implemented with [TweenAnimationBuilder] rather than [AnimatedSwitcher]
/// deliberately: `AnimatedSwitcher` keeps the outgoing *and* incoming
/// child mounted simultaneously for the length of the crossfade, which
/// would mean two `Text` widgets carrying the same test [key] existing at
/// once mid-transition — exactly the kind of transient state a single
/// `tester.pump()` in a widget test can catch, turning `find.byKey` into
/// "Bad state: too many elements". `TweenAnimationBuilder` only ever has
/// one instance of [key] mounted, so there's no such window.
class AnimatedScoreText extends StatelessWidget {
  final int points;
  final Key scoreKey;

  /// Adds a soft accent halo behind the digits — set for the serving
  /// side. A shadow only, so the digits' own color and size are the same
  /// on both sides.
  final bool glow;

  const AnimatedScoreText({
    super.key,
    required this.points,
    required this.scoreKey,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.scoreDisplay(context);
    final style = glow
        ? base.copyWith(shadows: [
            Shadow(color: context.palette.scoreGlow, blurRadius: 48),
          ])
        : base;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: TweenAnimationBuilder<double>(
        // Changing the key forces this whole subtree to be recreated
        // (rather than smoothly re-animated) whenever the score changes,
        // which is exactly what makes the tween restart from 1.25 -> 1.0
        // every time instead of only playing once.
        key: ValueKey(points),
        tween: Tween(begin: 1.25, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          child: child,
        ),
        child: Text(
          '$points',
          key: scoreKey,
          style: style,
        ),
      ),
    );
  }
}
