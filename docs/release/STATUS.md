# Pikolumi release status — 2026-10-11

**Implemented QA app. Neither store has received a submission.** The public launch requirements are not yet satisfied; test ads remain enabled in every generated QA package.

| Item | Verified status |
|---|---|
| Bundled content | Exactly 2,400 activities, 16 sections; all entries pass automated validation in five locales |
| Art/audio | 456 original vectors, Piko/icon artwork, 541 narration clips and 8 original note tones bundled |
| Features | Navigation, profiles, all activity engines, persistence, gallery, favorites, stickers, parent controls and test ads implemented |
| Automated checks | 17 Flutter tests pass; static analysis reports no issues |
| Native smoke | Pixel physical phone, Android API 36 emulator and iPhone iOS 27 simulator pass bundled audio, save/reopen, learning completion, sibling isolation and language layouts; fresh Pixel USB airplane-mode smoke passes |
| Android signing | Dedicated upload keystore created; signed QA APK/AAB use test ads |
| iOS signing | App ID and “Pikolumi App Store 1.0” profile registered; signed local IPA exported with the existing Apple Distribution certificate |
| AdMob | Publisher verified live; separate Android/iOS apps and four dedicated units created; unlinked store registrations require readiness review |
| Name screening | No exact match found in preliminary indexed store and TMview searches; no name reservation or legal trademark clearance is claimed |
| Support/privacy/listings | Five-language support/privacy pages published to seifelmoulouk.com; existing app-ads.txt verified; listing drafts not submitted |
| Android | Not submitted → not reviewed → not publicly available |
| iOS | Held; not submitted → not reviewed → not publicly available |

## Open public-release requirements

1. **Apple Kids advertising exception:** the proposed AdMob setup has not been shown to have publicly documented practices satisfying §1.3's human review of creatives and permitted child-data handling. G-rated, non-personalized, child-directed requests alone do not establish the exception. Keep iOS production ads and submission held unless adequate evidence is obtained. Do not change the audience or remove ads without a new user decision. [Apple guideline](https://developer.apple.com/app-store/review/guidelines/#kids-category).
2. **Narration redistribution rights:** the Arabic development model's license evidence is unresolved; other fine-tuned models also need complete base-model rights and attribution review. Obtain explicit permitted recordings or replace affected clips. See `ASSETS.md` and archived model cards.
3. **Educational/editorial review:** a native reviewer must review each language's instruction text, word choice, spoken letter names and pronunciation. Arabic contextual handwriting needs refinement/review; the current tracing draft uses isolated skeletons and RTL sequences, while letter recognition uses initial/final shaped forms. Letter-sound/phoneme coverage and skill-band assignments require educator approval. No automated test is represented as educational certification.
4. **Physical-device QA:** the unlocked wireless Pixel passed native smoke testing. A full physical Android acceptance matrix and connected iPhone/iPad testing remain pending. Connect/unlock devices over USB and play representative activities across every section, language and difficulty. Include small phones/tablets, background/termination recovery, audio, extended offline sessions, drawing performance and ad close behavior. Fresh Pixel airplane-mode smoke is complete.
5. **Store website links:** support/privacy pages are published in all five languages at https://seifelmoulouk.com/pikolumi/en.html and sibling locale URLs, with rahmani@seifelmoulouk.com. The existing root app-ads.txt is verified. Link this developer website in both store records when they are created.
6. **Physical iOS availability:** the user confirmed no iPhone/iPad is available now. Signed IPA export is complete, but simulator results do not replace physical iOS testing.
7. **Store/ads declarations and final review assets:** complete exact-build App Privacy/Data Safety answers and audience declarations, validate interstitial dismissal against Families rules, review native phone/tablet screenshots and fill reviewer URLs/build numbers. AdMob store links/readiness are pending the real store records.

## Signing recovery

The Android upload key is at `/Users/rahmaniseif/.config/pikolumi/signing/pikolumi-upload.jks`. Its private password/configuration backup is stored alongside it in `key.properties`; the working copy `android/key.properties` is ignored by Git. Back up the signing directory securely. Do not put the password into documentation, source control, screenshots or chat. The package identifier and key must remain stable for updates.

`docs/release/readiness.json` records release gates conservatively. `scripts/build_release.py` refuses a production build while required evidence is false; QA builds use the independent test-ad configuration. Submission, approval and live availability must be recorded only after separately verifying each external state.
