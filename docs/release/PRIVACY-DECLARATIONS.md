# Privacy declarations — preparation draft

These are evidence-based preparation notes, not completed App Store Connect or Play Console declarations. No declaration has been submitted. Final answers must match the exact signed production binary, its enabled SDK behavior, current platform questions and published privacy policy.

## Application behavior

- Avatar profile IDs, difficulty, language, local progress, favorites, parent PIN salt/hash, gallery metadata and artwork are stored on the device. No real name or birthdate is requested. Android app backup is disabled and iOS Application Support is excluded from backup.
- There is no account, cloud API, Firebase, third-party analytics integration, purchase or subscription.
- A parent can export a PNG through the OS share sheet. The destination is chosen by the parent; the app does not upload the image to its own server.
- Essential narration is synthetic and bundled. No microphone, camera, contacts, location or photo-library access is requested. Export uses a temporary shared file.
- AdMob/UMP perform network requests. Do **not** answer that the app collects no data merely because app-owned storage is local.

## Advertising SDK behavior to reconcile

The resolved Android Google Mobile Ads SDK is `play-services-ads:25.4.0`; Flutter plugin `google_mobile_ads:9.1.0`; UMP `4.0.0`. Next-Gen SDK opt-in is not enabled. The integration applies child-directed treatment and maximum G rating before initialization and non-personalized requests. On iOS, the publisher first-party ID is disabled through the Flutter same-app-key API before initialization. That Flutter API is a no-op on Android. Android now calls `MobileAds.putPublisherFirstPartyIdEnabled(false)` through the app's native bridge after SDK initialization and before any ad loads; a false result, exception or timeout suspends ads. Android merged permissions remove advertising ID and AdServices identifier/topic/attribution permissions. There is no ATT prompt or usage-description key on iOS.

Google's SDK disclosure documentation lists possible IP address, interaction, diagnostic and device/identifier processing. Identifier restrictions do not eliminate IP or diagnostic processing. Review the current Android/iOS Google disclosures and the actual merged manifest/privacy manifests before final store answers. There is no explicit store-neutral age screen because the proposed audience is exclusively children; if the final audience includes other ages, implement the required neutral screening before changing store declarations or SDK treatment.

- [Android SDK data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure)
- [iOS SDK data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure)
- [Flutter privacy flow](https://developers.google.com/admob/flutter/privacy)
- [Google Families policy](https://support.google.com/googleplay/android-developer/answer/9893335)
- [Apple Kids category §1.3](https://developer.apple.com/app-store/review/guidelines/#kids-category)

## Required before submitting

Confirm the public controller/publisher identity and support contact; publish localized support/privacy pages; host `app-ads.txt` at the actual linked developer website root; complete a production binary/SDK data audit; review applicable consent choices for the declared audience/regions; record the final Play Data Safety and Apple App Privacy answers. Retain the evidence used for each answer.

The five localized pages are published at https://seifelmoulouk.com/pikolumi/ with rahmani@seifelmoulouk.com as the confirmed contact. The existing root app-ads.txt is verified. Production iOS advertising remains held because publicly documented human review of creatives and permitted data handling satisfying Apple's Kids exception have not been established for the proposed setup.

## Exact QA IPA manifest audit, 2026-10-12

The five privacy-policy URLs are now saved in App Store Connect and verified after a page reload. `app-store-draft.json` records the per-locale values and screenshots. Saving these links does not complete or publish the data-collection declaration. The user's 2026-10-13 instruction authorizes Android/iOS uploads, review submissions and publication once the required evidence passes; see `release-authorization.json`.

The app now reconciles eligibility after parent privacy choices, disposes pending/loaded ads when eligibility is withdrawn, rejects stale load callbacks, and keeps required forms inside the parent area. SDK retries reapply child protections before initialization. Mute is applied before initialization on iOS and after initialization but before ad loading on Android, as required by Android SDK 25.4. Fifteen silent method-channel/lifecycle/widget tests exercise these cases with official test IDs, including native-setting rejection, bridge errors, timeouts and foreground accounting during interrupted startup. They do not measure SDK network traffic or approve store declarations. Run `scripts/audit_qa_privacy.py` after recording each fresh QA IPA to keep the archived manifests tied to that exact package.

The same audit records the exact Android APK hash and its packaged manifest permissions. Advertising ID and AdServices ID/Attribution/Topics permissions are absent. This is a manifest check, not proof of every runtime identifier or SDK data path.

`qa-privacy-manifest-audit.json` retains every bundled privacy manifest and the exact IPA SHA-256. The resolved iOS frameworks are Google Mobile Ads 13.11.0 and UMP 3.1.0. The Google Mobile Ads manifest declares linked coarse location, advertising data and product interactions, plus a tracking-linked device-ID category. UMP declares coarse location, performance and interaction data for app functionality. These broad SDK declarations are consistent with [Google’s iOS disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure); they are not proof that every category is transmitted in this child-directed configuration. Do not replace the SDK manifest or declare “no data collected.” Exact runtime identifiers/data handling and final store answers remain unverified. The iOS advertising exception is still held.

## Android native verification and disclosure scope, 2026-10-12

The Pixel's real SDK accepted and persisted publisher first-party ID disablement, reported child treatment and maximum G rating, and passed the silent native test body and teardown. See `docs/qa/android-publisher-id/integration_response_data.json`. This establishes an accepted SDK setting, not an absence-of-traffic guarantee. The original native run exposed an existing Android startup failure caused by calling mute before SDK initialization; corrected call ordering passed the subsequent native run.

[Google's Android identifier API](https://developers.google.com/admob/android/reference/com/google/android/gms/ads/MobileAds#putPublisherFirstPartyIdEnabled(boolean)) requires SDK initialization first and returns whether the disabled choice was persisted. [Google's Android privacy guidance](https://support.google.com/admob/answer/11402075) distinguishes the advertising ID from a rotating SDK instance identifier. Removing AAID permission and disabling the publisher ID cannot justify a declaration that no identifiers exist.

The current [Android disclosure page](https://developers.google.com/admob/android/privacy/play-data-disclosure), checked on 2026-10-12, explicitly describes SDK **25.5.0**, while the packaged plugin uses **25.4.0**. Treat its general categories as a preparation baseline, not exact-version or exact-configuration proof. No SDK upgrade was made solely to match that page; production declarations still need an exact-build review. Google documents network-derived location, interactions, diagnostics and device/account identifiers; do not infer that child treatment or non-personalized ads suppress every category.
