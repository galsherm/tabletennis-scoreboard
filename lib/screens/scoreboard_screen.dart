import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/player.dart';
import '../models/player_names.dart';
import '../models/scoring_engine.dart';
import '../services/ads_service.dart';
import '../services/commentary_strings.dart';
import '../services/match_export.dart';
import '../services/monetization_controller.dart';
import '../services/pro_status_store.dart';
import '../services/purchase_gateway.dart';
import '../services/voice_announcer.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_score_text.dart';
import '../widgets/match_complete_dialog.dart';
import '../widgets/pro_dialog.dart';

class ScoreboardScreen extends StatefulWidget {
  final int bestOf;
  final Player firstServer;

  /// Overridable for tests; defaults to a real [VoiceAnnouncer] backed by
  /// the device's TTS engine and the bundled clip set, in whichever
  /// language the widget tree is currently displaying.
  final VoiceAnnouncer? voiceAnnouncer;

  /// Custom player names, set on the setup screen before this match
  /// started — the *only* place names can be edited (Phase 4H). Once
  /// this screen is showing, names render as plain, uneditable text.
  final PlayerNames? initialNames;

  /// Owns ads/purchases/Pro status (Phase 5) — overridable for tests to
  /// inject fakes; defaults to a real, self-initializing instance
  /// otherwise, matching [voiceAnnouncer]'s optional-with-safe-default
  /// pattern. See [SetupScreen.monetization] for the ownership rule this
  /// follows.
  final MonetizationController? monetization;

  const ScoreboardScreen({
    super.key,
    required this.bestOf,
    required this.firstServer,
    this.voiceAnnouncer,
    this.initialNames,
    this.monetization,
  });

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  late TableTennisScoringEngine _engine;
  late VoiceAnnouncer _voice;
  bool _voiceInitialized = false;

  /// Custom names for this match (Phase 4F), fixed for the lifetime of
  /// this screen — set once from [widget.initialNames] on the setup
  /// screen and never mutated here (Phase 4H locks editing to setup
  /// only), including across a "New match" reset: since there's no way
  /// to re-edit a name from this screen, clearing it on reset would
  /// permanently lose it until the user backs all the way out to setup.
  late final PlayerNames _names;

  late final MonetizationController _monetization;
  late final bool _ownsMonetization;

  @override
  void initState() {
    super.initState();
    _engine = TableTennisScoringEngine(
      bestOf: widget.bestOf,
      firstServer: widget.firstServer,
    );
    _names = widget.initialNames ?? PlayerNames();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reading the effective locale requires an inherited widget lookup,
    // which isn't safe in initState — this runs once, right before the
    // first build, which is early enough since the match's language is
    // fixed for the lifetime of this screen (changing the override sends
    // the user back through setup for their next match).
    if (!_voiceInitialized) {
      _voiceInitialized = true;
      _voice = widget.voiceAnnouncer ??
          VoiceAnnouncer(
            strings: CommentaryStrings.forLanguage(
              CommentaryLanguage.fromLanguageCode(
                Localizations.localeOf(context).languageCode,
              ),
            ),
          );
    }
  }

  void _scorePoint(Player scorer) {
    if (!_engine.canScore) return;
    final event = _engine.addPoint(scorer);
    final server = _engine.currentServer; // who serves next, not who just served
    setState(() {});

    // nameFor: a custom name (Phase 4F), once set, is what voice should
    // say too — a game/match win renamed "Alex" shouldn't still announce
    // "Player 1". Falls back to _voice.strings.playerLabel (the voice
    // layer's OWN language default), not the widget tree's UI-locale
    // label — those can legitimately differ (e.g. a screen configured
    // with an explicit VoiceAnnouncer in one language inside a UI
    // showing another, as several tests do), and voice should stay
    // internally consistent with itself when no custom name overrides
    // it. See PHASE4F_THEME_AND_NAMES.md.
    _voice.announcePoint(
      engine: _engine,
      event: event,
      server: server,
      nameFor: _voiceNameFor,
    );

    // Exactly one of these three branches applies per point — a
    // completed game always implies a change of ends, so we don't
    // show two separate banners for the same point.
    if (event.matchCompleted) {
      _showMatchCompleteDialog(event.matchWinner!);
    } else if (event.gameCompleted) {
      _showGameCompleteBanner(event.gameWinner!);
    } else if (event.changeEndsNow) {
      _showChangeEndsBanner();
    }
  }

