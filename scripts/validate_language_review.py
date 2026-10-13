#!/usr/bin/env python3
"""Check review coverage, source bindings and offline references; never approve content."""
import csv
import hashlib
import json
import re
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse

from review_checklists import clip_hash, lesson_hash

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'docs/qa/language-review'


class Packet(HTMLParser):
    def __init__(self):
        super().__init__()
        self.references = []
        self.autoplay = False

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        for key in ['href', 'src']:
            if values.get(key):
                self.references.append(values[key])
        if tag in ['audio', 'video'] and 'autoplay' in values:
            self.autoplay = True


def validate():
    catalog = json.loads((ROOT / 'assets/content/catalog.json').read_text())
    audio = json.loads((ROOT / 'assets/content/audio_manifest.json').read_text())
    art = json.loads((ROOT / 'assets/content/art.json').read_text())
    strings = json.loads((ROOT / 'assets/content/strings.json').read_text())
    manifest = json.loads((DEST / 'packet-manifest.json').read_text())
    expected_ids = {activity['id'] for activity in catalog['activities']}
    assert len(expected_ids) == manifest['distinctActivities'] == 2400
    counts = []
    for entry in manifest['locales']:
        locale = entry['locale']
        recordings = list(csv.DictReader((DEST / entry['narrationChecklist']).open()))
        assert len(recordings) == len(audio[locale]) == entry['recordings']
        assert {row['file'] for row in recordings} == set(audio[locale])
        for row in recordings:
            assert row['script'] == audio[locale][row['file']]
            assert row['sourceSha256'] == clip_hash(ROOT, locale, row['file'])
        activities = list(csv.DictReader((DEST / entry['activityChecklist']).open()))
        assert len(activities) == 2400 and {row['activityId'] for row in activities} == expected_ids
        by_id = {row['activityId']: row for row in activities}
        for activity in catalog['activities']:
            row = by_id[activity['id']]
            assert row['locale'] == locale
            assert row['sourceSha256'] == lesson_hash(activity, locale, art)
        interface = list(csv.DictReader((DEST / entry['interfaceChecklist']).open()))
        assert len(interface) == len(strings) and {row['key'] for row in interface} == set(strings)
        for row in interface:
            expected = strings[row['key']][locale]
            assert row['text'] == expected and row['locale'] == locale
            assert row['sourceSha256'] == hashlib.sha256(json.dumps([row['key'], locale, expected], ensure_ascii=False).encode()).hexdigest()
        lesson_html = (DEST / f'{locale}-lessons.html').read_text()
        payload = json.loads(re.search(r'<script id="lesson-data" type="application/json">(.*?)</script>', lesson_html, re.S).group(1))
        assert len(payload['activities']) == 2400 and {activity['id'] for activity in payload['activities']} == expected_ids
        for activity in payload['activities']:
            assert activity['sourceSha256'] == by_id[activity['id']]['sourceSha256']
            if activity['preview']:
                assert (DEST / unquote(urlparse(activity['preview']).path)).is_file()
        counts.append({'locale': locale, 'recordings': len(recordings), 'activities': len(activities), 'interfaceTexts': len(interface)})
    pages = list(DEST.glob('*.html')) + [ROOT / 'docs/qa/arabic-review/index.html']
    for path in pages:
        source = path.read_text()
        assert '@@' not in source, f'Unrendered template: {path}'
        packet = Packet()
        packet.feed(source)
        assert not packet.autoplay, f'Autoplay: {path}'
        for reference in packet.references + re.findall(r'url\(([^)]+)\)', source):
            url = urlparse(reference)
            assert not url.scheme and not url.netloc, f'External resource: {reference}'
            if url.path:
                assert (path.parent / unquote(url.path)).is_file(), f'Missing link: {path.name}: {reference}'
    result = {'checkedAtUTC': datetime.now(timezone.utc).isoformat(), 'passed': True,
              'scope': 'Packet coverage, exact source SHA bindings and local references; no media playback',
              'locales': counts, 'distinctAdvertisedActivities': 2400, 'speechRecordings': 648,
              'offlineReferencesValidated': True, 'humanApproval': False,
              'releaseGatesChanged': False}
    (DEST / 'source-validation.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    validate()
