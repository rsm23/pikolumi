#!/usr/bin/env python3
"""Prepare offline, source-bound review packets without playing media."""
import csv
import hashlib
import html
import json
from pathlib import Path

from review_checklists import clip_hash, lesson_hash, render_pronunciation, write_checklist

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'docs/qa/language-review'
LOCALES = {
    'en': ('English', 'en', 'english'),
    'fr': ('French', 'fr', 'french'),
    'es': ('Spanish', 'es', 'spanish'),
    'pt': ('Brazilian Portuguese', 'pt-BR', 'brazilian-portuguese'),
    'ar': ('Modern Standard Arabic', 'ar', 'arabic'),
}
GROUPS = {
    'letters': 'Letters and long vowels', 'syllables': 'Short vowel sounds',
    'words': 'Vocabulary', 'tracing': 'Handwriting words',
    'instructions': 'Instructions and feedback',
}


def category(filename):
    if filename.startswith('letter_') or filename in ['lam_alif.mp3', 'long_alif.mp3']:
        return 'letters'
    for prefix, group in [('syllable_', 'syllables'), ('trace_word_', 'tracing'), ('word_', 'words')]:
        if filename.startswith(prefix):
            return group
    return 'instructions'


def recording_order(item):
    filename, _ = item
    number = filename.rsplit('_', 1)[-1].split('.')[0]
    return list(GROUPS).index(category(filename)), int(number) if number.isdigit() else 1000, filename


def localized(value, locale, languages):
    if isinstance(value, dict):
        if set(languages).issubset(value):
            return localized(value[locale], locale, languages)
        return {key: localized(child, locale, languages) for key, child in value.items()}
    if isinstance(value, list):
        return [localized(child, locale, languages) for child in value]
    return value


