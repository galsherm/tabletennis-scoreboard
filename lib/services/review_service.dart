import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Play Store listing for this app — the fallback target when the
/// plugin's own "open the store listing" call fails.
const String playStoreListingUrl =
    'https://play.google.com/store/apps/details?id=com.kozmokramer.tabletennisscoreboard';

/// The platform side of "Rate this app": the store's own in-app review
/// sheet (automatic prompt only) and the store listing page (the manual
/// menu item).
///
/// Same shape as [AdsService]/[PurchaseGateway]/[SoundEffectPlayer]: an
/// abstract interface so tests inject a fake, and a real implementation
/// whose every method is best-effort and swallows its own errors — a
/// rating prompt is the least essential thing in this app and must never
/// crash or block it.
abstract class ReviewService {
  /// Asks the store to show its in-app review sheet. The store
  /// quota-limits this sheet at its own discretion and reports nothing
  /// back either way, so this may well show nothing — which is why it
  /// must never be wired to a button, only to the one-time automatic
  /// prompt.
  Future<void> requestReview();

  /// Opens this app's store listing. Resolves to whether it was opened.
  Future<bool> openStoreListing();
}

/// Real [ReviewService] backed by `in_app_review`.
class InAppReviewService implements ReviewService {
  final InAppReview _review = InAppReview.instance;

  @override
  Future<void> requestReview() async {
    try {
      if (!await _review.isAvailable()) return;
      await _review.requestReview();
    } catch (e) {
      debugPrint('InAppReviewService: requestReview failed: $e');
    }
  }

  @override
  Future<bool> openStoreListing() async {
    try {
      await _review.openStoreListing();
      return true;
    } catch (e) {
      debugPrint('InAppReviewService: openStoreListing failed: $e');
    }
    try {
      return await launchUrl(
        Uri.parse(playStoreListingUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('InAppReviewService: store listing URL failed: $e');
      return false;
    }
  }
}
