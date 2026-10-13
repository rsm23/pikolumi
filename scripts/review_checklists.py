"""Retain human review notes and bind approvals to the reviewed source."""
import csv
import hashlib
import json

REVIEW_FIELDS = ('approved', 'reviewer', 'date', 'notes')


def clip_hash(root, locale, filename):
    return hashlib.sha256((root / 'assets/audio' / locale / filename).read_bytes()).hexdigest()


def lesson_hash(activity, locale, art):
    config = {key: value for key, value in activity['config'].items() if key != 'locales'}
    config.update(activity['config'].get('locales', {}).get(locale, {}))
    references = set()

    def collect(value):
        if isinstance(value, str) and value in art:
            references.add(value)
        elif isinstance(value, dict):
            for child in value.values():
                collect(child)
        elif isinstance(value, list):
            for child in value:
                collect(child)

    collect(config)
    collect(activity.get('preview'))
    source = {
        'config': config, 'instructions': activity['instructions'][locale],
        'title': activity['title'][locale], 'objective': activity['objective'],
        'stage': activity['stage'], 'cue': activity.get('cue', {}).get(locale),
        'art': {key: art[key] for key in sorted(references)},
    }
    return hashlib.sha256(json.dumps(source, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def render_pronunciation(template, data, recordings, lesson_content, *,
                         locale_name='Arabic', checklist='arabic-narration-review.csv',
                         related_links='<a href="../language-review/index.html">All languages</a>',
                         lesson_guidance=None):
    import html
    locale = data.get('locale', 'ar')
    if lesson_guidance is None:
        lesson_guidance = '''<p><a href="arabic-lesson-review.csv">240-lesson checklist</a>. Check letter identity, stroke direction, joining, dots, vowel signs and teaching suitability.</p>
<p>Review all 28 letter names, short vowels, long vowels, lam–alif, and consonant contrasts: <span lang="ar" dir="rtl">س/ص، ت/ط، د/ض، ذ/ظ، ح/ه، ع/ء</span>. Contextual-form compounds demonstrate letter shapes; word tracing uses real words.</p>'''
    replacements = {
        '@@LOCALE_NAME@@': html.escape(locale_name),
        '@@SCRIPT_FONT@@': 'Arabic' if locale == 'ar' else 'Nunito',
        '@@SCRIPT_ALIGN@@': 'right' if locale == 'ar' else 'left',
        '@@CHECKLIST@@': html.escape(checklist, quote=True),
        '@@RELATED_LINKS@@': related_links,
        '@@LESSON_GUIDANCE@@': lesson_guidance,
        '@@RECORDINGS@@': recordings, '@@LESSON_CONTENT@@': lesson_content,
        '@@DATA@@': json.dumps(data, ensure_ascii=False).replace('<', '\\u003c'),
    }
    for key, value in replacements.items():
        template = template.replace(key, value)
    return template


def write_checklist(path, fields, rows, keys):
    previous = {}
    if path.exists():
        with path.open(newline='') as file:
            for row in csv.DictReader(file):
                previous[tuple(row.get(key, '') for key in keys)] = row
    output = []
    for values in rows:
        row = dict(zip(fields, values))
        old = previous.get(tuple(row.get(key, '') for key in keys), {})
        for field in REVIEW_FIELDS:
            row[field] = old.get(field, '')
        source_changed = any(
            str(row.get(field, '')) != old.get(field, '')
            for field in fields if field not in REVIEW_FIELDS
        )
        if source_changed and row['approved']:
            row['approved'] = ''
            row['notes'] = (row['notes'] + '\nSource changed; approval needs a new review.').strip()
        output.append(row)
    with path.open('w', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=fields)
        writer.writeheader()
        writer.writerows(output)
