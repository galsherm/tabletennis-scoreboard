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
///
/// Stateful since Phase 5, purely to show the "copied" confirmation for
/// the export button (see [_MatchCompleteDialogState._exported]) inline,
/// rather than via a `ScaffoldMessenger` SnackBar: Flutter freezes the
/// ticker on a route once another route is pushed above it, so a SnackBar
/// triggered by a button *inside* this dialog would sit on the obscured
/// Scaffold underneath and never actually animate into view — a real bug
/// a real user would hit, not just a test artifact. Showing the
/// confirmation inside the dialog's own (current, un-paused) route
/// sidesteps that entirely. See PHASE5_MONETIZATION.md.
class MatchCompleteDialog extends StatefulWidget {
  /// e.g. "Match complete" — shown as a small muted eyebrow heading.
  final String titleText;

  /// e.g. "Team 1 wins the match!" — the full sentence, shown large and
  /// bold. Deliberately still one complete string (not split into a
  /// separate "winner name" + "wins the match" pair) so the exact
  /// existing localized message keeps working unchanged.
  final String messageText;

  final String buttonText;
  final VoidCallback onNewMatch;

  /// Pro-only "Export match result" action (Phase 5) — both null together
  /// means no export button at all (free users, or Pro not yet loaded),
  /// so callers gate this by passing non-null only when
  /// `MonetizationController.isPro` is true rather than needing a
  /// separate boolean flag. See PHASE5_MONETIZATION.md.
  final String? exportButtonText;
  final VoidCallback? onExport;

  /// Shown in place of [exportButtonText] once [onExport] has been
  /// tapped, e.g. "Match result copied to clipboard" — required whenever
  /// [exportButtonText] is, since the button always needs *some* label to
  /// switch to once tapped.
  final String? exportedConfirmationText;

  const MatchCompleteDialog({
    super.key,
    required this.titleText,
    required this.messageText,
    required this.buttonText,
    required this.onNewMatch,
    this.exportButtonText,
    this.onExport,
    this.exportedConfirmationText,
  });

  @override
  State<MatchCompleteDialog> createState() => _MatchCompleteDialogState();
}

class _MatchCompleteDialogState extends State<MatchCompleteDialog> {
  bool _exported = false;

  void _handleExport() {
    widget.onExport?.call();
    setState(() => _exported = true);
  }

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
              widget.titleText.toUpperCase(),
              style: AppTypography.eyebrow(context),
            ),
            const SizedBox(height: 10),
            Text(
              widget.messageText,
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
                onPressed: widget.onNewMatch,
                child: Text(widget.buttonText),
              ),
            ),
            if (widget.exportButtonText != null && widget.onExport != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('exportMatchButton'),
                  onPressed: _exported ? null : _handleExport,
                  icon: Icon(_exported ? Icons.check : Icons.ios_share),
                  label: Text(_exported
                      ? (widget.exportedConfirmationText ??
                          widget.exportButtonText!)
                      : widget.exportButtonText!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
