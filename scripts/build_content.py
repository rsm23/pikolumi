#!/usr/bin/env python3
"""Compile the finite offline curriculum. Randomness is only used to author fixed maze layouts."""
import json, math, hashlib, random, collections
from pathlib import Path
from content_source import *
from illustrations import motif, scene, puzzle_scene, shape_icon, transformed
import arabic_curriculum as arabic
import latin_handwriting as latin
ROOT=Path(__file__).resolve().parents[1]
ART={}
for row in WORDS:
 ART[row[0]]={'width':200,'height':200,'revision':3,'strokeWidth':2.5,'shapes':motif(row[0])}
for shape in SHAPES:
 for color,(hexcode,_) in COLORS.items(): ART[f'{shape}_{color}']=shape_icon(shape,hexcode)
for i,row in enumerate(WORDS[:30]):
 for variant in range(12): ART[f'scene_{i}_{variant}']=scene(row[0],variant)

# Retain the original geometry for migrating existing v1 tracing checkpoints.
LATIN_STROKES={
'A':[[[35,160],[100,30],[165,160]],[[65,110],[135,110]]], 'B':[[[45,160],[45,30],[110,30],[153,50],[110,92],[45,92]],[[110,92],[160,116],[150,145],[110,160],[45,160]]],
'C':[[[159,50],[128,28],[68,35],[36,73],[35,119],[66,159],[128,164],[161,143]]], 'D':[[[44,160],[44,30],[105,30],[153,65],[166,104],[143,147],[105,160],[44,160]]],
'E':[[[162,30],[43,30],[43,160],[162,160]],[[43,93],[134,93]]], 'F':[[[43,160],[43,30],[163,30]],[[43,93],[136,93]]],
'G':[[[160,50],[129,28],[66,37],[34,78],[35,121],[67,160],[127,162],[164,134],[164,102],[111,102]]], 'H':[[[40,30],[40,160]],[[160,30],[160,160]],[[40,96],[160,96]]],
'I':[[[50,30],[150,30]],[[100,30],[100,160]],[[50,160],[150,160]]], 'J':[[[55,30],[151,30]],[[135,30],[135,129],[122,153],[83,165],[53,153],[39,130]]],
'K':[[[45,30],[45,160]],[[156,30],[45,99],[159,160]]], 'L':[[[45,30],[45,160],[162,160]]], 'M':[[[30,160],[30,30],[100,110],[170,30],[170,160]]],
'N':[[[40,160],[40,30],[160,160],[160,30]]], 'O':[[[100,28],[55,44],[32,87],[38,131],[64,160],[110,166],[153,142],[168,99],[153,51],[100,28]]],
'P':[[[45,160],[45,30],[114,30],[157,54],[154,88],[113,104],[45,104]]], 'Q':[[[100,28],[55,44],[32,87],[38,131],[64,160],[110,166],[153,142],[168,99],[153,51],[100,28]],[[117,123],[177,178]]],
'R':[[[45,160],[45,30],[114,30],[157,54],[154,88],[113,104],[45,104]],[[102,104],[165,160]]], 'S':[[[155,49],[124,29],[76,29],[43,55],[49,84],[132,105],[158,132],[138,158],[78,167],[43,149]]],
'T':[[[30,30],[170,30]],[[100,30],[100,160]]], 'U':[[[37,30],[37,121],[55,151],[100,168],[145,151],[163,121],[163,30]]],
'V':[[[30,30],[100,166],[170,30]]], 'W':[[[20,30],[54,164],[100,69],[145,164],[180,30]]], 'X':[[[35,30],[165,160]],[[165,30],[35,160]]],
'Y':[[[30,30],[100,95],[170,30]],[[100,95],[100,160]]], 'Z':[[[35,30],[165,30],[35,160],[165,160]]],
'0':[[[100,30],[62,46],[44,95],[58,146],[100,169],[141,146],[159,95],[141,46],[100,30]]], '1':[[[67,59],[107,29],[107,165]]],
'2':[[[42,58],[70,29],[119,28],[157,57],[149,86],[44,164],[166,164]]], '3':[[[44,39],[103,27],[150,45],[148,70],[107,95],[151,117],[154,141],[114,166],[45,155]]],
'4':[[[132,30],[40,123],[167,123]],[[132,30],[132,166]]], '5':[[[162,30],[52,30],[49,93],[110,88],[152,107],[160,139],[130,163],[75,167],[44,152]]],
'6':[[[146,36],[103,28],[60,55],[37,111],[47,152],[93,173],[139,155],[159,120],[134,95],[85,95],[47,120]]],
'7':[[[34,30],[167,30],[84,166]]], '8':[[[102,95],[52,65],[62,34],[103,26],[145,35],[153,65],[102,95],[46,123],[52,153],[100,174],[149,153],[159,121],[102,95]]],
'9':[[[152,100],[97,104],[49,80],[47,49],[94,25],[137,35],[160,79],[152,130],[123,163],[73,169]]]
}
ARABIC=list('ابتثجحخدذرزسشصضطظعغفقكلمنهوي')
ARABIC_NAMES=['ألف','باء','تاء','ثاء','جيم','حاء','خاء','دال','ذال','راء','زاي','سين','شين','صاد','ضاد','طاء','ظاء','عين','غين','فاء','قاف','كاف','لام','ميم','نون','هاء','واو','ياء']
ALPHABETS={lang:list('ABCDEFGHIJKLMNÑOPQRSTUVWXYZ' if lang=='es' else 'ABCDEFGHIJKLMNOPQRSTUVWXYZ') for lang in LANGS if lang!='ar'}
ALPHABETS['ar']=ARABIC
TRACE_ALPHABETS={**ALPHABETS,'fr':list('ABCDEFGHIJKLMNOPQRSTUVWXYZÉÈÊÇ'),'pt':list('ABCDEFGHIJKLMNOPQRSTUVWXYZÁÃÇÉÊÍÓÕÚ')}
for glyph,base,marks in [
 ('Ñ','N',[[[65,15],[83,8],[110,19],[130,12]]]),
 ('É','E',[[[88,15],[117,4]]]),('È','E',[[[88,4],[117,15]]]),('Ê','E',[[[78,17],[101,4],[124,17]]]),
 ('Ç','C',[[[100,167],[90,184],[110,191],[119,181]]]),
 ('Á','A',[[[88,15],[117,4]]]),('Ã','A',[[[65,15],[83,8],[110,19],[130,12]]]),
 ('Í','I',[[[88,15],[117,4]]]),('Ó','O',[[[88,15],[117,4]]]),
 ('Õ','O',[[[65,15],[83,8],[110,19],[130,12]]]),('Ú','U',[[[88,15],[117,4]]])]:
 LATIN_STROKES[glyph]=LATIN_STROKES[base]+marks
