/// Master switch for the entire monetization stack (AdMob ads, the
/// GDPR/UMP consent flow that exists solely to gate them, and the
/// one-time "Remove Ads / Pro" purchase). Set to `false` to disable
/// monetization entirely for launch, testing market demand before
/// turning ads/purchases back on — see
/// PHASE7_MONETIZATION_DISABLED_FOR_LAUNCH.md.
///
/// When `false`, [MonetizationController] (the only place that reads
/// this constant):
/// - never initializes AdMob and never requests a banner or
///   interstitial ad;
/// - never runs the UMP consent flow (nothing to consent to with no
///   ads ever requested), so "Privacy options" never appears either;
/// - reports [MonetizationController.isPro] as always `true`, so every
///   Pro-gated feature (match export, ad-free play) behaves as if
///   already purchased;
/// - never offers the automatic "Remove Ads" upsell.
///
/// `SetupScreen` additionally hides the "Remove Ads / Pro" menu entry
/// itself while this is `false`, since there is nothing left for it to
/// do (no ads to remove, already-unlocked features).
///
/// Every implementation this gates — `AdMobAdsService`,
/// `InAppPurchaseGateway`, `UmpConsentService`, `ProDialog`, etc. —
/// stays fully intact and wired either way. Flip this one line back to
/// `true` to re-enable the entire stack; nothing else needs to change.
const bool monetizationEnabled = false;
