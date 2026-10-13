#!/usr/bin/env python3
"""Compile licensed narration to files. Never plays audio."""
import argparse, hashlib, importlib.metadata, json, os, subprocess, tempfile
from pathlib import Path
os.environ.setdefault('PYTORCH_ENABLE_MPS_FALLBACK','1')
import numpy as np
import soundfile as sf
import torch
from huggingface_hub import hf_hub_download
from kokoro import KModel, KPipeline

ROOT=Path(__file__).resolve().parents[1]
CACHE=Path(os.environ.get('PIKOLUMI_VOICE_CACHE',Path.home()/'.cache/pikolumi/licensed-voices'))
BASE=('hexgrad/Kokoro-82M','f3ff3571791e39611d31c381e3a41a3af07b4987')
AR=('silma-ai/silma-tts','226dd7a65cadf51f9a6dbe3953fc89003b3844d5')
VOCODER=('charactr/vocos-mel-24khz','0feb3fdd929bcd6649e0e7c5a688cf7dd012ef21')
VOICES={'en':('a','af_heart'),'fr':('f','ff_siwis'),'es':('e','ef_dora'),'pt':('p','pf_dora')}
REFERENCE_TEXT='Welcome to our colorful garden. Let us explore, draw, and learn together.'
torch.set_num_threads(2)

def digest(path):
    with Path(path).open('rb') as file: return hashlib.file_digest(file,'sha256').hexdigest()

def fetch(source,name): return Path(hf_hub_download(source[0],name,revision=source[1]))

def encode(samples,output):
    samples=np.asarray(samples,dtype=np.float32).reshape(-1)
    if not len(samples) or not np.isfinite(samples).all() or np.max(np.abs(samples))<.001:
        raise ValueError(f'Invalid or silent generated audio: {output}')
    samples*=min(1.,.95/np.max(np.abs(samples)))
    with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
        sf.write(tmp.name,samples,24000)
        target=output.with_suffix('.pending.mp3')
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',tmp.name,'-codec:a','libmp3lame','-b:a','48k',str(target)],check=True)
        target.replace(output)

def archive(source,label):
    target=ROOT/'docs/release/voice-licenses';target.mkdir(parents=True,exist_ok=True)
    (target/f'{label}-MODEL_CARD.md').write_bytes(fetch(source,'README.md').read_bytes())

