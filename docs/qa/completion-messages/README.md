# Piko completion messages — 2026-10-13

100 distinct, activity-neutral completion messages in each of five interface languages (English, French, Spanish, Brazilian Portuguese, Modern Standard Arabic). Canonical copy is in `scripts/completion_messages.py`; `messages.json` is a readable QA copy. The bundled UI uses `pikoFinished` and `pikoFinished1`–`pikoFinished99`.

A session-wide shuffled bag selects one key after each successful completion. All 100 keys appear before reuse, and the last key cannot immediately repeat across a reshuffle. The sequence survives activity navigation, profile changes and language changes in the same running app; it is not written to user data. A completion screen selects once, so rebuilds, rotation and duplicate callbacks retain its message. Translation uses the app's interface language independently of the learning language.

Messages celebrate finishing, effort, ideas and curiosity, with kind reminders about asking for help, learning at one's own pace and taking breaks. No comparisons with other children, speed rankings, pressure to keep playing or perfect-performance claims. New text does not create new voice recordings; existing audio is unchanged.

The full Flutter checks cover four complete shuffle cycles and boundary repeats, 100 nonempty/unique strings per language, actual completion/replay screens in all five UI languages with a different target learning language, rotation and duplicate callbacks. Native Android/iPhone/iPad fixtures finish actual quizzes in five languages, verify distinct keys across routes and capture the messages silently using in-memory data and SilentAudio. Format/content/checklist checks preserve all 2,400 activities and 54 approved Arabic audio hashes. Automated checks do not provide human editorial approval.

`validation.json` binds the current sources, native reports/captures and normal Android/iOS QA packages. `pixel-installation.json` verifies the normal compatible update with unchanged saved database files/record fingerprints. No uninstall, data clearing, sound preference, system-volume, phone wake-setting or store changes. Physical iOS remains unavailable; Pixel user playtesting is pending.
