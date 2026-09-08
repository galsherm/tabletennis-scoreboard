import 'dart:math';

import 'package:flutter/material.dart';

import '../models/player.dart';
import '../theme/app_theme.dart';

/// A brief 3D coin-flip flourish shown while the toss result is being
/// decided. The winning side's label is legible right on the coin face
/// once it lands — not as separate text elsewhere on screen — see
/// PHASE4C_TOSS_AND_TEAM_LABELS.md.
///
/// Follows the same pattern as `AnimatedScoreText` (Phase 4B): a single
/// [TweenAnimationBuilder] mount per toss, rather than [AnimatedSwitcher]
/// or two widgets cross-fading. The caller is expected to give this
/// widget a fresh `key` (e.g. keyed on a toss counter) each time a new
/// toss starts, so a repeated toss gets a brand-new animation run instead
/// of updating in place. [onComplete] fires exactly once, when the flip
/// finishes, via [TweenAnimationBuilder.onEnd] — the same "one clean
/// mount, no manual Timer" approach used for the score-pop animation.
///
/// The coin has two fixed faces — [player1Label] is always "heads,"
/// [player2Label] is always "tails" — and [winner] decides only how many
/// half-turns the flip makes: an integer number of full turns lands
/// heads-up, one extra half-turn lands tails-up. Either way exactly one
/// face is ever built at a time (a hard cut at the rotation's midpoint,
/// like a real coin — never a cross-fade), so there's never a moment with
/// two same-keyed widgets mounted together.
class CoinFlipIndicator extends StatelessWidget {
  /// Shown on the coin's "heads" face.
  final String player1Label;

  /// Shown on the coin's "tails" face.
  final String player2Label;

  /// Which side the coin must come to rest showing.
  final Player winner;

  /// Called once, when the flip animation finishes.
  final VoidCallback onComplete;

  const CoinFlipIndicator({
    super.key,
    required this.player1Label,
    required this.player2Label,
    required this.winner,
    required this.onComplete,
  });

  static const _duration = Duration(milliseconds: 700);

  /// Enlarged from Phase 4C's original 40 — a two-word label needs more
  /// room to read clearly than the plain disc did.
  static const _diameter = 88.0;

  @override
  Widget build(BuildContext context) {
    // 3 full turns lands heads-up (player1Label); one extra half-turn
    // lands tails-up instead. Same overall spin either way — only the
    // resting face differs.
    final turns = winner == Player.one ? 3.0 : 3.5;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _duration,
      curve: Curves.easeOutCubic,
      onEnd: onComplete,
      builder: (context, t, child) {
        // Perspective + rotation, exactly as before — only what's on the
        // face changed, not the motion.
        final angle = t * (turns * 2 * pi);
        final scale = 1.0 + 0.18 * sin(t * pi);
        final showHeads = cos(angle) >= 0;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0018)
          ..rotateY(angle)
          ..scaleByDouble(scale, scale, scale, 1);
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: _CoinFace(
            label: showHeads ? player1Label : player2Label,
            // The "tails" face is being viewed through the back of the
            // rotation, so its content needs pre-mirroring horizontally
            // or it would read backwards once rotated into view.
            mirrored: !showHeads,
          ),
        );
      },
    );
  }
}

class _CoinFace extends StatelessWidget {
  final String label;
  final bool mirrored;

  const _CoinFace({required this.label, required this.mirrored});

  @override
  Widget build(BuildContext context) {
    final face = Container(
      width: CoinFlipIndicator._diameter,
      height: CoinFlipIndicator._diameter,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          key: const Key('coinFaceLabel'),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
    );
    if (!mirrored) return face;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1, 1, 1, 1),
      child: face,
    );
  }
}
