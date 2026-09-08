import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../services/monetization_controller.dart';
import '../theme/app_theme.dart';

/// The Pro purchase dialog — opened either from the setup screen's
/// app-bar icon at any time, or automatically as an occasional post-match
/// upsell (see `MonetizationController.shouldOfferUpsell`). Shows the
/// buy/restore flow when the user hasn't purchased Pro yet, or a simple
/// confirmation once they have. Listens to
/// [MonetizationController.feedback] to show an inline status message for
/// every purchase-flow state — pending, success, restored, cancelled,
/// error, or "no previous purchase found" — so nothing about a tap on
/// "Remove Ads" or "Restore purchases" is ever silent.
///
/// The status message is shown inline (a `Text` inside this dialog's own
/// build), not via a `ScaffoldMessenger` SnackBar: a real-device bug
/// report ("tapping Remove Ads does nothing") traced back to exactly
/// that — Flutter freezes the ticker on a route once another route is
/// pushed above it, so a SnackBar triggered from a button *inside* this
/// dialog sits on the obscured Scaffold underneath and never actually
/// animates into view. The same bug, and the same fix, applied to
/// `MatchCompleteDialog`'s export confirmation in Phase 5 — see
/// PHASE5_MONETIZATION.md.
class ProDialog extends StatefulWidget {
  final MonetizationController monetization;

  const ProDialog({super.key, required this.monetization});

  @override
  State<ProDialog> createState() => _ProDialogState();
}

class _ProDialogState extends State<ProDialog> {
  StreamSubscription<PurchaseFeedback>? _subscription;
  PurchaseFeedback? _feedback;

  @override
  void initState() {
    super.initState();
    _subscription = widget.monetization.feedback.listen((feedback) {
      if (!mounted) return;
      setState(() => _feedback = feedback);
    });
  }

  String? _feedbackMessage(AppLocalizations l10n) {
    return switch (_feedback) {
      null => null,
      PurchaseFeedback.pending => l10n.proStatusPending,
      PurchaseFeedback.purchased => l10n.proStatusSuccess,
      PurchaseFeedback.restored => l10n.proStatusRestored,
      PurchaseFeedback.cancelled => l10n.proStatusCancelled,
      PurchaseFeedback.error => l10n.proStatusError,
      PurchaseFeedback.restoreNotFound => l10n.proStatusRestoreNotFound,
    };
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final feedbackMessage = _feedbackMessage(l10n);
    return ListenableBuilder(
      listenable: widget.monetization,
      builder: (context, _) {
        final isPro = widget.monetization.isPro;
        return Dialog(
          backgroundColor: palette.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPro ? Icons.verified : Icons.workspace_premium,
                  key: const Key('proDialogIcon'),
                  size: 48,
                  color: palette.accent,
                ),
                const SizedBox(height: 16),
                Text(
                  isPro ? l10n.proDialogAlreadyProTitle : l10n.proDialogTitle,
                  key: const Key('proDialogTitleText'),
                  style: AppTypography.eyebrow(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  isPro
                      ? l10n.proDialogAlreadyProBody
                      : l10n.proDialogDescriptionFree,
                  key: const Key('proDialogBodyText'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.mutedText),
                ),
                if (!isPro) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('proBuyButton'),
                      onPressed: widget.monetization.buyPro,
                      child: Text(l10n.proBuyButton),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const Key('proRestoreButton'),
                      onPressed: widget.monetization.restorePurchases,
                      child: Text(l10n.proRestoreButton),
                    ),
                  ),
                ],
                if (feedbackMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    feedbackMessage,
                    key: const Key('proFeedbackText'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
