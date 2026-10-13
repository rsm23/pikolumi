# Compact library banner

The previous footer requested a large anchored-adaptive slot and used its requested size, plus 18 pixels of bottom padding. A smaller test creative sat inside that taller slot, leaving visible empty space above the bottom navigation. `pixel-before.png` captures the reported layout on the user's Pixel.

The footer now requests a standard anchored-adaptive size with explicit orientation and fits the native size returned after loading. The installed google_mobile_ads 9.1.0 plugin still supports the standard API on both platforms; its deprecation recommends the larger video format. The targeted suppression keeps this library strip compact. Google documents the [larger format's height allowance and banner sizing](https://developers.google.com/admob/flutter/banner). The app neither crops nor stretches the creative.

The advertisement label and dividing line remain. Bottom padding is 12 logical pixels, and the main library leaves the system bottom inset to NavigationBar. Section screens retain their own safe area. Rotation reloads the appropriate banner; failed or unavailable loads reserve no empty slot. A late sizing response cannot bring an ad back after privacy eligibility is revoked. Banners remain hidden during activities and interstitials.

The regression first failed on an ad container measuring 150 pixels when the native ad size was 50. All 56 Flutter tests now pass, with clean static analysis, alongside eight Python tests. Tests verify native-size fitting, a 12-pixel navigation gap, the home indicator's separate 34-pixel inset, tablet rotation, and privacy revocation during an asynchronous size query.

The native fixture uses test ads, isolated memory and SilentAudio, with sound disabled before UI and SDK initialization. It measures the footer in all five locales, checks section banners, and verifies that entering an activity removes the banner and its reserved space. Native results, captures, build hashes and installation outcomes are in validation.json. Flutter's Android screenshot capture omits the platform-view creative; its geometry measurements remain valid. The normal app's native display capture is recorded separately when available.

Pixel checks verified that the normal user database was unchanged; its restored sound preference stays intact. Temporary wake settings are restored after QA. Local packages use the normal app entry point and test-ad configuration. No store upload, review submission or publication is authorized; both stores remain held until the user's explicit instruction.
