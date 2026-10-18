# Trace & Write narration, October 18, 2026

Trace & Write now automatically reads its displayed letter, syllable, word or letter sequence when the activity opens and again on successful completion. Restart and Listen repeat the same complete model. Narration uses the learning language independently of the interface language, respects Sound & voice and foreground eligibility, and is cancelled on leaving the activity or starting another playback. Completion uses the model narration in place of the generic success clip so that it is not interrupted. Visual celebration remains available immediately.

The compiled catalog adds ordered `traceCues` metadata to all 320 Latin localized letter guides. All 80 Arabic guides retain their reviewed letter, syllable and word cues. Existing number and motor-pattern activities retain their instructional audio. No audio files, activity IDs, guide geometry, stroke order or tracing progress revisions changed. A structural comparison against the previous catalog confirmed that the 320 new narration lists are the only catalog changes.

Validation:

- 95 Flutter tests passed, including the existing Arabic/Latin gesture and rotation tests.
- New widget regressions exercise entry, restart, Listen and completion for three representative models across all 25 interface/learning-language pairs, plus muted entry/completion and lifecycle transitions.
- New controlled-player tests verify sequential playback without clipping, cancellation on exit/replay and silent/background eligibility. These tests use no host audio output.
- 22 Python tests passed, including complete ordered narration/file coverage for all localized letter guides.
- `scripts/flutter.sh analyze --no-pub lib test integration_test` passed without issues. A whole-workspace analysis also sees historical copied harnesses under ignored `output/release-verification/ios-curriculum/` whose relative imports are no longer valid; these archived outputs were not changed.
- `scripts/validate_content.py` passed for all 2,400 entries.
- `.venv/bin/python scripts/validate_audio.py` decoded all 648 speech clips and eight tones successfully without playback; no files were repaired. The initial system-Python invocation lacked soundfile; the project virtual environment completed the check.
- `scripts/flutter.sh build apk --debug --no-pub` succeeded. Existing Gradle/Kotlin migration warnings remain advisory.

Build: `build/app/outputs/flutter-apk/app-debug.apk` (development/test ads), SHA-256 `208bffcf306716c8f1480e2c0dc6f7dbb4d7719551cf368fe20be5413886ad4d`.

This is local source and debug-build validation. No new physical-device install, iOS build, store upload, submission or approval is established by this change. The already submitted Android 1.0.1 (2) production bundle is unchanged and does not contain this feature.
