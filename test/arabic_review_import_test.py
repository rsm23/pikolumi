import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from import_arabic_review import apply_review
from audio_review import protected_record


def sha(data):
    return hashlib.sha256(data).hexdigest()


class ReviewImportTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.folder = self.root / 'docs/qa/arabic-corrections'
        for path in [self.folder / 'candidates', self.folder / 'originals', self.root / 'assets/audio/ar', self.root / 'assets/content']:
            path.mkdir(parents=True)
        self.rows = []
        candidates = []
        clips = {}
        manifest = {}
        for i, decision in enumerate(['correct', 'wrong']):
            name = f'syllable_{i}.mp3'
            original = f'original-{i}'.encode()
            replacement = f'new-{i}'.encode()
            text = ['بِ', 'حِ'][i]
            (self.folder / 'candidates' / name).write_bytes(replacement)
            (self.folder / 'originals' / name).write_bytes(original)
            (self.root / 'assets/audio/ar' / name).write_bytes(original)
            manifest[name] = text
            clips[name] = {'sha256': sha(original), 'text': text}
            candidates.append({'file': name, 'text': text, 'sha256': sha(replacement), 'originalSha256': sha(original), 'synthesisText': text, 'seed': i, 'targetSeconds': .5, 'extraction': 'test'})
            self.rows.append({'file': name, 'text': text, 'sha256': sha(replacement), 'decision': decision, 'notes': ''})
        (self.folder / 'candidates.json').write_text(json.dumps({'source': {'generator': 'test'}, 'recordings': candidates}))
        (self.root / 'assets/content/audio_manifest.json').write_text(json.dumps({'ar': manifest}))
        (self.root / 'assets/content/audio_provenance.json').write_text(json.dumps({'locales': {'ar': {'clips': clips}}}))
        self.review = self.root / 'review.json'
        self.write_review()

    def write_review(self):
        self.review.write_text(json.dumps({'locale': 'ar', 'exportedAt': '2026-10-12T21:46:44Z', 'recordings': self.rows}))

    def test_only_approved_bytes_are_promoted_and_receipt_is_idempotent(self):
        result = apply_review(self.review, self.root)
        self.assertEqual(result['approvedAndBundled'], ['syllable_0.mp3'])
        self.assertEqual(result['rejectedAndNotBundled'], ['syllable_1.mp3'])
        self.assertEqual((self.root / 'assets/audio/ar/syllable_0.mp3').read_bytes(), b'new-0')
        self.assertEqual((self.root / 'assets/audio/ar/syllable_1.mp3').read_bytes(), b'original-1')
        provenance = self.root / 'assets/content/audio_provenance.json'
        first = provenance.read_bytes()
        apply_review(self.review, self.root)
        self.assertEqual(provenance.read_bytes(), first)
        record = json.loads(first)['locales']['ar']['clips']['syllable_0.mp3']
        self.assertEqual(record['nativeReview']['reviewedSha256'], sha(b'new-0'))
        self.assertFalse(result['allArabicPronunciationApproved'])

    def test_stale_review_rejects_the_entire_batch_before_writes(self):
        self.rows[1]['sha256'] = '0' * 64
        self.write_review()
        with self.assertRaises(ValueError):
            apply_review(self.review, self.root)
        self.assertEqual((self.root / 'assets/audio/ar/syllable_0.mp3').read_bytes(), b'original-0')
        self.assertFalse((self.folder / 'reviews').exists())

    def test_duplicate_filename_is_rejected(self):
        self.rows[1] = dict(self.rows[0])
        self.write_review()
        with self.assertRaises(ValueError):
            apply_review(self.review, self.root)

    def test_approved_recordings_are_protected_from_regeneration_and_script_changes(self):
        apply_review(self.review, self.root)
        path = self.root / 'assets/audio/ar/syllable_0.mp3'
        record = json.loads((self.root / 'assets/content/audio_provenance.json').read_text())['locales']['ar']['clips']['syllable_0.mp3']
        self.assertEqual(protected_record(record, path, 'بِ'), record)
        with self.assertRaises(ValueError): protected_record(record, path, 'بُ')
        path.write_bytes(b'changed')
        with self.assertRaises(ValueError): protected_record(record, path, 'بِ')


if __name__ == '__main__':
    unittest.main()
