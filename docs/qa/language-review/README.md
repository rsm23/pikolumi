# Reviewing Pikolumi's languages

Open [the review index](index.html) locally. It links every recording and all 2,400 activity definitions in English, French, Spanish, Brazilian Portuguese and Modern Standard Arabic. These are localized views of the same library, not additional activities.

## Pronunciation corrections

Press Play yourself when ready. Tick **Wrong pronunciation**, add an optional note, and copy the selected list into the chat or download it. The agent's computer tests stay silent. Selections save separately for each language, even when filenames match.

Downloaded reports merge with saved selections from the same language. Importing a different language's report leaves current choices unchanged. If a recording changes, its old flag clears and its note stays for another review. The Arabic page keeps its existing storage key and download format.

## Lesson and interface review

The lesson pages show 24 activities at a time. Search by activity ID, title, word or question; filter by section and skill band. Each card includes the localized instructions, question, answer options, source configuration and related recording filenames. Tracing diagrams use the same 220-unit coordinate space and ordered points as the app.

Open the activity, recording and interface CSV checklists in a spreadsheet or text editor. For an item you have actually reviewed, enter `yes` or `no` in `approved`, your reviewer name, an ISO date such as `2026-10-12`, and correction notes as needed. Leave unreviewed items blank. Keep IDs, filenames, locale and source hashes unchanged. Send the completed checklist back for source validation and confirmation; the packet generators never grant release approval.

Review pronunciation, letter identity, accents and diacritics, word choice, instruction clarity, correct answers, age suitability, handwriting direction and progression. The shared learning objectives are internal curriculum notes in English; child-facing text is shown in the chosen language. Play representative activities in the actual app as well, including a different interface and learning language. Catalog pages and simulator captures alone do not establish physical-device acceptance.

Arabic's specialized 240-lesson handwriting/form packet and 214-recording checklist remain at `../arabic-review/`. Its recording checklist is the authoritative Arabic narration checklist. The new Arabic activity checklist covers the full 2,400-activity library.

## Regeneration and silent checks

From the project root:

```sh
.venv/bin/python scripts/build_arabic_review.py
.venv/bin/python scripts/build_language_review.py
.venv/bin/python scripts/validate_language_review.py
node tool/test_arabic_review.cjs
node tool/test_language_review.cjs
```

The DOM checks use the existing temporary jsdom installation documented in the project README. They do not open a browser session, fetch resources, or play media. Their flags and notes are isolated test fixtures, never human corrections or approvals. Visual browser verification remains pending because automated navigation to local file URLs is blocked.

Regeneration preserves checklist reviewer fields. A changed reviewed source clears its approval and retains the note for another review. First-generation language checklists also retain applicable legacy review notes. `source-validation.json` checks coverage and source binding; `ui-validation.json` records selection and lesson-browser behavior. Neither approves pronunciation or educational content.