def generate():
    DEST.mkdir(parents=True, exist_ok=True)
    catalog = json.loads((ROOT / 'assets/content/catalog.json').read_text())
    audio = json.loads((ROOT / 'assets/content/audio_manifest.json').read_text())
    art = json.loads((ROOT / 'assets/content/art.json').read_text())
    strings = json.loads((ROOT / 'assets/content/strings.json').read_text())
    pronunciation_template = (ROOT / 'scripts/templates/arabic_review.html').read_text()
    lesson_template = (ROOT / 'scripts/templates/lesson_review.html').read_text()
    legacy_activity_path = ROOT / 'docs/qa/arabic-review/activity-review.csv'
    legacy_activity = {(row['activityId'], row['locale']): row
                       for row in csv.DictReader(legacy_activity_path.open())} if legacy_activity_path.exists() else {}
    arabic_activity_path = ROOT / 'docs/qa/arabic-review/arabic-lesson-review.csv'
    if arabic_activity_path.exists():
        for row in csv.DictReader(arabic_activity_path.open()):
            if any(row.get(field) for field in ['approved', 'reviewer', 'date', 'notes']):
                legacy_activity[row['activityId'], 'ar'] = row
    summary = []
    for locale, (name, html_language, slug) in LOCALES.items():
        narration_path = ROOT / 'docs/qa/arabic-review/arabic-narration-review.csv' if locale == 'ar' else DEST / f'{locale}-narration-review.csv'
        source_checklist = ROOT / 'docs/qa/arabic-review/narration-review.csv'
        if not narration_path.exists() and source_checklist.exists():
            rows = [row for row in csv.DictReader(source_checklist.open()) if row['locale'] == locale]
            with narration_path.open('w', newline='') as file:
                writer = csv.DictWriter(file, fieldnames=['locale','file','script','approved','reviewer','date','notes','sourceSha256'])
                writer.writeheader()
                writer.writerows(rows)
        if locale != 'ar':
            write_checklist(narration_path,
                ['locale','file','script','approved','reviewer','date','notes','sourceSha256'],
                ([locale, filename, text, '', '', '', '', clip_hash(ROOT, locale, filename)]
                 for filename, text in audio[locale].items()), ['locale', 'file'])
        activity_path = DEST / f'{locale}-activity-review.csv'
        activity_fields = ['activityId','locale','section','stage','title','approved','reviewer','date','notes','sourceSha256']
        if not activity_path.exists():
            with activity_path.open('w', newline='') as file:
                writer = csv.DictWriter(file, fieldnames=activity_fields)
                writer.writeheader()
                for activity in catalog['activities']:
                    old = legacy_activity.get((activity['id'], locale), {})
                    row = {'activityId': activity['id'], 'locale': locale, 'section': activity['section'],
                           'stage': activity['stage'], 'title': activity['title'][locale], 'sourceSha256': old.get('sourceSha256', '')}
                    row.update({field: old.get(field, '') for field in ['approved', 'reviewer', 'date', 'notes']})
                    writer.writerow(row)
        write_checklist(activity_path, activity_fields,
            ([activity['id'], locale, activity['section'], activity['stage'], activity['title'][locale],
              '', '', '', '', lesson_hash(activity, locale, art)] for activity in catalog['activities']),
            ['activityId', 'locale'])
        write_checklist(DEST / f'{locale}-interface-review.csv',
            ['key','locale','text','approved','reviewer','date','notes','sourceSha256'],
            ([key, locale, values[locale], '', '', '', '',
              hashlib.sha256(json.dumps([key, locale, values[locale]], ensure_ascii=False).encode()).hexdigest()]
             for key, values in strings.items()), ['key', 'locale'])
        if locale != 'ar':
            reviews = {row['file']: row for row in csv.DictReader(narration_path.open())}
            records, cards = [], []
            for index, (filename, text) in enumerate(sorted(audio[locale].items(), key=recording_order)):
                sha = clip_hash(ROOT, locale, filename)
                group = category(filename)
                row = {'file': filename, 'text': text, 'category': group, 'sha256': sha,
                       'activityIds': [activity['id'] for activity in catalog['activities']
                                       if activity.get('cue', {}).get(locale) == filename or activity.get('audio') == filename]}
                review = reviews[filename]
                rejected = review['approved'].lower() in ['no', 'false', 'incorrect']
                if rejected or review['notes']:
                    row['initialReview'] = {'flagged': rejected, 'notes': review['notes'], 'sha256': review['sourceSha256']}
                records.append(row)
                escaped = html.escape(filename, quote=True)
                cards.append(f'''<article class="recording" data-file="{escaped}">
<div class="file-name">{escaped}</div><div class="category">{GROUPS[group]}</div>
<p class="script{' short' if len(text) < 12 else ''}" lang="{html_language}" dir="ltr">{html.escape(text)}</p>
<audio controls preload="none" aria-label="Listen to {escaped}" src="../../../assets/audio/{locale}/{escaped}?v={sha}"></audio>
<label class="flag-control"><input type="checkbox" data-flag aria-label="Wrong pronunciation: {escaped}">Wrong pronunciation</label>
<p class="updated" data-updated hidden>Recording updated. Your previous note is retained; listen and select again if needed.</p>
<div data-note-container hidden><label class="note-label" for="note-{index}">Correction or what sounds wrong (optional)</label>
<textarea id="note-{index}" data-note maxlength="5000" dir="auto" placeholder="Write the correct text or pronunciation"></textarea></div></article>''')
            data = {'catalogVersion': catalog['version'], 'locale': locale, 'localeName': name,
                    'storageKey': f'pikolumi-{slug}-pronunciation-review-v1',
                    'exportName': f'pikolumi-{slug}-corrections.json', 'recordings': records}
            guidance = f'''<p><a href="{locale}-lessons.html">Browse all 2,400 activities</a> or open the <a href="{locale}-activity-review.csv">activity checklist</a>.</p>
<p>Check the language's letter names, accents, word stress, vocabulary and instruction clarity. Record approvals with your name and review date in the checklist; leaving a recording unselected does not approve it.</p>'''
            page = render_pronunciation(pronunciation_template, data, ''.join(cards), '',
                locale_name=name, checklist=narration_path.name,
                related_links='<a href="index.html">All languages</a>', lesson_guidance=guidance)
            (DEST / f'{locale}.html').write_text(page)
        lessons = []
        for activity in catalog['activities']:
            config = {key: value for key, value in activity['config'].items() if key != 'locales'}
            config.update(activity['config'].get('locales', {}).get(locale, {}))
            preview = config.get('scene') or activity.get('preview')
            image = ROOT / 'docs/qa/art-review/images' / f'{preview}.png'
            lessons.append({
                'id': activity['id'], 'section': activity['section'], 'stage': activity['stage'],
                'engine': activity['engine'], 'title': activity['title'][locale],
                'objective': activity['objective'], 'instructions': activity['instructions'][locale],
                'config': localized(config, locale, catalog['languages']),
                'sourceSha256': lesson_hash(activity, locale, art),
                'preview': f'../art-review/images/{preview}.png?v={hashlib.sha256(image.read_bytes()).hexdigest()}' if image.is_file() else None,
                'audio': [filename for filename in dict.fromkeys([activity.get('audio'), activity.get('cue', {}).get(locale)]) if filename],
            })
        lesson_data = {'locale': locale, 'htmlLanguage': html_language, 'name': name,
            'catalogVersion': catalog['version'], 'activities': lessons,
            'sections': [{'id': section['id'], 'name': section['name'][locale]} for section in catalog['sections']]}
        page = lesson_template.replace('@@LOCALE_NAME@@', html.escape(name))
        page = page.replace('@@LOCALE@@', locale)
        page = page.replace('@@PRONUNCIATION_URL@@', '../arabic-review/index.html' if locale == 'ar' else f'{locale}.html')
        page = page.replace('@@DATA@@', json.dumps(lesson_data, ensure_ascii=False).replace('<', '\\u003c'))
        (DEST / f'{locale}-lessons.html').write_text(page)
        summary.append({'locale': locale, 'name': name, 'recordings': len(audio[locale]),
                        'activities': len(lessons), 'interfaceTexts': len(strings), 'humanApproval': 'pending',
                        'narrationChecklist': '../arabic-review/arabic-narration-review.csv' if locale == 'ar' else narration_path.name,
                        'activityChecklist': activity_path.name, 'interfaceChecklist': f'{locale}-interface-review.csv'})
    rows = ''.join(f'''<tr><th scope="row">{row['name']}</th><td>{row['recordings']}</td>
<td><a href="{'../arabic-review/index.html' if row['locale']=='ar' else row['locale']+'.html'}">Select pronunciation problems</a></td>
<td><a href="{row['locale']}-lessons.html">Review 2,400 activities</a></td>
<td><a href="{row['locale']}-interface-review.csv">{row['interfaceTexts']} interface texts</a></td></tr>''' for row in summary)
    (DEST / 'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pikolumi language reviews</title><style>
body{max-width:1100px;margin:32px auto;padding:0 20px;background:#fbf7ee;color:#344850;font:18px/1.6 system-ui}h1{font-size:34px;line-height:1.2}p{max-width:75ch}a{color:#006b75}a:focus-visible{outline:3px solid #007e91;outline-offset:3px}table{width:100%;border-collapse:collapse;background:white;margin:24px 0}th,td{text-align:left;padding:16px;border-bottom:1px solid #c8d3d3}thead{background:#dcebee}.table{overflow:auto}td a{display:inline-block;padding:8px 0}small{font-size:15px}
</style><h1>Language and lesson reviews</h1><p>Each page uses the bundled scripts and activity definitions. Play recordings manually when ready, select pronunciation problems, and send the exported corrections. The lesson pages show instructions, answers and configurations for every activity.</p>
<p><a href="../PREVIEW.html">App previews</a> · <a href="../art-review/index.html">Coloring and puzzle artwork</a> · <a href="README.md">Recording approvals</a></p>
<div class="table" tabindex="0" aria-label="Language review links"><table><thead><tr><th>Language</th><th>Recordings</th><th>Pronunciation</th><th>Lessons</th><th>Interface</th></tr></thead><tbody>''' + rows + '''</tbody></table></div>
<p>These are five localized views of the same 2,400 activities. Source hashes bind checklist approvals to the material reviewed. A correction selection reports a problem; unselected items remain unreviewed.</p>
<p><small>Arabic reviewer: the user. Reviewers for the other languages are not yet assigned. Human approval remains pending for all languages. Computer testing stays silent.</small></p></html>''')
    (DEST / 'packet-manifest.json').write_text(json.dumps({'catalogVersion': catalog['version'], 'locales': summary,
        'distinctActivities': len(catalog['activities']), 'essentialSpeechRecordings': sum(len(files) for files in audio.values()),
        'humanApproval': 'pending', 'autoplay': False}, indent=2) + '\n')
    print('Prepared five language review packets: 648 recordings and 2,400 activities per locale view. No approvals or playback.')


if __name__ == '__main__':
    generate()
