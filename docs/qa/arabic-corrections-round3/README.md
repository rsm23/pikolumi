# Arabic replacements: third review round

The second review approved eight additional takes, for 52 approved replacements now bundled. The round-three receipt approved ظِ (`syllable_46.mp3`) and هَ (`syllable_72.mp3`), now bundled for a cumulative 54 approvals. صِ (`syllable_37.mp3`) remains rejected and keeps its bundled original. [Round 5](../arabic-corrections-round5/index.html) has a fresh contextual attempt.

Open `index.html`, compare the previous rejected take with each new candidate, select **Sounds correct** or **Still wrong**, then **Save review**. This page has its own browser storage, the imported three hash-bound decisions, hash-bound export and no automatic playback. Rejected candidates remain outside app assets.

Generation uses direct vowel-marked Modern Standard Arabic, a new deterministic seed and a 0.80-second window per sound, with already approved synthetic elephant/handwriting clips and existing counting guidance as references. The first attempted 0.50-second strategy produced silence and was rejected automatically. Exact source, model/reference hashes, text, seeds and extraction are archived in `candidates.json`; no human voice cloning or paid provider was used.

`validation.json` verifies finite, non-silent mono 24 kHz audio, changed hashes, two promoted approvals and archived source bindings. `review-ui-validation.json` checks six player controls, review state, filters and export without playback/network calls. The extraction label was clarified after generation to avoid claiming all references are approved consonant examples; no audio bytes changed. These checks do not approve pronunciation. No store actions were performed.
