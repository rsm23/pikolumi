# Pikolumi — Color, Play & Learn

An offline Flutter app for Android, iPhone and iPad. The bundled catalog contains **2,400 distinct activities across 16 sections**, with English, French, Spanish, Brazilian Portuguese and Arabic interfaces and essential audio. Everything is available without purchases or an account.

**Status: implemented QA app; public release held.** Android QA packages use Google test ads and a dedicated upload signature. Signed iOS QA IPA and simulator builds are available. Neither platform has been submitted, approved or published. See [release status](docs/release/STATUS.md) for the remaining requirements and evidence.

## Run and build

This Mac uses isolated Flutter 3.47.7 / Dart 3.13.5 through `scripts/flutter.sh`, CocoaPods 1.17 and OpenJDK 25. On another machine, install a supported stable Flutter SDK and Android/iOS build dependencies. The wrapper uses Flutter on PATH, prefers the existing local SDK cache, and accepts an explicit `PIKOLUMI_FLUTTER_BIN` executable path. An existing `JAVA_HOME` is preserved.

```sh
scripts/flutter.sh pub get
scripts/flutter.sh run -d <device-id> --dart-define-from-file=config/ads.json
.venv/bin/python scripts/validate_content.py
scripts/flutter.sh analyze
scripts/flutter.sh test
scripts/flutter.sh test --no-uninstall integration_test/device_smoke_test.dart -d <device-id>
scripts/build_qa.sh
# Fresh, isolated USB Android install with temporarily disabled networking:
scripts/run_android_offline_qa.sh <usb-serial>
```

Python is only needed for content authoring and validation. The installed app contains no Python, voice model, cloud generator or downloadable curriculum. The content scripts use standard Python for catalog creation; voice production uses pinned Kokoro/SILMA models, PyTorch, NumPy and ffmpeg. It writes audio files without playback. Generated catalog, illustrations, narration and fonts are bundled in `assets/`.

`config/ads.json` contains public AdMob identifiers with production disabled. The native application identifiers are `com.seifelmoulouk.pikolumi`. Android release signing is read from `android/key.properties`, which points to the existing upload key under `signing/android/` using a relative path. The owner explicitly requested the Android key and plain-text recovery information in this private repository. A missing upload key deliberately fails release signing. iOS Release signing uses the existing Apple Distribution identity, team WQ983X3Y8P and app-specific “Pikolumi App Store 1.0” profile; install an authorized matching certificate/private key and profile on a replacement Mac. iOS credentials and provisioning profiles remain outside Git. `config/qa-export-options.plist` exports locally without upload. Existing saves depend on retaining the bundle identifier, activity IDs and database schema.

## Private repository and signing recovery