  void _toggleMute() => setState(() => _voice.toggleMuted());

  void _undo() => setState(() => _engine.undo());

  /// Resets the match itself. Custom names are *not* cleared — see the
  /// [_names] doc comment (Phase 4H changed this from Phase 4F's
  /// behavior, where "New match" used to reset names too).
  void _resetMatch() => setState(() => _engine.resetMatch());

  String _defaultPlayerLabel(Player player) {
    final l10n = AppLocalizations.of(context);
    return player == Player.one ? l10n.player1Label : l10n.player2Label;
  }

  String _playerLabel(Player player) {
    final slot = player == Player.one ? 1 : 2;
    return _names.resolve(slot, _defaultPlayerLabel(player));
  }

  /// Like [_playerLabel], but falls back to the voice layer's own
  /// language default ([VoiceAnnouncer.strings]) instead of the UI's
  /// [AppLocalizations] when no custom name is set — see the call site
  /// in [_scorePoint] for why those can differ.
  String _voiceNameFor(Player player) {
    final slot = player == Player.one ? 1 : 2;
    return _names.resolve(slot, _voice.strings.playerLabel(player));
  }

  void _showChangeEndsBanner() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('changeEndsSnackBar'),
        content: Text(AppLocalizations.of(context).changeEndsSnackBar),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showGameCompleteBanner(Player winner) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('gameCompleteSnackBar'),
        content: Text(AppLocalizations.of(context)
            .gameCompleteMessage(_playerLabel(winner))),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMatchCompleteDialog(Player winner) {
    final l10n = AppLocalizations.of(context);
    // Fire-and-forget: on a real device, a loaded interstitial takes over
    // the full screen and the dialog beneath it simply appears once
    // dismissed; if Pro has removed ads or none was ready, this is a
    // no-op and the dialog shows immediately, exactly as before Phase 5.
    _monetization.maybeShowMatchEndAd();
    _monetization.recordMatchCompleted();
    final isPro = _monetization.isPro;
    showDialog(
      context: context,
      builder: (_) => MatchCompleteDialog(
        key: const Key('matchCompleteDialog'),
        titleText: l10n.matchCompleteDialogTitle,
        messageText: l10n.matchCompleteMessage(_playerLabel(winner)),
        buttonText: l10n.newMatchButton,
        exportButtonText: isPro ? l10n.exportMatchButton : null,
        onExport: isPro ? () => _exportMatch(winner) : null,
        exportedConfirmationText: isPro ? l10n.exportMatchCopied : null,
        onNewMatch: () {
          Navigator.of(context).pop();
          _resetMatch();
        },
      ),
    ).then((_) => _maybeShowUpsell());
  }

  /// An occasional, unprompted "Remove Ads" nudge — never mid-match (this
  /// only ever runs right after the match-complete dialog above closes),
  /// and gated by [MonetizationController.shouldOfferUpsell] so it
  /// appears every few matches at most, never every single one, and
  /// never twice in the same session once dismissed. The purchase flow
  /// itself is unaffected by this gate — it's always reachable via the
  /// setup screen's app-bar Pro icon regardless. See
  /// PHASE5_MONETIZATION.md.
  void _maybeShowUpsell() {
    if (!mounted || !_monetization.shouldOfferUpsell) return;
    _monetization.markUpsellShown();
    showDialog(
      context: context,
      builder: (_) => ProDialog(monetization: _monetization),
    ).then((_) {
      if (!_monetization.isPro) _monetization.dismissUpsell();
    });
  }

