import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Shows a single interstitial ad, and only ever at match-end — never
/// mid-match, never a banner sitting on screen during play. See
/// PHASE5_MONETIZATION.md for why an end-of-match interstitial was
/// chosen over a persistent banner: a banner would be visible for the
/// entire match, which reads as "mid-match" in exactly the way research
/// flagged as the most common competitor complaint; an interstitial
/// fires once, at a natural break in play, and never again until the
/// next match ends. There is deliberately no banner ad anywhere in this
/// app — if real-device testing is looking for one, it was never built;
/// only this interstitial exists.
///
/// Best-effort like [VoiceAnnouncer]/[ThemePreference]: any failure (ad
/// network error, no fill, plugin unavailable — notably in `flutter
/// test`, which has no real AdMob platform implementation) is caught and
/// treated as "no ad this time" rather than crashing or blocking the
/// match-complete flow. Unlike those simpler services, every failure
/// here is also logged via [debugPrint] — a real-device bug report
/// ("the ad never shows") found this had previously been swallowed with
/// no diagnostic output at all, making it impossible to tell a bad ad
/// unit ID apart from a transient network failure apart from AdMob
/// simply having no fill. See PHASE5_MONETIZATION.md.
abstract class AdsService {
  Future<void> initialize();
  Future<void> loadInterstitial();
  Future<void> showMatchEndInterstitial();
  void dispose();
}

/// Google's own published sample/test ad unit IDs — verified against
/// Google's official test-ad documentation, not placeholders. Always
/// fill with a clearly-marked test ad, never real inventory, and are
/// safe to ship during development. See PHASE5_MONETIZATION.md for what
/// to replace these with before release.
String get _testInterstitialAdUnitId {
  try {
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910';
  } catch (_) {
    // Platform.isIOS throws on web/unsupported platforms; fall through
    // to the Android ID, which is also harmless there since AdMob simply
    // won't load on an unsupported platform.
  }
  return 'ca-app-pub-3940256099942544/1033173712';
}

class AdMobAdsService implements AdsService {
  InterstitialAd? _interstitialAd;

  /// Backs off a failed load attempt rather than giving up on ads for
  /// the rest of the session — a real-device bug report ("the ad never
  /// appears") traced back to exactly this: the very first load attempt
  /// failed (a transient network hiccup at cold start) and nothing ever
  /// tried again, since a retry was previously only scheduled after
  /// successfully *showing* an ad. Doubles up to [_maxRetryDelay] on each
  /// consecutive failure, and resets to [_initialRetryDelay] on success.
  static const _initialRetryDelay = Duration(seconds: 5);
  static const _maxRetryDelay = Duration(minutes: 2);
  Duration _retryDelay = _initialRetryDelay;
  Timer? _retryTimer;

  @override
  Future<void> initialize() async {
    try {
      final status = await MobileAds.instance.initialize();
      final adapterSummary = status.adapterStatuses.entries
          .map((e) => '${e.key}=${e.value.state.name}')
          .join(', ');
      debugPrint('AdMobAdsService: SDK initialized ($adapterSummary)');
    } catch (e) {
      debugPrint('AdMobAdsService.initialize failed: $e');
    }
  }

  @override
  Future<void> loadInterstitial() async {
    _retryTimer?.cancel();
    final adUnitId = _testInterstitialAdUnitId;
    debugPrint('AdMobAdsService: requesting interstitial ($adUnitId)');
    try {
      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('AdMobAdsService: interstitial loaded successfully');
            _interstitialAd = ad;
            _retryDelay = _initialRetryDelay;
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdMobAdsService: interstitial failed to load — '
                'code=${error.code} domain=${error.domain} '
                'message=${error.message}');
            _interstitialAd = null;
            _scheduleRetry();
          },
        ),
      );
    } catch (e) {
      debugPrint('AdMobAdsService.loadInterstitial threw: $e');
      _interstitialAd = null;
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, loadInterstitial);
    final nextDelaySeconds =
        (_retryDelay.inSeconds * 2).clamp(1, _maxRetryDelay.inSeconds);
    _retryDelay = Duration(seconds: nextDelaySeconds);
  }

  @override
  Future<void> showMatchEndInterstitial() async {
    final ad = _interstitialAd;
    if (ad == null) {
      debugPrint('AdMobAdsService: no interstitial ready to show at '
          'match end');
      return; // no ad ready — never block match-end on one
    }
    debugPrint('AdMobAdsService: showing interstitial at match end');
    _interstitialAd = null;
    try {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          debugPrint('AdMobAdsService: interstitial presented on screen');
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('AdMobAdsService: interstitial dismissed, preloading '
              'next');
          ad.dispose();
          loadInterstitial(); // preload the next one for the match after
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('AdMobAdsService: interstitial failed to show — '
              'code=${error.code} domain=${error.domain} '
              'message=${error.message}');
          ad.dispose();
          loadInterstitial();
        },
      );
      await ad.show();
    } catch (e) {
      debugPrint('AdMobAdsService.showMatchEndInterstitial threw: $e');
      ad.dispose();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _interstitialAd?.dispose();
  }
}
