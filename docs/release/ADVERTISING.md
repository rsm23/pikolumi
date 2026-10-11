# Advertising integration and evidence

Publisher `pub-3316613733634147` verified in the signed-in live AdMob account on 2026-10-11. Two dedicated Pikolumi app registrations and four ad units were created; IDs are in `config/ads.json`. Screenshots `admob-android.png` and `admob-ios.png` show the units. They are not linked to a published store listing and AdMob readiness review remains pending.

Development and QA use Google's official test unit IDs even though native app IDs belong to Pikolumi. Production is opt-in with `ADS_PRODUCTION`, and iOS additionally checks `IOS_KIDS_ADS_VERIFIED`. The release script refuses to produce a public release unless the evidence file passes every release gate. This flag must never be used as a substitute for evidence.

Flutter integration: `google_mobile_ads 9.1.0`, default stable Android `com.google.android.gms:play-services-ads:25.4.0` (not the Next-Gen opt-in artifact), UMP 4.0.0. Google's Families self-certified list currently includes `play-services-ads` 19.0.0 and later. Recheck the resolved dependency graph and the live list at submission.

Before SDK initialization: age-restricted treatment `child`, content rating G, same-app key disabled on iOS. Every request is non-personalized. Android manifests explicitly remove AD_ID, ad-services identifier, Topics and Attribution permissions. There is no ATT request or app-owned identifier collection. These settings do not mean that the advertising SDK processes no network/device information.

Audience is wholly child-directed. Older people can enjoy advanced activities, but v1 does not declare a mixed child/adult audience or relax advertising protections based on a profile's learning stage. If the actual declared store audience changes to mixed, add a neutral age screen before SDK initialization; a learning band is not an age screen.

UMP updates at launch. Failed updates/loads or unavailable privacy eligibility do not block offline content. Privacy controls are inside the parent gate. One labeled adaptive banner appears at the bottom of the current library page, separated by padding/divider from content and navigation; banners are hidden during activities and interstitials. No launch, exit, rewarded or offerwall ads exist.

Interstitial policy is global across profiles/restarts: at least 300,000 ms accumulated foreground use, at least four completions, at least 300,000 ms foreground use since the last shown interstitial, fewer than six impressions in the trailing 3,600,000 ms. Actual displayed impressions, rather than load attempts, consume the budget. Ineligible/unavailable ads return immediately. Completion is committed before an interstitial. Audio stops when backgrounded or while an ad is presented; sound preferences survive dismissal.

## Native QA and dismissal gate

A muted iOS simulator run loaded the banner and displayed the official Google interstitial test creative. Its native close action could not be completed through the simulator mirror; no dismissal or restoration pass is claimed. Physical-device dismissal timing remains required before either public submission. Google Families requires interfering ads to be closeable after five seconds. The sample creative's eventual X does not establish compliant timing for the production serving setup. Do not enable production merely because an ad loaded.

## Unresolved iOS production gate

Apple Kids category guideline 1.3 permits third-party contextual advertising only in limited cases, including publicly documented human review of ad creatives for age appropriateness and restrictive data handling. AdMob's child-directed flags, G rating and Families SDK certification do not establish the Apple exception. No authoritative public evidence that this particular AdMob serving configuration satisfies the human-review requirement has been established. Production iOS ads and App Store submission are therefore held. The intended audience and ads are not silently changed.

Sources:
- https://developer.apple.com/app-store/review/guidelines/#kids-category
- https://support.google.com/googleplay/android-developer/answer/9893335?hl=en
- https://support.google.com/googleplay/android-developer/answer/12955712
- https://developers.google.com/admob/flutter/targeting
- https://developers.google.com/admob/flutter/privacy
