# Piko encouragement inside activities

Piko now speaks in short, silent text bubbles below the activity header. The tail points toward the header mascot. The instruction area reserves enough space for both its instruction and its longest localized prompt, so showing or dismissing a bubble cannot move activity touch targets. Instructions return when the child interacts or after ten seconds.

- After 45 seconds without activity interaction, Piko offers a gentle invitation. Three unsuccessful quiz, spelling, sorting, Memory or music attempts also invite encouragement.
- Successful intermediate steps clear the unsuccessful-attempt count. Interaction dismisses a visible prompt. Prompts have a 90-second cooldown, use a shuffled phrase collection, and never reveal answers, change results, or request ads/audio.
- Drawing and coloring get creative encouragement instead of mistake feedback. Drawing and tracing motion reset the idle delay. The fullscreen drawing canvas pauses these prompts to retain its unobstructed editing surface; completing a creative activity still shows the completion bubble.
- Timers stop when the app is inactive or the activity route is covered. Returning starts a fresh grace period. Reduced motion retains static messages and the existing static mascot fallback.
- Completion always presents an immediate bubble above the celebrating Piko in the scrollable completion dialog. Continue remains reachable in landscape.
- All text uses the interface language (English, French, Spanish, Brazilian Portuguese or Arabic), independently of the lesson language. RTL, Arabic shaping and text scaling are retained. New translations are included in the existing language-review packets; native-speaker approval is still pending.

A drawing-step label also now wraps inside the landscape tool sidebar. The updated instruction height exposed its previous fixed-width overflow; the guide, editing state and saved artwork are unchanged.

## Test on the Pixel

Open a level and pause for about 45 seconds, or try three incorrect answers. Piko's bubble appears for ten seconds. It dismisses when you touch the activity. Solve the level to see the celebration message immediately. Switch the interface language in the parent area to check another language. Prompts have a cooldown so they do not repeat continuously.

`test/activity_encouragement_test.dart` checks timers, cooldowns, drawing interaction, progress reset, background behavior, five independent UI/lesson language pairs, stable activity bounds, small-phone text scaling and landscape completion controls. The existing full Flutter suite also covers all sections, saves, canvas editing, Memory turns and mascot animations.

`integration_test/activity_encouragement_test.dart` uses actual incorrect/correct answer taps and captures both bubble states in all five languages on Android, iPhone and iPad simulators. It uses an in-memory store and SilentAudio, with sound disabled before mounting. Native report status is recorded in `validation.json`; device installation and fresh save fingerprints are recorded separately in `pixel-installation.json`. No physical iOS device is available, and the user will perform the Pixel playtest.

No store uploads, submissions or publication are authorized or performed. No new mascot frames, pronunciation recordings, audio playback, phone wake settings or user preference changes are needed for this feature.
