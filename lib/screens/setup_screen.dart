import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/player.dart';
import '../models/player_names.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_flip_indicator.dart';
import '../widgets/editable_name_label.dart';
import 'doubles_scoreboard_screen.dart';
import 'match_transition_screen.dart';
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

  /// Current Light/Dark/System theme choice (Phase 4F), shown as a
  /// checkmark in the theme menu.
  final ThemeMode themeMode;

  /// Called with the newly chosen theme mode.
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SetupScreen({
    super.key,
    required this.currentLocaleOverride,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _bestOf = 5;
  bool _isDoubles = false;
  Player? _firstServer;

  /// Custom names set on this screen — slots 1/2 for singles, slots 1-4
  /// (plus optional team names) for doubles — carried into the
  /// scoreboard screen when the match starts. Since Phase 4H, this is
  /// the *only* place names can be edited: once a match starts, the
  /// scoreboard renders whatever's here as plain, uneditable text. See
  /// PHASE4H_NAME_EDITING_REFINEMENT.md.
  final _names = PlayerNames();

  /// The toss outcome, decided the instant the coin is tossed — not
  /// withheld for suspense, since the flip's job is purely to show it
  /// (see [CoinFlipIndicator]'s `winner` param, which uses this to decide
  /// which face the coin comes to rest on). `null` means no toss yet.
  Player? _pendingResult;

  /// Bumped on every toss so [CoinFlipIndicator] gets a fresh `key` each
  /// time — a repeated tap gets a brand-new animation mount rather than
  /// updating an existing one in place (the same one-clean-mount pattern
  /// `AnimatedScoreText` uses, keyed on the score instead).
  int _tossSequence = 0;

  void _tossCoin() {
    setState(() {
      _pendingResult = Random().nextBool() ? Player.one : Player.two;
      _firstServer = null;
      _tossSequence++;
    });
  }

  /// [CoinFlipIndicator.onComplete] — the flip has finished, so
  /// [_firstServer] (and therefore "Start match") can now be enabled.
  void _onCoinFlipComplete() {
    setState(() => _firstServer = _pendingResult);
  }

  /// "Player 1"/"Player 2" for singles; "Team 1"/"Team 2" for doubles —
  /// with 4 players on screen, "Player 1" is ambiguous about whether it
  /// means one specific individual or an entire side, so doubles gets its
  /// own wording for side-level text (the toss result and the game/
  /// match-complete banners). The four individual on-court labels
  /// (Player 1–4) and their serve/receive icons are unaffected.
  String _sideLabel(AppLocalizations l10n, Player player) {
    if (_isDoubles) {
      return player == Player.one ? l10n.team1Label : l10n.team2Label;
    }
    return player == Player.one ? l10n.player1Label : l10n.player2Label;
  }

  void _start() {
    final firstServer = _firstServer;
    if (firstServer == null) return;
    final destination = _isDoubles
        ? DoublesScoreboardScreen(
            bestOf: _bestOf,
            firstServingTeam: firstServer,
            initialNames: _names,
          )
        : ScoreboardScreen(
            bestOf: _bestOf,
            firstServer: firstServer,
            initialNames: _names,
          );
    // A brief ball-flyby transition plays first, then replaces itself
    // with `destination` — see MatchTransitionScreen and
    // PHASE4D_TEAM_CLARITY_AND_TRANSITION.md.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchTransitionScreen(destination: destination),
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

  Widget _eyebrow(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(), style: AppTypography.eyebrow(context)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newMatchScreenTitle),
        actions: [
          PopupMenuButton<ThemeMode>(
            key: const Key('themeMenuButton'),
            icon: const Icon(Icons.brightness_6),
            tooltip: l10n.themeMenuTooltip,
            onSelected: widget.onThemeModeChanged,
            itemBuilder: (context) => [
              CheckedPopupMenuItem<ThemeMode>(
                key: const Key('themeOptionSystem'),
                value: ThemeMode.system,
                checked: widget.themeMode == ThemeMode.system,
                child: Text(l10n.themeSystemOption),
              ),
              CheckedPopupMenuItem<ThemeMode>(
                key: const Key('themeOptionLight'),
                value: ThemeMode.light,
                checked: widget.themeMode == ThemeMode.light,
                child: Text(l10n.themeLightOption),
              ),
              CheckedPopupMenuItem<ThemeMode>(
                key: const Key('themeOptionDark'),
                value: ThemeMode.dark,
                checked: widget.themeMode == ThemeMode.dark,
                child: Text(l10n.themeDarkOption),
              ),
            ],
          ),
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
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                key: const Key('modeSelector'),
                segments: [
                  ButtonSegment(
                      value: false, label: Text(l10n.modeSinglesOption)),
                  ButtonSegment(
                      value: true, label: Text(l10n.modeDoublesOption)),
                ],
                selected: {_isDoubles},
                onSelectionChanged: (selection) {
                  setState(() => _isDoubles = selection.first);
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_isDoubles
                    ? Padding(
                        padding: const EdgeInsets.only(top: 20),
                        // The same tap-to-rename preview doubles already
                        // had — singles previously had no equivalent
                        // step at all. See
                        // PHASE4H_NAME_EDITING_REFINEMENT.md.
                        child: Row(
                          key: const Key('singlesPlayerNames'),
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            EditableNameLabel(
                              displayName:
                                  _names.resolve(1, l10n.player1Label),
                              defaultLabel: l10n.player1Label,
                              style: AppTypography.playerLabel(context),
                              editHint: l10n.editNameHint,
                              textKey: const Key('player1PreviewNameText'),
                              fieldKey:
                                  const Key('player1PreviewNameField'),
                              onChanged: (name) =>
                                  setState(() => _names.set(1, name)),
                            ),
                            EditableNameLabel(
                              displayName:
                                  _names.resolve(2, l10n.player2Label),
                              defaultLabel: l10n.player2Label,
                              style: AppTypography.playerLabel(context),
                              editHint: l10n.editNameHint,
                              textKey: const Key('player2PreviewNameText'),
                              fieldKey:
                                  const Key('player2PreviewNameField'),
                              onChanged: (name) =>
                                  setState(() => _names.set(2, name)),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Row(
                          key: const Key('doublesPlayerSlots'),
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _TeamSlotPreview(
                              teamNumber: 1,
                              defaultTeamLabel: l10n.team1Label,
                              teamLabelKey: const Key('team1PreviewHeading'),
                              slots: const [1, 2],
                              defaultLabels: [
                                l10n.player1Label,
                                l10n.player2Label
                              ],
                              names: _names,
                              editHint: l10n.editNameHint,
                              onNameChanged: (slot, name) =>
                                  setState(() => _names.set(slot, name)),
                              onTeamNameChanged: (name) => setState(
                                  () => _names.setTeam(1, name)),
                            ),
                            _TeamSlotPreview(
                              teamNumber: 2,
                              defaultTeamLabel: l10n.team2Label,
                              teamLabelKey: const Key('team2PreviewHeading'),
                              slots: const [3, 4],
                              defaultLabels: [
                                l10n.player3Label,
                                l10n.player4Label
                              ],
                              names: _names,
                              editHint: l10n.editNameHint,
                              onNameChanged: (slot, name) =>
                                  setState(() => _names.set(slot, name)),
                              onTeamNameChanged: (name) => setState(
                                  () => _names.setTeam(2, name)),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 28),
              _eyebrow(l10n.bestOfLabel),
              SegmentedButton<int>(
                key: const Key('bestOfSelector'),
                segments: [3, 5, 7]
                    .map((bestOf) => ButtonSegment(
                          value: bestOf,
                          // Every language shows a bare number here — the
                          // explanatory word lives once, in the eyebrow
                          // heading above ("Best of" / "Gewinnsätze" /
                          // "Au meilleur de"), never inside the segment
                          // itself. German used to embed "Gewinnsätze" in
                          // each segment, tripling its text versus
                          // English/French and overflowing the segment —
                          // see PHASE4B_UI_POLISH.md.
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
              const SizedBox(height: 36),
              // Not height-constrained: the toss prompt wraps to two
              // lines in German/French (it's noticeably longer than
              // English), so a fixed-height box here would clip it.
              _pendingResult == null
                  ? Text(
                      l10n.tossPrompt,
                      key: const Key('tossPromptText'),
                      textAlign: TextAlign.center,
                      style: AppTypography.playerLabel(context),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Center(
                        // The result is read directly off the coin's face
                        // once it lands — no separate result text. See
                        // PHASE4C_TOSS_AND_TEAM_LABELS.md.
                        child: CoinFlipIndicator(
                          key: ValueKey(_tossSequence),
                          player1Label: _sideLabel(l10n, Player.one),
                          player2Label: _sideLabel(l10n, Player.two),
                          winner: _pendingResult!,
                          onComplete: _onCoinFlipComplete,
                        ),
                      ),
                    ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('tossButton'),
                onPressed: _tossCoin,
                child: Text(l10n.tossButton),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                key: const Key('startMatchButton'),
                onPressed: _firstServer == null ? null : _start,
                child: Text(l10n.startMatchButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A team's pair of player names, grouped visually under a "Team
/// 1"/"Team 2" heading and a light bordered box — without it, two
/// unlabeled name columns read as "four separate players," not
/// obviously two pairs. See PHASE4D_TEAM_CLARITY_AND_TRANSITION.md.
///
/// Every name here is tap-to-rename (Phase 4F, [EditableNameLabel]),
/// including the team heading itself since Phase 4G: an optional custom
/// team name (a club or nickname), entirely separate from the two player
/// names — leaving it unset keeps showing the generic "Team 1"/"Team 2"
/// exactly as before. [slots] and [defaultLabels] are parallel lists
/// (length 2: one per player in this team); [names] is shared with the
/// sibling team's preview so both read from (and write to) the same
/// [PlayerNames] instance.
class _TeamSlotPreview extends StatelessWidget {
  final int teamNumber;
  final String defaultTeamLabel;
  final Key teamLabelKey;
  final List<int> slots;
  final List<String> defaultLabels;
  final PlayerNames names;
  final String editHint;
  final void Function(int slot, String? name) onNameChanged;
  final ValueChanged<String?> onTeamNameChanged;

  const _TeamSlotPreview({
    required this.teamNumber,
    required this.defaultTeamLabel,
    required this.teamLabelKey,
    required this.slots,
    required this.defaultLabels,
    required this.names,
    required this.editHint,
    required this.onNameChanged,
    required this.onTeamNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EditableNameLabel(
            displayName: names.resolveTeam(teamNumber, defaultTeamLabel),
            defaultLabel: defaultTeamLabel,
            style: AppTypography.eyebrow(context),
            editHint: editHint,
            textKey: teamLabelKey,
            fieldKey: Key('team${teamNumber}PreviewHeadingField'),
            onChanged: onTeamNameChanged,
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < slots.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: EditableNameLabel(
                displayName: names.resolve(slots[i], defaultLabels[i]),
                defaultLabel: defaultLabels[i],
                style: AppTypography.compactPlayerLabel(context),
                editHint: editHint,
                textKey: Key('player${slots[i]}PreviewNameText'),
                fieldKey: Key('player${slots[i]}PreviewNameField'),
                onChanged: (name) => onNameChanged(slots[i], name),
              ),
            ),
        ],
      ),
    );
  }
}
