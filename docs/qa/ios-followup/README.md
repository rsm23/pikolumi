# iOS follow-up validation, October 13

The fresh signed IPA and both silent native-audio checks include the authorized Arabic reference. `summary.json` links the separate iPhone/iPad driver reports. Both bodies and teardown passed; exact SHA-256 matches the bundled clip and native duration is 816 ms, including encoded padding.

No audio playback, ad request or application-persistence access occurs in this targeted harness. It checks codec preparation, not pronunciation correctness. The owner's earlier full-language review and commercial-use authorization remain separate evidence. No simulator was booted/reset, no app was uninstalled/data-cleared and no host volume setting changed. The normal main entry point was restored on both already booted simulators without launching it, and the original XcodeBuildMCP defaults restored.

The IPA audit is `../../release/ios-followup-package-audit.json`. The artifact is distribution signed but uses official test ads and remains local. Physical iOS QA, exact privacy answers and Apple Kids advertising evidence remain required before production release.

To repeat the targeted check on an already booted, verified simulator:

```sh
PIKOLUMI_CAPTURE_DIR=docs/qa/ios-followup/iphone scripts/flutter.sh drive \
  --driver=test_driver/screenshots.dart \
  --target=integration_test/arabic_reference_audio_test.dart \
  --dart-define-from-file=config/ads.json -d <verified-simulator-id>
```

Rebuild/reinstall `lib/main.dart` afterward; the harness is not the normal application entry point.
