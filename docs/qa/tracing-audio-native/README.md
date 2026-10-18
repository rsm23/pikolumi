# Trace & Write native audio and Pixel installation

October 18, 2026. The authoritative final run passed on a dedicated Pixel 9 Pro XL Android API 36 emulator (`pikolumi-tracing-audio-api36`).

- Every one of the 198 distinct tracing narration assets prepared successfully with a positive native duration: English 26, French 30, Spanish 27, Portuguese 35 and Arabic 80.
- Fifteen representative letter/sequence/syllable/word models completed automatic playback at both entry and completion, covering all five learning languages paired with different interface languages. All 46 expected native playback start and completion events matched their ordered asset paths. These are actual MediaPlayer events, with player volume 0 and the emulator started with `-no-audio`.
- The test uses isolated in-memory profiles, no user database, no initialized ad SDK, reduced motion and bounded frame pumps. Bulk codec preparation uses a separate disposed player per language so it is separate from application playback. The existing 25-language-pair widget regressions and complete gesture tests are recorded in `../tracing-narration-20261018.md`.
- The normal `lib/main.dart` APK contains the exact current catalog and all 198 tracing narration files byte-for-byte. Source analysis (`lib test integration_test`) passed without issues.
- The physical Pixel 9 Pro XL was updated in place to development/test-ad version **1.0.1 (2)** after the native run passed. Its installed APK SHA-256 matches the verified normal-entry artifact. The compatible development signing certificate was verified before replacement.
- A fresh private SQLite snapshot was taken immediately before installation and compared with one immediately afterward. Every stored record is identical, including profiles, artwork, gallery, results, resumable activities and preferences. Sound & voice remained enabled. No uninstall, data clear, system-volume change or wake-setting change occurred. The normal app was not launched for playback on the physical phone.

Evidence: `android-native.json`, `package-audit.json`, `pixel-installation.json`. Private device snapshots and original APK are retained only in ignored `output/qa/tracing-audio-20261018/private` and the surrounding ignored output folder. No profile payloads are recorded in these public-format QA reports.

Earlier attempts are not acceptance evidence: the shared ADB server was repeatedly stopped during transfers; a bulk-preparation attempt timed out; a combined bulk/playback run encountered a native MediaPlayer error; the shared emulator then disconnected during installation. The dedicated run also exposed an unbounded screen-settling wait, so the final harness waits directly for audio completion with bounded timeouts and reduced motion. None of these attempts was marked passed. The final complete run returned exit code 0 and passed teardown. No production player changes or recording replacements were needed in this continuation.

This records native Android audio verification and physical installation, not new physical playback QA, iOS validation or a store submission. The already submitted Google Play artifact is unchanged.
