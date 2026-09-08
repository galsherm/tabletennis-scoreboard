import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../services/monetization_controller.dart';
import '../theme/app_theme.dart';

/// The Pro purchase dialog, opened from the setup screen's app bar
/// (Phase 5). Shows the buy/restore flow when the user hasn't purchased
/// Pro yet, or a simple confirmation once they have. Listens to
/// [MonetizationController.feedback] to show a localized SnackBar for
/// every purchase-flow state — pending, success, restored, cancelled,
/// error, or "no previous purchase found" — so nothing about a tap on
/// "Remove Ads" or "Restore purchases" is ever silent. See
/// PHASE5_MONETIZATION.md.
class ProDialog extends StatefulWidget {
  final MonetizationController monetization;

  const ProDialog({super.key, required this.monetization});

  @override
  State<ProDialog> createState() => _ProDialogState();
}

class _ProDialogState extends State<ProDialog> {
  StreamSubscription<PurchaseFeedback>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.monetization.feedback.listen(_onFeedback);
  }

  void _onFeedback(PurchaseFeedback feedback) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = switch (feedback) {
      PurchaseFeedback.pending => l10n.proStatusPending,
      PurchaseFeedback.purchased => l10n.proStatusSuccess,
      PurchaseFeedback.restored => l10n.proStatusRestored,
      PurchaseFeedback.cancelled => l10n.proStatusCancelled,
      PurchaseFeedback.error => l10n.proStatusError,
      PurchaseFeedback.restoreNotFound => l10n.proStatusRestoreNotFound,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(key: const Key('proFeedbackSnackBar'), content: Text(message)),
    );
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
              ],
            ),
          ),
        );
      },
    );
  }
}
