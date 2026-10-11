# Pikolumi QA evidence — 2026-10-11

## Automated validation

`catalog-validation.json` records a successful pass for every one of the 2,400 stable activities, all section counts, five languages, semantic challenge uniqueness, arithmetic/pattern/clock answers, solvable bidirectional mazes, tracing coordinates, original vector shape closure/region IDs, all references and bundled narration.

17 Flutter tests pass. Coverage includes persisted interstitial thresholds and the rolling-hour limit; actual SQLite sibling isolation and close/reopen; PIN throttling; parsing all 456 vector scenes and topmost coloring boundaries; two-tap activity access; saved coloring reopen/completion; representative rendering of every section in all five languages on a small phone and landscape tablet; real game interactions for quiz, spelling, sorting, memory, jigsaw, music, maze and tracing in every language; closed-letter tracing requiring a complete path; drawing undo/redo, pinch cancellation/zoom and rotation-safe logical coordinates; Arabic-digit PIN entry. Static analysis reports no issues.

## Native smoke checks completed

- Android emulator: Pixel 7 configuration, API 36 Google APIs ARM64, `emulator-5580`.
- iOS simulator: iPhone 18 Pro, iOS 27.

These and the unlocked physical Pixel 9 Pro XL passed `integration_test/device_smoke_test.dart`: load the full catalog and every bundled essential recording/tone, save/reopen a colored page using native SQLite, record a learning completion, isolate sibling artwork/progress, render five-language math routes and play a bundled voice through the native audio plugin. Updated narration contains 541 speech clips plus 8 note tones; the harness derives its count from the manifest.

The wireless physical Pixel 9 Pro XL was visible and received the QA APK, then stopped responding. The hanging run was cancelled and its stale wireless ADB transport disconnected. After the user unlocked it, reconnection and the complete native smoke test passed in 47 seconds. Full physical acceptance QA is still pending. No physical iOS device was connected.

## Native previews and performance samples

`integration_test/capture_test.dart` and `test_driver/screenshots.dart` capture library, coloring, jigsaw and math screens in each of the five languages. Files under `screenshots/` are native test-run previews. The test harness suppresses banner display for these captures only and supplies a colored-page fixture; the production UI and production ad configuration have no screenshot suppression switch.

Complete 20-image capture runs passed on the physical Pixel 9 Pro XL in profile mode, iPhone 18 Pro simulator and iPad Pro 13-inch (M5) simulator in debug mode. Their three folders contain 60 PNG previews plus compact performance JSON. The Android emulator capture stopped at installation/transport and is not counted as a successful capture run. All 15 library screens were later refreshed after correcting a missing sorting-card asset reference. The physical Pixel refresh used USB and disabled DDS after the profiler service connection failed; refresh captures skip performance sampling, so the original drawing/scroll reports remain separate.

| Device/mode | Drawing build/raster average | Library build/raster average | Sample limitation |
|---|---|---|---|
| Physical Pixel 9 Pro XL/profile | 3.751 / 3.846 ms | 6.217 / 4.251 ms | 161 drawing frames, 16 scrolling frames; 2 and 1 build-budget misses, no raster-budget misses |
| iPhone simulator/debug | 4.286 / 0.752 ms | 2.215 / 0.898 ms | Simulator development sample |
| iPad simulator/debug | 4.137 / 0.756 ms | 3.718 / 0.929 ms | Simulator development sample |

These are short samples, not sustained performance or physical iOS evidence. Store screenshots still need final device-size/composition review before upload.

## Silent ad/offline attempts

The native iOS harness loaded a banner and Google interstitial test ad with the app and SDK muted. The actual creative rendered and eventually showed an X. Simulator mirror coordinate and accessibility actions did not dismiss it, so the run was stopped and dismissal/restoration remains unverified. `ios-interstitial-test.png` records the visible test creative; it is not evidence of policy-approved close timing. The harness restores its synthetic ad budget in teardown and never requests production ads.

A fresh-data, airplane-mode run on the dedicated Android QA emulator installed its APK but stalled before test execution. The transport also stalled in a previous online capture attempt. The owned emulator and hanging test were stopped. The later physical Pixel USB test passed on a fresh `com.seifelmoulouk.pikolumi.qa` installation with airplane mode enabled and Wi-Fi off. It loaded the full catalog and all 549 audio assets, exercised native SQLite coloring recovery, learning completion and sibling isolation, and checked native playback at zero volume. It passed in 20 seconds. Networking was restored and verified at airplane mode 0 / Wi-Fi 1. See `offline-pixel-evidence.json`. This smoke pass does not complete the full physical acceptance matrix.

All computer-based activity testing after the user request uses sound off; the native audio smoke check uses player volume zero. Pronunciation review has not been performed during silent testing.

## Outstanding acceptance evidence

- Human illustration/editorial review and native pronunciation review across all languages/difficulty bands.
- Arabic connected handwriting refinement and approved phoneme curriculum.
- Wider physical small-phone and Android/iOS tablet coverage; no iPhone/iPad is available now.
- Representative manual play across all sections/locales/bands, long canvas sessions, interruption/termination recovery and a real shipped-version update save fixture.
- Actual interstitial dismissibility timing, failed loads/privacy eligibility, banner separation and restored audio on physical devices.
- Production SDK data/privacy audit and complete narration-rights evidence.

Automated semantic checks prove internal consistency, not educational quality, age suitability, ad-policy approval or native-speaker pronunciation. No physical-device, App Store approval or public availability is inferred from simulator success.

## Integration cleanup

Flutter integration tests default to uninstalling their initial application package at teardown. With an optional Android QA suffix, the initial package reference came from an earlier APK, while the test itself installed the new `.qa` package. Cleanup removed the earlier test installation and left `.qa` installed. The original normal entry-point QA app is restored afterward. Use `--no-uninstall` for native `flutter test` runs on user devices; do not rely on a suffix alone to protect an existing install. The dedicated offline script now sets this option and refuses to clear an existing QA package.

## Build workflow

Android APK/AAB and local App Store-signed iOS IPA are built from `lib/main.dart` with production ads disabled; the simulator ZIP also uses the normal entry point. Build platforms sequentially in this workspace: simultaneous Flutter invocations can overwrite shared generated plugin registration and cause an integration-test plugin reference in a release compile. The initial concurrent Android rebuild failed for this reason and was rerun sequentially.