  /// Pro-only (Phase 5): copies a plain-text summary of the just-completed
  /// match to the clipboard — the minimal "match-history export" scoped
  /// for this phase (one match, not a saved history). The dialog itself
  /// shows the "copied" confirmation (see [MatchCompleteDialog.
  /// exportedConfirmationText]) rather than a SnackBar here, since a
  /// SnackBar triggered from within an open dialog never actually
  /// animates into view. See PHASE5_MONETIZATION.md.
  void _exportMatch(Player winner) {
    final l10n = AppLocalizations.of(context);
    final summary = buildMatchExportSummary(
      appTitle: l10n.appTitle,
      player1Label: _playerLabel(Player.one),
      player2Label: _playerLabel(Player.two),
      completedGames: _engine.completedGames,
      bestOf: widget.bestOf,
      gameLine: (number, p1Points, p2Points) =>
          l10n.exportGameLine(number, p1Points, p2Points),
      winnerMessage: l10n.matchCompleteMessage(_playerLabel(winner)),
    );
    Clipboard.setData(ClipboardData(text: summary));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final server = _engine.currentServer;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scoreboardTitle),
        actions: [
          IconButton(
            key: const Key('muteButton'),
            icon: Icon(_voice.isMuted ? Icons.volume_off : Icons.volume_up),
            iconSize: AppMetrics.iconButtonSize,
            tooltip: _voice.isMuted ? l10n.unmuteTooltip : l10n.muteTooltip,
            onPressed: _toggleMute,
          ),
          IconButton(
            key: const Key('undoButton'),
            icon: const Icon(Icons.undo),
            iconSize: AppMetrics.iconButtonSize,
            tooltip: l10n.undoTooltip,
            onPressed: _engine.canUndo ? _undo : null,
          ),
          IconButton(
            key: const Key('resetButton'),
            icon: const Icon(Icons.refresh),
            iconSize: AppMetrics.iconButtonSize,
            tooltip: l10n.resetTooltip,
            onPressed: _resetMatch,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: _PlayerZone(
              key: const Key('player1Zone'),
              label: _playerLabel(Player.one),
              points: _engine.player1Points,
              gamesLabel: l10n.gamesCountLabel(_engine.player1Games),
              isServer: server == Player.one,
              servingTooltip: l10n.servingTooltip,
              pointsKey: const Key('player1PointsText'),
              serverIconKey: const Key('player1ServerIcon'),
              nameTextKey: const Key('player1NameText'),
              onTap: () => _scorePoint(Player.one),
            ),
          ),
          VerticalDivider(width: 1, color: context.palette.divider),
          Expanded(
            child: _PlayerZone(
              key: const Key('player2Zone'),
              label: _playerLabel(Player.two),
              points: _engine.player2Points,
              gamesLabel: l10n.gamesCountLabel(_engine.player2Games),
              isServer: server == Player.two,
              servingTooltip: l10n.servingTooltip,
              pointsKey: const Key('player2PointsText'),
              serverIconKey: const Key('player2ServerIcon'),
              nameTextKey: const Key('player2NameText'),
              onTap: () => _scorePoint(Player.two),
            ),
          ),
        ],
      ),
    );
  }
}

/// A large, tap-anywhere half of the scoreboard. Layout defers entirely
/// to the score digit at its center — the player label above and the
/// games count below are deliberately small and muted (see
/// [AppTypography]) so the eye lands on the number first.
class _PlayerZone extends StatelessWidget {
  final String label;
  final int points;
  final String gamesLabel;
  final bool isServer;
  final String servingTooltip;
  final Key pointsKey;
  final Key serverIconKey;
  final Key nameTextKey;
  final VoidCallback onTap;

  const _PlayerZone({
    super.key,
    required this.label,
    required this.points,
    required this.gamesLabel,
    required this.isServer,
    required this.servingTooltip,
    required this.pointsKey,
    required this.serverIconKey,
    required this.nameTextKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // A visible highlight while held, on top of the ripple — courtside
        // taps are quick and imprecise, so the press feedback needs to be
        // obvious, not subtle.
        highlightColor: context.palette.accent.withValues(alpha: 0.12),
        splashColor: context.palette.accent.withValues(alpha: 0.18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 30,
                child: isServer
                    ? Tooltip(
                        message: servingTooltip,
                        child: Icon(
                          Icons.sports_tennis,
                          key: serverIconKey,
                          color: context.palette.accent,
                          size: 26,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              // Plain, uneditable text — names can only be set on the
              // setup screen (Phase 4H); the in-match screen stays
              // focused purely on score, with no edit affordance at all.
              Text(
                label,
                key: nameTextKey,
                style: AppTypography.playerLabel(context),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Expanded(
                child: Center(
                  child: AnimatedScoreText(points: points, scoreKey: pointsKey),
                ),
              ),
              const SizedBox(height: 6),
              Text(gamesLabel, style: AppTypography.gamesLabel(context)),
            ],
          ),
        ),
      ),
    );
  }
}