# Isolated, right-to-left letter skeletons; dots form their own numbered strokes.
AR_STROKES={
'ا':[[[112,30],[112,164]]], 'ب':[[[168,92],[163,143],[126,157],[75,158],[38,141],[31,93]],[[97,183],[103,183]]],
'ت':[[[168,92],[163,143],[126,157],[75,158],[38,141],[31,93]],[[87,66],[93,66]],[[115,66],[121,66]]],
'ث':[[[168,92],[163,143],[126,157],[75,158],[38,141],[31,93]],[[87,66],[93,66]],[[115,66],[121,66]],[[101,43],[107,43]]],
'ج':[[[159,65],[119,44],[71,66],[151,96],[84,104],[45,139],[52,172],[95,187],[152,179]],[[98,145],[104,145]]],
'ح':[[[159,65],[119,44],[71,66],[151,96],[84,104],[45,139],[52,172],[95,187],[152,179]]],
'خ':[[[159,65],[119,44],[71,66],[151,96],[84,104],[45,139],[52,172],[95,187],[152,179]],[[115,22],[121,22]]],
'د':[[[102,65],[154,116],[139,143],[59,145]]], 'ذ':[[[102,65],[154,116],[139,143],[59,145]],[[112,32],[118,32]]],
'ر':[[[145,70],[159,121],[137,160],[92,184],[43,181]]], 'ز':[[[145,70],[159,121],[137,160],[92,184],[43,181]],[[144,36],[150,36]]],
'س':[[[173,79],[168,124],[148,129],[133,93],[125,129],[104,132],[90,97],[79,151],[57,173],[29,166],[22,131]]],
'ش':[[[173,79],[168,124],[148,129],[133,93],[125,129],[104,132],[90,97],[79,151],[57,173],[29,166],[22,131]],[[112,57],[118,57]],[[146,57],[152,57]],[[131,32],[137,32]]],
'ص':[[[76,117],[119,70],[161,69],[178,98],[167,125],[79,127],[67,161],[43,174],[22,153],[21,121]]],
'ض':[[[76,117],[119,70],[161,69],[178,98],[167,125],[79,127],[67,161],[43,174],[22,153],[21,121]],[[144,39],[150,39]]],
'ط':[[[93,129],[92,24]],[[51,131],[121,72],[162,76],[173,107],[155,129],[51,131]]],
'ظ':[[[93,129],[92,24]],[[51,131],[121,72],[162,76],[173,107],[155,129],[51,131]],[[143,40],[149,40]]],
'ع':[[[144,72],[115,52],[86,73],[118,96],[156,96],[66,120],[45,153],[66,182],[126,185],[157,171]]],
'غ':[[[144,72],[115,52],[86,73],[118,96],[156,96],[66,120],[45,153],[66,182],[126,185],[157,171]],[[118,24],[124,24]]],
'ف':[[[153,99],[126,82],[134,57],[161,62],[173,96],[164,138],[125,155],[71,155],[35,140],[29,105]],[[148,26],[154,26]]],
'ق':[[[153,99],[126,82],[134,57],[161,62],[173,96],[164,153],[128,182],[77,183],[37,161],[32,120]],[[138,26],[144,26]],[[160,26],[166,26]]],
'ك':[[[165,27],[165,153],[56,156],[35,137],[35,105]],[[126,68],[103,81],[121,91],[88,110]]],
'ل':[[[148,29],[148,142],[126,174],[80,181],[45,160],[40,119]]],
'م':[[[152,106],[142,76],[116,79],[103,100],[121,116],[150,106],[72,121],[60,182]]],
'ن':[[[165,98],[166,139],[139,173],[90,184],[45,167],[33,128],[38,103]],[[99,67],[105,67]]],
'ه':[[[145,99],[134,70],[107,61],[75,75],[59,105],[65,138],[94,157],[126,150],[145,129],[145,99]]],
'و':[[[148,102],[156,69],[133,51],[106,71],[109,98],[148,102],[151,135],[112,174],[52,182]]],
'ي':[[[150,71],[172,88],[170,111],[125,132],[165,155],[135,184],[81,187],[39,167],[28,122]],[[88,205],[94,205]],[[117,205],[123,205]]]
}

