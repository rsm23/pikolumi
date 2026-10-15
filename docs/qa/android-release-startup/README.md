# Optimized Android startup regression — October 15, 2026

Google rejected 1.0.0 (1) because it crashed immediately on opening. A universal APK generated from the exact submitted AAB reproduced the crash before Flutter: AndroidX Startup could not instantiate WorkManager’s Room database. The submitted R8 usage report lists `WorkDatabase_Impl`’s public no-argument constructor as removed; its map ID matches the crash. The replacement keeps these reflected Room database constructors while retaining shrinking and optimization.

The regression went red on the submitted optimized application. The fixed AAB is 1.0.1 (2), SHA-256 `e267da3c9d04977fcf678703990322a32a6f72d78e0c2854ee60d1db74a1b873`. The universal APK uses the emulator debug certificate for installation; application code and native libraries are derived from that optimized production AAB. The original upload-signed AAB is the store artifact.

## Evidence

- `submitted-red.json` and `submitted-crash.log`: actual production startup failure.
- `fixed-4k-three-launches.json`: three 15-second cold launches, no fatal exception, live PID and resumed activity.
- `fixed-4k-avd-verified.json`: explicit AVD and actual 4096-byte page-size verification.
- `fixed-16k-three-launches.json`: three 30-second cold launches on verified `pace-ledger-16k`, actual 16384-byte pages, no fatal exception, live PID and resumed activity. `fixed-16k-screen.png` shows the rendered library.
- The first attempted 16 KB run collided with another emulator’s port and actually measured 4096 bytes. It is excluded from 16 KB acceptance. The harness now requires the expected AVD name and actual page size before any log clearing or launch.
- On the dedicated 16 KB instance, the first early launch did not yet report a PID at 15 seconds, without a fatal exception; a later PID was present. Repeated 30-second checks are recorded separately and retain that initial limitation.

No app data is cleared. These are targeted release-packaging tests; they do not claim fresh physical Pixel QA or repeat the unchanged curriculum acceptance. All 687 source assets are byte-identical to the original submission. No Dart behavior, profiles, artwork, permissions, or ad placement changed.

Run after generating and installing a universal APK from the exact release AAB:

```sh
python3 scripts/check_android_release_startup.py --serial emulator-5590 --expected-avd pace-ledger-16k --expected-page-size 16384 --seconds 30 --attempts 3 --output output/release-verification/startup
```

The official Android full-mode documentation explains why keeping a class does not implicitly preserve its default constructor: https://developer.android.com/topic/performance/app-optimization/full-mode
