# Drawing Studio fix and expanded art tools

Selecting a drawing now shows its full outline immediately. The previous first step showed only an unoutlined background in 90 of the 120 drawing activities. Guide steps now count drawable elements, keep the remaining picture visible as a lighter reference, and save the chosen step. Changing a guide alone does not complete an activity.

Both Drawing Studio and Coloring offer 36 colors, a scrolling palette and an All colors panel. Round, pencil, translucent marker and textured wax crayon strokes use different rendering. Their types are saved with each stroke; older artwork without a type continues to use the original round brush. Existing activity IDs, artwork geometry, profiles and progress are preserved.

Validation is silent:

- The original blank-canvas regression failed with zero visible guide pixels, then passed after the fix.
- All 120 initial drawing guides pass pixel rendering checks.
- Brush renderings differ, crayon grain is deterministic, and legacy strokes render identically to round strokes.
- Guide undo/redo and saved artwork recovery preserve the step, selected stroke colors and all four stroke types.
- All 48 Flutter tests and eight Python tests pass; static analysis reports no issues.
- iPhone 18 Pro and iPad Pro 13-inch simulator runs pass the test body and teardown in all five interface languages. They exercise library navigation, the formerly blank picture, the palette, brush selection and saved artwork recovery. Each run uses an isolated memory store and SilentAudio disabled before runApp; neither initializes the ad SDK. Native evidence is in the `ios-phone` and `ios-tablet` folders. Simulator results do not replace physical-device QA.
- The language review packet now contains 85 interface strings per locale. Coverage/source checks and isolated DOM checks pass with zero media playback or network requests; no human review approval was granted.

The updated local Android APK is `output/qa/Pikolumi-Drawing-Studio-QA.apk`, using the normal app entry point, profile mode and test-ad configuration. Its signing certificate matches the previous Pixel QA installation, permitting an in-place update. The separately signed release-mode test-ad APK is `output/qa/Pikolumi-Drawing-Studio-Signed-QA.apk`; its upload-key signature does not match the development installation. Do not uninstall or clear the Pixel's app to install that release-mode file. The Pixel was disconnected during these checks, so neither new APK has been installed there. The normal simulator app is restored after QA without uninstalling or clearing user data. `validation.json` records build hashes, source bindings, installation status and native screenshot hashes.

The earlier aggregate packages and store screenshots predate this drawing/tool update. They must be refreshed before a later authorized release. No Android/iOS build upload, review submission or publication is authorized; the user's explicit release hold remains in effect.
