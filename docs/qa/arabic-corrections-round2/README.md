# Arabic replacements: second review round

The received review approved 44 recordings and rejected these 11 short sounds: جِ، حِ، خِ، رَ، صِ، طِ، ظِ، عِ، غِ، هَ، هِ. The 44 approved hashes are bundled and protected from regeneration. The second received review approved eight of these eleven takes. They are now bundled, bringing the cumulative total to 52. Round 3 subsequently approved ظِ and هَ, bringing the total to 54. صِ remains rejected, with a new contextual attempt in [round 5](../arabic-corrections-round5/index.html).

Open `index.html`, compare the previous rejected take with the new candidate, select **Sounds correct** or **Still wrong**, add a note if needed, and **Save review**. The page shows the exact imported decisions, preserves notes and choices, binds decisions to each new file hash, and never autoplays. The old 55-file page retains the imported decisions and links to this focused round.

Generation keeps Modern Standard Arabic, distinct consonants and short vowels. It uses a new deterministic seed per sound and an Arabic vowel anchor before and after the target syllable, taking the middle sound when pause boundaries are reliable. If boundaries cannot be identified, it uses an isolated-sound fallback. This changes the generation strategy; correctness still requires native review.

The pinned SILMA/Vocos models remain unchanged. References are existing AI-generated Arabic project recordings: the newly user-approved elephant and handwriting-word takes plus the existing counting instruction. No human speaker recording or cloning, paid provider, or audible playback is used. Exact generation source, synthesis text, references, extraction, duration and seeds are archived/hash-bound in `candidates.json` and `docs/release/voice-licenses/generators/`.

`validation.json` verifies all eleven files differ from the rejected takes, decode as finite, non-silent mono 24 kHz MP3s, match their metadata/source snapshots, and record eight bundled approvals with three rejected takes outside the app. `review-ui-validation.json` verifies all 22 player controls, review decisions, filters, persistence, export and stale-approval behavior without playing audio or making network calls. These checks do not approve pronunciation.

No store upload, submission or publication is authorized or performed.
