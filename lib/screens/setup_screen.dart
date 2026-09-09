import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/player.dart';
import '../models/player_names.dart';
import '../services/ads_service.dart';
import '../services/monetization_controller.dart';
import '../services/pro_status_store.dart';
import '../services/purchase_gateway.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_flip_indicator.dart';
import '../widgets/editable_name_label.dart';
import '../widgets/pro_dialog.dart';
import 'doubles_scoreboard_screen.dart';
import 'match_transition_screen.dart';
import 'scoreboard_screen.dart';

/// Every action reachable from the setup screen's single app-bar overflow
/// menu (Phase 4I) — theme, language, and the Pro purchase dialog used to
/// be three separate icon buttons competing for attention; consolidating
/// them behind one "⋮" matches how most apps tuck several secondary
/// settings behind a single overflow menu. Each item keeps exactly the
/// functionality it had as its own icon — only the entry point moved.
/// See PHASE4I_POLISH_ROUND2.md.
///
/// A flat enum (rather than nesting `ThemeMode`/`Locale?` values
/// directly) exists for the same reason the old language-only menu
/// needed one: `PopupMenuButton`'s `onSelected` is never called for a
/// `null` selection (Flutter treats that identically to the menu being
/// dismissed with no choice made — see `popup_menu.dart`'s
/// `_PopupMenuButtonState._handleMenu`), so "System default" language
/// needs its own non-null value (`languageSystem`) to be selectable at
/// all; folding every other action into the same enum keeps one
/// `PopupMenuButton<_OverflowAction>` instead of mixing types.
enum _OverflowAction {
  themeSystem,
  themeLight,
  themeDark,
  languageSystem,
  languageEn,
  languageDe,
  languageFr,
  pro,
}

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

  /// Owns ads/purchases/Pro status (Phase 5). Overridable for tests, so
  /// they can inject a controller backed by fake [AdsService]/
  /// [PurchaseGateway] implementations instead of touching real AdMob/
  /// Billing; defaults to a real, self-initializing instance otherwise —
  /// same optional-with-safe-default pattern as [ScoreboardScreen.
  /// voiceAnnouncer]. When not given, this screen owns the instance's
  /// lifecycle (initializes it, disposes it); when given (as `main.dart`
  /// does, so Pro status survives navigating to and from the scoreboard),
  /// the caller owns it instead.
  final MonetizationController? monetization;

  const SetupScreen({
    super.key,
    required this.currentLocaleOverride,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.monetization,
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

  late final MonetizationController _monetization;
  late final bool _ownsMonetization;

  @override
  void initState() {
    super.initState();
    final injected = widget.monetization;
    if (injected != null) {
      _monetization = injected;
      _ownsMonetization = false;
    } else {
      _monetization = MonetizationController(
        ads: AdMobAdsService(),
        purchases: InAppPurchaseGateway(),
        proStatusStore: ProStatusStore(),
      );
      _ownsMonetization = true;
      _monetization.initialize();
    }
  }

  @override
  void dispose() {
    if (_ownsMonetization) _monetization.dispose();
    super.dispose();
  }

  void _openProDialog() {
    showDialog(
      context: context,
      builder: (_) => ProDialog(monetization: _monetization),
    );
  }

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
  ///
  /// Resolves through [_names] first (a custom player name in singles, a
  /// custom team name in doubles), falling back to the generic localized
  /// label — matching exactly how `ScoreboardScreen._playerLabel` and
  /// `DoublesScoreboardScreen._teamLabel` resolve the same information.
  /// This used to return the generic label unconditionally, so the coin
  /// toss kept saying "Player 1"/"Player 2" even after renaming — the
  /// same class of voice/banner desync bug fixed for Phase 4D, just not
  /// caught here until now. See PHASE4I_POLISH_ROUND2.md.
  String _sideLabel(AppLocalizations l10n, Player player) {
    if (_isDoubles) {
      final teamNumber = player == Player.one ? 1 : 2;
      final defaultLabel =
          player == Player.one ? l10n.team1Label : l10n.team2Label;
      return _names.resolveTeam(teamNumber, defaultLabel);
    }
    final slot = player == Player.one ? 1 : 2;
    final defaultLabel =
        player == Player.one ? l10n.player1Label : l10n.player2Label;
    return _names.resolve(slot, defaultLabel);
  }

  void _start() {
    final firstServer = _firstServer;
    if (firstServer == null) return;
    final destination = _isDoubles
        ? DoublesScoreboardScreen(
            bestOf: _bestOf,
            firstServingTeam: firstServer,
            initialNames: _names,
            monetization: _monetization,
          )
        : ScoreboardScreen(
            bestOf: _bestOf,
            firstServer: firstServer,
            initialNames: _names,
            monetization: _monetization,
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

  void _onOverflowSelected(_OverflowAction action) {
    switch (action) {
      case _OverflowAction.themeSystem:
        widget.onThemeModeChanged(ThemeMode.system);
      case _OverflowAction.themeLight:
        widget.onThemeModeChanged(ThemeMode.light);
      case _OverflowAction.themeDark:
        widget.onThemeModeChanged(ThemeMode.dark);
      case _OverflowAction.languageSystem:
        widget.onLocaleChanged(null);
      case _OverflowAction.languageEn:
        widget.onLocaleChanged(const Locale('en'));
      case _OverflowAction.languageDe:
        widget.onLocaleChanged(const Locale('de'));
      case _OverflowAction.languageFr:
        widget.onLocaleChanged(const Locale('fr'));
      case _OverflowAction.pro:
        _openProDialog();
    }
  }

  Widget _eyebrow(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(), style: AppTypography.eyebrow(context)),
      );

  /// A non-interactive heading inside the overflow menu (Phase 4I) —
  /// `enabled: false` keeps it unselectable/untappable while still
  /// reading clearly as a section divider between theme, language, and
  /// the Pro action, now that all three live in one menu instead of
  /// their own separate icons.
  PopupMenuEntry<_OverflowAction> _sectionLabel(String text) =>
      PopupMenuItem<_OverflowAction>(
        enabled: false,
        height: 32,
        child: Text(text.toUpperCase(), style: AppTypography.eyebrow(context)),
      );

  /// A language option's row: a small flag/globe glyph beside the label
  /// (Phase 4I) — a common, low-effort touch that makes the language list
  /// easier to scan at a glance. Plain Unicode flag emoji, not image
  /// assets: they render natively and consistently on both Android and
  /// iOS (this app's actual targets) with no extra asset weight; emoji
  /// flag rendering is only inconsistent on some desktop platforms, which
  /// isn't a concern for a phone app.
  Widget _flagOption(String flag, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          // Flexible + ellipsis rather than a bare Text: the popup menu's
          // available width is constrained by how much screen space
          // remains between its anchor (the app-bar icon) and the screen
          // edge, not just by its content — a bare Text overflowed and
          // crashed layout for longer localized labels once a leading
          // flag was added. See PHASE4I_POLISH_ROUND2.md.
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      );

  /// Tighter than `PopupMenuItem`'s 16px-a-side default — freed up just
  /// enough room for the flag/icon rows added in Phase 4I, which
  /// overflowed the default width for the longer language labels (e.g.
  /// French "Français") once a leading glyph was added. See
  /// PHASE4I_POLISH_ROUND2.md.
  static const _tightItemPadding = EdgeInsets.symmetric(horizontal: 10);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newMatchScreenTitle),
        actions: [
          PopupMenuButton<_OverflowAction>(
            key: const Key('overflowMenuButton'),
            icon: const Icon(Icons.more_vert),
            tooltip: l10n.moreOptionsTooltip,
            onSelected: _onOverflowSelected,
            itemBuilder: (context) => [
              _sectionLabel(l10n.themeMenuTooltip),
              CheckedPopupMenuItem<_OverflowAction>(
                key: const Key('themeOptionSystem'),
                value: _OverflowAction.themeSystem,
                checked: widget.themeMode == ThemeMode.system,
                child: Text(l10n.themeSystemOption),
              ),
              CheckedPopupMenuItem<_OverflowAction>(
                key: const Key('themeOptionLight'),
                value: _OverflowAction.themeLight,
                checked: widget.themeMode == ThemeMode.light,
                child: Text(l10n.themeLightOption),
              ),
              CheckedPopupMenuItem<_OverflowAction>(
                key: const Key('themeOptionDark'),
                value: _OverflowAction.themeDark,
                checked: widget.themeMode == ThemeMode.dark,
                child: Text(l10n.themeDarkOption),
              ),
              const PopupMenuDivider(),
              _sectionLabel(l10n.languageMenuTooltip),
              CheckedPopupMenuItem<_OverflowAction>(
                key: const Key('languageOptionSystem'),
                value: _OverflowAction.languageSystem,
                checked: widget.currentLocaleOverride == null,
                padding: _tightItemPadding,
                // A globe rather than a specific flag — "system default"
                // isn't any one country/language.
                child: _flagOption('🌐', l10n.languageSystemOption),
              ),
              CheckedPopupMenuItem<_OverflowAction>(
                key: const Key('languageOptionEn'),
                value: _OverflowAction.languageEn,
                checked: widget.currentLocaleOverride == const Locale('en'),
                padding: _tightItemPadding,
                // Language names are always shown in their own language,
                // not translated, so a reader can find their language
                // regardless of what the UI currently displays.
                child: _flagOption('🇬🇧', 'English'),
              ),
              CheckedPopupMenuItem<_OverflowAction>(
                key: const Key('languageOptionDe'),
                value: _OverflowAction.languageDe,
                checked: widget.currentLocaleOverride == const Locale('de'),
                padding: _tightItemPadding,
                child: _flagOption('🇩🇪', 'Deutsch'),
              ),
              CheckedPopupMenuItem<_OverflowAction>(
                key: const Key('languageOptionFr'),
                value: _OverflowAction.languageFr,
                checked: widget.currentLocaleOverride == const Locale('fr'),
                padding: _tightItemPadding,
                child: _flagOption('🇫🇷', 'Français'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<_OverflowAction>(
                key: const Key('proMenuButton'),
                value: _OverflowAction.pro,
                padding: _tightItemPadding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _monetization.isPro
                          ? Icons.verified
                          : Icons.workspace_premium,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    // Flexible + ellipsis — see _flagOption's doc comment
                    // for why a bare Text isn't safe here across all
                    // three languages.
                    Flexible(
                      child: Text(l10n.proMenuTooltip,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
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
              // English), so a fixed-height box here would clip it. Only
              // shown before the first toss — once a result exists, the
              // coin's own settled face communicates that clearly enough.
              if (_pendingResult == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.tossPrompt,
                    key: const Key('tossPromptText'),
                    textAlign: TextAlign.center,
                    style: AppTypography.playerLabel(context),
                  ),
                ),
              // The coin is the toss control itself (Phase 4I) — there is
              // no separate "Toss coin" button. It's always mounted (not
              // rebuilt fresh per toss via a keyed remount, unlike Phase
              // 4C) so it can sit idle and tappable before the first
              // toss; CoinFlipIndicator notices `_tossSequence` changing
              // and plays the flip itself. The result is read directly
              // off the coin's face once it lands — no separate result
              // text. See PHASE4C_TOSS_AND_TEAM_LABELS.md and
              // PHASE4I_POLISH_ROUND2.md.
              Center(
                child: CoinFlipIndicator(
                  player1Label: _sideLabel(l10n, Player.one),
                  player2Label: _sideLabel(l10n, Player.two),
                  winner: _pendingResult,
                  tossSequence: _tossSequence,
                  onTap: _tossCoin,
                  onComplete: _onCoinFlipComplete,
                ),
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
