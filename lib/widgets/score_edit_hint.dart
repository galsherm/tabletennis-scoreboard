import 'package:flutter/material.dart';

import '../services/score_edit_hint_store.dart';

/// A barely-noticeable, exactly-once "breathing" pulse (scale 1.0 ->
/// 1.02 -> 1.0, slow and gentle) on whatever [child] it wraps — the
/// discoverability hint for the Phase 4M long-press score-correction
/// gesture. Deliberately not a dashed underline (that affordance is
/// reserved for editable names, see [EditableNameLabel]) and not a
/// pencil/edit icon — just a quiet motion cue, played once per install
/// via [ScoreEditHintStore], the very first time a scoreboard screen is
/// ever opened, then never again (persists across new matches and app
/// restarts). See PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md.
///
/// Independent of [AnimatedScoreText]'s own score-change "pop" — that
/// tween restarts on every point scored (keyed on the score value
/// itself); this one runs at most once for this widget's entire
/// lifetime, driven by its own [AnimationController], so the two never
/// fight over the same animation or accidentally cancel each other.
class ScoreEditHint extends StatefulWidget {
  final Widget child;

  /// Overridable for tests, so they can inject a store backed by a
  /// mocked `SharedPreferences` (or assert on calls directly) without
  /// depending on real plugin timing — same optional-with-safe-default
  /// pattern as this app's other services.
  final ScoreEditHintStore? store;

  const ScoreEditHint({super.key, required this.child, this.store});

  @override
  State<ScoreEditHint> createState() => _ScoreEditHintState();
}

class _ScoreEditHintState extends State<ScoreEditHint>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1400);

  late final ScoreEditHintStore _store;
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ScoreEditHintStore();
    _controller = AnimationController(vsync: this, duration: _duration);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.02)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.02, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
    _maybePlay();
  }

  Future<void> _maybePlay() async {
    final alreadyShown = await _store.hasShown();
    if (alreadyShown || !mounted) return;
    // Marked shown before playing, not after: what matters is that this
    // install has already been offered the hint once, not that the
    // animation necessarily ran to completion (e.g. the screen could be
    // popped mid-pulse) — either way, showing it again next time would
    // be the exact repeat this feature exists to prevent.
    await _store.markShown();
    if (!mounted) return;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        key: const Key('scoreEditHintTransform'),
        scale: _scale.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}
