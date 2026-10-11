#!/usr/bin/env python3
"""Generate bundled development narration with offline Piper models, never Apple system voices."""
import json, urllib.request, pathlib, subprocess, tempfile, concurrent.futures, wave
from piper import PiperVoice, SynthesisConfig
ROOT=pathlib.Path(__file__).resolve().parents[1]
CACHE=pathlib.Path('/Users/rahmaniseif/.cache/pikolumi/voices')
VOICES={'en':('en/en_US/ljspeech/high','en_US-ljspeech-high'),'fr':('fr/fr_FR/siwis/medium','fr_FR-siwis-medium'),'es':('es/es_ES/sharvard/medium','es_ES-sharvard-medium'),'pt':('pt/pt_BR/faber/medium','pt_BR-faber-medium'),'ar':('ar/ar_JO/kareem/medium','ar_JO-kareem-medium')}
manifest=json.loads((ROOT/'assets/content/audio_manifest.json').read_text())
CACHE.mkdir(parents=True,exist_ok=True)

def generate(lang):
 folder,model=VOICES[lang];base='https://huggingface.co/rhasspy/piper-voices/resolve/main/'+folder+'/'
 for extension in ['.onnx','.onnx.json']:
  target=CACHE/(model+extension)
  if not target.exists(): urllib.request.urlretrieve(base+model+extension,target)
 card=urllib.request.urlopen(base+'MODEL_CARD').read()
 (ROOT/'docs/release'/f'voice-{lang}-MODEL_CARD.md').write_bytes(card)
 voice=PiperVoice.load(str(CACHE/(model+'.onnx')))
 dest=ROOT/'assets/audio'/lang;dest.mkdir(parents=True,exist_ok=True)
 config=SynthesisConfig(length_scale=1.08,noise_scale=.5,noise_w_scale=.6,normalize_audio=True)
 cache_file=CACHE/f'{lang}-texts.json'
 old_texts=json.loads(cache_file.read_text()) if cache_file.exists() else {}
 for i,(filename,text) in enumerate(manifest[lang].items()):
  out=dest/filename
  if out.exists() and old_texts.get(filename)==text: continue
  with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
   with wave.open(tmp.name,'wb') as wav: voice.synthesize_wav(text,wav,syn_config=config)
   subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',tmp.name,'-codec:a','libmp3lame','-b:a','48k',str(out)],check=True)
  if (i+1)%25==0: print(f'{lang}: {i+1}/{len(manifest[lang])}',flush=True)
 cache_file.write_text(json.dumps(manifest[lang],ensure_ascii=False,indent=2))
 print(f'{lang}: complete',flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for result in pool.map(generate,VOICES): pass
# Original synthesized piano-like tones, not sampled instruments.
import numpy as np
for i,hz in enumerate([261.63,293.66,329.63,349.23,392,440,493.88,523.25]):
 t=np.arange(16000*.45)/16000; signal=(np.sin(2*np.pi*hz*t)+.24*np.sin(2*np.pi*hz*2*t)) * np.exp(-t*5)
 samples=(signal/1.3*22000).astype('<i2')
 with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
  with wave.open(tmp.name,'wb') as w: w.setnchannels(1);w.setsampwidth(2);w.setframerate(16000);w.writeframes(samples.tobytes())
  subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',tmp.name,'-codec:a','libmp3lame','-b:a','48k',str(ROOT/'assets/audio'/f'note_{i}.mp3')],check=True)
print('All audio assets compiled',flush=True)
