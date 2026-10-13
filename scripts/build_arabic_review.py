#!/usr/bin/env python3
"""Build an offline review packet. No audio is autoplayed or executed."""
import csv, html, json, unicodedata
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from arabic_reshaper import ArabicReshaper
reshape = ArabicReshaper(configuration={"delete_harakat": False, "shift_harakat_position": True}).reshape
from bidi.algorithm import get_display
from review_checklists import write_checklist, render_pronunciation
from review_checklists import clip_hash as source_clip_hash, lesson_hash as source_lesson_hash
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'docs/qa/arabic-review';DEST.mkdir(parents=True,exist_ok=True)
catalog=json.loads((ROOT/'assets/content/catalog.json').read_text())
audio=json.loads((ROOT/'assets/content/audio_manifest.json').read_text())
art=json.loads((ROOT/'assets/content/art.json').read_text())
font=ImageFont.truetype(str(ROOT/'assets/fonts/NotoSansArabic.ttf'),32)
latin=ImageFont.truetype(str(ROOT/'assets/fonts/Nunito.ttf'),16)
traces=[a for a in catalog['activities'] if a['section']=='tracing' and a['config'].get('locales',{}).get('ar',{}).get('arabicLesson')]
for page in range(0,len(traces),8):
    image=Image.new('RGB',(1200,680),'#fbf7ee');draw=ImageDraw.Draw(image)
    for cell,a in enumerate(traces[page:page+8]):
        cfg=a['config']['locales']['ar'];left=(cell%4)*300;top=(cell//4)*340
        draw.rounded_rectangle((left+10,top+10,left+290,top+330),radius=15,fill='white')
        draw.text((left+20,top+15),a['id'],font=latin,fill='#344850')
        heading=get_display(reshape(''.join(c for c in cfg['glyph'] if not unicodedata.combining(c))))
        draw.text((left+150,top+75),heading,font=font,anchor='mm',fill='#344850')
        if cfg['arabicLesson']=='fatha':
            box=draw.textbbox((left+150,top+75),heading,font=font,anchor='mm')
            draw.line([(left+155,box[1]-7),(left+145,box[1]-3)],fill='#344850',width=2)
        for s,path in enumerate(cfg['strokes']):
            points=[(left+40+x,top+106+y) for x,y in path]
            draw.line(points,fill='#328e9d',width=max(1,round(cfg.get('guideWidth',9))),joint='curve')
            x,y=points[0];draw.ellipse((x-4,y-4,x+4,y+4),fill='#f3c65f')
        draw.text((left+20,top+302),cfg['arabicLesson'],font=latin,fill='#667582')
    image.save(DEST/f'traces-{page+1:02}-{min(page+8,len(traces)):02}.png')

def clip_hash(lang,filename):
    return source_clip_hash(ROOT,lang,filename)
cards=[]
for a in catalog['activities']:
    if a['section'] not in ['letters','tracing']:continue
    cfg=a['config'].get('locales',{}).get('ar')
    if not cfg or 'arabicLesson' not in cfg:continue
    cue=a['cue']['ar'];text=audio['ar'][cue]
    display=cfg.get('display') or cfg.get('glyph') or cfg.get('visualCue','')
    choices=' · '.join(o['value'] for o in cfg.get('options',[]))
    question=cfg.get('question',{}).get('ar','')
    cards.append(f'<article><small>{a["id"]} · {html.escape(cfg["arabicLesson"])}</small><p dir="rtl">{html.escape(question)}</p><p dir="rtl">{html.escape(display)}</p><p dir="rtl">{html.escape(choices)}</p><p dir="rtl">{html.escape(text)}</p><audio controls preload="none" src="../../../assets/audio/ar/{cue}?v={clip_hash("ar",cue)}"></audio></article>')
def lesson_hash(activity,lang):
    return source_lesson_hash(activity,lang,art)
write_checklist(DEST/'narration-review.csv',
    ['locale','file','script','approved','reviewer','date','notes','sourceSha256'],
    ([lang,filename,text,'','','','',clip_hash(lang,filename)]
     for lang,files in audio.items() for filename,text in files.items()), ['locale','file'])
write_checklist(DEST/'activity-review.csv',
    ['activityId','locale','approved','reviewer','date','notes','sourceSha256'],
    ([a['id'],lang,'','','','',lesson_hash(a,lang)]
     for a in catalog['activities'] for lang in catalog['languages']), ['activityId','locale'])
write_checklist(DEST/'arabic-narration-review.csv',
    ['file','script','approved','reviewer','date','notes','sourceSha256'],
    ([filename,text,'','','','',clip_hash('ar',filename)]
     for filename,text in audio['ar'].items()), ['file'])
write_checklist(DEST/'arabic-lesson-review.csv',
    ['activityId','lesson','questionArabic','display','correctChoice','approved','reviewer','date','notes','sourceSha256'],
    ([a['id'],cfg['arabicLesson'],cfg.get('question',{}).get('ar',''),cfg.get('display',cfg.get('glyph','')),
      cfg.get('correct',''),'','','','',lesson_hash(a,'ar')]
     for a in catalog['activities']
     if (cfg:=a['config'].get('locales',{}).get('ar',{})).get('arabicLesson')), ['activityId'])
body=''.join(f'<img src="{p.name}" alt="Arabic stroke review {p.stem}">' for p in sorted(DEST.glob('traces-*.png')))
def category(filename):
    if filename.startswith('letter_') or filename in ['lam_alif.mp3','long_alif.mp3']:return 'letters'
    if filename.startswith('syllable_'):return 'syllables'
    if filename.startswith('trace_word_'):return 'tracing'
    if filename.startswith('word_'):return 'words'
    return 'instructions'
labels={'letters':'Letters and long vowels','syllables':'Short vowel sounds',
        'words':'Vocabulary','tracing':'Handwriting words','instructions':'Instructions and feedback'}
def order(item):
    filename,_=item;group=category(filename)
    rank=int(filename.rsplit('_',1)[-1].split('.')[0]) if group in ['letters','syllables','tracing'] and filename.rsplit('_',1)[-1].split('.')[0].isdigit() else 1000
    return list(labels).index(group),rank,filename
reviews={r['file']:r for r in csv.DictReader((DEST/'arabic-narration-review.csv').open())}
recordings=[];review_data=[]
for index,(filename,text) in enumerate(sorted(audio['ar'].items(),key=order)):
    group=category(filename);escaped=html.escape(filename);source_hash=clip_hash('ar',filename)
    row={'file':filename,'text':text,'category':group,'sha256':source_hash,
         'activityIds':[a['id'] for a in catalog['activities'] if a.get('cue',{}).get('ar')==filename or a.get('audio')==filename]}
    review=reviews[filename]
    rejected=review['approved'].lower() in ['no','false','incorrect']
    if rejected or review['notes']:
        row['initialReview']={'flagged':rejected,'notes':review['notes'],'sha256':review['sourceSha256']}
    review_data.append(row)
    recordings.append(f'''<article class="recording" data-file="{escaped}">
<div class="file-name">{escaped}</div><div class="category">{labels[group]}</div>
<p class="script{' short' if len(text)<12 else ''}" lang="ar" dir="rtl">{html.escape(text)}</p>
<audio controls preload="none" aria-label="Listen to {escaped}" src="../../../assets/audio/ar/{escaped}?v={source_hash}"></audio>
<label class="flag-control"><input type="checkbox" data-flag aria-label="Wrong pronunciation: {escaped}">Wrong pronunciation</label>
<p class="updated" data-updated hidden>Recording updated. Your previous note is retained; listen and select again if needed.</p>
<div data-note-container hidden><label class="note-label" for="note-{index}">Correction or what sounds wrong (optional)</label>
<textarea id="note-{index}" data-note maxlength="5000" dir="auto" placeholder="Arabic, vowel marks or transliteration"></textarea></div></article>''')
previews=''
for path,caption in [
    ('ios-phone/en-ui-ar-learn-letters-0030.png','English questions with Arabic letter forms'),
    ('ios-tablet/ar-ui-es-learn-vocabulary.png','Arabic controls with Spanish vocabulary'),
]:
    if (DEST/path).is_file():
        previews+=f'<figure><figcaption>{caption}</figcaption><img style="max-height:680px;width:auto" src="{path}" alt="{caption}"></figure>'
template=(ROOT/'scripts/templates/arabic_review.html').read_text()
data={'catalogVersion':catalog['version'],'recordings':review_data,'locale':'ar','localeName':'Arabic',
      'storageKey':'pikolumi-arabic-pronunciation-review-v1','exportName':'pikolumi-arabic-corrections.json'}
lesson_content='<h2>Separate interface and learning languages</h2>'+previews+'<h2>Stroke sheets</h2>'+body+'<h2>Interactive lesson scripts</h2><div class="lesson-grid">'+''.join(cards)+'</div>'
page=render_pronunciation(template,data,''.join(recordings),lesson_content)
(DEST/'index.html').write_text(page)
print(f'Wrote {len(cards)} Arabic lesson cards and {sum(map(len,audio.values()))} narration review rows: {DEST}')
