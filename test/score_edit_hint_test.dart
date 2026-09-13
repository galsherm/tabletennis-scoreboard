import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/services/score_edit_hint_store.dart';
import 'package:tabletennis_scoreboard/widgets/score_edit_hint.dart';

/// Verifies the Phase 4P score-edit discoverability pulse actually plays
/// exactly once on a fresh install and never again afterwards — the
/// persistence guarantee is the whole point of [ScoreEditHintStore], and
/// isn't something a still screenshot could ever confirm. See
/// PHASE4P_PREMIUM_VISUAL_AND_MOTION_PASS.md.
void main() {
  Widget harness() => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScoreEditHint(
              child: Text('0', key: Key('digit')),
            ),
          ),
        ),
      );

  double currentScale(WidgetTester tester) => tester
      .widget<Transform>(find.byKey(const Key('scoreEditHintTransform')))
      .transform
      .getMaxScaleOnAxis();

  group('ScoreEditHint (Phase 4P)', () {
    testWidgets(
        'plays the one-time pulse on a fresh install, then records it as '
        'shown', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(harness());
      // Two zero-duration pumps to flush the async hasShown()/markShown()
      // round-trip through the mocked shared_preferences channel before
      // _controller.forward() is even called.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700)); // mid-pulse

      expect(currentScale(tester), greaterThan(1.0),
          reason: 'the pulse should be partway through scaling up by now — '
              'if this is 1.0, it never started playing at all');

      await tester.pumpAndSettle();
      expect(currentScale(tester), 1.0,
          reason: 'the pulse eases back to rest once it finishes, rather '
              'than leaving the digit permanently enlarged');

      final store = ScoreEditHintStore();
      expect(await store.hasShown(), isTrue,
          reason: 'a fresh install must record the hint as shown once it '
              'has played, so a later screen/session never replays it');
    });

    testWidgets(
        'never plays again once already recorded as shown — this is what '
        'makes it survive a simulated app restart, since the store reads '
        'from the same persisted shared_preferences state either way',
        (tester) async {
      SharedPreferences.setMockInitialValues({'score_edit_hint_shown': true});
      await tester.pumpWidget(harness());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(currentScale(tester), 1.0,
          reason: 'an install that has already been shown the hint once '
              'must not play it a second time');

      await tester.pumpAndSettle();
      expect(currentScale(tester), 1.0);
    });
  });
}
