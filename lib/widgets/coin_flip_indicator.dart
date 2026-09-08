import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A brief 3D coin-flip flourish shown while the toss result is being
/// decided, before it's revealed — see PHASE4C_TOSS_AND_TEAM_LABELS.md.
///
/// Follows the same pattern as `AnimatedScoreText` (Phase 4B): a single
/// [TweenAnimationBuilder] mount per toss, rather than [AnimatedSwitcher]
/// or two widgets cross-fading. The caller is expected to give this
/// widget a fresh `key` (e.g. keyed on a toss counter) each time a new
/// toss starts, so a repeated toss gets a brand-new animation run instead
/// of updating in place. [onComplete] fires exactly once, when the flip
/// finishes, via [TweenAnimationBuilder.onEnd] — the same "one clean
/// mount, no manual Timer" approach used for the score-pop animation.
class CoinFlipIndicator extends StatelessWidget {
  /// Called once, when the flip animation finishes.
  final VoidCallback onComplete;

  const CoinFlipIndicator({super.key, required this.onComplete});

  static const _duration = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _duration,
      curve: Curves.easeOutCubic,
      onEnd: onComplete,
      builder: (context, t, child) {
        // Three full rotations around the vertical axis, landing flat —
        // combined with the perspective entry below, this reads as a
        // coin tumbling and settling face-up, not a flat spin.
        final angle = t * (3 * 2 * pi);
        // A small scale "hop" that peaks mid-flip and settles back to
        // 1.0 exactly as the spin ends, suggesting the coin lifting and
        // landing rather than just rotating in place.
        final scale = 1.0 + 0.18 * sin(t * pi);
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0018)
          ..rotateY(angle)
          ..scaleByDouble(scale, scale, scale, 1);
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: child,
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
