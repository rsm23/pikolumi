# Pikolumi implementation

## App shell and services

`main.dart` opens the bundled catalog, SQLite store, audio and app controller, then starts the UI before ad initialization. Riverpod provides the controller. Activity engines receive a common `EngineContext` and report completion through `ActivityScreen`; only the shell can request an interstitial.

`Catalog` loads versioned JSON with stable `section-nnnn` activity IDs, section names, skill bands, objectives, five-language titles/instructions, narration references, vector references and engine configuration. `Activity.config(locale)` merges language-specific curriculum into shared configuration. Assets are bundled; there is no content HTTP API.

`AppController` owns profile selection, preferences, favorites, completion results, stickers derived from results, and gallery metadata. `RecordStore` provides read/write/list/remove operations. Native persistence uses Drift with a SQLite `records(namespace, record_key, payload)` table, schema version 1. Profile namespaces isolate siblings. Artwork geometry is stored in a separate namespace from gallery metadata. Writes snapshot JSON and are queued so changing a canvas cannot mutate an in-flight save. Native app backup is disabled; exports require the parent area. Web localStorage is a development preview, not a target store release.

`AudioService` owns narration and piano-note players, supports replay and sound controls, and stops on backgrounding or before interstitials. `AdsService` owns privacy eligibility, SDK configuration, loading, lifecycle and global frequency accounting. `AdBudget` persists foreground time, completions and rolling-hour impressions across restarts/profile changes; ad load failure never locks content.

## Canvas and engines

`VectorScene` parses compact closed primitives and paths. Region hit-testing walks visible shapes from front to back. Brush clipping subtracts foreground regions to prevent painting across their boundaries. Artwork uses logical scene coordinates independent of screen dimensions. A single scale recognizer handles drawing and two-finger zoom, cancelling the tentative brush mark when a pinch starts. Autosave checkpoints run during drawing, on pointer completion, backgrounding and navigation; queued writes finish before recording completion.

The common activity shell dispatches canvas, quiz, spelling, trace, sort, memory, jigsaw, maze and music engines. Configuration-driven quiz displays cover counting, math, shape/color identification, patterns, science and time. Puzzle layout state and stroke progress are resumable. Blank drawing is a creative extra and does not inflate the advertised catalog/completion count.

Responsive grids support phones/tablets. Canvas controls move to a side column on short landscape displays. The UI uses Material localization delegates and bundled Noto Sans Arabic; Arabic is RTL while numeric equations, musical sequences and canvas coordinates retain their intended direction. Arabic letter recognition includes contextual initial/final forms; the current tracing draft uses isolated skeletons and right-to-left sequences. Connected Arabic handwriting exercises still need native educator review and refinement before public release.

## Content authoring and updates

`build_content.py` emits the finite catalog and original vector scenes from authored rules and fixed seeds. Translation, replay and answer ordering never count as additional activities. `validate_content.py` checks all 2,400 IDs, semantic challenge uniqueness in each locale, counts, answers, arithmetic, patterns, clocks, maze reachability, trace coordinates, all asset references and narration presence. It cannot certify educational appropriateness or pronunciation.

Never renumber or reuse a published activity ID. Preserve scene region IDs if illustrations change. Increment catalog version for a shipped curriculum update, keep old activity IDs readable for saved artwork, and implement a database migration before increasing SQLite schema version. Native SQLite reopen/isolation tests verify persistence; a released-version migration must additionally be tested against that release's real save fixture.

## Parent controls and privacy

First-time setup uses an adult challenge then a six-digit PIN. PINs use a random salt and SHA-256; failed attempts and lockout time persist. Arabic/Persian digits are normalized before verification. Parent sessions return to the child library after backgrounding. Profiles use avatars and generated explorer labels, with no names, birthdates, sign-in or cloud sync. Support links are enabled only when a real `SUPPORT_URL` is supplied in release configuration.

No purchases, subscriptions, Firebase or app-owned analytics are included. AdMob remains a third-party data-processing SDK and must be disclosed accurately; identifier restrictions do not mean that no data leaves the device.
