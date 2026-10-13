# Android final QA — 2026-10-13

- Tablet emulator: 320/320 cases passed; 16 sections, five languages, nine engines, sibling isolation and a second SQLite connection. See `tablet-curriculum/integration_response_data.json`.
- Pixel: 168/320 case completions verified, across an interrupted first run and interrupted continuation. See `phone-partial-cases.json`. The next offset is 168; no physical full-pass claim.
- Pixel native test ads: dismissal callback and restoration passed. Five-second close-control availability remains unverified. See `ad-dismissal/integration_response_data.json`.
- Original Pixel screen settings were restored. Normal profile IDs, artwork and progress were preserved; ad state and learning-language preferences differed and were not overwritten.
- Every test was silent. Production ads and store submissions remain held by the outstanding evidence, including the known incorrect صِ recording.

The curriculum harness uses native device dimensions and an isolated temporary SQLite database. `PIKOLUMI_QA_START_CASE` allows a bounded continuation without recounting earlier cases. Recorded IDs/languages are checked against the full tablet run. It never counts translations as additional catalog activities.

Example continuation, with a confirmed unlocked idle Pixel:

```sh
ORG_GRADLE_PROJECT_pikolumiQa=true PIKOLUMI_CAPTURE_DIR=docs/qa/pixel-final-qa/phone-remaining \
  scripts/flutter.sh drive --driver=test_driver/screenshots.dart \
  --target=integration_test/android_acceptance_test.dart \
  --dart-define=PIKOLUMI_QA_START_CASE=168 \
  --dart-define-from-file=config/ads.json -d <verified-pixel-device-id>
```

This updates only the separate `.qa` package. Leave the automatically opened QA screen active and avoid pressing the power button. Restore any temporary display setting after the run. Private normal-app database backups and raw build logs are deliberately excluded from this directory and Git.
