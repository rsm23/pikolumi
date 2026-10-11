# Pikolumi — Color, Play & Learn

An offline Flutter app for Android, iPhone and iPad. The bundled catalog contains **2,400 distinct activities across 16 sections**, with English, French, Spanish, Brazilian Portuguese and Arabic interfaces and essential audio. Everything is available without purchases or an account.

**Status: implemented QA app; public release held.** Android QA packages use Google test ads and a dedicated upload signature. Signed iOS QA IPA and simulator builds are available. Neither platform has been submitted, approved or published. See [release status](docs/release/STATUS.md) for the remaining requirements and evidence.

## Run and build

This Mac uses isolated Flutter 3.47.7 / Dart 3.13.5 through `scripts/flutter.sh`, CocoaPods 1.17 and OpenJDK 25. On another machine, install a supported stable Flutter SDK, Android/iOS build dependencies, and replace the machine-specific paths in that wrapper.

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

Python is only needed for content authoring and validation. The installed app contains no Python, voice model, cloud generator or downloadable curriculum. The content scripts use standard Python for catalog creation; voice production additionally uses Piper, NumPy and ffmpeg. Generated catalog, illustrations, narration and fonts are bundled in `assets/`.

`config/ads.json` contains public AdMob identifiers with production disabled. The native application identifiers are `com.seifelmoulouk.pikolumi`. Android release signing is read from ignored `android/key.properties`; a missing upload key deliberately fails release signing. iOS Release signing uses the existing Apple Distribution identity, team WQ983X3Y8P and app-specific “Pikolumi App Store 1.0” profile; install an authorized matching certificate/private key and profile on a replacement Mac. `config/qa-export-options.plist` exports locally without upload. Never commit signing keys, their passwords or provisioning profiles. Existing saves depend on retaining the bundle identifier, activity IDs and database schema.

```sh
# Recreate the bundled catalog without changing stable IDs intentionally:
.venv/bin/python scripts/build_content.py
.venv/bin/python scripts/build_audio.py
.venv/bin/python scripts/validate_content.py

# Capture native five-language phone/tablet previews and performance samples:
PIKOLUMI_CAPTURE_DIR=docs/qa/screenshots/android-phone scripts/flutter.sh drive \
  --profile --driver=test_driver/screenshots.dart \
  --target=integration_test/capture_test.dart -d <android-device-id>

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
- Official Mobile Ads integration: child-directed request configuration, G content rating, non-personalized ads, removed Android advertising-ID permissions, parent-facing supported privacy flow, library banners and persisted interstitial frequency limits.

## Architecture and release material

[Implementation](docs/IMPLEMENTATION.md) describes data and service boundaries. [QA](docs/qa/REPORT.md) and [60 native previews](docs/qa/PREVIEW.html) distinguishes automated checks from native simulator and outstanding physical-device review. [Advertising](docs/release/ADVERTISING.md), [asset provenance](docs/release/ASSETS.md), [reviewer notes](docs/release/REVIEWER-INSTRUCTIONS.md) and [privacy declarations](docs/release/PRIVACY-DECLARATIONS.md) support release preparation.

Five-language listing drafts are under `docs/release/listings/`. Support/privacy page drafts and `app-ads.txt` are under `site/`; the pages are published at https://seifelmoulouk.com/pikolumi/ with the confirmed support contact; the root app-ads.txt is verified. App icon assets are installed in both native projects.