def eq_opts(answer,other):
 vals=[answer]+[v for v in other if v!=answer]
 vals=list(dict.fromkeys(str(v) for v in vals))[:4]
 while len(vals)<4:
  v=str(int(answer)+len(vals)+5) if str(answer).lstrip('-').isdigit() else str(len(vals))
  if v not in vals: vals.append(v)
 return [{'value':v,'label':l(v,v,v,v,v)} for v in vals]

OBJECTIVES={
'coloring':'Practice purposeful color choices and fine motor coordination within closed regions.',
'drawing':'Break a subject into simple shapes and recreate it with directed drawing steps.',
'tracing':'Follow ordered strokes to form the shown letters, numerals or motor-skill trail.',
'letters':'Recognize spoken letter names, match letter cases or contextual forms, and complete alphabet sequences.',
'words':'Connect pictures and spoken vocabulary to written words, then assemble their spelling.',
'counting':'Use one-to-one correspondence to identify the cardinality of a pictured set.',
'math':'Solve the stated addition, subtraction, multiplication, division or half-of quantity.',
'shapes':'Identify a shape, identify its color, or count a set of shapes.',
'sorting':'Classify the presented objects by semantic category, color or shape.',
'memory':'Remember picture locations and match every pair in the given deck.',
'jigsaw':'Reconstruct a scene by arranging every tile in its original position.',
'patterns':'Infer a numeric step or repeating picture rule and choose its continuation.',
'mazes':'Plan a legal route from the bird to the goal through the given maze.',
'nature':'Classify objects, identify animal features and answer foundational science questions.',
'everyday':'Read an analog clock, reason about elapsed hours or apply a familiar daily-life rule.',
'music':'Listen to a melody and reproduce its ordered notes on the keyboard.'}
entries=[]
def add(sec,engine,cfg,title=None,stage=0,preview=None,cue=None):
 n=sum(e['section']==sec for e in entries)+1
 entry={'id':f'{sec}-{n:04}','section':sec,'engine':engine,'stage':stage,'objective':OBJECTIVES[sec],'title':title or PROMPTS[sec],'instructions':PROMPTS[sec], 'audio':f'{sec}.mp3','config':cfg}
 if preview: entry['preview']=preview
 if cue: entry['cue']=cue
 entries.append(entry)

def word_options(index):
 ids=[index,(index+7)%60,(index+19)%60,(index+31)%60]
 return [{'value':WORDS[i][0],'label':WORD_MAP[WORDS[i][0]],'art':WORDS[i][0]} for i in ids]

