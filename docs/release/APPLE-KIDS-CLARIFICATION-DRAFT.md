Subject: Pikolumi — pre-submission clarification of Kids Category advertising requirements

Hello App Review Support,

We are preparing Pikolumi: Color & Learn (Apple ID 6821776826, bundle ID com.seifelmoulouk.pikolumi, version 1.0.0) for the Kids Category. The app has 16 educational/creative sections and 2,400 bundled offline activities. Profiles and artwork stay locally on the device; there is no account, cloud backend, app-owned analytics, purchase or subscription.

We plan to use Google AdMob adaptive banners on library screens and interstitials only after eligible activity completions. The implementation uses Google Mobile Ads 13.11.0 / UMP 3.1.0, child age treatment and maximum G content rating before initialization, non-personalized requests and disabled publisher first-party ID. It does not request IDFA/ATT. Google publicly discloses IP-derived location, interactions, diagnostics/performance and possible app/developer-bounded identifiers; we are not claiming zero third-party data collection.

Before submission, please clarify:

1) Guideline 1.3 requires publicly documented Kids practices including human age review of ad creatives. Google support points to Families controls and says it does not publish a specific external certificate, but has not supplied a public policy expressly documenting the human review. What public evidence is required for this setup?

2) Google confirms it has no built-in parental gate for ad clicks. The standard banner/interstitial delegates are notification callbacks without a cancel/resume decision. Does 1.3 require a parental gate before each ad opens an external browser or store? Would placing the complete advertising experience in a designated area entered through a parental gate satisfy this requirement, and what restrictions apply?

3) Are the documented advertising/diagnostic practices compatible with the Kids advertising exception for this configuration, or must additional SDK/demand restrictions be established?

No iOS build has been uploaded or submitted; production iOS ads remain held while these questions are unresolved. Simulator curriculum checks are complete; physical-device acceptance remains pending.

Thank you,
Rahmani Seif El Moulouk
rahmani@seifelmoulouk.com
