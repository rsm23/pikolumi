# Advertising integration and evidence

Publisher `pub-3316613733634147` verified in the signed-in live AdMob account on 2026-10-11. Two dedicated Pikolumi app registrations and four ad units were created; IDs are in `config/ads.json`. Screenshots `admob-android.png` and `admob-ios.png` show the units. They are not linked to a published store listing and AdMob readiness review remains pending.

Development and QA use Google's official test unit IDs even though native app IDs belong to Pikolumi. Production is opt-in with `ADS_PRODUCTION`, and iOS additionally checks `IOS_KIDS_ADS_VERIFIED`. The release script refuses to produce a public release unless the evidence file passes every release gate. This flag must never be used as a substitute for evidence.

Flutter integration: `google_mobile_ads 9.1.0`, default stable Android `com.google.android.gms:play-services-ads:25.4.0` (not the Next-Gen opt-in artifact), UMP 4.0.0. Google's Families self-certified list currently includes `play-services-ads` 19.0.0 and later. Recheck the resolved dependency graph and the live list at submission.

Before SDK initialization: age-restricted treatment `child` and content rating G. On iOS, the publisher first-party ID and current mute preference are applied before initialization. Android requires initialization before its publisher-ID and mute APIs: the app calls the native `putPublisherFirstPartyIdEnabled(false)` switch, checks that the choice persisted, and applies mute before allowing any ad load. Failure or timeout leaves ads suspended. Every request is non-personalized. Android manifests explicitly remove AD_ID, ad-services identifier, Topics and Attribution permissions. There is no ATT request or app-owned identifier collection. These settings do not mean that the advertising SDK processes no network/device information.

Audience is wholly child-directed. Older people can enjoy advanced activities, but v1 does not declare a mixed child/adult audience or relax advertising protections based on a profile's learning stage. If the actual declared store audience changes to mixed, add a neutral age screen before SDK initialization; a learning band is not an age screen.

UMP updates at launch. Required forms and privacy options are presented only from the parent area; required consent holds production ad requests. The privacy entry appears when required or when an update needs retry. A retry reapplies all child protections and mute settings before initializing or requesting ads. Concurrent initialization/privacy actions share their pending operation. Leaving the parent route prevents a delayed form from appearing. Failed updates/loads or unavailable privacy eligibility do not block offline content. Withdrawing eligibility disposes loaded/pending banners and interstitials, and late SDK callbacks cannot restore them.

One labeled adaptive banner appears at the bottom of the current library page, separated by padding/divider from content and navigation; banners are hidden during activities and interstitials. No launch, exit, rewarded or offerwall ads exist.

## Live serving settings, 2026-10-12

High-engagement ads were initially On for both Pikolumi registrations. They are now saved Off, verified by reopening each setting after saving. `admob-serving-settings.json` records the Android/iOS app IDs and proof screenshots. [Google's setting documentation](https://support.google.com/admob/answer/15525707?hl=en-GB) explains the extra viewing time and exit steps enabled by this mode. The setting does not cover partner bidding units; Pikolumi uses dedicated standard units. Disabling this mode does not certify actual production dismissal timing or satisfy Apple's advertising exception.

Interstitial policy is global across profiles/restarts: at least 300,000 ms accumulated foreground use, at least four completions, at least 300,000 ms foreground use since the last shown interstitial, fewer than six impressions in the trailing 3,600,000 ms. Startup takes its state from Flutter's current lifecycle: an already-paused app cannot start the foreground clock or enable audio. Resume starts counting, and pause stops it. Actual displayed impressions, rather than load attempts, consume the budget. Ineligible/unavailable ads return immediately. Completion is committed before an interstitial. Audio stops when backgrounded or while an ad is presented; sound preferences survive dismissal.

## Native QA and dismissal gate

Muted iPhone and iPad simulator runs now pass banner loading, hiding during the interstitial, native close/dismissal callback, global frequency accounting, muted sound preferences and banner restoration on return to the library. The initial close failures were traced to Device Hub disabling legacy HID input. The serve-sim input repair was scoped to each test simulator; the original input flag and normal app were restored afterward. The harness uses an isolated memory store and official test IDs. Evidence is in `docs/qa/ad-checks/ios-phone-mirror/` and `ios-tablet-mirror/`.

Physical-device dismissal timing remains required before either public submission. Google Families requires interfering ads to be closeable after five seconds. The official test creative does not establish compliant timing for the production serving setup. Simulator callback success does not clear either platform's production dismissal gate.

The live Families SDK table was rechecked on 2026-10-12. Its Google AdMob entry covers `com.google.android.gms:play-services-ads` 19.0.0 or later. The exact signed QA APK's `play-services-ads.properties` reports 25.4.0. `android-families-sdk-verification.json` ties this check to the package hash and clears the Android SDK-list gate. Recheck the list before actual submission; this does not approve creatives, privacy declarations or the Apple exception.

## Unresolved iOS production gate

Apple Kids category guideline 1.3 permits third-party contextual advertising only in limited cases, including publicly documented human review of ad creatives for age appropriateness and restrictive data handling. AdMob's child-directed flags, G rating and Families SDK certification do not establish the Apple exception. No authoritative public evidence that this particular AdMob serving configuration satisfies the human-review requirement has been established. Production iOS ads and App Store submission are therefore held. The intended audience and ads are not silently changed.

On 2026-10-12, [Google's Families guidance](https://support.google.com/admob/answer/6223431?hl=en) confirms child-directed SDK protections and family-friendly ad selection. It does not document a Kids-specific human creative review process. The [Ad review center overview](https://support.google.com/admob/answer/3480906?hl=en) describes publisher review after impressions and notes that blocking can take up to 24 hours. That tool does not establish the publicly documented human review for age appropriateness in [Apple §1.3](https://developer.apple.com/app-store/review/guidelines/#kids-category). This is an evidence gap, not a claim that Apple categorically rejects every AdMob integration.

With explicit user authorization, the five-question technical request was sent to Google AdMob publisher email support on 2026-10-12 at 04:36 UTC. The portal confirmed delivery without a case number; it promises follow-up only if it has further information. [The submission record](google-admob-support-request.json) retains the exact body and screenshot proof. Kids creative-review practices, child-mode SDK disclosures, initialization identifiers and external navigation remain unverified until supporting evidence is received and assessed.

Sources:
- https://developer.apple.com/app-store/review/guidelines/#kids-category
- https://support.google.com/googleplay/android-developer/answer/9893335?hl=en
- https://support.google.com/googleplay/android-developer/answer/12955712
- https://developers.google.com/admob/flutter/targeting
- https://developers.google.com/admob/flutter/privacy
