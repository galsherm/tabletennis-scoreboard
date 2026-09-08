import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/player.dart';
import 'doubles_scoreboard_screen.dart';
import 'scoreboard_screen.dart';

/// Menu-item identity for the language picker. A plain `PopupMenuButton
/// <Locale?>` can't represent "System default" as `value: null`: Flutter's
/// own [PopupMenuButton] treats a `null` selection the same as the menu
/// being dismissed with no choice made, so `onSelected` is never called
/// for it (see `popup_menu.dart`'s `_PopupMenuButtonState._handleMenu`) —
/// this enum sidesteps that by giving "system" its own non-null value.
enum _LanguageMenuOption { system, en, de, fr }

class SetupScreen extends StatefulWidget {
  /// Current manual language override, or null to follow the device
  /// locale. Used only to show a checkmark against the active choice in
  /// the language menu.
  final Locale? currentLocaleOverride;

  /// Called with the newly chosen override, or null to go back to
  /// following the device locale.
  final ValueChanged<Locale?> onLocaleChanged;

  const SetupScreen({
    super.key,
    required this.currentLocaleOverride,
    required this.onLocaleChanged,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _bestOf = 5;
  bool _isDoubles = false;
  Player? _firstServer;

  void _tossCoin() {
    setState(() {
      _firstServer = Random().nextBool() ? Player.one : Player.two;
    });
  }

  void _start() {
    final firstServer = _firstServer;
    if (firstServer == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _isDoubles
            ? DoublesScoreboardScreen(
                bestOf: _bestOf,
                firstServingTeam: firstServer,
              )
            : ScoreboardScreen(
                bestOf: _bestOf,
                firstServer: firstServer,
              ),
      ),
    );
  }

  void _onLanguageOptionSelected(_LanguageMenuOption option) {
    switch (option) {
      case _LanguageMenuOption.system:
        widget.onLocaleChanged(null);
      case _LanguageMenuOption.en:
        widget.onLocaleChanged(const Locale('en'));
      case _LanguageMenuOption.de:
        widget.onLocaleChanged(const Locale('de'));
      case _LanguageMenuOption.fr:
        widget.onLocaleChanged(const Locale('fr'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newMatchScreenTitle),
        actions: [
          PopupMenuButton<_LanguageMenuOption>(
            key: const Key('languageMenuButton'),
            icon: const Icon(Icons.language),
            tooltip: l10n.languageMenuTooltip,
            onSelected: _onLanguageOptionSelected,
            itemBuilder: (context) => [
              CheckedPopupMenuItem<_LanguageMenuOption>(
                key: const Key('languageOptionSystem'),
                value: _LanguageMenuOption.system,
                checked: widget.currentLocaleOverride == null,
                child: Text(l10n.languageSystemOption),
              ),
              CheckedPopupMenuItem<_LanguageMenuOption>(
                key: const Key('languageOptionEn'),
                value: _LanguageMenuOption.en,
                checked: widget.currentLocaleOverride == const Locale('en'),
                // Language names are always shown in their own language,
                // not translated, so a reader can find their language
                // regardless of what the UI currently displays.
                child: const Text('English'),
              ),
              CheckedPopupMenuItem<_LanguageMenuOption>(
                key: const Key('languageOptionDe'),
                value: _LanguageMenuOption.de,
                checked: widget.currentLocaleOverride == const Locale('de'),
                child: const Text('Deutsch'),
              ),
              CheckedPopupMenuItem<_LanguageMenuOption>(
                key: const Key('languageOptionFr'),
                value: _LanguageMenuOption.fr,
                checked: widget.currentLocaleOverride == const Locale('fr'),
                child: const Text('Français'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              key: const Key('modeSelector'),
              segments: [
                ButtonSegment(value: false, label: Text(l10n.modeSinglesOption)),
                ButtonSegment(value: true, label: Text(l10n.modeDoublesOption)),
              ],
              selected: {_isDoubles},
              onSelectionChanged: (selection) {
                setState(() => _isDoubles = selection.first);
              },
            ),
            if (_isDoubles) ...[
              const SizedBox(height: 16),
              Row(
                key: const Key('doublesPlayerSlots'),
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(children: [
                    Text(l10n.player1Label),
                    Text(l10n.player2Label),
                  ]),
                  Column(children: [
                    Text(l10n.player3Label),
                    Text(l10n.player4Label),
                  ]),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text(l10n.bestOfLabel),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              key: const Key('bestOfSelector'),
              segments: [3, 5, 7]
                  .map((bestOf) => ButtonSegment(
                        value: bestOf,
                        // English/French show the raw best-of-N number;
                        // German shows "N Gewinnsätze" (games needed to
                        // *win*) instead — see bestOfSegmentLabel's ARB
                        // description and PHASE3_VERIFICATION.md. The
                        // underlying `bestOf` value passed to the engine
                        // is unaffected either way.
                        label: Text(l10n.bestOfSegmentLabel(
                          bestOf,
                          (bestOf ~/ 2) + 1,
                        )),
                      ))
                  .toList(),
              selected: {_bestOf},
              onSelectionChanged: (selection) {
                setState(() => _bestOf = selection.first);
              },
            ),
            const SizedBox(height: 32),
            Text(
              _firstServer == null
                  ? l10n.tossPrompt
                  : l10n.firstServerLabel(_firstServer == Player.one
                      ? l10n.player1Label
                      : l10n.player2Label),
              key: const Key('firstServerLabel'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('tossButton'),
              onPressed: _tossCoin,
              child: Text(l10n.tossButton),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              key: const Key('startMatchButton'),
              onPressed: _firstServer == null ? null : _start,
              child: Text(l10n.startMatchButton),
            ),
          ],
        ),
      ),
    );
  }
}
