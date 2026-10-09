import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/hero_band.dart';

/// The "How to use" page: one scrolling column of short illustrated
/// cards, each covering a single thing the app does. Reached only from
/// the setup screen's menu — never shown on its own, and entirely
/// static: it reads nothing but the active locale and theme.
///
/// Every card describes behavior that already exists elsewhere (tap to
/// score, long-press to correct, undo, the server/receiver markers,
/// change of ends, doubles serving order, names/theme/language, mute);
/// if one of those changes, its card's text needs to change with it.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cards = [
      (Icons.touch_app, l10n.helpScoreTitle, l10n.helpScoreBody),
      (Icons.edit_outlined, l10n.helpCorrectTitle, l10n.helpCorrectBody),
      (Icons.undo, l10n.helpUndoTitle, l10n.helpUndoBody),
      // The same glyph the scoreboards use for the server/receiver
      // markers this card explains.
      (Icons.sports_tennis, l10n.helpServeTitle, l10n.helpServeBody),
      (Icons.swap_horiz, l10n.helpChangeEndsTitle, l10n.helpChangeEndsBody),
      (Icons.groups_outlined, l10n.helpDoublesTitle, l10n.helpDoublesBody),
      (Icons.tune, l10n.helpSetupTitle, l10n.helpSetupBody),
      (Icons.volume_up, l10n.helpVoiceTitle, l10n.helpVoiceBody),
    ];
    return Scaffold(
      body: Column(
        children: [
          HeroBand(
            leading: IconButton(
              key: const Key('helpBackButton'),
              icon: const Icon(Icons.arrow_back),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: l10n.helpTitle,
          ),
          Expanded(
            child: SafeArea(
              // The hero band above already handles the top inset.
              top: false,
              child: SingleChildScrollView(
                key: const Key('helpScrollView'),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, (icon, title, body)) in cards.indexed)
                      Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                        child: _HelpCard(icon: icon, title: title, body: body),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One help topic: a large accent icon on a translucent chip (the same
/// treatment as [ChipIconButton]), a short title, and one short line of
/// text, inside the bordered rounded box the setup screen already uses
/// for its doubles team previews.
class _HelpCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final iconChip = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.accent.withValues(alpha: 0.14),
      ),
      child: Icon(icon, size: 30, color: palette.accent),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.playerLabel(context)
              .copyWith(color: palette.scoreText, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: AppTypography.compactPlayerLabel(context)
              .copyWith(fontWeight: FontWeight.w500, height: 1.35),
        ),
      ],
    );
    // With a large system font, an icon column beside the text leaves
    // too narrow a strip for it on a small phone — the icon moves above
    // the text instead, giving the text the card's full width.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Container(
      key: const Key('helpCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [iconChip, const SizedBox(height: 12), text],
            )
          : Row(
              children: [
                iconChip,
                const SizedBox(width: 16),
                Expanded(child: text),
              ],
            ),
    );
  }
}
