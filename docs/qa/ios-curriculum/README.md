# iOS curriculum acceptance — October 13, 2026

All 320 representative activity cases passed on iPhone 18 Pro (iOS 27.0), and all 320 passed on a landscape iPad Pro 13-inch (M5, iPadOS 27.0). Each run covers 64 distinct activity IDs across all 16 sections, nine engines, all available skill bands and five locales. Repeated translations are execution cases, not additional advertised activities.

See [summary.json](summary.json) and the two native reports. Artwork and sibling isolation passed with an isolated temporary SQLite database, including readback through a second connection. This is not physical-device, process-death, upgrade, pronunciation or ad-dismissal evidence. Audio playback and ad requests were disabled throughout; host audio settings were not changed.

The first iPad attempt stopped before any activity because iPadOS rejected programmatic rotation in its windowing mode. The harness now registers cleanup before startup assertions and verifies actual landscape geometry. Rotating hardware through Device Hub before the retry produced a complete passing run at 1376 × 1032 logical pixels. The phone ran at 402 × 874. The summary preserves each executed harness hash; the phone run preceded the cleanup/orientation setup adjustment.

There are 32 native captures per device, with English and Arabic representatives of each section. Representative tracing, drawing and puzzle captures were visually inspected. Some captures retain a thin navigation-transition edge; these are QA captures, not listing screenshots. Both normal app entry points were rebuilt and reinstalled without uninstalling or clearing data, the iPad was restored to portrait, and the original Device Hub selection and XcodeBuildMCP defaults were restored. The normal app was not launched afterward.

No connected physical iOS device was available. Physical acceptance, live ad dismissal, Apple Kids creative-review evidence and final SDK privacy answers remain separate release requirements.
