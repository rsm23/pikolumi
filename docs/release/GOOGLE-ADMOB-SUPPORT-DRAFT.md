# Google AdMob support request

Status: sent on 2026-10-12 at 04:36 UTC with explicit user authorization. Destination: Google AdMob publisher email support through [the official support portal](https://support.google.com/admob/gethelp), using the form's verified publisher account `pub-3316613733634147`. The portal confirmed “Your email has been sent”; it displayed no case number and says follow-up is conditional. No files were attached.

The form permits 1,000 characters, so the submitted 984-character body preserves the five questions and SDK configuration in condensed form. The exact submitted subject/body and confirmation are saved in [google-admob-support-request.json](google-admob-support-request.json), with [screenshot proof](store-proof/admob-support-sent.png). Replies go to the signed-in AdMob login email; `rahmani@seifelmoulouk.com` is included as the public contact in the body. This request does not resolve or approve the pending release requirements. The full prepared message is retained below for a follow-up if requested.

## Message

**Subject: Pikolumi: public Kids advertising practices and child-mode SDK data disclosures**

We are preparing Pikolumi, a free educational app for children aged 2–11 on Android, iPhone and iPad. Activities, avatar profiles, artwork and progress work locally. There are no accounts, real-name or birthdate fields, cloud backend, app-owned analytics, purchases or subscriptions. App-owned external links, exports and privacy controls are behind a parent gate. Production release is held; QA uses official Google test ad units.

Our publisher account is `pub-3316613733634147`. The package/bundle identifier is `com.seifelmoulouk.pikolumi`. We use banners on library screens and interstitials only between completed activities and the library, with foreground-use and frequency limits. High-engagement ads are disabled in both AdMob app registrations.

Current integration:

- Flutter plugin `google_mobile_ads` 9.1.0; legacy Android Google Mobile Ads 25.4.0 and UMP 4.0.0; iOS Google Mobile Ads 13.11.0 and UMP 3.1.0. No mediation adapters or Next-Gen SDK opt-in.
- `AgeRestrictedTreatment.child` and maximum G rating are applied before initialization. Requests are non-personalized. UMP uses `tagForUnderAgeOfConsent: true`; required forms are reserved for parents.
- Android advertising-ID and AdServices identifier/topic/attribution permissions are removed. After initialization, we call `putPublisherFirstPartyIdEnabled(false)` and require a successful persistence result before loading ads.
- iOS publisher first-party ID is disabled before initialization. There is no ATT request or tracking usage-description key.
- We have native test evidence for accepted SDK settings, not an inspection of every transmitted field.

Before enabling production advertising, could you provide public documentation or precise technical clarification for these points?

1. **Kids creative review:** which published AdMob practices cover human review of creatives for age appropriateness in Apple's Kids category, including banners, interstitials and programmatic demand? Apple's [Guideline 1.3](https://developer.apple.com/app-store/review/guidelines/#kids-category) requires publicly documented Kids practices that include human creative review. G ratings, child treatment and publisher review after impressions do not by themselves establish that evidence.
2. **Exact child-mode data handling:** for these SDK versions and settings, what data is collected or shared during initialization and ad requests? Please distinguish IP-derived location, advertising/interactions/diagnostics, AAID/IDFA, IDFV, Android ID, app set ID, rotating SDK instance IDs and other account or device identifiers, with purposes and recipients.
3. **Android initialization:** the publisher-ID API requires initialization first. On a fresh install, is that identifier generated or transmitted before the disabled setting can be persisted, despite child treatment? Which identifier protections apply on Android versions predating the advertising-ID permission requirement?
4. **Store disclosures:** which Apple App Privacy and Google Play Data Safety categories, linkage, tracking, sharing and purposes remain applicable? The bundled iOS SDK manifest includes a linked/tracking device-ID category, while our app requests no ATT authorization. Google's current [Android disclosure page](https://developers.google.com/admob/android/privacy/play-data-disclosure) describes 25.5.0; please identify the corresponding 25.4.0 disclosure or relevant differences.
5. **Kids navigation:** is there a documented SDK mechanism or serving practice for handling ad click-through/external navigation in an iOS Kids app with parent-gated external links?

Please provide published Kids-specific sources where available. We will keep the iOS release held while these requirements remain unestablished; we are not asking for a guarantee of App Store approval.

Support/privacy website: https://seifelmoulouk.com/pikolumi/en.html

Contact: rahmani@seifelmoulouk.com

Thank you,

Pikolumi development
