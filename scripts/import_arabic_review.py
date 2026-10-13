"""Import hash-bound user feedback; promote approved takes only, without playback."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def apply_review(path, root=ROOT, folder_name='docs/qa/arabic-corrections'):
    root = root.resolve()
    folder = (root / folder_name).resolve()
    if not folder.is_relative_to(root.resolve()): raise ValueError('Review folder must be inside project')
    raw = path.read_bytes()
    receipt = json.loads(raw)
    candidates = json.loads((folder / 'candidates.json').read_text())
    by_file = {r['file']: r for r in candidates['recordings']}
    manifest = json.loads((root / 'assets/content/audio_manifest.json').read_text())['ar']
    provenance_path = root / 'assets/content/audio_provenance.json'
    provenance = json.loads(provenance_path.read_text())
    rows = receipt['recordings']
    names = [r['file'] for r in rows]
    if receipt.get('locale') != 'ar' or len(names) != len(set(names)) or set(names) != set(by_file):
        raise ValueError('Review must name each candidate exactly once in Arabic')
    for row in rows:
        filename = row['file']
        if not re.fullmatch(r'[a-z0-9_]+\.mp3', filename) or row['decision'] not in ('correct', 'wrong'):
            raise ValueError('Invalid recording filename or decision')
        candidate = by_file[filename]
        if row['text'] != candidate['text'] or row['text'] != manifest[filename]:
            raise ValueError(f'Script mismatch: {filename}')
        if row['sha256'] != candidate['sha256'] or digest(folder / 'candidates' / filename) != row['sha256']:
            raise ValueError(f'Reviewed bytes changed: {filename}')
        if digest(folder / 'originals' / filename) != candidate['originalSha256']:
            raise ValueError(f'Original snapshot changed: {filename}')
        current = digest(root / 'assets/audio/ar' / filename)
        bundled_original = candidate.get('bundledOriginalSha256', candidate['originalSha256'])
        if current not in (bundled_original, row['sha256']):
            raise ValueError(f'Bundled audio changed independently: {filename}')
        if row['decision'] == 'wrong' and current != bundled_original:
            raise ValueError(f'Rejected candidate already bundled: {filename}')
    review_sha = hashlib.sha256(raw).hexdigest()
    reviews = folder / 'reviews'
    reviews.mkdir(exist_ok=True)
    stored = reviews / f'{review_sha}.json'
    stored.write_bytes(raw)
    stored_ref = str(stored.relative_to(root))
    approved, rejected = [], []
    for row in rows:
        filename = row['file']
        candidate = by_file[filename]
        if row['decision'] == 'wrong':
            rejected.append(filename)
            continue
        approved.append(filename)
        previous = provenance['locales']['ar']['clips'][filename]
        if previous.get('nativeReview', {}).get('reviewFileSha256') == review_sha:
            continue
        (root / 'assets/audio/ar' / filename).write_bytes((folder / 'candidates' / filename).read_bytes())
        provenance['locales']['ar']['clips'][filename] = {
            'inputSha256': hashlib.sha256(json.dumps([candidates['source'], candidate['synthesisText'], candidate['seed']], sort_keys=True, ensure_ascii=False).encode()).hexdigest(),
            'sha256': row['sha256'], 'text': row['text'], 'seed': candidate['seed'],
            'replacement': {'source': candidates['source'], 'synthesisText': candidate['synthesisText'],
                            'extraction': candidate['extraction'], 'targetSeconds': candidate['targetSeconds'],
                            'previousClip': previous, 'originalSha256': candidate['originalSha256']},
            'nativeReview': {'decision': 'correct', 'reviewer': 'user', 'reviewFile': stored_ref,
                             'reviewFileSha256': review_sha, 'reviewedSha256': row['sha256'],
                             'exportedAt': receipt.get('exportedAt'), 'notes': row.get('notes', '')},
        }
    total_approved = sum(c.get('nativeReview', {}).get('decision') == 'correct' for c in provenance['locales']['ar']['clips'].values())
    provenance['locales']['ar']['pronunciationReview'] = f'partial: {total_approved} replacement takes approved; other recordings remain pending or rejected'
    provenance_path.write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n')
    for path in (root / 'docs/qa/arabic-review').glob('*narration-review.csv'):
        with path.open(newline='') as f:
            reader = csv.DictReader(f); fields = reader.fieldnames; checklist = list(reader)
        decisions = {r['file']: r for r in rows}
        for row in checklist:
            decision = decisions.get(row['file'])
            if decision is None:
                continue
            row['approved'] = 'yes' if decision['decision'] == 'correct' else 'no'
            row['reviewer'] = 'user'
            row['date'] = receipt['exportedAt'][:10]
            row['sourceSha256'] = digest(root / 'assets/audio/ar' / row['file'])
            note = f"Replacement review {review_sha[:12]}: {decision['decision']}; candidate SHA-256 {decision['sha256']}. {decision.get('notes', '')}".strip()
            if note not in row['notes']:
                row['notes'] = (row['notes'] + '\n' + note).strip()
        with path.open('w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fields); writer.writeheader(); writer.writerows(checklist)
    summary = {'reviewFile': stored_ref, 'reviewFileSha256': review_sha,
               'exportedAt': receipt['exportedAt'], 'reviewer': 'user',
               'approvedAndBundled': approved, 'rejectedAndNotBundled': rejected,
               'totalApprovedArabicRecordings': total_approved, 'allArabicPronunciationApproved': False, 'audioPlayback': False}
    (folder / 'imported-review.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    signoffs = root / 'docs/qa/review-signoffs.json'
    if signoffs.exists():
        values = json.loads(signoffs.read_text())
        values['audioProvenanceSha256'] = digest(provenance_path)
        values['arabicPronunciationApproval'] = 'partial; full approval pending'
        values['arabicPronunciationIssues'] = f'{total_approved} hash-bound replacements approved by user and bundled; {len(rejected)} rejected replacements in this round need another review. Other Arabic recordings and educational content are not covered by this approval.'
        values['arabicReplacementReview'] = stored_ref
        strings_path = root / 'assets/content/strings.json'
        if strings_path.exists():
            interface_count = len(json.loads(strings_path.read_text()))
            values['reviewPacketScope'] = f'648 speech recordings; 2,400 activities and {interface_count} interface texts in each of five localized views'
        signoffs.write_text(json.dumps(values, ensure_ascii=False, indent=2) + '\n')
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('review', type=Path)
    parser.add_argument('--folder', default='docs/qa/arabic-corrections')
    args = parser.parse_args()
    result = apply_review(args.review, folder_name=args.folder)
    print(f"Promoted {len(result['approvedAndBundled'])} approved takes; kept {len(result['rejectedAndNotBundled'])} rejected takes outside the app; no playback")
