#!/usr/bin/env python3
"""Validate the finite bundled library; presentation order never makes a new challenge."""
import json,hashlib,sys,collections,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
load=lambda name:json.loads((ROOT/f'assets/content/{name}.json').read_text())
cat=load('catalog');art=load('art');strings=load('strings');manifest=load('audio_manifest')
languages=cat['languages'];errors=[];semantic={};counts=collections.Counter();ids=set()
def check(ok,message):
 if not ok:errors.append(message)
def translations(value,label):
 check(isinstance(value,dict) and all(isinstance(value.get(l),str) and value[l].strip() for l in languages),label+' incomplete localization')
def fingerprint(cfg,engine):
 ignore={'lesson','layout','trail','comparison','melody','options'}
 clean={k:v for k,v in cfg.items() if k not in ignore}
 if engine=='memory':clean['pairs']=sorted(clean['pairs'])
 if engine=='sort':clean['items']=sorted(clean['items'],key=lambda i:i['art']);clean['groups']=sorted(clean['groups'],key=lambda i:i['value'])
 return hashlib.sha256(json.dumps(clean,sort_keys=True,ensure_ascii=False).encode()).hexdigest()
for key,value in strings.items():translations(value,f'UI {key}')
for sec in cat['sections']:translations(sec['name'],sec['id'])
for e in cat['activities']:
 id=e['id'];check(id not in ids,f'duplicate ID {id}');ids.add(id);counts[e['section']]+=1
 translations(e['title'],id);translations(e['instructions'],id)
 check(0<=e['stage']<=4,id+' invalid stage')
 if 'preview' in e:check(e['preview'] in art,id+' missing preview')
 for lang in languages:
  cfg={k:v for k,v in e['config'].items() if k!='locales'};cfg.update(e['config'].get('locales',{}).get(lang,{}))
  check((ROOT/f'assets/audio/{lang}/{e["audio"]}').is_file(),id+' missing instruction audio')
  if e.get('cue'):check((ROOT/f'assets/audio/{lang}/{e["cue"][lang]}').is_file(),id+' missing cue audio')
  for key in ['scene','subject']:
   if cfg.get(key):check(cfg[key] in art,id+' missing '+key)
  for picture in cfg.get('pictures',[]):check(picture in art,id+' missing picture')
  key=(e['section'],lang,fingerprint(cfg,e['engine']))
  check(key not in semantic,f'{id} duplicates designed challenge {semantic.get(key)} in {lang}')
  semantic[key]=id
  if e['engine']=='quiz':
   options=cfg['options'];values=[o['value'] for o in options]
   check(len(values)>=2 and len(values)==len(set(values)),id+' invalid choices')
   check(cfg['correct'] in values,id+' no correct answer')
   for option in options:
    translations(option['label'],id+' option')
    if option.get('art'):check(option['art'] in art,id+' missing option art')
   if 'a' in cfg:
    a,b=cfg['a'],cfg['b'];op=cfg['operation'];computed=(a+b if op=='+' else a-b if op=='−' else a*b if op=='×' else a/b)
    check(float(cfg['correct'])==computed,id+' incorrect arithmetic')
   if 'count' in cfg:check(str(cfg['count'])==cfg['correct'],id+' incorrect counting')
   if 'rule' in cfg:check(int(cfg['correct'])==cfg['rule']['start']+4*cfg['rule']['delta'],id+' incorrect pattern')
   if 'pattern' in cfg:check(cfg['correct']==cfg['pattern'][len(cfg['pictures'])%len(cfg['pattern'])],id+' incorrect picture pattern')
   if 'clock' in cfg:check(cfg['correct']==f'{cfg["clock"]["hour"]}:{cfg["clock"]["minute"]:02}',id+' incorrect time')
   if 'duration' in cfg:check(int(cfg['correct'])==(cfg['hour']+cfg['duration']-1)%12+1,id+' incorrect duration')
  elif e['engine']=='sequence':check(bool(cfg['word'].strip()) and cfg['subject'] in art,id+' invalid word')
  elif e['engine']=='trace':
   check(len(cfg['strokes'])>0,id+' empty trace')
   for stroke in cfg['strokes']:check(len(stroke)>=2 and all(len(p)==2 and all(math.isfinite(v) and 0<=v<=220 for v in p) for p in stroke),id+' invalid trace coordinates')
  elif e['engine']=='sort':
   groups={g['value'] for g in cfg['groups']};check(len(groups)>=2,id+' no sorting groups')
   check(len({j['value'] for j in cfg['items']})==len(cfg['items']),id+' duplicate sort item')
   for item in cfg['items']:check(item['target'] in groups and item['art'] in art,id+' invalid sort answer')
  elif e['engine']=='memory':check(len(cfg['pairs'])==len(set(cfg['pairs'])) and all(p in art for p in cfg['pairs']),id+' invalid memory deck')
  elif e['engine']=='jigsaw':check(2<=cfg['size']<=5 and cfg['scene'] in art,id+' invalid jigsaw')
  elif e['engine']=='music':check(all(0<=n<8 for n in cfg['notes']) and len(cfg['notes'])>=3,id+' invalid notes')
  elif e['engine']=='maze':
   n=cfg['size'];w=cfg['walls'];seen={0};queue=[0];check(len(w)==n*n,id+' invalid maze size')
   for at in queue:
    x,y=at%n,at//n
    for d,(dx,dy) in enumerate([(0,-1),(1,0),(0,1),(-1,0)]):
     nx,ny=x+dx,y+dy
     if not (0<=nx<n and 0<=ny<n):check(w[at][d]==1,id+' open maze boundary');continue
     to=ny*n+nx;check(w[at][d]==w[to][(d+2)%4],id+' asymmetric maze')
     if w[at][d]==0 and to not in seen:seen.add(to);queue.append(to)
   check(len(seen)==n*n and cfg['finish'] in seen,id+' unsolvable maze')
