import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Shows a single interstitial ad, and only ever at match-end — never
/// mid-match, never a banner sitting on screen during play. See
/// PHASE5_MONETIZATION.md for why an end-of-match interstitial was
/// chosen over a persistent banner: a banner would be visible for the
/// entire match, which reads as "mid-match" in exactly the way research
/// flagged as the most common competitor complaint; an interstitial
/// fires once, at a natural break in play, and never again until the
/// next match ends.
///
/// Best-effort like [VoiceAnnouncer]/[ThemePreference]: any failure (ad
/// network error, no fill, plugin unavailable — notably in `flutter
/// test`, which has no real AdMob platform implementation) is caught and
/// treated as "no ad this time" rather than crashing or blocking the
/// match-complete flow.
abstract class AdsService {
  Future<void> initialize();
  Future<void> loadInterstitial();
  Future<void> showMatchEndInterstitial();
  void dispose();
}

/// Google's own published sample/test ad unit IDs — always fill with a
/// clearly-marked test ad, never real inventory, and are safe to ship
/// during development. See PHASE5_MONETIZATION.md for what to replace
/// these with before release.
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

  @override
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      // No AdMob platform implementation available (e.g. desktop, or a
      // widget test) — ads simply never show, nothing else breaks.
    }
  }

  @override
  Future<void> loadInterstitial() async {
    try {
      await InterstitialAd.load(
        adUnitId: _testInterstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitialAd = ad,
          onAdFailedToLoad: (error) => _interstitialAd = null,
        ),
      );
    } catch (_) {
      _interstitialAd = null;
    }
  }

  @override
  Future<void> showMatchEndInterstitial() async {
    final ad = _interstitialAd;
    if (ad == null) return; // no ad ready — never block match-end on one
    _interstitialAd = null;
    try {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadInterstitial(); // preload the next one for the match after
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          loadInterstitial();
        },
      );
      await ad.show();
    } catch (_) {
      ad.dispose();
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
  }
}
