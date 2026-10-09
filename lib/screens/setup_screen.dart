import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/player.dart';
import '../models/player_names.dart';
import '../services/ads_service.dart';
import '../services/consent_service.dart';
import '../services/locale_resolution.dart';
import '../services/monetization_controller.dart';
import '../services/pro_status_store.dart';
import '../services/privacy_links.dart';
import '../services/purchase_gateway.dart';
import '../services/review_prompter.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_flip_indicator.dart';
import '../widgets/editable_name_label.dart';
import '../widgets/hero_band.dart';
import '../widgets/option_tiles.dart';
import '../widgets/pro_dialog.dart';
import 'doubles_scoreboard_screen.dart';
import 'help_screen.dart';
import 'match_transition_screen.dart';
import 'scoreboard_screen.dart';

// The hero band used to live in this file; kept importable from here.
export '../widgets/hero_band.dart' show heroDiagonalBottomX;

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

  /// Backs the "Rate this app" menu entry, and is passed on to
  /// whichever scoreboard screen this one starts for its automatic
  /// post-match prompt. Overridable for tests to inject a fake
  /// [ReviewService]; defaults to a real one otherwise.
  final ReviewPrompter? reviewPrompter;

  const SetupScreen({
    super.key,
    required this.currentLocaleOverride,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.monetization,
    this.muted = false,
    this.onMutedChanged,
    this.reviewPrompter,
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
  late final ReviewPrompter _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = widget.reviewPrompter ?? ReviewPrompter();
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

  /// Opens this app's store listing — see [ReviewPrompter.rateManually].
  void _rateApp() {
    _reviews.rateManually();
  }

  void _openHelp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HelpScreen()),
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
            initialMuted: widget.muted,
            onMutedChanged: widget.onMutedChanged,
            reviewPrompter: _reviews,
          )
        : ScoreboardScreen(
            bestOf: _bestOf,
            firstServer: firstServer,
            initialNames: _names,
            monetization: _monetization,
            initialMuted: widget.muted,
            onMutedChanged: widget.onMutedChanged,
            reviewPrompter: _reviews,
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
        child: Text(text, style: AppTypography.eyebrow(context)),
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
          // Flexible so a label too long for the menu's width (see
          // [_menuWidth]) wraps onto a second line — never an ellipsis.
          Flexible(child: Text(label)),
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
  ///
  /// [submenu] makes the panel drop down directly beneath the row that
  /// opened it instead of flying out beside it — see [_menuWidth].
  MenuStyle _menuStyle(BuildContext context, {bool submenu = false}) =>
      MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.palette.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(3),
        side:
            WidgetStatePropertyAll(BorderSide(color: context.palette.divider)),
        alignment: submenu ? AlignmentDirectional.bottomStart : null,
      );

  /// The gap kept between the menu and the screen's edges.
  static const _menuScreenMargin = 12.0;

  /// One width for the menu and both of its submenus: just wide enough
  /// for the longest row in any of them on one line, capped at the
  /// screen's width less a margin (past which a label wraps onto a
  /// second line rather than being cut off).
  ///
  /// The panels share a width because a phone has no room for a submenu
  /// *beside* the menu: Flutter would slide it back over the menu,
  /// leaving the rows underneath half covered and reading as truncated
  /// ("Politique de c", "Datenschutzer" — found on a real device). With
  /// equal widths and [_menuStyle]'s `submenu` placement, a submenu
  /// instead drops down exactly over the rows below the one that opened
  /// it, so a row is either fully visible or fully covered.
  ///
  /// The per-row extras below are `MenuItemButton`'s own layout: 12
  /// padding at each end, a 12 gap after a leading widget, a 20 icon or
  /// the 24 check-mark slot (see [_leadingCheck]), a 24 submenu arrow.
  double _menuWidth(
    BuildContext context,
    AppLocalizations l10n,
    String detectedLanguage,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    double textWidth(String text, [TextStyle? style]) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style ?? labelStyle),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    const submenuRow = 12.0 + 12 + 24 + 12;
    const iconRow = 12.0 + 20 + 12 + 12;
    const checkRow = 12.0 + 24 + 12 + 12;
    // The flag glyph and the gap after it — see [_flagOption].
    final flag = textWidth('🇬🇧', const TextStyle(fontSize: 16)) + 6;

    final rows = [
      textWidth(l10n.themeMenuTooltip) + submenuRow,
      textWidth(l10n.languageMenuTooltip) + submenuRow,
      textWidth(l10n.helpTitle) + iconRow,
      if (_monetization.monetizationEnabled)
        textWidth(l10n.proMenuTooltip) + iconRow,
      if (_monetization.privacyOptionsRequired)
        textWidth(l10n.privacyOptionsMenuItem) + iconRow,
      textWidth(l10n.privacyPolicyMenuItem) + iconRow,
      textWidth(l10n.rateAppMenuItem) + iconRow,
      textWidth(l10n.themeSystemOption) + checkRow,
      textWidth(l10n.themeLightOption) + checkRow,
      textWidth(l10n.themeDarkOption) + checkRow,
      textWidth(l10n.languageAutomatic(detectedLanguage)) + checkRow + flag,
      for (final locale in AppLocalizations.supportedLocales)
        textWidth(nativeLanguageName(locale)) + checkRow + flag,
    ];
    // A little slack so sub-pixel rounding never tips a label that
    // exactly fits onto a second line.
    final widest = rows.reduce(max) + 4;
    final available = MediaQuery.sizeOf(context).width - 2 * _menuScreenMargin;
    return min(widest, max(0.0, available));
  }

  /// Forces a menu row's own text/icon color onto [AppPalette.scoreText]
  /// (this app's primary foreground) instead of Material 3's
  /// auto-derived `onSurface`, matching the "explicit `AppColors`, not
  /// Material-derived" fix alongside [_menuStyle]. Shared by every
  /// `MenuItemButton` and `SubmenuButton` row in this menu.
  ///
  /// [width] fixes every row — and with it the panel, which is exactly
  /// as wide as its rows — at the menu's shared width; see
  /// [_menuWidth]. (A width set on the `MenuStyle` itself has no effect:
  /// a vertical menu sizes itself to its rows.) Rows keep their usual
  /// minimum height and grow taller if a label wraps.
  ButtonStyle _menuItemStyle(BuildContext context, {required double width}) =>
      ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(context.palette.scoreText),
        iconColor: WidgetStatePropertyAll(context.palette.scoreText),
        minimumSize: WidgetStatePropertyAll(Size(width, 48)),
        maximumSize: WidgetStatePropertyAll(Size(width, double.infinity)),
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
    // What "Automatic" currently means: the same resolution
    // `MaterialApp` applies to the device's locale list, so an
    // unsupported device language reads "Automatic (English)".
    final detectedLanguage = nativeLanguageName(resolveDeviceLocale(
      WidgetsBinding.instance.platformDispatcher.locales,
      AppLocalizations.supportedLocales,
    ));
    final menuWidth = _menuWidth(context, l10n, detectedLanguage);
    final itemStyle = _menuItemStyle(context, width: menuWidth);
    final menuStyle = _menuStyle(context);
    final submenuStyle = _menuStyle(context, submenu: true);
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
          menuStyle: submenuStyle,
          // Flush under its own row: the default offset is tuned for a
          // submenu opening to the side.
          alignmentOffset: Offset.zero,
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
          menuStyle: submenuStyle,
          // Flush under its own row: the default offset is tuned for a
          // submenu opening to the side.
          alignmentOffset: Offset.zero,
          menuChildren: [
            MenuItemButton(
              key: const Key('languageOptionSystem'),
              style: itemStyle,
              leadingIcon: _leadingCheck(widget.currentLocaleOverride == null,
                  const Key('languageOptionSystem_check')),
              onPressed: () => widget.onLocaleChanged(null),
              // A globe rather than a specific flag — following the
              // device isn't any one country/language. The detected
              // language is named in its own language, like the rows
              // below; only the word "Automatic" follows the UI.
              child:
                  _flagOption('🌐', l10n.languageAutomatic(detectedLanguage)),
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
              child:
                  _flagOption('🇬🇧', nativeLanguageName(const Locale('en'))),
            ),
            MenuItemButton(
              key: const Key('languageOptionDe'),
              style: itemStyle,
              leadingIcon: _leadingCheck(
                  widget.currentLocaleOverride == const Locale('de'),
                  const Key('languageOptionDe_check')),
              onPressed: () => widget.onLocaleChanged(const Locale('de')),
              child:
                  _flagOption('🇩🇪', nativeLanguageName(const Locale('de'))),
            ),
            MenuItemButton(
              key: const Key('languageOptionFr'),
              style: itemStyle,
              leadingIcon: _leadingCheck(
                  widget.currentLocaleOverride == const Locale('fr'),
                  const Key('languageOptionFr_check')),
              onPressed: () => widget.onLocaleChanged(const Locale('fr')),
              child:
                  _flagOption('🇫🇷', nativeLanguageName(const Locale('fr'))),
            ),
          ],
          child: Text(l10n.languageMenuTooltip),
        ),
        Divider(height: 1, color: context.palette.divider),
        MenuItemButton(
          key: const Key('helpMenuButton'),
          style: itemStyle,
          leadingIcon: const Icon(Icons.help_outline, size: 20),
          onPressed: _openHelp,
          child: Text(l10n.helpTitle),
        ),
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
        MenuItemButton(
          key: const Key('rateAppMenuButton'),
          style: itemStyle,
          leadingIcon: const Icon(Icons.star_outline, size: 20),
          onPressed: _rateApp,
          child: Text(l10n.rateAppMenuItem),
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
          HeroBand(
            leading: _buildOverflowMenu(l10n),
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
                  // The bottom inset leaves room for the "Start match"
                  // button's soft shadow, which would otherwise be
                  // clipped at the scroll view's edge.
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OptionTiles<bool>(
                        key: const Key('modeSelector'),
                        options: [
                          (false, l10n.modeSinglesOption),
                          (true, l10n.modeDoublesOption),
                        ],
                        selected: _isDoubles,
                        onSelected: (isDoubles) =>
                            setState(() => _isDoubles = isDoubles),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: !_isDoubles
                              // The same tap-to-rename preview doubles
                              // already had — singles previously had no
                              // equivalent step at all. See
                              // PHASE4H_NAME_EDITING_REFINEMENT.md.
                              ? Row(
                                  key: const Key('singlesPlayerNames'),
                                  children: [
                                    for (final slot in const [1, 2]) ...[
                                      if (slot == 2) const SizedBox(width: 8),
                                      Expanded(
                                        child: _FieldTile(
                                          barColor: slot == 1
                                              ? context.palette.neutralBar
                                              : context.palette.accent,
                                          child: EditableNameLabel(
                                            displayName: _names.resolve(
                                                slot,
                                                slot == 1
                                                    ? l10n.player1Label
                                                    : l10n.player2Label),
                                            defaultLabel: slot == 1
                                                ? l10n.player1Label
                                                : l10n.player2Label,
                                            style: AppTypography.fieldName(
                                                context),
                                            editHint: l10n.editNameHint,
                                            textKey: Key(
                                                'player${slot}PreviewNameText'),
                                            fieldKey: Key(
                                                'player${slot}PreviewNameField'),
                                            fillPadding:
                                                _FieldTile.contentPadding,
                                            onChanged: (name) => setState(
                                                () => _names.set(slot, name)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : Row(
                                  key: const Key('doublesPlayerSlots'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _TeamSlotPreview(
                                        teamNumber: 1,
                                        defaultTeamLabel: l10n.team1Label,
                                        teamLabelKey:
                                            const Key('team1PreviewHeading'),
                                        slots: const [1, 2],
                                        defaultLabels: [
                                          l10n.player1Label,
                                          l10n.player2Label
                                        ],
                                        names: _names,
                                        editHint: l10n.editNameHint,
                                        onNameChanged: (slot, name) => setState(
                                            () => _names.set(slot, name)),
                                        onTeamNameChanged: (name) => setState(
                                            () => _names.setTeam(1, name)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _TeamSlotPreview(
                                        teamNumber: 2,
                                        defaultTeamLabel: l10n.team2Label,
                                        teamLabelKey:
                                            const Key('team2PreviewHeading'),
                                        slots: const [3, 4],
                                        defaultLabels: [
                                          l10n.player3Label,
                                          l10n.player4Label
                                        ],
                                        names: _names,
                                        editHint: l10n.editNameHint,
                                        onNameChanged: (slot, name) => setState(
                                            () => _names.set(slot, name)),
                                        onTeamNameChanged: (name) => setState(
                                            () => _names.setTeam(2, name)),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _eyebrow(l10n.bestOfLabel),
                      OptionTiles<int>(
                        key: const Key('bestOfSelector'),
                        options: [
                          for (final bestOf in const [3, 5, 7])
                            (
                              bestOf,
                              // Every language shows a bare number here —
                              // the explanatory word lives once, in the
                              // label above ("Best of" / "Gewinnsätze" /
                              // "Au meilleur de"), never inside the tile
                              // itself. German used to embed
                              // "Gewinnsätze" in each segment, tripling
                              // its text versus English/French and
                              // overflowing it — see PHASE4B_UI_POLISH.md.
                              l10n.bestOfSegmentLabel(
                                  bestOf, (bestOf ~/ 2) + 1),
                            ),
                        ],
                        selected: _bestOf,
                        onSelected: (bestOf) =>
                            setState(() => _bestOf = bestOf),
                      ),
                      const SizedBox(height: 24),
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
                            style: AppTypography.prompt(context),
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
                      _StartMatchButton(
                        label: l10n.startMatchButton,
                        onPressed: _firstServer == null ? null : _start,
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

/// The setup screen's one primary action. Disabled (a quiet outlined
/// slab) until the toss has picked a first server, then solid accent
/// with a soft accent shadow beneath it.
class _StartMatchButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _StartMatchButton({required this.label, required this.onPressed});

  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.30),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        key: const Key('startMatchButton'),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          side: enabled ? null : BorderSide(color: palette.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.uiFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shrinks a long translation (or a large system font) to
            // the button's width rather than overflowing it.
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }
}

/// A surface tile with a thin colored bar down its leading edge — one
/// player's name field in singles, one team's group of names in
/// doubles. The bar tells the two sides apart at a glance: a quiet
/// neutral for side 1, the accent for side 2.
class _FieldTile extends StatelessWidget {
  final Color barColor;
  final Widget child;

  const _FieldTile({required this.barColor, required this.child});

  static const _barWidth = 4.0;

  /// The inset a tile's content should keep, clear of the bar.
  static const contentPadding =
      EdgeInsetsDirectional.fromSTEB(_barWidth + 14, 16, 14, 16);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      // A transparent Material so the name's own ink ripple paints on
      // this tile's surface rather than underneath it.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            child,
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: _barWidth,
              child: ColoredBox(color: barColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// A team's pair of player names, grouped visually under a "Team
/// 1"/"Team 2" heading inside one [_FieldTile] — without it, two
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
    final nameStyle = AppTypography.fieldName(context).copyWith(fontSize: 17);
    return _FieldTile(
      barColor:
          teamNumber == 1 ? context.palette.neutralBar : context.palette.accent,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: nameStyle,
                  editHint: editHint,
                  textKey: Key('player${slots[i]}PreviewNameText'),
                  fieldKey: Key('player${slots[i]}PreviewNameField'),
                  onChanged: (name) => onNameChanged(slots[i], name),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
