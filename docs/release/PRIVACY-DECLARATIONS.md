# Privacy declarations — preparation draft

These are evidence-based preparation notes, not completed App Store Connect or Play Console declarations. No declaration has been submitted. Final answers must match the exact signed production binary, its enabled SDK behavior, current platform questions and published privacy policy.

## Application behavior

- Avatar profile IDs, difficulty, language, local progress, favorites, parent PIN salt/hash, gallery metadata and artwork are stored on the device. No real name or birthdate is requested. Android app backup is disabled and iOS Application Support is excluded from backup.
- There is no account, cloud API, Firebase, third-party analytics integration, purchase or subscription.
- A parent can export a PNG through the OS share sheet. The destination is chosen by the parent; the app does not upload the image to its own server.
- Essential narration is synthetic and bundled. No microphone, camera, contacts, location or photo-library access is requested. Export uses a temporary shared file.
- AdMob/UMP perform network requests. Do **not** answer that the app collects no data merely because app-owned storage is local.

## Advertising SDK behavior to reconcile

The resolved Android Google Mobile Ads SDK is `play-services-ads:25.4.0`; Flutter plugin `google_mobile_ads:9.1.0`; UMP `4.0.0`. Next-Gen SDK opt-in is not enabled. The integration applies child-directed treatment and maximum G rating before initialization, non-personalized requests and disabled same-app key. Android merged permissions remove advertising ID and AdServices identifier/topic/attribution permissions. There is no ATT prompt or usage-description key on iOS.

Google's SDK disclosure documentation lists possible IP address, interaction, diagnostic and device/identifier processing. Identifier restrictions do not eliminate IP or diagnostic processing. Review the current Android/iOS Google disclosures and the actual merged manifest/privacy manifests before final store answers. There is no explicit store-neutral age screen because the proposed audience is exclusively children; if the final audience includes other ages, implement the required neutral screening before changing store declarations or SDK treatment.

- [Android SDK data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure)
- [iOS SDK data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure)
- [Flutter privacy flow](https://developers.google.com/admob/flutter/privacy)
- [Google Families policy](https://support.google.com/googleplay/android-developer/answer/9893335)
- [Apple Kids category §1.3](https://developer.apple.com/app-store/review/guidelines/#kids-category)

## Required before submitting

Confirm the public controller/publisher identity and support contact; publish localized support/privacy pages; host `app-ads.txt` at the actual linked developer website root; complete a production binary/SDK data audit; review applicable consent choices for the declared audience/regions; record the final Play Data Safety and Apple App Privacy answers. Retain the evidence used for each answer.

The five localized pages are published at https://seifelmoulouk.com/pikolumi/ with rahmani@seifelmoulouk.com as the confirmed contact. The existing root app-ads.txt is verified. Production iOS advertising remains held because publicly documented human review of creatives and permitted data handling satisfying Apple's Kids exception have not been established for the proposed setup.
