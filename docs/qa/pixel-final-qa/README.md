# Android final QA — 2026-10-13

## Completed continuation and final checks

- Physical Pixel: all 320 planned completions covered, earlier 168 plus the final 152 passing cases and teardown. See `physical-curriculum-complete.json` and `phone-remaining/integration_response_data.json`.
- Landscape tablet: 320/320 passed across 16 sections, five languages and nine engines.
- Native test creative: visible X within a conservative 4.906-second bound; successful actual dismissal, frequency limits, muted audio and banner restoration. Enabled state at the first visible frame was not independently measured. This sampled QA does not guarantee every production creative. See `ad-recording/dismissal-timing-validation.json` and `close-visible-before-five-seconds.png`.
- The initial screenshot-transfer timing attempt was inconclusive and its driver timed out. `ad-timing/` is retained as historical evidence; the final successful recording/callback report is `ad-recording/`.
- Exact new owner-authorized صِ bytes decoded natively at volume 0 without playback. Curriculum fixtures use SilentAudio and the earlier audio bundle; new audio was checked separately.
- Normal app updated with test ads, without uninstall or data clearing. Every SQLite record identical before/after; `normal-app-update.json`. Normal app not launched by this update audit.
- Original timeout 60000 ms and plugged-in keep-awake setting 0 restored; `remaining-settings-restored.json`. Temporary scrcpy process stopped and owned device-local recording files removed. No computer volume changes; private databases/raw movies ignored.
- Owner confirmed full five-language review completion. All 55 flagged Arabic replacements resolved. Android production built/audited/submitted; iOS held for its own requirements. See `../../release/STATUS.md`.

Second-connection native SQLite readback is not process-termination proof. Prior interruption/recovery evidence remains separate. Translations are never counted as extra activities.

## Historical partial runs, superseded above

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