for i,row in enumerate(WORDS[:30]):
 for v in range(12):
  title={lang:f'{WORD_MAP[row[0]][lang]} · {v+1}' for lang in LANGS}
  add('coloring','canvas',{'scene':f'scene_{i}_{v}','mode':'coloring'},title,min(4,v//3),f'scene_{i}_{v}')
for i,row in enumerate(WORDS[:30]):
 for v in range(4):
  add('drawing','canvas',{'scene':row[0] if v==0 else f'scene_{i}_{[0,0,4,8][v]}','mode':'drawing','guide':0},WORD_MAP[row[0]],v,row[0])
# Single letters, ordered letter sequences and two-digit numerals are distinct motor tasks.
def sequence_strokes(glyphs,source,rtl=False):
 out=[];count=len(glyphs)
 for j,glyph in enumerate(glyphs):
  pos=count-1-j if rtl else j
  for stroke in source[glyph]:
   out.append([[round((x-10)*.86/count+10+pos*200/count,2),round(y*.82+12,2)] for x,y in stroke])
 return out
for i in range(80):
 cfg={};titles={};cues={}
 for lang in LANGS:
  alphabet=TRACE_ALPHABETS[lang]
  j=i%len(alphabet); mode=i//len(alphabet)
  glyphs=[alphabet[(j+k)%len(alphabet)] for k in range(mode+1)]
  cfg[lang]={'glyph':' '.join(glyphs),'strokes':sequence_strokes(glyphs,AR_STROKES if lang=='ar' else LATIN_STROKES,lang=='ar'),'direction':'rtl' if lang=='ar' else 'ltr'}
  if lang != 'ar':
   cfg[lang]=latin.trace(glyphs,cfg[lang]['strokes'])
  titles[lang]=' '.join(glyphs)
  cues[lang]=f'letter_{i%len(TRACE_ALPHABETS[lang])}.mp3'
 cfg['ar'],cues['ar']=arabic.tracing(i,AR_STROKES,sequence_strokes)
 titles['ar']=cfg['ar']['glyph']
 add('tracing','trace',{'locales':cfg},titles,min(2,i//28),cue=cues)
for i in range(40):
 digits=str(i)
 add('tracing','trace',latin.trace(list(digits),sequence_strokes(list(digits),LATIN_STROKES)),l(digits,digits,digits,digits,digits),0 if i<10 else 1)
for i in range(40):
 kind=i%5; phase=i//5; points=[]
 for k in range(25):
  t=k/24
  if kind==0: x=20+t*160; y=100+math.sin(t*math.pi*(2+phase*.35))*(25+phase*3)
  elif kind==1: x=100+math.cos(t*math.pi*2)*(40+phase*4); y=100+math.sin(t*math.pi*2)*(40+phase*4)
  elif kind==2: x=20+t*160; y=35+phase*3+(k%6)*(13+phase)
  elif kind==3: x=100+math.cos(t*math.pi*4)*(12+t*(50+phase*2)); y=100+math.sin(t*math.pi*4)*(12+t*(50+phase*2))
  else: x=20+t*160; y=100+math.sin(t*math.pi)*(-40-phase*3)
  points.append([round(x,2),round(y,2)])
 add('tracing','trace',{'glyph':'','strokes':[points]},stage=min(4,i//10))
for i in range(160):
 cfg={};title={};cue={}
 for lang in LANGS:
  alphabet=ALPHABETS[lang]
  j=i%len(alphabet); letter=alphabet[j];mode=i//len(alphabet)
  target=letter;display=letter;spoken=False
  question=l('Find the letter','Trouve la lettre','Busca la letra','Encontre a letra','ابحث عن الحرف')
  if mode==0: spoken=True
  elif mode==1: display=letter+'\u200d' if lang=='ar' else letter.lower()
  elif mode==2:
   display='\u200d'+letter if lang=='ar' else letter
   if lang!='ar':target=letter.lower()
  elif mode==3:
   display=f'{letter}   ?';target=alphabet[(j+1)%len(alphabet)]
   question=l('Which letter comes next?','Quelle lettre vient après ?','¿Qué letra sigue?','Qual letra vem depois?','أي حرف يأتي بعده؟')
  elif mode==4:
   display=f'?   {letter}';target=alphabet[(j-1)%len(alphabet)]
   question=l('Which letter comes before?','Quelle lettre vient avant ?','¿Qué letra viene antes?','Qual letra vem antes?','أي حرف يأتي قبله؟')
  elif mode==6:
   display=f'{letter}   {alphabet[(j+1)%len(alphabet)]}   ?';target=alphabet[(j+2)%len(alphabet)]
   question=l('Complete the sequence','Complète la suite','Completa la secuencia','Complete a sequência','أكمل التسلسل')
  else:
   display=f'{letter}   ?   {alphabet[(j+2)%len(alphabet)]}';target=alphabet[(j+1)%len(alphabet)]
   question=l('Find the missing letter','Trouve la lettre manquante','Busca la letra que falta','Encontre a letra que falta','ابحث عن الحرف الناقص')
  target_index=alphabet.index(target if lang=='ar' else target.upper())
  indices=[target_index]+[(target_index+k)%len(alphabet) for k in [5,11,17]]
  options=[{'value':alphabet[k].lower() if mode==2 and lang!='ar' else alphabet[k],'label':l(*([alphabet[k].lower() if mode==2 and lang!='ar' else alphabet[k]]*5))} for k in indices]
  cfg[lang]={'question':question,'display':display,'spokenOnly':spoken,'visualCue':target,'correct':target,'options':options,'direction':'rtl' if lang=='ar' else 'ltr'}
  title[lang]=f'{letter} · {mode+1}';cue[lang]=f'letter_{target_index}.mp3'
 ar=arabic.lesson(i)
 ar_questions={
  'name':l('Listen to the letter name and choose it.','Écoute le nom de la lettre et choisis-la.','Escucha el nombre de la letra y elígela.','Escute o nome da letra e escolha-a.',ar['question']),
  'forms':l('Which letter do these forms show?','Quelle lettre reconnais-tu dans ces formes ?','¿Qué letra muestran estas formas?','Qual letra aparece nestas formas?',ar['question']),
  'medial':l('Which letter is in the middle of this group?','Quelle lettre est au milieu de ce groupe ?','¿Qué letra está en medio de este grupo?','Qual letra está no meio deste grupo?',ar['question']),
  'ligature':l('Choose lam and alif joined together.','Choisis le lam et l’alif liés.','Elige lam y alif unidas.','Escolha lam e alif ligadas.',ar['question']),
  'short-vowel':l('Listen to the letter with its short vowel, then choose it.','Écoute la lettre avec sa voyelle courte, puis choisis-la.','Escucha la letra con su vocal corta y elígela.','Escute a letra com sua vogal curta e escolha-a.',ar['question']),
 }
 cfg['ar']={'question':ar_questions[ar['kind']],'display':ar['display'],'spokenOnly':ar['spokenOnly'],
            'visualCue':ar['target'],'correct':ar['target'],'options':[{'value':v,'label':l(*([v]*5))} for v in ar['choices']],
            'direction':'rtl','arabicLesson':ar['kind']}
 if ar['kind']=='short-vowel':cfg['ar'].update(consonant=ar['consonant'],vowel=ar['vowel'])
 title['ar']=ar['target'];cue['ar']=ar['cue']
 add('letters','quiz',{'locales':cfg},title,min(3,i//40),cue=cue)
for i,row in enumerate(WORDS):
 for mode in range(3):
  cfg={'subject':row[0],'lesson':mode,'options':word_options(i),'correct':row[0]}
  if mode==1: cfg.update(spokenOnly=True,visualCue=WORD_MAP[row[0]])
  if mode==2: cfg={'locales':{lang:{'word':WORD_MAP[row[0]][lang],'subject':row[0]} for lang in LANGS}}
  add('words','sequence' if mode==2 else 'quiz',cfg,WORD_MAP[row[0]],mode,row[0],{lang:f'word_{row[0]}.mp3' for lang in LANGS})
for i in range(160):
 n=i%40+1; subject=WORDS[(i//40)*7][0]
 add('counting','quiz',{'count':n,'subject':subject,'display':'','correct':str(n),'options':eq_opts(n,[n+1,max(0,n-1),n+2])},stage=min(3,(n-1)//10),preview=subject)
for i in range(220):
 if i<50: a=i%10; b=i//10; op='+'; ans=a+b; stage=1
 elif i<100: j=i-50; b=j//10; a=j%10+b; op='−'; ans=a-b; stage=2
 elif i<150: j=i-100; a=j%10+1; b=j//10+1; op='×'; ans=a*b; stage=3
 elif i<200: j=i-150; b=j%10+1; ans=j//10+1; a=b*ans; op='÷'; stage=3
 else: a=(i-199)*2; b=2; op='÷'; ans=a//2; stage=4
 cfg={'display':f'{a} {op} {b} = ?','correct':str(ans),'options':eq_opts(ans,[ans+1,ans+3,max(0,ans-1)]),'a':a,'b':b,'operation':op,'fraction':i>=200}
 if i>=200: cfg['display']=f'½ × {a} = ?'
 add('math','quiz',cfg,stage=stage)
for i in range(120):
 shape=list(SHAPES)[i%6]; color=list(COLORS)[(i//6)%6]; art=f'{shape}_{color}'
 mode=i//36
 if mode==0:
  options=[{'value':v,'label':SHAPES[v],'art':f'{v}_{color}'} for v in list(SHAPES) if v!=shape][:3]+[{'value':shape,'label':SHAPES[shape],'art':art}]
  cfg={'subject':art,'correct':shape,'options':options,'lesson':'shape'}
 elif mode==1:
  cfg={'subject':art,'correct':color,'options':[{'value':v,'label':COLORS[v][1],'color':COLORS[v][0]} for v in [color]+[c for c in COLORS if c!=color][:3]],'lesson':'color'}
 else:
  n=(i-72)//6+2
  cfg={'count':n,'subject':art,'correct':str(n),'options':eq_opts(n,[n+1,n+2,max(0,n-1)]),'lesson':'shapeCount','targetShape':shape}
 add('shapes','quiz',cfg,stage=min(3,mode),preview=art)
for i in range(120):
 mode=i//40;j=i%40
 if mode==0:
  ga=list(GROUPS)[j%6];gb=list(GROUPS)[(j%6+1+j//6)%6]
  if ga==gb:gb=list(GROUPS)[(j%6+1)%6]
  pool=[r for r in WORDS if r[5] in [ga,gb]]
  rng=random.Random(779+i);selected=rng.sample(pool,min(len(pool),4+j//12))
  cfg={'groups':[{'value':g,'label':GROUPS[g]} for g in [ga,gb]],'items':[{'value':r[0],'art':r[0],'target':r[5]} for r in selected]}
 else:
  ca=list(COLORS)[j%6];cb=list(COLORS)[(j%6+1+j//6)%6]
  if ca==cb:cb=list(COLORS)[(j%6+1)%6]
  sa=list(SHAPES)[j%6];sb=list(SHAPES)[(j%6+1+j//6)%6]
  if sa==sb:sb=list(SHAPES)[(j%6+1)%6]
  groups=[ca,cb] if mode==1 else [sa,sb]
  cfg={'groups':[{'value':g,'label':COLORS[g][1],'color':COLORS[g][0]} if mode==1 else {'value':g,'label':SHAPES[g]} for g in groups],'items':[]}
  pool=[(sh,co) for sh in SHAPES for co in COLORS if (co if mode==1 else sh) in groups]
  selected=random.Random(991+i).sample(pool,4+j//10)
  cfg['items']=[{'value':f'{sh}_{co}','art':f'{sh}_{co}','target':co if mode==1 else sh} for sh,co in selected]
 add('sorting','sort',cfg,stage=mode)
for i in range(100):
 pairs=[r[0] for r in random.Random(650+i).sample(WORDS,[3,4,6,8,10][i//20])]
 add('memory','memory',{'pairs':pairs,'layout':i},stage=i//20,preview=pairs[0])
for i in range(120):
 n=2+i//30; sid=f'puzzle_{i:03}'
 ART[sid]=puzzle_scene(WORDS[i%30][0],i//30)
 add('jigsaw','jigsaw',{'scene':sid,'size':n,'legacyScene':f'scene_{i%30}_{(i//30)*3}'},
     {lang:f'{WORD_MAP[WORDS[i%30][0]][lang]} · {n}×{n}' for lang in LANGS},stage=i//30,preview=sid)
for i in range(160):
 if i<80:
  a=i%16+1; delta=i//16+1; seq=[str(a+k*delta) for k in range(4)]; target=a+4*delta
  cfg={'display':'  '.join(seq)+'  ?','correct':str(target),'options':eq_opts(target,[target+1,target-1,target+delta+2]),'rule':{'start':a,'delta':delta}}
 else:
  j=i-80; length=2+j//20; offset=j%20
  pattern=[WORDS[(offset*2+k*11)%60][0] for k in range(length)]
  shown=(pattern*3)[:length+3]; target=pattern[(length+3)%length]
  candidates=[target]+[WORDS[(offset*2+23+k*9)%60][0] for k in range(3)]
  candidates=list(dict.fromkeys(candidates))
  cfg={'pictures':shown,'correct':target,'options':[{'value':k,'label':WORD_MAP[k],'art':k} for k in candidates],'pattern':pattern}
 add('patterns','quiz',cfg,stage=min(4,i//40))
def maze(n,seed):
 rng=random.Random(seed); walls=[[1,1,1,1] for _ in range(n*n)]; visited={0}; stack=[0]
 while stack:
  at=stack[-1]; x=at%n;y=at//n; candidates=[]
  for d,(dx,dy) in enumerate([(0,-1),(1,0),(0,1),(-1,0)]):
   nx=x+dx;ny=y+dy
   if 0<=nx<n and 0<=ny<n and ny*n+nx not in visited: candidates.append((d,ny*n+nx))
  if not candidates: stack.pop();continue
  d,to=rng.choice(candidates);walls[at][d]=0;walls[to][(d+2)%4]=0;visited.add(to);stack.append(to)
 return walls
for i in range(120):
 n=4+i//12
 add('mazes','maze',{'size':n,'walls':maze(n,2801+i),'start':0,'finish':n*n-1},stage=min(4,i//24))
# Animal features and classifications, followed by foundational environmental science.
feature_questions=[l('How many legs does it have?','Combien de pattes a-t-il ?','¿Cuántas patas tiene?','Quantas patas tem?','كم عدد أرجله؟'),l('Which group does it belong to?','À quel groupe appartient-il ?','¿A qué grupo pertenece?','A que grupo pertence?','إلى أي مجموعة ينتمي؟')]
legs=[4,4,4,4,4,4,4,4,4,0,2,2,2,6,6,0,8,0,4,4]
for i in range(60):
 row=WORDS[i]
 add('nature','quiz',{'subject':row[0],'question':feature_questions[1],'correct':row[5],'options':[{'value':g,'label':GROUPS[g]} for g in [row[5]]+[g for g in GROUPS if g!=row[5]][:3]]},WORD_MAP[row[0]],0,row[0])
for i in range(20):
 row=WORDS[i]
 add('nature','quiz',{'subject':row[0],'question':l('How many arms does an octopus have?','Combien de bras a une pieuvre ?','¿Cuántos brazos tiene un pulpo?','Quantos braços tem um polvo?','كم عدد أذرع الأخطبوط؟') if row[0]=='octopus' else feature_questions[0],'correct':str(legs[i]),'options':eq_opts(legs[i],[0,2,4,6,8])},WORD_MAP[row[0]],2,row[0])
FACTS=[
(l('What gives Earth light during the day?','Qu’est-ce qui éclaire la Terre le jour ?','¿Qué ilumina la Tierra de día?','O que ilumina a Terra durante o dia?','ما الذي يضيء الأرض نهارًا؟'),'sun',['moon','cloud','star']),
(l('What falls from rain clouds?','Que tombe-t-il des nuages de pluie ?','¿Qué cae de las nubes de lluvia?','O que cai das nuvens de chuva?','ماذا يسقط من سحب المطر؟'),l('Water','Eau','Agua','Água','ماء'),[l('Sand','Sable','Arena','Areia','رمل'),l('Leaves','Feuilles','Hojas','Folhas','أوراق'),l('Stones','Pierres','Piedras','Pedras','حجارة')]),
(l('What does a plant absorb through its roots?','Qu’absorbe une plante par ses racines ?','¿Qué absorbe una planta por sus raíces?','O que a planta absorve pelas raízes?','ماذا يمتص النبات بجذوره؟'),l('Water','Eau','Agua','Água','ماء'),[l('Books','Livres','Libros','Livros','كتب'),l('Music','Musique','Música','Música','موسيقى'),l('Stars','Étoiles','Estrellas','Estrelas','نجوم')]),
(l('Which animal makes honey?','Quel animal produit du miel ?','¿Qué animal produce miel?','Qual animal produz mel?','أي حيوان يصنع العسل؟'),'bee',['cat','fish','snail']),
(l('Which animal has a shell?','Quel animal a une carapace ?','¿Qué animal tiene caparazón?','Qual animal tem casco?','أي حيوان له درع؟'),'turtle',['fox','bird','lion']),
(l('Which animal has feathers?','Quel animal a des plumes ?','¿Qué animal tiene plumas?','Qual animal tem penas?','أي حيوان له ريش؟'),'bird',['dog','frog','fish']),
(l('Which fruit grows on an apple tree?','Quel fruit pousse sur un pommier ?','¿Qué fruta crece en un manzano?','Qual fruta cresce numa macieira?','أي فاكهة تنمو على شجرة التفاح؟'),'apple',['carrot','banana','bread']),
(l('Which object is natural?','Quel objet vient de la nature ?','¿Qué objeto es natural?','Qual objeto vem da natureza?','أي شيء طبيعي؟'),'leaf',['pencil','car','clock']),
(l('Which animal breathes air even though it lives in the sea?','Quel animal respire de l’air même s’il vit dans la mer ?','¿Qué animal respira aire aunque vive en el mar?','Qual animal respira ar mesmo vivendo no mar?','أي حيوان يتنفس الهواء رغم أنه يعيش في البحر؟'),'whale',['fish','snail','bee']),
(l('Which animal is an insect?','Quel animal est un insecte ?','¿Qué animal es un insecto?','Qual animal é um inseto?','أي حيوان حشرة؟'),'butterfly',['turtle','dog','whale']),
]
# 30 additional concrete comparisons: which item is an animal, food, or plant-related object.
for j in range(30):
 row=WORDS[(j*7)%60]; group=row[5]
 others=[r for r in WORDS if r[5]!=group]
 question={lang: {'en':'Which picture belongs to: ', 'fr':'Quelle image appartient au groupe : ', 'es':'¿Qué imagen pertenece a: ', 'pt':'Qual imagem pertence ao grupo: ', 'ar':'أي صورة تنتمي إلى: '}[lang]+GROUPS[group][lang] for lang in LANGS}
 candidates=[row[0]]+[others[(j*3+k*5)%len(others)][0] for k in range(3)]
 add('nature','quiz',{'question':question,'correct':row[0],'options':[{'value':k,'label':WORD_MAP[k],'art':k} for k in candidates],'comparison':j},stage=1)
for question,answer,other in FACTS:
 if isinstance(answer,str): opts=[{'value':k,'label':WORD_MAP[k],'art':k} for k in [answer]+other];correct=answer
 else: opts=[{'value':str(k),'label':v} for k,v in enumerate([answer]+other)];correct='0'
 add('nature','quiz',{'question':question,'correct':correct,'options':opts},stage=3)
for i in range(60):
 hour=i%12+1;minute=(i//12)*15 if i//12<4 else [5,10,20,25,35,40,50,55,5,10,20,25][i%12]
 label=f'{hour}:{minute:02}'
 opts=[label,f'{hour%12+1}:{minute:02}',f'{hour}:{(minute+15)%60:02}',f'{(hour+10)%12+1}:{minute:02}']
 add('everyday','quiz',{'clock':{'hour':hour,'minute':minute},'correct':label,'options':[{'value':v,'label':l(v,v,v,v,v)} for v in dict.fromkeys(opts)]},stage=1 if minute==0 else 3)
for i in range(30):
 hour=i%10+1;delta=i//10+1;answer=(hour+delta-1)%12+1
 question=l(f'It is {hour}:00. What time is it {delta} hours later?',f'Il est {hour} h. Quelle heure sera-t-il dans {delta} heures ?',f'Son las {hour}:00. ¿Qué hora será dentro de {delta} horas?',f'São {hour}:00. Que horas serão daqui a {delta} horas?',f'الساعة {hour}:00. كم تصبح بعد {delta} ساعات؟')
 add('everyday','quiz',{'question':question,'correct':str(answer),'options':eq_opts(answer,[answer%12+1,(answer+9)%12+1,(answer+3)%12+1]),'duration':delta,'hour':hour},stage=3)
DAYS=[l('Monday','Lundi','Lunes','Segunda-feira','الاثنين'),l('Tuesday','Mardi','Martes','Terça-feira','الثلاثاء'),l('Wednesday','Mercredi','Miércoles','Quarta-feira','الأربعاء'),l('Thursday','Jeudi','Jueves','Quinta-feira','الخميس'),l('Friday','Vendredi','Viernes','Sexta-feira','الجمعة'),l('Saturday','Samedi','Sábado','Sábado','السبت'),l('Sunday','Dimanche','Domingo','Domingo','الأحد')]
for i in range(7):
 question={lang: {'en':'Which day comes after ', 'fr':'Quel jour vient après ', 'es':'¿Qué día viene después de ', 'pt':'Qual dia vem depois de ', 'ar':'أي يوم يأتي بعد '}[lang]+DAYS[i][lang]+'?' for lang in LANGS}
 add('everyday','quiz',{'question':question,'correct':str((i+1)%7),'options':[{'value':str(j),'label':DAYS[j]} for j in [(i+1)%7,(i+3)%7,(i+5)%7,i]]},stage=2)
for i,(q,a,others) in enumerate([
(l('Where do the puzzle pieces belong when you finish playing?','Où ranges-tu les pièces du puzzle après avoir joué ?','¿Dónde guardas las piezas del puzle después de jugar?','Onde você guarda as peças do quebra-cabeça depois de brincar?','أين تضع قطع الأحجية بعد الانتهاء من اللعب؟'),l('In their box','Dans leur boîte','En su caja','Na caixa delas','في علبتها'),[l('Under the rug','Sous le tapis','Debajo de la alfombra','Debaixo do tapete','تحت السجادة'),l('Behind the curtain','Derrière le rideau','Detrás de la cortina','Atrás da cortina','خلف الستارة'),l('In a plant pot','Dans un pot de fleurs','En una maceta','Em um vaso de plantas','في أصيص نبات')]),
(l('What helps you stay safe in a car?','Qu’est-ce qui te protège en voiture ?','¿Qué te protege en un coche?','O que protege você no carro?','ما الذي يحافظ على سلامتك في السيارة؟'),l('A suitable child seat and seat belt','Un siège adapté et la ceinture','Un asiento adecuado y el cinturón','Uma cadeirinha adequada e o cinto','مقعد طفل مناسب وحزام الأمان'),[l('A book','Un livre','Un libro','Um livro','كتاب'),l('A ball','Un ballon','Una pelota','Uma bola','كرة'),l('A crayon','Un crayon','Un lápiz','Um lápis','قلم')]),
(l('Who can help when something worries you?','Qui peut t’aider quand quelque chose t’inquiète ?','¿Quién puede ayudarte si algo te preocupa?','Quem pode ajudar quando algo preocupa você?','من يساعدك عندما يقلقك شيء؟'),l('A trusted grown-up','Un adulte de confiance','Un adulto de confianza','Um adulto de confiança','شخص بالغ تثق به'),[l('A toy','Un jouet','Un juguete','Um brinquedo','لعبة'),l('A clock','Une horloge','Un reloj','Um relógio','ساعة'),l('A cloud','Un nuage','Una nube','Uma nuvem','سحابة')])]):
 add('everyday','quiz',{'question':q,'correct':'0','options':[{'value':str(j),'label':v} for j,v in enumerate([a]+others)],'routine':i},stage=0)
for i in range(80):
 length=3+i//20;rng=random.Random(7191+i)
 notes=[rng.randrange(8) for _ in range(length)]
 add('music','music',{'notes':notes,'tempo':450+(i%4)*60},stage=i//20)

# Region IDs are stable within a versioned scene, including thumbnail motifs.
for scene in ART.values():
 for index,shape in enumerate(scene['shapes']):shape.setdefault('id',f'r{index}')
COUNTS={k:sum(e['section']==k for e in entries) for k,*_ in SECTIONS}
assert COUNTS=={s[0]:s[1] for s in SECTIONS},COUNTS
assert len(entries)==2400
# Each choice order is compiled, not regenerated during play; correct values stay stable.
for entry in entries:
 def reorder(cfg):
  if 'options' in cfg:
   offset=int(hashlib.sha256(entry['id'].encode()).hexdigest()[:4],16)%len(cfg['options'])
   cfg['options']=cfg['options'][offset:]+cfg['options'][:offset]
  if 'locales' in cfg:
   for val in cfg['locales'].values(): reorder(val)
 reorder(entry['config'])

out=ROOT/'assets/content';out.mkdir(parents=True,exist_ok=True)
for name,value in [('catalog.json',{'version':3,'languages':LANGS,'sections':[{'id':a,'count':b,'icon':c,'color':d,'name':e} for a,b,c,d,e in SECTIONS],'activities':entries}),('art.json',ART),('strings.json',UI),('words.json',WORD_MAP)]:
 (out/name).write_text(json.dumps(value,ensure_ascii=False,separators=(',',':')))
manifest={lang:{**{f'{k}.mp3':v[lang] for k,v in PROMPTS.items()},**{f'word_{k}.mp3':v[lang] for k,v in WORD_MAP.items()},'great.mp3':UI['great'][lang],'again.mp3':UI['again'][lang],'welcome.mp3':UI['hello'][lang]} for lang in LANGS}
for lang in LANGS:
 letters=ARABIC_NAMES if lang=='ar' else TRACE_ALPHABETS[lang]
 for i,letter in enumerate(letters):
  prefix={'en':'The letter ','fr':'La lettre ','es':'La letra ','pt':'A letra ','ar':''}[lang]
  manifest[lang][f'letter_{i}.mp3']=prefix+letter+('.' if lang!='ar' else '')
manifest['ar'].update(arabic.audio())
manifest['ar'].update({f'{k}.mp3':v for k,v in arabic.GUIDANCE.items()})
assert len(arabic.VOCABULARY)==len(WORDS)
manifest['ar'].update({f'word_{row[0]}.mp3':spoken for row,spoken in zip(WORDS,arabic.VOCABULARY)})
(out/'arabic_review.json').write_text(json.dumps({'version':1,'status':'native educator and pronunciation review pending','lessons':{e['id']:{'config':e['config']['locales']['ar'],'cue':e['cue']['ar']} for e in entries if e['section'] in ['letters','tracing'] and 'locales' in e['config']}},ensure_ascii=False,indent=2))
(out/'audio_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print(json.dumps({'activities':len(entries),'sections':COUNTS,'vectorScenes':len(ART),'speechClips':sum(map(len,manifest.values()))},indent=2))
