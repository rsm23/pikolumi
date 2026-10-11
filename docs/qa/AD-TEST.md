# Native ad harness

Run `scripts/flutter.sh test --no-uninstall integration_test/ad_test.dart -d <device-id>` with a connected device and network. It explicitly rejects production mode, mutes both app and SDK, waits for a banner and interstitial, and seeds a synthetic eligible budget. It then hides the banner through the activity boundary, presents the test interstitial and waits up to three minutes for a human to close its native control. A pass requires the dismissal callback, persisted impression accounting and retained muted preferences. Teardown restores the original budget.

Flutter cannot tap the native SDK overlay with widget finders. Do not replace native close verification with an artificial callback or SDK disposal. On this Mac the simulator mirror rendered the creative and exposed its X, but mirror input did not close it. This run is incomplete, not a passing test. Five-second close timing and physical-device acceptance are separate release requirements.
