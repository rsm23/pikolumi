# iOS privacy resolution

## Current evidence

The signed local test-ad IPA is audited in `ios-followup-package-audit.json`: Google Mobile Ads 13.11.0, UMP 3.1.0, six preserved privacy manifests, all 687 current assets and the authorized Arabic replacement. It is not uploaded and is not production eligible.

The native iPhone/iPad SDK check exercises the actual app's `AdsService` with isolated memory, official test units and silent audio. It reads back child age treatment and maximum G rating from the native SDK. Privacy setup completed successfully; no ad was presented and the production Kids gate stayed false. It does not independently read persisted publisher-ID state, inspect network payloads or certify Apple's Kids exception. See `../qa/ios-sdk-privacy/summary.json`.

## Privacy labels to resolve

These are the packaged SDK declarations and the earlier App Store Connect draft, not a new claim of configuration-specific runtime collection. The final label remains unapproved.

| Data type | Packaged declaration | Remaining decision |
|---|---|---|
| Coarse location | GMA linked, not tracking; UMP unlinked for functionality | Retain disclosure; ask Google about child-mode collection/recipients and Kids data restrictions |
| Product interaction | GMA linked, not tracking; UMP unlinked for functionality | Retain disclosure; no app-owned learning results are sent |
| Advertising data | GMA linked, not tracking | Retain disclosure; do not call contextual ads zero-data |
| Crash data | GMA unlinked, not tracking, analytics | Retain disclosure |
| Other diagnostic data | GMA unlinked, not tracking, advertising/analytics | Retain disclosure |
| Performance data | GMA/UMP unlinked, not tracking; public Google disclosure describes user-associated performance | October 14: conservative draft changed to linked using the current public disclosure endorsed by Sellside; manifests preserved, exact-configuration clarification retained |
| Device/other identifiers | GMA generic manifest linked and tracking-related; IDFA suppressed by child mode and publisher first-party ID disabled by app | Identify residual app/developer/SDK IDs, recipients and exact child-mode tracking; card remains unconfigured |

[Apple's label guidance](https://developer.apple.com/app-store/app-privacy-details/) treats linkage through a device as linkage to the user and requires third-party SDK practices to be included. Tracking depends on cross-company data combination or broker sharing; an absent ATT prompt alone does not settle it. [Google's iOS disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure) still describes possible app/developer identifiers and associated performance data. Preserve the SDK manifests and resolve the exact-configuration discrepancy rather than removing these declarations.

## Evidence required from support

Both case IDs are retained: original `0-5962000041930` and apparent replacement `00484140`. The new authenticated acknowledgement arrived shortly after our reply and says a specialist is investigating; it does not explicitly name the original ID or answer the technical questions. See `google-admob-case-00484140.json`. No duplicate follow-up was sent.

To resolve the hold, a substantive response must establish:

1. Public Kids-specific policies covering human age review of creatives for banners/interstitials and applicable demand. Attach the supported public URLs to the eventual Apple reviewer notes. Families settings and publisher review after impressions do not establish this alone.
2. Actual child-mode data during initialization, UMP updates and ad requests: identifiers, coarse location, purposes, recipients, linkage and tracking. [Apple's Kids exception](https://developer.apple.com/app-store/review/guidelines/#kids-category) remains independently required.
3. Correct performance/identifier privacy-label answers for GMA 13.11.0 and UMP 3.1.0, with an explanation of any generic-manifest difference. Apply only supported answers to the final store label.
4. Supported Kids external-navigation and age-appropriate dismissal safeguards. A callback observed after an ad click is not proof of a parent gate before external navigation.

After those answers, implement any necessary SDK changes, rebuild/audit the exact production IPA, finish physical iPhone/iPad QA, complete the store privacy forms and select/upload the eligible build. The owner restored App Store Connect sign-in; release, privacy and free-pricing drafts are freshly verified in `apple-draft-rechecked-20261013.json`. The device-identifier card is still unconfigured, performance is now linked in the draft following the October 14 support-endorsed public disclosure and Publish is disabled. No unsupported answer was supplied. Native 320-case iPhone and 320-case landscape iPad curriculum acceptance is complete; physical iOS acceptance remains unavailable. No ad removal, audience change, unsupported privacy assertion or production-gate override is authorized by an automated acknowledgement.

## Latest store metadata continuation

Optional Privacy Choices URLs now point to each existing localized public page’s `#privacy` section. All five were entered and saved together; Portuguese after-save and English after-reload values were observed. All five saved values and their screenshot proof are now verified in the original authenticated Chrome profile. The earlier apparent sign-out came from a browser-profile mapping mistake after a timeout/reset; the original tab remained authenticated. No identifier/performance answers or release gates were overridden. See `privacy-choices-page-check.json`.

## October 14 Sellside guidance applied

Birpal replied in case 00484140 at 12:12:59 UTC. Current child age treatment/G rating are already implemented, and the unchanged signed Android bundle targets 36 without AD_ID. The reply endorses Google's current platform disclosures and confirms TLS. The App Store performance-data draft was changed to linked based on that page's user-associated performance description, using a conservative disclosure rather than omitting linkage because the generic manifest says unlinked. Existing purposes and the manifest-supported no-tracking answer for this data type were retained. This does not determine the residual-identifier tracking answer or certify the whole privacy label. See `sellside-response-actions-20261014.json` and `store-proof/performance-linked-20261014.png`.

The reply gives no public human-review policy or cancel/resume API for ad navigation. The documented native banner/full-screen delegates return void notifications, and Flutter forwards click events without a veto/resume result. A callback after a recorded click is not a parent gate before navigation. We sent a specific engineering follow-up in the same case, verified in Sent. No touch overlay, SDK swizzling or unsupported click replay was added; ads/audience are unchanged and production iOS remains held.

## October 15 escalation

Apple Developer/App Review Support accepted the prepared Kids advertising clarification as **case 102996845545** under the owner's explicit send authorization. Google case 00484140 now has a holding response from Birpal: the partner solution team is investigating, with a detailed update expected by October 15. Neither response resolves the technical/privacy questions or establishes the Kids exception. The fresh App Store review check lists missing build and App Privacy; content rights are no longer missing. See `apple-kids-clarification-sent-20261015.json`, `google-case-00484140-status-20261015.json` and `ios-publishing-continuation-20261015.json`.
