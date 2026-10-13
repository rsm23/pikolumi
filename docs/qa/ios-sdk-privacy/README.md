# Native iOS SDK privacy setup

The actual app `AdsService` initializes with isolated memory and silent audio. On both iPhone/iPad simulators, GMA 13.11.0 reads back child age treatment and maximum G content rating. Privacy setup returns successfully and uses official test units. Native interstitial preload may occur, but no ad is presented and no audio is played. The production Kids gate remains false.

`summary.json` and the separate driver reports record successful test bodies/teardown. Persisted publisher-ID state is not independently read back; network payloads and Apple Kids exception compliance are not tested. Physical acceptance remains unavailable. The normal entry point was rebuilt/reinstalled on both simulators without uninstall/clear or launch, and original XcodeBuildMCP defaults restored.

This narrow evidence does not clear final privacy, physical QA or production ad-dismissal gates. Support questions remain in `../../release/IOS-PRIVACY-RESOLUTION.md`.
