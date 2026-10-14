Dear Birpal,

Thank you for the guidance on case 00484140. We have checked the actionable items:

• iOS GMA 13.11.0 uses ageRestrictedTreatment = child (the current equivalent of tagForChildDirectedTreatment), maximum G rating, non-personalized requests and disabled publisher first-party ID before initialization. Native SDK readback passed.
• The signed Android production bundle targets API 36 and contains no AD_ID permission; its audited hash is unchanged.
• Following the iOS disclosure page you endorsed, we are correcting the App Privacy draft to disclose performance data as linked, rather than relying on the generic manifest's unlinked declaration. The SDK manifests remain unmodified.

We need implementable details for the remaining steps:

1. You recommend custom interception/UI layers before an ad opens a browser or app store. For standard adaptive BannerAd and InterstitialAd using Flutter google_mobile_ads 9.1.0 / iOS GMA 13.11.0, which supported API can pause/cancel the SDK click-through, present a parent challenge and resume only after success? The documented click delegates are void notifications, and Flutter forwards them as events; they do not expose a cancel/resume decision. Please provide approved code or an engineering reference for both formats, including whether a touch-intercepting overlay is permitted. A gate after navigation or only before showing the ad would not prove a gate before each external link.

2. We are not requesting an external certificate. Apple §1.3 asks for publicly documented Kids practices including human review of creatives for age appropriateness. Please provide a public policy URL explicitly documenting that human review for the applicable AdMob banner/interstitial demand, or confirm that AdMob cannot provide it for this setup.

3. With this child configuration, IDFA and publisher first-party ID disabled, which residual iOS identifiers are collected/transmitted, for what purposes, and are they linked or used for Apple's cross-company advertising measurement/tracking definition? Your identifier examples are Android-specific. Also, AAID is distinct from Android publisher first-party ID; does the latter exist or transmit before its supported post-initialization disable call?

The app's audience and ad formats remain unchanged. Production iOS advertising/submission remains held until these implementation and disclosure questions are resolved.

Best regards,
Rahmani Seif El Moulouk
