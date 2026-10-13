"""Generate review candidates for the user's Arabic corrections; never play audio.

Uses the existing pinned, licensed SILMA/Vocos models and previously synthesized
Arabic guidance as a reference. This creates no human speaker clone. Candidates
remain outside bundled assets until selected for promotion and reviewed.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
import yaml
from silma_tts.model import CFM, DiT
from silma_tts.model.utils import get_tokenizer
from vocos import Vocos

from build_audio import ROOT, AR, VOCODER, fetch, digest, encode
from arabic_curriculum import bare


def trim_speech(samples):
    block = 240
    rms = np.array([np.sqrt(np.mean(samples[i:i+block]**2)) for i in range(0, len(samples), block)])
    active = np.flatnonzero(rms > max(.001, rms.max()*.035))
    if not len(active):
        return samples
    return samples[max(0, (active[0]-6)*block):min(len(samples), (active[-1]+7)*block)]


def middle_sound(samples):
    # Keep consonant closures within one utterance; split only substantial pauses.
    block = 240
    rms = np.array([np.sqrt(np.mean(samples[i:i+block]**2)) for i in range(0, len(samples), block)])
    active = np.flatnonzero(rms > max(.001, rms.max()*.035))
    if not len(active):
        return None
    groups = np.split(active, np.flatnonzero(np.diff(active) > 12)+1)
    groups = [g for g in groups if len(g) >= 5]
    if len(groups) != 3:
        return None
    group = groups[1]
    return samples[max(0, (group[0]-6)*block):min(len(samples), (group[-1]+7)*block)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--limit', type=int)
    parser.add_argument('--folder', default='docs/qa/arabic-corrections')
    parser.add_argument('--source-folder', default='assets/audio/ar')
    parser.add_argument('--seed-round', default='ar-correction-v1-')
    parser.add_argument('--anchored', action='store_true')
    parser.add_argument('--reference-files', nargs='+')
    parser.add_argument('--short-duration', type=float)
    parser.add_argument('--direct', action='store_true')
    args = parser.parse_args()
    folder = (ROOT / args.folder).resolve()
    source_folder = (ROOT / args.source_folder).resolve()
    assert folder.is_relative_to(ROOT) and source_folder.is_relative_to(ROOT)
    torch.set_num_threads(4)
    request = json.loads((folder / 'requested.json').read_text())
    manifest = json.loads((ROOT / 'assets/content/audio_manifest.json').read_text())['ar']
    output = folder / 'candidates'
    original = folder / 'originals'
    output.mkdir(exist_ok=True)
    original.mkdir(exist_ok=True)
    reference_files = args.reference_files or (['word_elephant.mp3', 'trace_word_8.mp3', 'counting.mp3'] if args.anchored else ['counting.mp3', 'welcome.mp3'])
    reference_parts, reference_records = [], []
    for filename in reference_files:
        path = ROOT / 'assets/audio/ar' / filename
        data, rate = sf.read(path, dtype='float32')
        assert rate == 24000 and data.ndim == 1
        reference_parts.extend([data, np.zeros(2400, dtype=np.float32)])
        reference_records.append({'file': filename, 'sha256': digest(path), 'text': manifest[filename],
                                  'origin': 'existing AI-synthesized project audio; not a human reference'})
    reference = np.concatenate(reference_parts)
    reference_text = ' '.join(r['text'] for r in reference_records)
    config = yaml.safe_load(fetch(AR, 'config.yaml').read_text())
    chars, size = get_tokenizer(str(fetch(AR, 'vocab.txt')), 'custom')
    model = CFM(transformer=DiT(**config['model']['arch'], text_num_embeds=size, mel_dim=100),
                mel_spec_kwargs=config['model']['mel_spec'], odeint_kwargs={'method': 'euler'}, vocab_char_map=chars)
    weights = fetch(AR, 'model.pt')
    state = torch.load(weights, map_location='cpu', weights_only=True)
    model.load_state_dict(state['model_state_dict'])
    del state
    vocoder_weights = fetch(VOCODER, 'pytorch_model.bin')
    vocoder = Vocos.from_hparams(str(fetch(VOCODER, 'config.yaml')))
    vocoder.load_state_dict(torch.load(vocoder_weights, map_location='cpu', weights_only=True))
    device = 'mps' if torch.backends.mps.is_available() else 'cpu'
    model.eval().to(device)
    vocoder.eval().to(device)
    audio = torch.from_numpy(reference).unsqueeze(0).to(device)
    audio *= .1 / torch.sqrt(torch.mean(audio.square()))
    frames = audio.shape[-1] // 256
    identity = {'model': AR, 'modelSha256': digest(weights), 'vocoder': VOCODER,
                'vocoderSha256': digest(vocoder_weights), 'reference': reference_records,
                'referenceText': reference_text, 'steps': 48, 'cfgStrength': 2,
                'device': device, 'generatorSha256': digest(__file__),
                'normalization': 'explicit Arabic text; no phonemizer; preserves consonants and vowel marks'}
    archive = ROOT / 'docs/release/voice-licenses/generators'
    archive.mkdir(parents=True, exist_ok=True)
    (archive / (digest(__file__) + '.py')).write_bytes(Path(__file__).read_bytes())
    candidates = []
    stop_scripts = {'letter_7.mp3': 'دَالْ', 'letter_8.mp3': 'ذَالْ', 'letter_10.mp3': 'زَايْ',
                    'long_alif.mp3': 'أَلِفْ مَدّ. آ.'}
    for item in request['recordings'][:args.limit]:
        filename = item['file']
        source = source_folder / filename
        assert digest(source) == item['originalSha256'], f'Source already changed: {filename}'
        (original / filename).write_bytes(source.read_bytes())
        text = stop_scripts.get(filename, item['text'])
        short_sound = filename.startswith('syllable_')
        if short_sound and not args.direct:
            anchor = 'بِ' if 'ِ' in text else 'بَ'
            text = '. '.join([anchor, text, anchor] if args.anchored else [text]*3)+'.'
            duration = 2.4
        elif short_sound:
            duration = args.short_duration or .65
        elif filename.startswith('letter_'):
            duration = .82
        elif filename == 'long_alif.mp3':
            duration = 2.4
        elif filename.startswith(('word_', 'trace_word_')):
            duration = max(.95, .20 * len(bare(text)))
        else:
            duration = max(1.2, frames * 256 / 24000 * len(text) / len(reference_text))
        extra = round(duration * 24000 / 256)
        seed = int(hashlib.sha256((args.seed_round + filename).encode()).hexdigest()[:8], 16)
        torch.manual_seed(seed)
        with torch.inference_mode():
            generated, _ = model.sample(cond=audio, text=[reference_text + ' ' + text],
                duration=frames + extra, steps=48, cfg_strength=2., sway_sampling_coef=-1)
            samples = vocoder.decode(generated[:, frames:, :].float().permute(0, 2, 1)).squeeze().cpu().numpy()
        extraction = 'direct vowel-marked sound with approved consonant/vowel references; trimmed outer silence' if args.direct else 'trimmed outer silence'
        if short_sound and not args.direct:
            isolated = middle_sound(samples)
            if isolated is not None:
                samples = isolated
                extraction = 'middle target between two Arabic vowel anchors; 60 ms boundary padding' if args.anchored else 'middle of three repeated syllables; 60 ms boundary padding'
            else:
                text = item['text']
                duration = .65 if args.anchored else .95
                extra = round(duration * 24000 / 256)
                torch.manual_seed(seed)
                with torch.inference_mode():
                    generated, _ = model.sample(cond=audio, text=[reference_text+' '+text],
                        duration=frames+extra, steps=48, cfg_strength=2., sway_sampling_coef=-1)
                    samples = vocoder.decode(generated[:,frames:,:].float().permute(0,2,1)).squeeze().cpu().numpy()
                extraction = 'direct isolated-sound fallback; no reliable three-utterance boundary'
        samples = trim_speech(samples)
        path = output / filename
        encode(samples, path)
        decoded, rate = sf.read(path, dtype='float32')
        assert rate == 24000 and np.isfinite(decoded).all() and np.max(np.abs(decoded)) <= 1
        candidates.append({**item, 'synthesisText': text, 'targetSeconds': duration,
                           'extraction': extraction,
                           'durationSeconds': len(decoded) / rate, 'seed': seed,
                           'sha256': digest(path), 'status': 'replacement candidate; native pronunciation approval pending'})
        print(f'{len(candidates)}/{len(request["recordings"])} Arabic candidates generated silently: {filename}', flush=True)
        (folder / 'candidates.json').write_text(json.dumps({'source': identity, 'pronunciationApproval': False,
            'recordings': candidates}, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
