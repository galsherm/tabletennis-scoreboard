import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The match-complete dialog, redesigned in Phase 4G to match the
/// premium visual language established in PHASE4B_UI_POLISH.md and
/// PHASE4E_MATCH_START_TRANSITION.md — the original was a bare default
/// `AlertDialog`, visually inconsistent with the rest of the app's
/// polish.
///
/// A trophy icon does a brief scale-in ("one deliberate motion moment,"
/// same philosophy as the score-pop animation) — tasteful and
/// celebratory without being childish, in keeping with the "premium
/// sports broadcast" direction the match-start transition set. The
/// winner announcement itself is large, bold, and centered, rather than
/// the small muted body text a default `AlertDialog` gives its content.
class MatchCompleteDialog extends StatelessWidget {
  /// e.g. "Match complete" — shown as a small muted eyebrow heading.
  final String titleText;

  /// e.g. "Team 1 wins the match!" — the full sentence, shown large and
  /// bold. Deliberately still one complete string (not split into a
  /// separate "winner name" + "wins the match" pair) so the exact
  /// existing localized message keeps working unchanged.
  final String messageText;

  final String buttonText;
  final VoidCallback onNewMatch;

  const MatchCompleteDialog({
    super.key,
    required this.titleText,
    required this.messageText,
    required this.buttonText,
    required this.onNewMatch,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Dialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1.0),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Icon(
                Icons.emoji_events,
                key: const Key('matchCompleteTrophyIcon'),
                size: 56,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              titleText.toUpperCase(),
              style: AppTypography.eyebrow(context),
            ),
            const SizedBox(height: 10),
            Text(
              messageText,
              key: const Key('matchCompleteMessageText'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: palette.scoreText,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('newMatchButton'),
                onPressed: onNewMatch,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