def silma_synth(reference):
    # Finite Arabic scripts are explicitly vowelled; no automatic normalizer.
    from silma_tts.model import CFM, DiT
    from silma_tts.model.utils import get_tokenizer
    from vocos import Vocos
    import yaml
    config=yaml.safe_load(fetch(AR,'config.yaml').read_text())
    chars,size=get_tokenizer(str(fetch(AR,'vocab.txt')),'custom')
    model=CFM(transformer=DiT(**config['model']['arch'],text_num_embeds=size,mel_dim=100),
              mel_spec_kwargs=config['model']['mel_spec'],odeint_kwargs={'method':'euler'},vocab_char_map=chars)
    weights=fetch(AR,'model.pt')
    state=torch.load(weights,map_location='cpu',weights_only=True)
    model.load_state_dict(state['model_state_dict']);del state
    vocoder_config=fetch(VOCODER,'config.yaml');vocoder_weights=fetch(VOCODER,'pytorch_model.bin')
    vocoder=Vocos.from_hparams(str(vocoder_config))
    vocoder.load_state_dict(torch.load(vocoder_weights,map_location='cpu',weights_only=True))
    device='mps' if torch.backends.mps.is_available() else 'cpu'
    model.eval().to(device);vocoder.eval().to(device)
    audio=torch.from_numpy(reference).unsqueeze(0).to(device)
    audio*=.1/torch.sqrt(torch.mean(audio.square()))
    frames=audio.shape[-1]//256
    def synth(text,seed):
        torch.manual_seed(seed)
        extra=max(70,int(frames*len(text)/len(REFERENCE_TEXT)/.85))
        with torch.inference_mode():
            generated,_=model.sample(cond=audio,text=[REFERENCE_TEXT+' '+text],duration=frames+extra,
                                     steps=32,cfg_strength=2.,sway_sampling_coef=-1)
            return vocoder.decode(generated[:,frames:,:].float().permute(0,2,1)).squeeze().cpu().numpy()
    return synth,{'model':AR,'modelSha256':digest(weights),'vocoder':VOCODER,'vocoderSha256':digest(vocoder_weights),
                  'referenceSha256':hashlib.sha256(reference.tobytes()).hexdigest(),'referenceText':REFERENCE_TEXT,
                  'steps':32,'speed':.85,'minFrames':70,'device':device,'silmaPackage':importlib.metadata.version('silma-tts')}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--languages',nargs='+',choices=['en','fr','es','pt','ar'],default=['en','fr','es','pt','ar'])
    parser.add_argument('--limit',type=int,help='Limited candidate set; does not produce release provenance')
    args=parser.parse_args();CACHE.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((ROOT/'assets/content/audio_manifest.json').read_text())
    archive(BASE,'kokoro')
    model_path=fetch(BASE,'kokoro-v1_0.pth');config=fetch(BASE,'config.json')
    model=KModel(repo_id=BASE[0],config=str(config),model=str(model_path)).eval()
    index_path=ROOT/'assets/content/audio_provenance.json'
    index=json.loads(index_path.read_text()) if index_path.exists() else {'schema':1,'locales':{}}
    for lang in args.languages:
        if lang=='ar':
            archive(AR,'silma');archive(VOCODER,'vocos')
            voice=torch.load(fetch(BASE,'voices/af_heart.pt'),map_location='cpu',weights_only=True)
            pipeline=KPipeline(lang_code='a',repo_id=BASE[0],model=model)
            reference=np.concatenate([a.cpu().numpy() for _,_,a in pipeline(REFERENCE_TEXT,voice=voice,speed=1.)])
            synth,identity=silma_synth(reference)
        else:
            code,name=VOICES[lang];voice_path=fetch(BASE,f'voices/{name}.pt')
            pipeline=KPipeline(lang_code=code,repo_id=BASE[0],model=model)
            voice=torch.load(voice_path,map_location='cpu',weights_only=True)
            identity={'model':BASE,'modelSha256':digest(model_path),'configSha256':digest(config),
                      'voice':name,'voiceSha256':digest(voice_path),'speed':.9,'kokoroPackage':importlib.metadata.version('kokoro')}
            def synth(text,seed):
                torch.manual_seed(seed)
                return np.concatenate([a.cpu().numpy() for _,_,a in pipeline(text,voice=voice,speed=.9)])
        identity.update(torch=torch.__version__,generatorSha256=digest(__file__))
        dest=ROOT/'assets/audio'/lang;dest.mkdir(parents=True,exist_ok=True)
        cache_path=CACHE/f'{lang}-index.json'
        old=json.loads(cache_path.read_text()) if cache_path.exists() else {};records={}
        files=list(manifest[lang].items())[:args.limit] if args.limit else list(manifest[lang].items())
        for i,(filename,text) in enumerate(files):
            seed=int(hashlib.sha256((lang+filename).encode()).hexdigest()[:8],16)
            key=hashlib.sha256(json.dumps([identity,text,seed],sort_keys=True,ensure_ascii=False).encode()).hexdigest()
            output=dest/filename
            if not output.exists() or old.get(filename,{}).get('inputSha256')!=key or old.get(filename,{}).get('sha256')!=digest(output):
                encode(synth(text,seed),output)
            records[filename]={'inputSha256':key,'sha256':digest(output),'text':text,'seed':seed}
            old[filename]=records[filename];cache_path.write_text(json.dumps(old,ensure_ascii=False,indent=2))
            if (i+1)%20==0 or i==len(files)-1: print(f'{lang}: {i+1}/{len(files)} compiled (silent)',flush=True)
        if not args.limit:
            index['locales'][lang]={'source':identity,'clips':records,'pronunciationReview':'pending'}
            index_path.write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n')
    for i,hz in enumerate([261.63,293.66,329.63,349.23,392,440,493.88,523.25]):
        t=np.arange(int(24000*.45))/24000
        encode((np.sin(2*np.pi*hz*t)+.24*np.sin(4*np.pi*hz*t))*np.exp(-t*5)*.65,ROOT/f'assets/audio/note_{i}.mp3')

if __name__=='__main__': main()
