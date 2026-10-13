# iOS encryption-declaration assessment

The current signed test IPA and source `Info.plist` do not contain `ITSAppUsesNonExemptEncryption`. Apple will therefore ask export-compliance questions at upload. This does not establish that the app uses non-exempt encryption.

The app-owned source uses SHA-256 for the local parent PIN check; no app-owned cipher, encrypted messenger, VPN, custom transport or encrypted cloud store is implemented. Narration, artwork and progress are local. The ad/privacy SDKs can make network requests; the assessment must include those third-party libraries and the Flutter runtime, not just `lib/`.

[Apple's property-list documentation](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption) permits a false value only when the whole app, including linked libraries, uses no encryption or only exempt forms. [Apple's export guide](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations) explains the exemption for ordinary system HTTPS and distinguishes proprietary encryption.

No declaration was inserted merely from a source search or the absence of ATT. The exact third-party encryption classification was not established by the privacy-manifest audit, which checks SDK declarations and signatures rather than proprietary SDK internals. Leave the upload questionnaire available until the complete applicable answer is supported. No agreement/certification was accepted, no SDK was changed and App Transport Security was not weakened.

This assessment is separate from the existing Kids creative-review, privacy-label and physical-device holds. It is an upload-preparation item, not a new claimed policy violation or an unsupported legal clearance.