Source, bundled assets, authoring scripts, tests and review evidence are kept in the private [rsm23/pikolumi repository](https://github.com/rsm23/pikolumi). A fresh clone includes every offline runtime asset; no Git LFS download or voice synthesis is required to run it. Run `scripts/flutter.sh pub get`, then use the run command above. Python validation tools require a separate local virtual environment; generated runtime assets are already committed.

Android signing is ready after cloning: `android/key.properties` resolves `../../signing/android/pikolumi-upload.jks` from the Gradle app directory. `signing/android/` includes the JKS, PKCS12, public certificate, unencrypted private-key PEM, original key.properties, checksum manifest and `ANDROID-SIGNING-RECOVERY.txt` with plain-text passwords/certificate details. This repository must remain private, as instructed by its owner. Retain the same upload key for updates. `python3 scripts/backup_android_signing.py` also makes a verified independent local backup outside the repository; only file paths are printed. Reviewer phone details, iOS credentials, build output and tool caches stay outside Git.

The user authorized both store releases on 2026-10-13, superseding the earlier hold. Required content, pronunciation, physical-device and advertising evidence remains separate from that authorization. The release builder refuses incomplete evidence; signed test-ad packages must not be uploaded as production releases. See [current release attempt](docs/release/2026-10-13-release-attempt.json).

```sh
# Recreate the bundled catalog without changing stable IDs intentionally:
.venv/bin/python scripts/build_content.py
.venv/bin/python scripts/build_audio.py
.venv/bin/python scripts/validate_audio.py --repair-peaks
.venv/bin/python scripts/validate_content.py

# Capture native five-language phone/tablet previews and performance samples:
PIKOLUMI_CAPTURE_DIR=docs/qa/screenshots/android-phone scripts/flutter.sh drive \
  --profile --disable-dds --keep-app-running --driver=test_driver/screenshots.dart \
  --target=integration_test/capture_test.dart -d <android-device-id>

# Render all revised illustrations and build a silent review library:
scripts/flutter.sh test tool/render_artwork.dart
.venv/bin/python scripts/build_art_review.py

# Production builds refuse incomplete release evidence:
.venv/bin/python scripts/build_release.py android
.venv/bin/python scripts/build_release.py ios
```

## What is implemented

- Coloring: closed-region fills, region-clipped brush, eraser, palettes, undo/redo, two-finger zoom, autosave and gallery. Guided drawing includes stepped guides and an unrestricted blank canvas.
- Quizzes, spelling, ordered tracing, sorting, memory pairs, tile puzzles, patterns, solvable mazes, clocks, science and repeat-the-melody activities.
- Direct section shortcuts, recommended skill-band journeys, favorites and earned stickers. There are no locked activities.
- Avatar profiles with isolated progress, artwork and resumable activities. Parent PIN protects management, difficulty, progress, export, privacy choices and external support links. The parent area locks after backgrounding.
- Five-language layout and essential bundled narration; Arabic shaping and interface RTL with separate mathematical/canvas/music direction.
- Separate parent settings for interface/questions and each explorer's learning language. Letters, vocabulary and handwriting can teach any of the five languages with instructions in another; progress and ongoing work are preserved per learning language.
- Official Mobile Ads integration: child-directed request configuration, G content rating, non-personalized ads, removed Android advertising-ID permissions, parent-facing supported privacy flow, library banners and persisted interstitial frequency limits.

## Architecture and release material

[Implementation](docs/IMPLEMENTATION.md) describes data and service boundaries. [QA](docs/qa/REPORT.md) and [60 native previews](docs/qa/PREVIEW.html) distinguishes automated checks from native simulator and outstanding physical-device review. [Advertising](docs/release/ADVERTISING.md), [asset provenance](docs/release/ASSETS.md), [reviewer notes](docs/release/REVIEWER-INSTRUCTIONS.md) and [privacy declarations](docs/release/PRIVACY-DECLARATIONS.md) support release preparation.

Five-language listing drafts are under `docs/release/listings/`. Support/privacy page drafts and `app-ads.txt` are under `site/`; the pages are published at https://seifelmoulouk.com/pikolumi/ with the confirmed support contact; the root app-ads.txt is verified. App icon assets are installed in both native projects.

The Arabic reviewer packet is `docs/qa/arabic-review/index.html`, with dedicated recording and lesson CSV checklists. Native-speaker approval is pending. Computer test runs stay muted. For `flutter drive` on a user device, retain `--keep-app-running`: the default teardown uninstalls the app. Stop it separately after the run to preserve its saves.

For local voice compilation, install ffmpeg and espeak-ng, create a Python environment and install `scripts/audio-requirements.txt`. Install `silma-tts==1.0.5` with `--no-deps` on macOS; this compiler uses its direct character model and the pinned dependencies above, without its Linux-only GPU normalizer. Model and voice downloads use pinned revisions and the cache under `~/.cache/pikolumi/licensed-voices`. Compilation and waveform validation never play sound.

The [Arabic review page](docs/qa/arabic-review/index.html) lets the reviewer tick incorrect recordings and copy or download a single correction list. Notes/choices stay in the browser; audio plays only after a manual Play action. Regeneration preserves CSV review notes and binds approvals to source hashes. To verify the selection workflow without media playback:

```sh
npm install --prefix tmp/arabic-review-test --no-save --ignore-scripts jsdom@30.1.2
node tool/test_arabic_review.cjs
```

The [five-language review hub](docs/qa/language-review/index.html) covers all 648 speech recordings, all 2,400 activity definitions in each locale, and 76 interface strings per language. It adds searchable, paginated lesson views and source-bound CSV checklists while retaining the existing Arabic selection page and saved-choice namespace. For silent regeneration and checks:

```sh
.venv/bin/python scripts/build_arabic_review.py
.venv/bin/python scripts/build_language_review.py
.venv/bin/python scripts/validate_language_review.py
node tool/test_language_review.cjs
```

Pronunciation selections report corrections. Browsing packets or passing their automated checks does not grant human approval or change release readiness.

The [Latin handwriting review](docs/qa/latin-tracing/index.html) shows all 320 English, French, Spanish and Portuguese letter/sequence guides and all 40 numerals with numbered pen starts. Models and practice boards share the original manuscript paths from `scripts/latin_handwriting.py`; uniform scaling preserves each glyph's proportions, including accents. `legacyStrokes` retains the prior geometry for saved-checkpoint migration. Arabic literacy geometry is unchanged. Regenerate the sheets with `.venv/bin/python scripts/build_latin_trace_atlas.py`; run `test/latin_handwriting_test.py` and `test/latin_tracing_test.dart` for direction, shape, accent and gesture regressions. Native checks and source/package hashes are recorded in `docs/qa/latin-tracing/validation.json`.

[Actual iPad rotation checks](docs/qa/ipad-tracing-rotation/index.html) cover both landscape directions, all five learning languages and numerals. `integration_test/ipad_tracing_rotation_test.dart` measures guide/ink pixel bounds from native screenshots, checks exact stroke/point recovery and reopens an isolated SQLite database. Run it with `flutter drive`, the screenshot driver and `--keep-app-running`; when `PIKO_ROTATION_READY` appears, use Device Hub's hardware Rotate Left/Right command matching the marker. App-requested orientation changes are ignored by the iPad's window mode, so they do not substitute for these hardware turns. The fixture never opens the normal app database or plays audio. Restore the normal `lib/main.dart` simulator app after testing.
