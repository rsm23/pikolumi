# Animated 3D Piko — 2026-10-12

Piko has an original editable Blender model with turquoise feathers, a lilac crest, yellow belly, coral wing tips and a red crayon. The app displays transparent Blender-rendered 3D frames: this is pre-rendered animation, not a real-time 3D renderer. Both clips have 90 poses at 30 fps. The offline WebP sheets add approximately 2.6 MiB; their combined decoded size is 19.5 MiB, shared across instances and released when unused.

Piko appears in the library and the 56-point activity header. Idle uses breathing, blinks, a gentle smile and head/crest motion, with rests between gestures. Completion triggers a one-shot smiling celebration in the header and the larger completion dialog, including anticipation, a soft hop, landing squash, asymmetric wing gestures and crest follow-through. All activity engines report completion through this shared shell. Full-screen drawing hides the header. The mascot has no audio, ad requests or persistence side effects.

Animations pause offstage and while the app is inactive. App and operating-system reduced-motion requests, plus accessibility navigation, show a static 3D pose without loading the animation sheets. The app now combines its reduced-motion preference with the operating-system preference instead of overriding the latter.

## Validation

- All 60 Flutter tests and eight existing Python tests pass; static analysis is clean.
- Four new widget tests verify actual bundled texture decoding, shared image ownership, frame advance, idle rests, offstage/background pause and resume, one-shot celebration, reduced-motion changes, OS reduced motion and completion persistence on a 320-point Arabic screen. Rotation to a 640 × 320 phone exposed a 148-pixel dialog overflow; a scrollable dialog fixes it while keeping the Continue action accessible, and the regression now passes.
- `asset-validation.json` verifies all 180 distinct transparent poses, unclipped bounds, sheet dimensions, decoded texture budget and original Blender source hashes.
- Silent physical Pixel profile-build and iPhone/iPad simulator runs pass test body and teardown in all five interface languages. The fixture verifies frame advance, a real answer-button completion, saved progress, the Listen control, full-screen drawing and reduced motion. Each device has 12 settled captures under its directory. Initial simulator captures caught route/dialog transitions and were replaced by settled captures before publication of this evidence.
- Native runs use `MemoryStore` and `SilentAudio`, mute before mounting the app, do not initialize the ad SDK and do not write normal user preferences. Diagnostic native frame timings are recorded in each response file; simulator/debug timings are not production performance certification.
- Physical Pixel animation QA passes. No physical iPhone/iPad is available; these mascot checks do not establish the full physical-device acceptance matrix.
- The normal local APK is installed on the Pixel with its existing development certificate. All database files match before/after installation, preserving profiles, artwork, progress and the user's sound preference. No uninstall or data clearing occurs. Both simulator apps are restored to the normal entry point after QA. Every one of the 677 source assets matches both local packages.
- A first Pixel run passed the native checks but its byte-only database guard detected a changed file; no record snapshot existed for that initial comparison, so its cause is not established. A repeat using stable read-only SQLite snapshots verifies integrity, identical raw bytes and identical payload digests for every saved namespace. Sound remains on; artwork and progress retain their prior timestamps. No database repair or preference change was performed. See `pixel-record-comparison.json` and `pixel-preservation.json`. The normal APK and original wake settings (stay-awake off, 60-second timeout) are restored.

`validation.json` binds the source, native reports, captures and local package hashes. `celebration-preview.gif` is a silent animation preview. Original editable sources and rebuilding instructions are in `art_source/piko/README.md`.

Both stores remain held: no upload, submission or publication is authorized or performed.
