Follow-up to case 102996845545 — Pikolumi Kids Category advertising

Hello App Review Support,

Please add this update to case 102996845545 and route it to the appropriate App Review specialist. Pikolumi (Apple app ID 6821776826; bundle ID com.seifelmoulouk.pikolumi) is a free children's educational app planned for the Kids Category, with AdMob banners and interstitials and no purchases. We want to retain advertising while meeting Guideline 1.3. No production iOS binary has been uploaded or submitted.

Google Sellside support supplied a technical response on October 15, 2026 (case 00484140):
- Standard AdMob banner/interstitial callbacks cannot pause, cancel or resume external navigation to place a parent gate before an ad opens its destination. Touch-intercepting overlays and simulated clicks are not supported.
- Support supplied no publicly documented guarantee of human age review of Kids ad creatives; it described automated Families controls and publisher review.
- With child-directed treatment and publisher first-party ID disabled, support says IDFA is not collected/transmitted. IP address, crash/performance metrics and SDK operation signals remain for contextual delivery, frequency capping and fraud detection. The exact residual identifier inventory remains unspecified.

Could you clarify the following before we enable production ads or submit?
1. Does Guideline 1.3 require a parental gate before every external ad destination? Could placing the entire advertising experience in a designated parent-gated area satisfy this requirement, and under what restrictions?
2. What publicly documented evidence is required to establish human review of age-appropriate ad creatives for the Kids advertising exception? Does the described AdMob setup qualify, or what specific provider/configuration change is required?
3. What SDK, demand-source and data restrictions would be necessary given the residual signals above? We have not treated the vendor's response as Apple approval or completed the final App Privacy declaration.

Our proposed setup uses child-directed treatment, maximum G content rating, non-personalized ads and disabled publisher first-party ID. We are holding production iOS advertising and submission pending your guidance. Please advise the supported path for a Kids Category release with ads.

Thank you,
Rahmani Seif El Moulouk
rahmani@seifelmoulouk.com
