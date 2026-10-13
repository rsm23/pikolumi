#!/usr/bin/env python3
"""Decode bundled audio without playback; optionally repair MP3 peak overshoot."""
import argparse
import datetime
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repair-peaks', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'assets/content/audio_manifest.json').read_text())
    provenance_path = ROOT / 'assets/content/audio_provenance.json'
    provenance = json.loads(provenance_path.read_text())
    entries = [(lang, file) for lang, files in manifest.items() for file in files]
    entries += [(None, f'note_{i}.mp3') for i in range(8)]
    reports, errors, repaired = [], [], []
    for lang, filename in entries:
        path = ROOT / 'assets/audio' / lang / filename if lang else ROOT / 'assets/audio' / filename
        data, rate = sf.read(path, dtype='float32', always_2d=True)
        peak = float(np.max(np.abs(data)))
        if args.repair_peaks and peak > .98:
            if lang and provenance['locales'][lang]['clips'][filename].get('nativeReview', {}).get('decision') == 'correct':
                raise ValueError(f'Cannot change approved bytes during peak repair: {filename}')
            source_hash, total_gain = digest(path), 1.
            original = data.copy()
            for _ in range(3):
                total_gain *= .9 / peak
                with tempfile.NamedTemporaryFile(suffix='.wav') as wav:
                    sf.write(wav.name, original * total_gain, rate, subtype='FLOAT')
                    pending = path.with_suffix('.mastering.mp3')
                    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                                    '-i', wav.name, '-codec:a', 'libmp3lame', '-b:a', '48k', str(pending)], check=True)
                    data, rate = sf.read(pending, dtype='float32', always_2d=True)
                    peak = float(np.max(np.abs(data)))
                if peak <= .98:
                    pending.replace(path)
                    break
            else:
                pending.unlink(missing_ok=True)
                raise ValueError(f'Peak repair failed: {path}')
            if lang:
                record = provenance['locales'][lang]['clips'][filename]
                record['mastering'] = {'sourceSha256': source_hash, 'gain': total_gain,
                                       'method': 'decoded float samples, linear attenuation, libmp3lame 48k',
                                       'scriptSha256': digest(Path(__file__))}
                record['sha256'] = digest(path)
                cache_root = Path(os.environ.get('PIKOLUMI_VOICE_CACHE', Path.home() / '.cache/pikolumi/licensed-voices'))
                cache_file = cache_root / f'{lang}-index.json'
                if cache_file.exists():
                    cached = json.loads(cache_file.read_text())
                    cached[filename] = record
                    cache_file.write_text(json.dumps(cached, ensure_ascii=False, indent=2))
            repaired.append(str(path.relative_to(ROOT)))
        duration = len(data) / rate
        rms = float(np.sqrt(np.mean(data ** 2)))
        ok = rate == 24000 and data.shape[1] == 1 and np.isfinite(data).all() and .1 <= duration <= 30 and rms > 1e-5 and peak <= 1
        if not ok:
            errors.append(str(path.relative_to(ROOT)))
        reports.append({'file': str(path.relative_to(ROOT)), 'durationSeconds': round(duration, 3),
                        'sampleRate': rate, 'channels': data.shape[1], 'peak': round(peak, 5),
                        'rms': round(rms, 5), 'sha256': digest(path), 'passed': bool(ok)})
    if repaired:
        provenance_path.write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n')
        archive = ROOT / 'docs/release/voice-licenses/generators'
        archive.mkdir(parents=True, exist_ok=True)
        source = Path(__file__)
        (archive / (digest(source) + '.py')).write_bytes(source.read_bytes())
    report = {'checkedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'catalogVersion': json.loads((ROOT / 'assets/content/catalog.json').read_text())['version'],
              'speechClips': sum(map(len, manifest.values())), 'toneClips': 8,
              'method': 'Decoded MP3 files and inspected finite samples, duration, level and format; no playback',
              'pronunciationApproval': False, 'repairedPeaks': repaired, 'errors': errors,
              'passed': not errors, 'clips': reports}
    (ROOT / 'docs/qa/audio-file-validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'clips'}, indent=2))
    raise SystemExit(bool(errors))


if __name__ == '__main__':
    main()
