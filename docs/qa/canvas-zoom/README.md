# Canvas full-screen mode and zoom

Drawing Studio, Coloring and the blank canvas now offer a full-screen toggle, zoom-in and zoom-out buttons, Fit picture, and two-finger pinch/panning. Zoom ranges from 100% to 400%. Full-screen mode hides the activity header, instructions and tool panels; a floating toolbar keeps zoom, Fit picture and Exit full screen available. Back exits full-screen mode before leaving the activity.

Artwork keeps its proportions inside the viewport. Switching modes or rotating preserves the zoom and keeps the visible area within canvas bounds. Drawing coordinates remain in the original logical space, so strokes, fills, undo/redo and saved artwork do not change when the viewport changes. A pinch cancels any provisional brush stroke and restores redo history.

All 50 Flutter tests and eight Python tests pass, with no static-analysis issues. The camera regression exercises Drawing Studio, Coloring and the blank canvas through the real activity shell. It checks full-screen on/off, zoom button limits, outward/inward pinch without added marks, redo preservation, rotation, state identity and Back returning to the normal editor. An additional regression keeps the full undo history at the sixty-stroke limit when a pinch cancels a provisional stroke. Existing brush, artwork, localization and ad protections also pass.

Native iPhone/iPad simulator runs use an isolated memory store and SilentAudio disabled before runApp. They do not initialize the ad SDK. The five-language runs verify full-screen entry/exit, zoom buttons, pinch, Fit picture, the larger palette and brush recovery. The screenshots and response data are in `ios-phone` and `ios-tablet`; `validation.json` binds evidence and local builds to their source hashes. These checks do not replace physical-device acceptance.

The new controls are localized in all five languages; the review packet now has 89 interface strings per locale. Source/coverage and isolated DOM checks pass without playback, network calls or human approval.

The Android profile update is `output/qa/Pikolumi-Canvas-Zoom-QA.apk`; it uses the normal entry point, test-ad configuration and the development signing key matching the previous Pixel QA app. Installation uses an in-place replacement without uninstalling or clearing saved data. The normal app is restored on both simulators after QA. Actual installation results are recorded in `validation.json`.

No store build upload, review submission or publication is authorized. Both stores remain held until the user explicitly instructs the relevant action. Earlier aggregate release packages and store screenshots predate these canvas changes and must be refreshed before any later authorized release.
