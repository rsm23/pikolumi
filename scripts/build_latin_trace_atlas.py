"""Silent overview of every Latin and numeral guide, with numbered starts."""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];DEST=ROOT/'docs/qa/latin-tracing';DEST.mkdir(parents=True,exist_ok=True)
catalog=json.loads((ROOT/'assets/content/catalog.json').read_text());traces=[e for e in catalog['activities'] if e['section']=='tracing']
label=ImageFont.truetype(str(ROOT/'assets/fonts/Nunito.ttf'),14)
heading=ImageFont.truetype(str(ROOT/'assets/fonts/Nunito.ttf'),23)
for lang in ['en','fr','es','pt','numbers']:
 rows=traces[80:120] if lang=='numbers' else traces[:80];cols=8;tile=230;h=260
 im=Image.new('RGB',(tile*cols,h*math.ceil(len(rows)/cols)),'#fbf7ee');d=ImageDraw.Draw(im)
 for i,e in enumerate(rows):
  cfg=e['config'] if lang=='numbers' else e['config']['locales'][lang];x=i%cols*tile;y=i//cols*h
  d.rounded_rectangle((x+4,y+4,x+tile-4,y+h-4),radius=12,fill='white')
  d.text((x+12,y+8),e['id'],font=label,fill='#344850');d.text((x+tile/2,y+38),cfg['glyph'],font=heading,anchor='mm',fill='#344850')
  scale=.81;ox=x+26;oy=y+54;w=cfg['guideWidth']*scale
  for step,path in enumerate(cfg['strokes']):
   pts=[(ox+px*scale,oy+py*scale) for px,py in path];d.line(pts,fill='#344850',width=max(1,round(w)),joint='curve')
   for px,py in (pts[0],pts[-1]):d.ellipse((px-w/2,py-w/2,px+w/2,py+w/2),fill='#344850')
   px,py=pts[0];d.ellipse((px-3,py-3,px+3,py+3),fill='#e3b34e');d.text((px+4,py-12),str(step+1),font=label,fill='#12606a')
  d.text((x+12,y+h-24),f'{len(cfg["strokes"])} strokes',font=label,fill='#344850')
 im.save(DEST/f'{lang}.png')
(DEST/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Pikolumi · Trace & Write review</title><style>body{font:18px system-ui;background:#fbf7ee;color:#344850;margin:24px;max-width:1600px}img{width:100%;background:white}a{color:#12606a}nav{display:flex;gap:20px;flex-wrap:wrap}section{margin-top:40px}</style><h1>Trace & Write: English, French, Spanish and Portuguese</h1><p>All 320 letter and sequence guides, plus 40 numerals. The app model and canvas use these same centre lines. Gold dots and numbers mark pen starts in order. Open a sheet to inspect it at full size.</p><nav>'''+''.join(f'<a href="#{lang}">{name}</a>' for lang,name in [('en','English'),('fr','French'),('es','Spanish'),('pt','Portuguese'),('numbers','Numerals')])+'''</nav><p>These are print manuscript guides, not cursive. Schools may teach other valid formation conventions. Original paths use consistent manuscript pen order, natural widths, a common baseline and uniform scale. Accents follow each letter’s body.</p><p>Native Android examples: <a href="android-emulator/fr-tracing-0057.png">French accents</a> · <a href="android-emulator/es-tracing-0041.png">Spanish letters with Arabic instructions</a> · <a href="android-emulator/landscape-fr-ui-pt-learning.png">Portuguese model with French instructions in landscape</a>.</p>'''+''.join(f'<section id="{lang}"><h2>{name}</h2><a href="{lang}.png"><img src="{lang}.png" alt="{name} tracing guides with numbered starts"></a></section>' for lang,name in [('en','English'),('fr','French'),('es','Spanish'),('pt','Portuguese'),('numbers','Numerals')])+'''<p>Formation reference: <a href="https://media.zaner-bloser.com/handwriting/pdfs/ZB_HW_Manuscript_Practice_Package.pdf">Zaner-Bloser manuscript practice package, formation pages 113–116</a>. Reference artwork is not bundled in the app.</p></html>''')
print('Rendered 320 Latin guides and 40 numerals')
