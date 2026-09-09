import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';

/// The lightweight inline stepper opened by long-pressing a score digit
/// (Phase 4M) — a fast fix for an accidental/missed tap, deliberately
/// *not* a separate full "edit mode" screen: it's a small dialog
/// anchored to the same action (a long-press right where the score is),
/// showing only a stepper for the one number being corrected, nothing
/// else on screen changes. See PHASE4M_QUICK_SCORE_CORRECTION.md.
///
/// Purely a number picker bounded by [maxValue] — it has no idea *why*
/// that's the ceiling (the caller/engine already worked out that a
/// higher value would already be a won game, via
/// `TableTennisScoringEngine.maxCorrectablePoints`); this widget only
/// enforces "stay within [0, maxValue]", the same job a `Slider` or
/// `NumberPicker` would do.
///
/// Returns the confirmed value via `Navigator.pop(context, value)`, or
/// `null` if dismissed/cancelled — the caller decides what to do with
/// that (see `ScoreboardScreen._correctScore`).
class ScoreCorrectorDialog extends StatefulWidget {
  final String playerLabel;
  final int initialValue;
  final int maxValue;

  const ScoreCorrectorDialog({
    super.key,
    required this.playerLabel,
    required this.initialValue,
    required this.maxValue,
  });

  @override
  State<ScoreCorrectorDialog> createState() => _ScoreCorrectorDialogState();
}

class _ScoreCorrectorDialogState extends State<ScoreCorrectorDialog> {
  late int _value = widget.initialValue.clamp(0, widget.maxValue);

  void _decrement() {
    if (_value <= 0) return;
    setState(() => _value--);
  }

  void _increment() {
    if (_value >= widget.maxValue) return;
    setState(() => _value++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('scoreCorrectorDialog'),
      title: Text(l10n.correctScoreDialogTitle(widget.playerLabel)),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const Key('scoreCorrectorDecrement'),
            icon: const Icon(Icons.remove_circle_outline),
            iconSize: 32,
            onPressed: _value > 0 ? _decrement : null,
          ),
          SizedBox(
            width: 72,
            child: Text(
              '$_value',
              key: const Key('scoreCorrectorValue'),
              textAlign: TextAlign.center,
              style: AppTypography.transitionHeadline(context),
            ),
          ),
          IconButton(
            key: const Key('scoreCorrectorIncrement'),
            icon: const Icon(Icons.add_circle_outline),
            iconSize: 32,
            onPressed: _value < widget.maxValue ? _increment : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('scoreCorrectorCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.correctScoreCancelButton),
        ),
        TextButton(
          key: const Key('scoreCorrectorConfirm'),
          onPressed: () => Navigator.of(context).pop(_value),
          child: Text(l10n.correctScoreConfirmButton),
        ),
      ],
    );
  }
}
