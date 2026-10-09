import 'review_prompt_store.dart';
import 'review_service.dart';

/// The automatic review prompt fires after this many completed matches.
const int reviewPromptMatchThreshold = 3;

/// Whether the one-time automatic "rate this app" prompt should fire
/// right now. A pure function of its arguments, like
/// `announcementForPoint`/`currentDoublesServingState`, so every rule is
/// unit-testable with no plugin or storage involved:
///
///  - not before the [reviewPromptMatchThreshold]th completed match;
///  - only once ([autoPrompted]);
///  - never once the user has already used the manual "Rate this app"
///    menu item ([manualUsed]) — they've been to the store already;
///  - never while a match is being played ([matchInProgress]).
bool shouldAutoPromptReview({
  required int completedMatches,
  required bool autoPrompted,
  required bool manualUsed,
  required bool matchInProgress,
}) {
  if (matchInProgress) return false;
  if (autoPrompted || manualUsed) return false;
  return completedMatches >= reviewPromptMatchThreshold;
}

/// Ties [ReviewService] (the store's review sheet / listing) to
/// [ReviewPromptStore] (what's already happened on this install), for
/// both routes to a rating: the manual menu item on the setup screen
/// (store listing) and the one-time automatic prompt after a match
/// (in-app review sheet).
///
/// Every method is best-effort and never throws, so call sites can
/// fire-and-forget them the same way they do [MonetizationController]'s.
class ReviewPrompter {
  final ReviewService _service;
  final ReviewPromptStore _store;

  /// The in-flight [recordMatchCompleted] write, if any — awaited by
  /// [maybePromptAfterMatch] so a result dialog dismissed very quickly
  /// can't read the count from before its own match was added to it.
  Future<void>? _pendingRecord;

  ReviewPrompter({ReviewService? service, ReviewPromptStore? store})
      : _service = service ?? InAppReviewService(),
        _store = store ?? ReviewPromptStore();

  /// Counts one more completed match towards the automatic prompt.
  Future<void> recordMatchCompleted() {
    final previous = _pendingRecord;
    final record = () async {
      if (previous != null) await previous;
      await _store.incrementCompletedMatches();
    }();
    _pendingRecord = record;
    return record;
  }

  /// Requests the store's review sheet if [shouldAutoPromptReview] says
  /// this is the moment, and records that it did so it never asks again.
  /// Resolves to whether a review was requested.
  ///
  /// Only ever asks for the in-app sheet — never opens the store
  /// listing the way [rateManually] does — so if the store decides to
  /// show nothing, nothing happens at all: an unprompted request must
  /// stay trivially easy to ignore.
  Future<bool> maybePromptAfterMatch({required bool matchInProgress}) async {
    try {
      await _pendingRecord;
      final state = await _store.load();
      if (!shouldAutoPromptReview(
        completedMatches: state.completedMatches,
        autoPrompted: state.autoPrompted,
        manualUsed: state.manualUsed,
        matchInProgress: matchInProgress,
      )) {
        return false;
      }
      // Recorded before asking, not after: a request that fails or is
      // throttled still counts as this install's one automatic attempt.
      await _store.markAutoPrompted();
      await _service.requestReview();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The "Rate this app" menu item: opens the store listing directly.
  /// Never the in-app review sheet — that one is quota-limited by the
  /// store and may silently show nothing, which a button the user just
  /// tapped can't afford. Also records the manual use, which retires
  /// the automatic prompt for good.
  Future<void> rateManually() async {
    try {
      await _store.markManualUsed();
      await _service.openStoreListing();
    } catch (_) {
      // Best-effort — see the class doc comment.
    }
  }
}
