"""Authored print manuscript centre lines, ordered pen lifts and uniform layout.

Formation conventions follow the Zaner-Bloser manuscript practice reference.
Coordinates and curves are original; no worksheet artwork or font outlines are used.
"""
from copy import deepcopy
from arabic_handwriting import curve

REVISION = 2

def line(*points):
 return curve(points[0],*[('L',*p) for p in points[1:]])

def oval(left=0,right=110,top=40,bottom=180):
 cx=(left+right)/2;cy=(top+bottom)/2;rx=(right-left)/2;ry=(bottom-top)/2;k=.55228475
 return curve((cx,top),('C',cx-k*rx,top,left,cy-k*ry,left,cy),('C',left,cy+k*ry,cx-k*rx,bottom,cx,bottom),('C',cx+k*rx,bottom,right,cy+k*ry,right,cy),('C',right,cy-k*ry,cx+k*rx,top,cx,top))

def forms():
 c=curve((110,60),('C',90,32,41,31,16,61),('C',-5,83,-5,137,16,159),('C',41,189,90,188,110,160))
 o=oval()
 bowl=curve((0,40),('L',48,40),('C',113,40,113,108,48,108),('L',0,108))
 b=curve((0,40),('L',48,40),('C',108,40,108,108,48,108),('L',0,108),('L',55,108),('C',120,108,120,180,55,180),('L',0,180))
 f={
 'A':[line((60,40),(0,180)),line((60,40),(120,180)),line((26,120),(94,120))],
 'B':[line((0,40),(0,180)),b],
 'C':[c],
 'D':[line((0,40),(0,180)),curve((0,40),('L',35,40),('C',138,40,138,180,35,180),('L',0,180))],
 'E':[line((0,40),(0,180)),line((0,40),(100,40)),line((0,110),(80,110)),line((0,180),(100,180))],
 'F':[line((0,40),(0,180)),line((0,40),(100,40)),line((0,110),(80,110))],
 'G':[curve((110,60),('C',90,32,41,31,16,61),('C',-5,83,-5,137,16,159),('C',41,189,110,190,110,126),('L',66,126))],
 'H':[line((0,40),(0,180)),line((110,40),(110,180)),line((0,110),(110,110))],
 'I':[line((40,40),(40,180)),line((0,40),(80,40)),line((0,180),(80,180))],
 'J':[curve((90,40),('L',90,135),('C',90,193,5,196,0,145)),line((25,40),(115,40))],
 'K':[line((0,40),(0,180)),line((105,40),(0,110),(105,180))],
 'L':[line((0,40),(0,180),(95,180))],
 'M':[line((0,40),(0,180)),line((0,40),(65,130),(130,40),(130,180))],
 'N':[line((0,40),(0,180)),line((0,40),(110,180),(110,40))],
 'O':[o],
 'P':[line((0,40),(0,180)),bowl],
 'Q':[o,line((70,145),(125,195))],
 'R':[line((0,40),(0,180)),curve((0,40),('L',48,40),('C',113,40,113,108,48,108),('L',0,108),('L',48,108),('L',110,180))],
 'S':[curve((105,60),('C',83,30,29,31,10,57),('C',-20,108,122,105,110,150),('C',103,189,29,193,0,162))],
 'T':[line((60,40),(60,180)),line((0,40),(120,40))],
 'U':[curve((0,40),('L',0,127),('C',0,198,110,198,110,127),('L',110,40))],
 'V':[line((0,40),(60,180),(120,40))],
 'W':[line((0,40),(35,180),(80,70),(125,180),(160,40))],
 'X':[line((0,40),(110,180)),line((110,40),(0,180))],
 'Y':[line((0,40),(60,105)),line((120,40),(60,105),(60,180))],
 'Z':[line((0,40),(110,40),(0,180),(110,180))],
 '0':[oval(0,90)],
 '1':[line((0,40),(0,180))],
 '2':[curve((0,70),('C',0,28,90,26,90,68),('C',90,98,48,127,0,180),('L',98,180))],
 '3':[curve((0,45),('C',104,16,111,105,37,110),('C',118,112,114,203,0,175))],
 '4':[line((0,40),(0,125),(100,125)),line((75,40),(75,180))],
 '5':[curve((10,40),('L',10,104),('C',116,74,119,203,0,170)),line((10,40),(100,40))],
 '6':[curve((88,40),('C',58,59,0,107,0,143),('C',0,196,99,196,99,143),('C',99,90,0,100,0,143))],
 '7':[line((0,40),(100,40),(34,180))],
 '8':[curve((50,40),('C',-15,40,-15,86,50,110),('C',121,137,116,180,50,180),('C',-16,180,-21,137,50,110),('C',115,86,115,40,50,40))],
 '9':[curve((95,79),('C',95,24,0,27,0,79),('C',0,133,95,131,95,79),('L',95,180))],
 }
 return f

BASE=forms()
ACCENTS={
 'Ñ':('N','tilde'),'É':('E','acute'),'È':('E','grave'),'Ê':('E','circumflex'),'Ç':('C','cedilla'),
 'Á':('A','acute'),'Ã':('A','tilde'),'Í':('I','acute'),'Ó':('O','acute'),'Õ':('O','tilde'),'Ú':('U','acute'),
}

def letter(glyph):
 base,accent=ACCENTS.get(glyph,(glyph,None));paths=deepcopy(BASE[base]);kinds=['body']*len(paths)
 if accent:
  points=[p for s in paths for p in s];center=(min(p[0] for p in points)+max(p[0] for p in points))/2
  marks={
   'acute':line((center-12,22),(center+12,5)),
   'grave':line((center-12,5),(center+12,22)),
   'circumflex':line((center-20,22),(center,5),(center+20,22)),
   'tilde':curve((center-26,19),('C',center-9,-3,center+9,36,center+26,14)),
   'cedilla':curve((center,180),('L',center-9,193),('C',center+18,190,center+20,210,center-5,209)),
  }
  paths.append(marks[accent]);kinds.append('accent')
 return paths,kinds

def trace(glyphs,legacy):
 paths=[];kinds=[];ranges=[];cursor=0
 for glyph in glyphs:
  local,local_kinds=letter(glyph);xs=[p[0] for s in local for p in s];left=min(xs);width=max(xs)-left
  start=len(paths)
  paths.extend([[[x-left+cursor,y] for x,y in s] for s in local]);kinds.extend(local_kinds)
  ranges.append([start,len(paths)]);cursor+=max(width,20)+30
 points=[p for s in paths for p in s];left=min(p[0] for p in points);right=max(p[0] for p in points);top=min(p[1] for p in points);bottom=max(p[1] for p in points)
 width=right-left;height=bottom-top;scale=min(1,186/max(width,1),174/max(height,1));cx=(left+right)/2;cy=(top+bottom)/2
 return {
  'glyph':' '.join(glyphs) if any(not g.isdigit() for g in glyphs) else ''.join(glyphs),
  'direction':'ltr','strokes':[[[round(110+(x-cx)*scale,3),round(110+(y-cy)*scale,3)] for x,y in s] for s in paths],
  'strokeKinds':kinds,'guideWidth':round(10*scale,3),'traceRevision':REVISION,
  'geometryScale':scale,'preserveAspectRatio':True,'glyphStrokeRanges':ranges,
  'modelWidth':round(max(92,min(280,80*(width+20)/(height+20)))),
  'legacyStrokes':legacy,
 }
