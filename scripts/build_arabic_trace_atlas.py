"""Render all 80 bundled Arabic handwriting guides without playing audio."""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw,ImageFont
from arabic_reshaper import ArabicReshaper
reshape = ArabicReshaper(configuration={"delete_harakat": False, "shift_harakat_position": True}).reshape
from bidi.algorithm import get_display
from arabic_curriculum import bare
ROOT=Path(__file__).resolve().parents[1];DEST=ROOT/'docs/qa/arabic-tracing';DEST.mkdir(parents=True,exist_ok=True)
catalog=json.loads((ROOT/'assets/content/catalog.json').read_text())
traces=[e for e in catalog['activities'] if e['section']=='tracing' and 'locales' in e['config']]
font=ImageFont.truetype(str(ROOT/'assets/fonts/NotoSansArabic.ttf'),36)
label=ImageFont.truetype(str(ROOT/'assets/fonts/Nunito.ttf'),14)
for name,activities,columns in [('isolated',traces[:28],7),('vowels',traces[28:56],7),('words',traces[56:],6)]:
 tile=230;rows=math.ceil(len(activities)/columns);im=Image.new('RGB',(tile*columns,290*rows),'#fbf7ee');d=ImageDraw.Draw(im)
 for i,e in enumerate(activities):
  cfg=e['config']['locales']['ar'];x=i%columns*tile;y=i//columns*290
  d.rounded_rectangle((x+5,y+5,x+tile-5,y+284),radius=14,fill='white')
  d.text((x+12,y+12),e['id'],font=label,fill='#344850')
  heading=get_display(reshape(bare(cfg['glyph'])))
  d.text((x+tile/2,y+48),heading,font=font,anchor='mm',fill='#344850')
  if cfg['arabicLesson']=='fatha':
   box=d.textbbox((x+tile/2,y+48),heading,font=font,anchor='mm')
   d.line([(x+tile/2+5,box[1]-7),(x+tile/2-5,box[1]-3)],fill='#344850',width=2)
  scale=.85;ox=x+22;oy=y+84;w=cfg['guideWidth']*scale
  for step,(path,kind) in enumerate(zip(cfg['strokes'],cfg['strokeKinds'])):
   points=[(ox+px*scale,oy+py*scale) for px,py in path]
   if kind=='dot':
    cx=sum(p[0] for p in points)/len(points);cy=sum(p[1] for p in points)/len(points);rr=w*.58;d.ellipse((cx-rr,cy-rr,cx+rr,cy+rr),fill='#344850')
   else:d.line(points,fill='#344850',width=max(1,round(w)),joint='curve')
   px,py=points[0];d.ellipse((px-4,py-4,px+4,py+4),fill='#e3b34e')
   d.text((px+4,py-13),str(step+1),font=label,fill='#12606a')
  d.text((x+12,y+266),f'{len(cfg["strokes"])} ordered strokes',font=label,fill='#344850')
 im.save(DEST/f'{name}.png')
print('Rendered 80 Arabic tracing guides in three overview sheets')
