import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/player.dart';
import '../models/player_names.dart';
import '../services/ads_service.dart';
import '../services/consent_service.dart';
import '../services/monetization_controller.dart';
import '../services/pro_status_store.dart';
import '../services/privacy_links.dart';
import '../services/purchase_gateway.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_flip_indicator.dart';
import '../widgets/editable_name_label.dart';
import '../widgets/pro_dialog.dart';
import 'doubles_scoreboard_screen.dart';
import 'match_transition_screen.dart';
import 'scoreboard_screen.dart';

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

  /// Whether voice/sound is muted — lifted up to `main.dart` (see its
  /// own doc comment) so it's available here, before any match (and its
  /// [VoiceAnnouncer]) exists, to silence the coin-flip landing sound.
  /// Defaults to `false` so existing direct constructions of this screen
  /// (this file's own tests included) keep behaving exactly as before.
  final bool muted;

  /// Called when the mute state changes — passed straight through to
  /// whichever scoreboard screen this one starts, so a mid-match mute
  /// toggle bubbles back up to `main.dart`'s shared state instead of
  /// staying local to that match's own [VoiceAnnouncer].
  final ValueChanged<bool>? onMutedChanged;

  const SetupScreen({
    super.key,
    required this.currentLocaleOverride,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.monetization,
    this.muted = false,
    this.onMutedChanged,
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
        consent: UmpConsentService(),
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

  /// Re-opens the UMP consent form so an EEA/UK user can review or
  /// change their earlier ad-consent choice — best-effort like the rest
  /// of [MonetizationController]; a failure here (e.g. no network) is
  /// only logged, never surfaced as a crash. See PHASE6_PRELAUNCH_PREP.md.
  void _openPrivacyOptionsForm() {
    _monetization.openPrivacyOptionsForm();
  }

  /// Opens the hosted Privacy Policy in the device's browser. Swallows
  /// any failure (e.g. no browser available) rather than crashing —
  /// same best-effort stance as every other optional, non-core action in
  /// this app.
  Future<void> _openPrivacyPolicy() async {
    try {
      final url = privacyPolicyUrlFor(Localizations.localeOf(context));
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('SetupScreen: failed to open privacy policy URL: $e');
    }
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
            initialMuted: widget.muted,
            onMutedChanged: widget.onMutedChanged,
          )
        : ScoreboardScreen(
            bestOf: _bestOf,
            firstServer: firstServer,
            initialNames: _names,
            monetization: _monetization,
            initialMuted: widget.muted,
            onMutedChanged: widget.onMutedChanged,
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

  Widget _eyebrow(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
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
          // Flexible + ellipsis defensively, as elsewhere in this menu —
          // a submenu flyout has more room than the old single-level
          // popup menu did, but a very long localized label still
          // shouldn't be able to overflow it. See
          // PHASE4I_POLISH_ROUND2.md.
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      );

  /// A checkmark shown in a `MenuItemButton`'s `leadingIcon` slot when
  /// [selected], or an equally-sized blank space when not — keeps every
  /// item's label aligned regardless of which one is currently checked,
  /// the same visual role `CheckedPopupMenuItem` played before the
  /// Phase 4J switch to `MenuAnchor`/`SubmenuButton` (needed for real
  /// nested submenus, which `PopupMenuButton` can't do). The checkmark
  /// itself carries [key] so tests can assert on selection state without
  /// depending on internal `MenuItemButton` structure.
  Widget _leadingCheck(bool selected, Key key) => SizedBox(
        width: 24,
        child: selected ? Icon(Icons.check, key: key, size: 18) : null,
      );

  /// Forces every menu surface (the top-level flyout and each
  /// `SubmenuButton`'s own flyout) onto this app's explicit
  /// [AppPalette.surface]/[AppPalette.divider], instead of Material 3's
  /// default `MenuStyle`.
  ///
  /// A real bug found via real-device testing (Phase 4K): with no
  /// explicit style, the menu rendered with a visibly wrong pale
  /// pink/brown background instead of this app's actual surface color
  /// (near-black in dark mode, white in light mode). The cause is
  /// Material 3's elevation-overlay behavion — an elevated surface's
  /// `surfaceTintColor` (which defaults to `ColorScheme.primary`, i.e.
  /// this app's orange accent) gets blended over its background color,
  /// and that blend is what actually rendered — the menu was never
  /// reading a wrong color, it was correctly applying a design system
  /// default this app never opted out of. `surfaceTintColor:
  /// Colors.transparent` disables that blend so the menu shows this
  /// app's real surface color unmodified. See
  /// PHASE4K_AUDIO_MENU_AND_ICON.md.
  MenuStyle _menuStyle(BuildContext context) => MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.palette.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(3),
        side:
            WidgetStatePropertyAll(BorderSide(color: context.palette.divider)),
      );

  /// Forces a menu row's own text/icon color onto [AppPalette.scoreText]
  /// (this app's primary foreground) instead of Material 3's
  /// auto-derived `onSurface`, matching the "explicit `AppColors`, not
  /// Material-derived" fix alongside [_menuStyle]. Shared by every
  /// `MenuItemButton` and `SubmenuButton` row in this menu.
  ButtonStyle _menuItemStyle(BuildContext context) => ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(context.palette.scoreText),
        iconColor: WidgetStatePropertyAll(context.palette.scoreText),
      );

  /// The single settings menu covering theme, language, and the Pro
  /// purchase dialog (Phase 4I consolidated three separate app-bar icons
  /// into this one menu; Phase 4J changed how it's built and what it
  /// looks like).
  ///
  /// Built on `MenuAnchor`/`SubmenuButton`/`MenuItemButton` rather than
  /// `PopupMenuButton` specifically so Theme and Language can be real
  /// nested submenus (tapping "Theme" reveals Light/Dark/System behind
  /// it, with the chevron `SubmenuButton` draws automatically) rather
  /// than a flat list of every option shown at once — `PopupMenuButton`
  /// has no nested-submenu support at all. "Remove Ads / Pro" stays a
  /// flat, one-tap `MenuItemButton`: a single purchase flow doesn't
  /// benefit from being tucked behind another expand step.
  Widget _buildOverflowMenu(AppLocalizations l10n) {
    final menuStyle = _menuStyle(context);
    final itemStyle = _menuItemStyle(context);
    return MenuAnchor(
      key: const Key('overflowMenuAnchor'),
      style: menuStyle,
      builder: (context, controller, child) => IconButton(
        key: const Key('overflowMenuButton'),
        // A hamburger (three horizontal lines) reads more clearly at a
        // glance as "there's a menu here" than the vertical-dots overflow
        // glyph it replaces — see PHASE4J_MENU_AUDIO_AND_NAME_SAVE.md for
        // the placement reasoning (this app settled on the app bar's
        // leading/left position, the conventional spot for this icon).
        icon: const Icon(Icons.menu),
        tooltip: l10n.moreOptionsTooltip,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        SubmenuButton(
          key: const Key('themeSubmenu'),
          style: itemStyle,
          menuStyle: menuStyle,
          menuChildren: [
            MenuItemButton(
              key: const Key('themeOptionSystem'),
              style: itemStyle,
              leadingIcon: _leadingCheck(widget.themeMode == ThemeMode.system,
                  const Key('themeOptionSystem_check')),
              onPressed: () => widget.onThemeModeChanged(ThemeMode.system),
              child: Text(l10n.themeSystemOption),
            ),
            MenuItemButton(
              key: const Key('themeOptionLight'),
              style: itemStyle,
              leadingIcon: _leadingCheck(widget.themeMode == ThemeMode.light,
                  const Key('themeOptionLight_check')),
              onPressed: () => widget.onThemeModeChanged(ThemeMode.light),
              child: Text(l10n.themeLightOption),
            ),
            MenuItemButton(
              key: const Key('themeOptionDark'),
              style: itemStyle,
              leadingIcon: _leadingCheck(widget.themeMode == ThemeMode.dark,
                  const Key('themeOptionDark_check')),
              onPressed: () => widget.onThemeModeChanged(ThemeMode.dark),
              child: Text(l10n.themeDarkOption),
            ),
          ],
          child: Text(l10n.themeMenuTooltip),
        ),
        SubmenuButton(
          key: const Key('languageSubmenu'),
          style: itemStyle,
          menuStyle: menuStyle,
          menuChildren: [
            MenuItemButton(
              key: const Key('languageOptionSystem'),
              style: itemStyle,
              leadingIcon: _leadingCheck(widget.currentLocaleOverride == null,
                  const Key('languageOptionSystem_check')),
              onPressed: () => widget.onLocaleChanged(null),
              // A globe rather than a specific flag — "system default"
              // isn't any one country/language.
              child: _flagOption('🌐', l10n.languageSystemOption),
            ),
            MenuItemButton(
              key: const Key('languageOptionEn'),
              style: itemStyle,
              leadingIcon: _leadingCheck(
                  widget.currentLocaleOverride == const Locale('en'),
                  const Key('languageOptionEn_check')),
              onPressed: () => widget.onLocaleChanged(const Locale('en')),
              // Language names are always shown in their own language,
              // not translated, so a reader can find their language
              // regardless of what the UI currently displays.
              child: _flagOption('🇬🇧', 'English'),
            ),
            MenuItemButton(
              key: const Key('languageOptionDe'),
              style: itemStyle,
              leadingIcon: _leadingCheck(
                  widget.currentLocaleOverride == const Locale('de'),
                  const Key('languageOptionDe_check')),
              onPressed: () => widget.onLocaleChanged(const Locale('de')),
              child: _flagOption('🇩🇪', 'Deutsch'),
            ),
            MenuItemButton(
              key: const Key('languageOptionFr'),
              style: itemStyle,
              leadingIcon: _leadingCheck(
                  widget.currentLocaleOverride == const Locale('fr'),
                  const Key('languageOptionFr_check')),
              onPressed: () => widget.onLocaleChanged(const Locale('fr')),
              child: _flagOption('🇫🇷', 'Français'),
            ),
          ],
          child: Text(l10n.languageMenuTooltip),
        ),
        Divider(height: 1, color: context.palette.divider),
        // Hidden entirely while monetization is switched off (Phase
        // 7) — there is nothing left for it to do: no ads to remove,
        // and every feature it would unlock is already unrestricted.
        // See PHASE7_MONETIZATION_DISABLED_FOR_LAUNCH.md.
        //
        // Flat — a single tap to one purchase flow doesn't need (or
        // benefit from) a submenu the way Theme/Language's multi-choice
        // pickers do.
        if (_monetization.monetizationEnabled)
          MenuItemButton(
            key: const Key('proMenuButton'),
            style: itemStyle,
            leadingIcon: Icon(
              _monetization.isPro ? Icons.verified : Icons.workspace_premium,
              size: 20,
            ),
            onPressed: _openProDialog,
            child: Text(l10n.proMenuTooltip),
          ),
        // GDPR/UK-only (Phase 6): hidden entirely outside the EEA/UK,
        // where UMP determined no consent decision — and therefore
        // nothing to review or change — ever existed. See
        // PHASE6_PRELAUNCH_PREP.md.
        if (_monetization.privacyOptionsRequired)
          MenuItemButton(
            key: const Key('privacyOptionsMenuButton'),
            style: itemStyle,
            leadingIcon: const Icon(Icons.privacy_tip_outlined, size: 20),
            onPressed: _openPrivacyOptionsForm,
            child: Text(l10n.privacyOptionsMenuItem),
          ),
        MenuItemButton(
          key: const Key('privacyPolicyMenuButton'),
          style: itemStyle,
          leadingIcon: const Icon(Icons.description_outlined, size: 20),
          onPressed: _openPrivacyPolicy,
          child: Text(l10n.privacyPolicyMenuItem),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      // Phase 4P: the standard Material AppBar was replaced with a
      // custom hero band — a large bold bottom-left title and a
      // bottom-left-positioned hamburger don't fit a normal 56dp
      // toolbar's layout at all, and the band's fixed dark+orange brand
      // treatment (matching the app icon/feature graphic, deliberately
      // NOT theme-adaptive) isn't something AppBar's theming supports
      // either. See PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md.
      body: Column(
        children: [
          _SetupHeroBand(
            overflowMenu: _buildOverflowMenu(l10n),
            title: l10n.newMatchScreenTitle,
          ),
          Expanded(
            // A real bug found via real-device testing (Phase 4J): tapping
            // a non-interactive area of the screen (e.g. the "BEST OF"
            // heading) while a name field is being edited does *not*, by
            // itself, move Flutter's focus away from that field — nothing
            // else claims the tap, so the `TextField`'s own focus-loss
            // commit (see `EditableNameLabel._onFocusChange`) never fires,
            // and the typed name is left stuck in an uncommitted edit.
            // Tapping an actual button/control elsewhere already worked
            // correctly (Material widgets request focus for themselves on
            // tap), so this only affected "dead space" taps — but that's
            // exactly what "tap away to save" means to a user. Wrapping
            // the whole body in a tap handler that explicitly unfocuses
            // closes that gap for every dead-space tap, without changing
            // how any other tappable widget behaves. See
            // PHASE4J_MENU_AUDIO_AND_NAME_SAVE.md.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                // The hero band above already handles the top inset —
                // see its own SafeArea(bottom: false).
                top: false,
                child: SingleChildScrollView(
                  // Vertical insets tightened from (24, 32) to (16, 20)
                  // (Phase 4Q), alongside the SizedBox gaps between
                  // sections below, to fit the whole setup screen (now
                  // with a taller edge-to-edge hero band above it) on a
                  // typical screen height without scrolling. See
                  // PHASE4Q_FINAL_STORE_SCREENSHOTS.md.
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              key: const Key('modeSelector'),
                              segments: [
                                ButtonSegment(
                                    value: false,
                                    label: Text(l10n.modeSinglesOption)),
                                ButtonSegment(
                                    value: true,
                                    label: Text(l10n.modeDoublesOption)),
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
                                      padding: const EdgeInsets.only(top: 12),
                                      // The same tap-to-rename preview doubles already
                                      // had — singles previously had no equivalent
                                      // step at all. See
                                      // PHASE4H_NAME_EDITING_REFINEMENT.md.
                                      child: Row(
                                        key: const Key('singlesPlayerNames'),
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          EditableNameLabel(
                                            displayName: _names.resolve(
                                                1, l10n.player1Label),
                                            defaultLabel: l10n.player1Label,
                                            style: AppTypography.playerLabel(
                                                context),
                                            editHint: l10n.editNameHint,
                                            textKey: const Key(
                                                'player1PreviewNameText'),
                                            fieldKey: const Key(
                                                'player1PreviewNameField'),
                                            onChanged: (name) => setState(
                                                () => _names.set(1, name)),
                                          ),
                                          EditableNameLabel(
                                            displayName: _names.resolve(
                                                2, l10n.player2Label),
                                            defaultLabel: l10n.player2Label,
                                            style: AppTypography.playerLabel(
                                                context),
                                            editHint: l10n.editNameHint,
                                            textKey: const Key(
                                                'player2PreviewNameText'),
                                            fieldKey: const Key(
                                                'player2PreviewNameField'),
                                            onChanged: (name) => setState(
                                                () => _names.set(2, name)),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        key: const Key('doublesPlayerSlots'),
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _TeamSlotPreview(
                                            teamNumber: 1,
                                            defaultTeamLabel: l10n.team1Label,
                                            teamLabelKey: const Key(
                                                'team1PreviewHeading'),
                                            slots: const [1, 2],
                                            defaultLabels: [
                                              l10n.player1Label,
                                              l10n.player2Label
                                            ],
                                            names: _names,
                                            editHint: l10n.editNameHint,
                                            onNameChanged: (slot, name) =>
                                                setState(() =>
                                                    _names.set(slot, name)),
                                            onTeamNameChanged: (name) =>
                                                setState(() =>
                                                    _names.setTeam(1, name)),
                                          ),
                                          _TeamSlotPreview(
                                            teamNumber: 2,
                                            defaultTeamLabel: l10n.team2Label,
                                            teamLabelKey: const Key(
                                                'team2PreviewHeading'),
                                            slots: const [3, 4],
                                            defaultLabels: [
                                              l10n.player3Label,
                                              l10n.player4Label
                                            ],
                                            names: _names,
                                            editHint: l10n.editNameHint,
                                            onNameChanged: (slot, name) =>
                                                setState(() =>
                                                    _names.set(slot, name)),
                                            onTeamNameChanged: (name) =>
                                                setState(() =>
                                                    _names.setTeam(2, name)),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _eyebrow(l10n.bestOfLabel),
                            SegmentedButton<int>(
                              key: const Key('bestOfSelector'),
                              segments: [3, 5, 7]
                                  .map((bestOf) => ButtonSegment(
                                        value: bestOf,
                                        // Every language shows a bare number
                                        // here — the explanatory word lives
                                        // once, in the eyebrow heading above
                                        // ("Best of" / "Gewinnsätze" / "Au
                                        // meilleur de"), never inside the
                                        // segment itself. German used to
                                        // embed "Gewinnsätze" in each
                                        // segment, tripling its text versus
                                        // English/French and overflowing the
                                        // segment — see PHASE4B_UI_POLISH.md.
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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
                          muted: widget.muted,
                          idleLabel: l10n.tapToTossLabel,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        key: const Key('startMatchButton'),
                        onPressed: _firstServer == null ? null : _start,
                        // ALL-CAPS + letter-spacing + a trailing arrow (Phase
                        // 4P) — a bolder, more deliberate call-to-action than
                        // plain sentence-case text. `.toUpperCase()` at display
                        // time only (matching `_eyebrow`'s existing approach),
                        // so the underlying `l10n.startMatchButton` string
                        // itself, and everything keyed off it, is unchanged.
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.startMatchButton.toUpperCase(),
                              style: const TextStyle(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The setup screen's hero header (Phase 4P), replacing the previous
/// plain Material `AppBar` — a large bold title sitting at the
/// *bottom*-left of a tall band, with the hamburger menu at its
/// top-left, doesn't fit a standard 56dp toolbar's layout at all. A
/// fixed dark near-black background with a large orange diagonal shape
/// in the upper-right corner echoes the app icon/feature graphic's own
/// visual language — deliberately NOT theme-adaptive (it stays this
/// same dark+orange brand treatment in both light and dark app themes,
/// the same way the icon itself doesn't change), so [AppPalette.dark]
/// is used directly here rather than `context.palette`. Deliberately
/// minimal: just the menu and the title, no extra icons or subtitle.
class _SetupHeroBand extends StatelessWidget {
  final Widget overflowMenu;
  final String title;

  const _SetupHeroBand({required this.overflowMenu, required this.title});

  static const _titleStyle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The app-wide default (set in main.dart) picks status bar icon
      // color from the active app theme, but this band's own background
      // is deliberately NOT theme-adaptive — it's always this same
      // near-black, even in Light mode (see the class doc above). So it
      // needs its own fixed override here rather than inheriting the
      // theme-driven default, or a Light-mode user would get dark
      // (invisible) status bar icons sitting on this always-dark band.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: AppPalette.dark.background,
        child: SafeArea(
          // The scrollable body below has its own SafeArea(top: false) —
          // together they cover the full screen exactly once, with this
          // band owning the top inset (status bar/notch) since it's the
          // one that actually sits under it. Edge-to-edge (main.dart)
          // means this ColoredBox's background now genuinely extends up
          // underneath the status bar instead of stopping below an
          // opaque OS-drawn strip — SafeArea only pushes the *content*
          // (menu icon, title) down to clear it.
          bottom: false,
          child: Padding(
            // Only vertical padding here — the horizontal insets for the
            // menu/title live on the inner `contentPadding` below instead,
            // so `constraints.maxWidth` reflects the band's true full
            // width (edge to edge) rather than a width already shrunk by
            // a right-side inset. The diagonal is sized from this
            // `constraints.maxWidth` (see the `SizedBox`/`Positioned.fill`
            // below), so if this outer `Padding` ever grows a horizontal
            // component again, the wedge's right edge will stop short of
            // the actual screen edge by that amount instead of touching it.
            // Bottom inset trimmed from 20->12 (Phase 4Q): together with
            // the menu-to-title gap below, this is one of the two biggest
            // levers on the band's overall height. Edge-to-edge painting
            // under the status bar (main.dart) made the band noticeably
            // taller, which on shorter screens pushed "Start match" below
            // the fold — see PHASE4Q_FINAL_STORE_SCREENSHOTS.md.
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The menu/title content's own horizontal inset, kept
                // separate from the band's overall width so the diagonal
                // (painted at the band's full `constraints.maxWidth`) can
                // still reach the true right edge of the screen.
                const contentPadding = EdgeInsets.fromLTRB(4, 0, 24, 0);

                // Measured directly (rather than reading the rendered
                // Text's own size after layout) so the diagonal's
                // clearance is known in the very same build/paint pass —
                // no post-frame callback or extra rebuild needed. This is
                // what lets the wedge stay clear of the title in every
                // shipped language: a longer translation (e.g. "Nouveau
                // match") simply pushes the wedge further right instead
                // of running underneath it, which a fixed 55%/40% split
                // could not account for. See the "hero band" section of
                // PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md.
                final titlePainter = TextPainter(
                  text: TextSpan(text: title, style: _titleStyle),
                  textDirection: Directionality.of(context),
                  maxLines: 1,
                )..layout(
                    maxWidth: constraints.maxWidth - contentPadding.horizontal);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _HeroDiagonalPainter(
                          color: AppPalette.dark.accent,
                          // The text's own left inset offsets where it
                          // actually ends, in the same left-edge-of-band
                          // coordinate space the wedge is painted in.
                          titleRight: contentPadding.left + titlePainter.width,
                        ),
                      ),
                    ),
                    // Without this explicit width, a `Stack` sizes itself
                    // to fit only its non-positioned children when (as
                    // here, inside a `Column`) its own height constraint
                    // is unbounded — so it would shrink-wrap to whichever
                    // of the menu icon or the title text is wider,
                    // nowhere near the band's actual full width. That
                    // starved the `Positioned.fill` diagonal above of
                    // most of its canvas: it was never actually painting
                    // across the true upper-right corner of the screen,
                    // only a corner of this much narrower box — which is
                    // exactly why the diagonal used to visibly cut
                    // through the title's own text (the box was barely
                    // wider than the text itself).
                    SizedBox(
                      width: constraints.maxWidth,
                      child: Padding(
                        padding: contentPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Forces the hamburger's own icon color to
                            // white, regardless of the app's light/dark
                            // theme — this button sits on the always-dark
                            // hero band, not on AppPalette.surface the way
                            // it used to (on an AppBar), so the theme's
                            // usual scoreText-based foreground (near-black
                            // in light mode) would be invisible here. Only
                            // affects this button's own theme-derived
                            // default; the flyout menu it opens still uses
                            // the app's real light/dark AppPalette.surface
                            // (baked into `_menuStyle`/`_menuItemStyle`
                            // explicitly, before this widget ever sees it),
                            // unaffected by this override.
                            Theme(
                              data: Theme.of(context).copyWith(
                                iconButtonTheme: IconButtonThemeData(
                                  style: IconButton.styleFrom(
                                      foregroundColor: Colors.white),
                                ),
                              ),
                              child: overflowMenu,
                            ),
                            // Trimmed from 32->18 (Phase 4Q) to keep the
                            // hero band's overall height in check — see
                            // the outer `Padding`'s comment above.
                            const SizedBox(height: 18),
                            Text(title, style: _titleStyle),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the hero band's orange diagonal — a slanted wedge occupying
/// the band's upper-right corner, the same "dark near-black split by an
/// orange diagonal" motif as the app icon and Play Store feature
/// graphic. A `CustomPainter` (rather than a `ClipPath`/`Container`
/// pair) so the shape always fills exactly this band's actual size,
/// whatever that ends up being, without hand-tuning pixel offsets.
class _HeroDiagonalPainter extends CustomPainter {
  final Color color;
  final double titleRight;

  const _HeroDiagonalPainter({required this.color, required this.titleRight});

  @override
  void paint(Canvas canvas, Size size) {
    final bottomX =
        heroDiagonalBottomX(bandWidth: size.width, titleRight: titleRight);
    // The top edge trails the bottom edge by a fixed offset so the wedge
    // keeps the same slanted look as before when there's no title to
    // dodge, but never crosses to the *left* of the (now possibly
    // pushed-right) bottom edge.
    final topLower = size.width * 0.55;
    final topUpper = max(topLower, size.width - 16.0);
    final topX = (bottomX + size.width * 0.15).clamp(topLower, topUpper);

    final path = Path()
      ..moveTo(topX, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(bottomX, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HeroDiagonalPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.titleRight != titleRight;
}

/// The hero band diagonal's bottom-edge x-coordinate: how far right the
/// wedge's lower corner sits, given the band's own width and how far
/// right the title text actually extends (`titleRight`, measured from
/// the same left edge the wedge and the title share).
///
/// Kept clamped between two bounds so the fix for one problem doesn't
/// create another: it never sits left of the title text plus a small
/// clearance (that was the original overlap bug — see the "hero band"
/// section of PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md), but it also
/// never crosses all the way to the band's right edge, so even a title
/// that fills almost the entire band width still leaves a visible sliver
/// of the wedge — the brand motif never fully disappears.
///
/// A plain top-level function (rather than folded into
/// [_HeroDiagonalPainter]'s paint method) so this clearance invariant is
/// directly unit-testable without pumping a widget or rendering a frame.
double heroDiagonalBottomX({
  required double bandWidth,
  required double titleRight,
}) {
  const clearance = 16.0;
  const minWedgeWidth = 32.0;
  final lowerBound = bandWidth * 0.40;
  final upperBound = max(0.0, bandWidth - minWedgeWidth);
  if (lowerBound >= upperBound) return upperBound;
  return (titleRight + clearance).clamp(lowerBound, upperBound);
}

/// Wraps a control group (the singles/doubles mode toggle + name
/// previews; the best-of selector) with a thin orange accent line along
/// its top edge — Phase 4P's replacement for a full bordered card, so
/// each group reads as its own distinct unit within the setup screen's
/// otherwise flat list without the heavier boxed-in look a full border
/// on every side would give.
class _SectionGroup extends StatelessWidget {
  final Widget child;

  const _SectionGroup({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.palette.accent, width: 2),
        ),
      ),
      child: child,
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