for name,scene in art.items():
 check(scene['width']>0 and scene['height']>0 and bool(scene['shapes']),name+' invalid vector')
 regions=set()
 for shape in scene['shapes']:
  check(shape['id'] not in regions,name+' duplicate coloring region');regions.add(shape['id'])
  check(shape['kind'] in ['ellipse','rect','path','poly','stroke'],name+' invalid primitive')
  if shape['kind']=='stroke':check(shape.get('fillable') is False,name+' ink detail must not be a paint region')
  if shape['kind']=='path':check(shape['d'].strip().upper().endswith('Z'),name+' open coloring path')
for lang,files in manifest.items():
 for file,text in files.items():
  path=ROOT/f'assets/audio/{lang}/{file}'
  check(bool(text.strip()) and path.is_file() and path.stat().st_size>100,lang+'/'+file+' missing audio')
provenance_path=ROOT/'assets/content/audio_provenance.json'
check(provenance_path.is_file(),'missing narration provenance')
if provenance_path.is_file():
 provenance=json.loads(provenance_path.read_text())
 for lang,files in manifest.items():
  record=provenance['locales'].get(lang,{})
  check(set(record.get('clips',{}))==set(files),lang+' incomplete narration provenance')
  for file,text in files.items():
   item=record.get('clips',{}).get(file,{})
   check(item.get('text')==text,lang+'/'+file+' speech script mismatch')
   path=ROOT/f'assets/audio/{lang}/{file}'
   if path.is_file():check(hashlib.sha256(path.read_bytes()).hexdigest()==item.get('sha256'),lang+'/'+file+' narration hash mismatch')
check((ROOT/'assets/content/CREDITS.txt').is_file(),'missing bundled attribution')
check(counts=={s['id']:s['count'] for s in cat['sections']},'section counts mismatch');check(len(ids)==2400,'total mismatch')
report={'catalogVersion':cat['version'],'activities':len(ids),'sections':dict(counts),'languages':languages,'vectors':len(art),'speechClips':sum(map(len,manifest.values())),'errors':errors,'passed':not errors,'manualReview':'pending; automated validation does not certify educational accuracy or pronunciation'}
(ROOT/'docs/qa/catalog-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2));sys.exit(bool(errors))
