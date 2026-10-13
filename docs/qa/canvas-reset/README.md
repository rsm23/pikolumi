# Reset drawing

Drawing Studio, Coloring and the blank canvas provide Reset drawing in the normal toolbar and as a floating icon in full-screen mode. A localized confirmation offers Cancel or Reset drawing. Reset clears the current artwork's fills and brush strokes, returns the guide to the activity's initial step, and immediately queues an autosave. It preserves the original artwork revision, the reference outline, selected tools, colors and viewport. Undo restores the picture while the activity stays open. Reset is disabled when there are no marks or changed guide steps to clear.

The regression checks exercise cancellation, confirmation, persisted reopening and Undo in all three canvas modes. They verify legacy artwork revision preservation, other drawings, sibling artwork, completed progress and no completion event from reset. A second check uses the full-screen control at 320-pixel phone width in all five interface languages. All 52 Flutter tests and eight Python tests pass; static analysis is clean.

The native fixture uses an isolated memory store, SilentAudio disabled before runApp, and no ad SDK initialization. It exercises Cancel, Reset, Undo and cleared-artwork reopening in five languages, alongside the existing drawing-tools and zoom checks. Captures and response data are stored by device; validation.json records the actual results and artifact hashes. Simulator QA does not replace physical-device acceptance.

The review packet contains 93 interface strings per locale. Human language and pronunciation approvals remain pending. The 2,400-activity catalog and narration assets are unchanged by this feature.

Local QA packages use the normal app entry point and test-ad configuration. Android installation replaces the existing development-signed QA app without clearing its data. Normal app builds are restored on the simulators after fixture tests. Installation outcomes and limitations are recorded in validation.json.

Neither store may receive an app build upload, review submission or publication until the user explicitly instructs the relevant action. Previous release packages, screenshots and task-specific evidence describe earlier source revisions and must be refreshed before any later authorized release.
