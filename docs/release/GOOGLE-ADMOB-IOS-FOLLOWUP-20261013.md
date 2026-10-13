# Pikolumi iOS support follow-up

Destination: `admob-publisher-support@google.com`, reply to authenticated case `0-5962000041930`. Sending is authorized by the owner's October 13 request to follow up with Google AdMob support. No attachments or private signing credentials are included.

Subject: Re: [0-5962000041930] Pikolumi iOS Kids release: human review and exact SDK privacy clarification

+Dear Google AdMob Support,

Please keep case 0-5962000041930 open and escalate it to a human specialist covering iOS SDK privacy and Kids Category ad-serving policy. The original request was submitted on October 12; your automated response was found in Spam today. We have checked the integration guidance. The unresolved questions concern published practices and exact data handling, rather than an SDK loading error.

Publisher: pub-3316613733634147
App: Pikolumi (com.seifelmoulouk.pikolumi), App Store Connect ID 6821776826
iOS AdMob app: ca-app-pub-3316613733634147~3616124950
Audience: children aged 2–11; App Store Kids primary band under six.
SDKs: Flutter google_mobile_ads 9.1.0, iOS Google Mobile Ads 13.11.0, UMP 3.1.0; no mediation adapters.
Android is now pinned to GMA 25.5.0/UMP 4.0.0 and its production release is in Google Play review. iOS production remains held.

Our iOS configuration applies AgeRestrictedTreatment.child and maximum G rating before initialization, non-personalized requests, UMP under-age treatment, publisher first-party ID disabled before initialization, and delayed app measurement initialization. There is no ATT request or tracking usage-description key. High-engagement ads are Off. The app has no login, cloud backend, separate analytics SDK, purchases or subscriptions. Child profiles, progress and artwork remain local. App-owned external links, export and privacy controls are parent-gated. QA uses official test ads only.

Please answer these release-blocking questions for this exact configuration:

1. Apple Kids creative-review evidence
Please provide public URLs documenting AdMob practices for Apple's Kids Category that include human review of creatives for age appropriateness BEFORE serving, for banners, interstitials and all applicable demand. Please distinguish these practices from automated G filtering, Google Play Families self-certification and publisher review after impressions. Apple guideline 1.3: https://developer.apple.com/app-store/review/guidelines/#kids-category

2. Residual child-mode identifiers and data
With the settings above, which identifiers and data are collected/transmitted during initialization, UMP updates and ad requests? Please specify IDFA, IDFV, app/developer-scoped IDs, publisher first-party IDs, SDK-instance IDs, IP-derived coarse location, interactions and diagnostics; their purposes, linkage, recipients and retention. Does any data support cross-app or cross-company tracking? The absence of IDFA alone does not establish absence of all device information under Apple's Kids rules.

3. Exact App Privacy linkage/tracking answers
The packaged GMA 13.11.0 PrivacyInfo.xcprivacy declares DeviceID linked=true and tracking=true, for third-party advertising, developer advertising and analytics. It declares PerformanceData linked=false and tracking=false for those purposes. UMP 3.1.0 declares performance data not linked/not tracking for app functionality.
The current public iOS disclosure describes user-associated performance data and app/developer-bounded identifiers: https://developers.google.com/admob/ios/privacy/data-disclosure
Please clarify which linkage/tracking declarations apply to the exact child-directed configuration, and explain the performance-linkage discrepancy. We are preserving the SDK manifests, not editing them to hide disclosures.

4. Child ad navigation and dismissal
What supported SDK mechanism or documented serving practice handles ad click-through/external navigation for a Kids app whose own external links require a parent gate? Which age-appropriate dismissal protections apply with high-engagement ads disabled?

Please provide published Kids-specific evidence where available, or state explicitly if this AdMob setup cannot satisfy the stated requirements. A generic quick-start link or personalized-ad disablement alone will not resolve these questions. We are not asking for a guarantee of Apple approval.

Please reply in this case; if your support migration creates a new case, retain this history and provide the new case number.

Public support/privacy: https://seifelmoulouk.com/pikolumi/en.html
Business contact: rahmani@seifelmoulouk.com

Thank you,
Rahmani Seif El Moulouk
Pikolumi development
