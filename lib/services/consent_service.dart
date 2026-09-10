import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google-mandated GDPR/UK consent gate (Phase 6), sitting in front of
/// every ad request built in Phase 5: EEA/UK users must see Google's
/// User Messaging Platform (UMP) consent form before this app's first ad
/// request, and must always have a way to review/change that choice
/// later (see [MonetizationController.privacyOptionsRequired] and the
/// "Privacy options" entry it drives in `SetupScreen`'s overflow menu).
/// Outside the EEA/UK, UMP itself determines no form is required and
/// every method here degrades to a same-session no-op. See
/// PHASE6_PRELAUNCH_PREP.md.
abstract class ConsentService {
  /// Requests a consent information update from Google's UMP SDK and,
  /// if required for this user's region (EEA/UK) and not already
  /// obtained, loads and shows the consent form. Must complete — with a
  /// decision made or confirmed not needed — before [canRequestAds] is
  /// checked. Best-effort like [AdsService]: any failure (no network,
  /// plugin unavailable — notably in `flutter test`, which has no real
  /// UMP platform implementation) is caught and treated as "no consent
  /// decision available" rather than crashing.
  Future<void> gatherConsent();

  /// Whether an ad request is currently allowed under UMP's consent
  /// state — false both while a required EEA/UK decision is still
  /// outstanding and on any failure to check, so a failure can never
  /// accidentally permit a non-compliant ad request.
  Future<bool> canRequestAds();

  /// Whether UMP requires this user to have a "Privacy options" entry
  /// point (EEA/UK, i.e. consent was actually gathered) — used to decide
  /// whether to show that menu entry at all.
  Future<bool> isPrivacyOptionsRequired();

  /// Re-opens the consent form so the user can review or change their
  /// choice later.
  Future<void> showPrivacyOptionsForm();
}

class UmpConsentService implements ConsentService {
  @override
  Future<void> gatherConsent() async {
    final completer = Completer<void>();
    void complete() {
      if (!completer.isCompleted) completer.complete();
    }

    // `ConsentInformation.requestConsentInfoUpdate` is callback-based
    // (declared `void`, not `Future<void>`), and its own implementation
    // only catches `PlatformException` internally — not the
    // `MissingPluginException` `flutter test`'s environment throws when
    // no real UMP platform implementation is registered. Without a zone
    // guard, that specific failure would escape as an unhandled async
    // error instead of reaching this class's own try/catch, since it
    // occurs inside a callback this code can't wrap in a normal
    // try/await. See PHASE6_PRELAUNCH_PREP.md for how this was found.
    runZonedGuarded(() {
      try {
        ConsentInformation.instance.requestConsentInfoUpdate(
          ConsentRequestParameters(),
          () {
            ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null) {
                debugPrint('UmpConsentService: consent form error — '
                    'code=${formError.errorCode} '
                    'message=${formError.message}');
              }
            }).catchError((Object e) {
              debugPrint(
                  'UmpConsentService: loadAndShowConsentFormIfRequired '
                  'threw: $e');
            }).whenComplete(complete);
          },
          (error) {
            debugPrint('UmpConsentService: requestConsentInfoUpdate '
                'failed — code=${error.errorCode} '
                'message=${error.message}');
            complete();
          },
        );
      } catch (e) {
        debugPrint('UmpConsentService.gatherConsent threw: $e');
        complete();
      }
    }, (error, stack) {
      debugPrint('UmpConsentService: unhandled consent-flow error — $error');
      complete();
    });

    return completer.future;
  }

  @override
  Future<bool> canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('UmpConsentService.canRequestAds threw: $e');
      return false;
    }
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('UmpConsentService.isPrivacyOptionsRequired threw: $e');
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptionsForm() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          debugPrint('UmpConsentService: privacy options form error — '
              'code=${formError.errorCode} message=${formError.message}');
        }
      });
    } catch (e) {
      debugPrint('UmpConsentService.showPrivacyOptionsForm threw: $e');
    }
  }
}
