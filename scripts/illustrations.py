"""Original, closed-region vector illustrations. Coordinates are authored on a 200px canvas."""
import math
from copy import deepcopy

PALETTE = ['74BEC6','F3C65F','E992AB','9B8ACA','8DB77B','F17C6E','F9D5B8']

def ellipse(x,y,w,h,c=0,ink=False): return {'kind':'ellipse','v':[x,y,w,h],'color':'263B43' if ink else PALETTE[c%len(PALETTE)],'fillable':not ink}
def rect(x,y,w,h,c=0,r=8): return {'kind':'rect','v':[x,y,w,h,r],'color':PALETTE[c%len(PALETTE)]}
def poly(points,c=0): return {'kind':'poly','v':points,'color':PALETTE[c%len(PALETTE)]}
def path(d,c=0): return {'kind':'path','d':d,'color':PALETTE[c%len(PALETTE)]}
def star(x,y,r,c=1):
 return poly([[round(x+math.sin(i*math.pi/5)*(r if i%2==0 else r*.43),2),round(y-math.cos(i*math.pi/5)*(r if i%2==0 else r*.43),2)] for i in range(10)],c)
def eyes(x=75,y=80,gap=45): return [ellipse(x,y,10,12,ink=True),ellipse(x+gap,y,10,12,ink=True)]

def motif(name):
 s=[]
 if name in ['cat','dog','rabbit','fox','bear','lion','elephant','giraffe','penguin','owl','hedgehog']:
  if name=='lion': s.append(ellipse(28,28,144,144,1))
  if name=='hedgehog': s.append(poly([[18+i*13,125-(35 if i%2 else 0)] for i in range(13)]+[[185,165],[20,165]],5))
  if name in ['cat','fox']: s += [poly([[45,72],[40,20],[85,55]],5),poly([[115,55],[160,20],[155,75]],5)]
  elif name=='rabbit': s += [ellipse(55,0,30,88,6),ellipse(112,0,30,88,6)]
  elif name=='giraffe': s += [rect(88,45,35,120,1),ellipse(48,8,22,50,1),ellipse(131,8,22,50,1)]
  elif name=='elephant': s += [ellipse(8,52,70,110,0),ellipse(123,52,70,110,0)]
  else: s += [ellipse(38,28,38,40,3),ellipse(124,28,38,40,3)]
  s += [ellipse(49,97,102,84,0),ellipse(39,43,122,107,1 if name in ['lion','giraffe'] else (5 if name=='fox' else 0)),ellipse(62,106,76,37,6)]
  if name=='penguin': s += [ellipse(71,114,58,56,6),poly([[90,85],[112,85],[101,103]],1)]
  elif name=='owl': s += [ellipse(55,65,40,43,6),ellipse(105,65,40,43,6),poly([[93,102],[110,102],[101,116]],1)]
  elif name=='elephant': s.append(path('M88 106 Q80 171 119 174 Q141 171 130 143 L114 147 Q121 154 114 155 Q101 154 110 107 Z',0))
  else: s.append(ellipse(92,105,17,13,ink=True))
  s += eyes(71,77,49)+[ellipse(43,162,40,24,5),ellipse(116,162,40,24,5)]
  if name=='dog': s += [ellipse(27,43,34,79,3),ellipse(142,43,34,79,3)]
  if name=='giraffe': s += [ellipse(85,130,12,18,5),ellipse(111,153,15,15,5)]
 elif name in ['fish','whale']:
  s += [poly([[141,100],[193,58],[190,147]],0),ellipse(14,56,146,90,0),ellipse(24,93,94,45,6),poly([[75,101],[109,75],[116,116]],2),ellipse(38,81,12,15,ink=True)]
  if name=='whale': s += [path('M80 51 Q62 18 86 6 Q100 27 95 47 Z',0),path('M110 47 Q111 20 137 13 Q135 40 120 52 Z',0)]
 elif name=='turtle':
  s += [ellipse(45,35,22,45,4),ellipse(122,35,22,45,4),ellipse(45,136,22,45,4),ellipse(122,136,22,45,4),ellipse(137,81,57,44,4),ellipse(18,43,136,114,4),poly([[60,65],[100,57],[128,90],[111,132],[64,140],[39,103]],1),ellipse(169,91,9,11,ink=True)]
 elif name in ['bird','bee','butterfly']:
  if name=='butterfly': s += [ellipse(9,28,85,78,2),ellipse(105,28,85,78,3),ellipse(20,99,72,76,3),ellipse(108,99,72,76,2),rect(91,49,18,113,1)]
  elif name=='bee': s += [ellipse(40,22,55,65,0),ellipse(106,22,55,65,0),ellipse(29,67,144,91,1),rect(66,70,15,83,5),rect(110,70,15,83,5)]
  else: s += [poly([[33,110],[8,147],[65,142]],3),ellipse(45,31,116,129,0),ellipse(60,88,63,63,1),poly([[147,67],[191,88],[146,100]],5),ellipse(49,85,52,36,3)]
  s += eyes(81,74,35)
 elif name=='snail': s += [path('M17 139 Q39 113 125 130 L171 88 Q191 72 190 114 L176 156 L25 161 Z',4),ellipse(29,32,119,111,2),ellipse(54,57,70,63,1),ellipse(76,74,28,28,3),ellipse(171,86,10,10,ink=True)]
 elif name=='octopus':
  for i in range(5): s.append(path(f'M{35+i*26} 114 Q{10+i*31} 185 {28+i*31} 174 Q{50+i*26} 152 {54+i*26} 112 Z',3))
  s += [ellipse(39,25,122,111,3)]+eyes(70,68,51)
 elif name=='frog': s += [ellipse(22,139,64,38,4),ellipse(114,139,64,38,4),ellipse(31,64,139,96,4),ellipse(36,34,57,65,4),ellipse(107,34,57,65,4),ellipse(50,45,26,32,6),ellipse(122,45,26,32,6)]+eyes(57,52,72)+[ellipse(61,117,75,17,6)]
 elif name in ['apple','pear','orange','strawberry','watermelon']:
  if name=='pear': s.append(path('M101 28 Q127 30 133 74 Q187 167 104 182 Q17 180 65 84 Q72 34 101 28 Z',4))
  elif name=='strawberry': s.append(path('M28 69 Q45 27 102 47 Q152 21 176 67 Q168 140 101 183 Q40 146 28 69 Z',5))
  elif name=='watermelon': s += [path('M15 55 L187 55 Q175 177 99 185 Q27 171 15 55 Z',4),path('M35 61 L167 61 Q162 155 99 165 Q48 153 35 61 Z',5)]
  else: s.append(ellipse(28,43,146,138,5 if name=='apple' else 1))
  s += [rect(94,17,10,36,5),path('M103 26 Q115 0 145 13 Q140 37 103 26 Z',4)]
  if name in ['strawberry','watermelon']:
   for x,y in [(69,81),(117,87),(90,122),(130,125),(59,113)]: s.append(ellipse(x,y,5,10,ink=True))
 elif name=='banana': s += [path('M42 22 Q44 130 166 102 L180 136 Q77 205 20 66 Z',1),rect(30,16,19,32,4)]
 elif name=='carrot': s += [poly([[54,62],[151,62],[106,184]],5),path('M91 66 Q36 24 75 14 Q94 22 100 55 Q111 4 140 12 Q161 31 109 68 Z',4)]
 elif name=='bread': s += [path('M25 165 L23 83 Q4 25 62 23 Q97 5 131 23 Q193 25 178 83 L176 165 Z',1),rect(46,67,109,73,6,18)]
 elif name=='cake': s += [rect(30,80,140,90,2),path('M29 91 L29 78 Q48 41 72 67 Q98 48 119 66 Q151 40 172 78 L172 96 Q152 122 136 94 Q109 122 91 95 Q64 122 48 94 Z',6),rect(92,24,16,53,0),path('M99 22 Q81 3 99 0 Q119 8 99 22 Z',1)]
 elif name=='cup': s += [ellipse(112,48,74,75,5),ellipse(128,61,42,46,6),rect(25,42,119,128,0,20),ellipse(26,31,115,30,1)]
 elif name in ['car','bus','train','tractor']:
  s += [rect(23,82,156,73,1,18)]
  if name=='car': s.append(path('M46 87 L72 42 L130 42 L158 87 Z',5))
  else: s.append(rect(32,39,132,65,5))
  s += [rect(61,53,32,34,0,4),rect(104,53,33,34,0,4),ellipse(39,133,43,43,3),ellipse(127,133,43,43,3),ellipse(52,146,17,17,6),ellipse(140,146,17,17,6)]
  if name=='train': s += [rect(22,18,20,47,3),ellipse(11,3,44,28,6)]
  if name=='tractor': s += [ellipse(121,118,58,58,3),ellipse(137,134,26,26,6)]
 elif name=='boat': s += [path('M12 116 L187 116 L154 163 L47 163 Z',5),rect(98,20,7,101,3),poly([[96,25],[96,104],[32,104]],1),poly([[110,44],[166,104],[110,104]],0)]
 elif name=='rocket': s += [poly([[63,108],[22,157],[69,148]],5),poly([[133,108],[178,157],[129,148]],5),path('M63 135 L63 68 Q70 19 100 5 Q133 23 137 68 L137 135 Z',0),ellipse(78,57,43,43,1),path('M70 137 L130 137 Q126 173 100 195 Q74 178 70 137 Z',5)]
 elif name=='airplane': s += [path('M87 28 Q100 7 113 28 L120 82 L190 122 L187 145 L116 118 L112 159 L142 180 L130 188 L100 177 L72 188 L59 180 L88 159 L84 118 L14 145 L11 122 L81 82 Z',0),ellipse(91,34,18,34,1)]
 elif name=='bicycle': s += [ellipse(9,99,68,68,0),ellipse(124,99,68,68,0),poly([[42,130],[75,79],[114,131]],5),poly([[76,80],[113,132],[159,133],[133,66]],4),rect(66,68,30,10,3),rect(126,52,35,9,3)]
 elif name=='tree': s += [rect(85,73,30,115,5),ellipse(24,33,96,87,4),ellipse(71,12,106,105,4),ellipse(76,65,104,65,4),ellipse(33,60,110,76,4)]
 elif name=='flower':
  s += [rect(93,86,13,101,4),path('M94 148 Q25 100 41 159 Q68 181 94 160 Z',4),path('M106 146 Q168 96 163 149 Q147 173 106 163 Z',4)]
  for i in range(6): s.append(ellipse(80+math.sin(i*math.pi/3)*42,50+math.cos(i*math.pi/3)*42,42,46,2))
  s.append(ellipse(77,51,47,47,1))
 elif name=='sun':
  for i in range(12):
   a=i*math.pi/6; s.append(poly([[100+math.sin(a-.12)*63,100+math.cos(a-.12)*63],[100+math.sin(a)*95,100+math.cos(a)*95],[100+math.sin(a+.12)*63,100+math.cos(a+.12)*63]],1))
  s += [ellipse(44,44,112,112,1)]+eyes(69,82,49)
 elif name=='moon': s += [path('M150 14 Q39 6 22 99 Q23 186 124 187 Q162 184 187 150 Q101 176 72 97 Q56 48 150 14 Z',1),star(157,67,21,3)]
 elif name=='star': s += [star(100,101,93,1)]+eyes(72,90,49)
 elif name=='cloud': s.append(path('M39 158 Q0 157 8 118 Q10 92 39 90 Q40 49 79 48 Q107 13 142 58 Q185 53 181 101 Q220 124 189 158 Z',0))
 elif name=='rainbow':
  for i,c in enumerate([5,1,4,0,3]): s.append(path(f'M{9+i*15} 171 Q100 {4+i*30} {191-i*15} 171 L{177-i*15} 171 Q100 {34+i*30} {23+i*15} 171 Z',c))
 elif name=='leaf': s += [path('M20 171 Q-3 38 170 15 Q192 179 20 171 Z',4),path('M23 166 L155 34 L30 176 Z',1)]
 elif name=='mountain': s += [poly([[2,185],[71,26],[137,185]],3),poly([[78,185],[139,54],[199,185]],0),poly([[52,70],[71,26],[89,69],[76,61],[66,77]],6)]
 elif name=='mushroom': s += [path('M74 84 L123 84 L133 172 Q100 193 65 172 Z',6),path('M10 100 Q28 9 100 12 Q172 9 190 100 Z',5),ellipse(52,41,26,26,6),ellipse(108,32,32,30,6),ellipse(140,68,20,20,6)]
 elif name=='house': s += [rect(31,81,138,105,1,4),poly([[12,88],[100,14],[188,88]],5),rect(81,119,39,67,3,4),rect(45,102,27,29,0,3),rect(131,102,25,29,0,3)]
 elif name=='book': s += [path('M100 43 Q51 13 10 35 L10 160 Q56 143 100 177 Z',0),path('M100 43 Q150 13 190 35 L190 160 Q145 143 100 177 Z',1),rect(95,43,10,135,3,3)]
 elif name=='pencil': s += [poly([[36,152],[54,168],[169,54],[149,34]],1),poly([[36,152],[18,187],[54,168]],6),poly([[18,187],[29,180],[22,169]],3),poly([[149,34],[169,54],[185,36],[165,16]],2)]
 elif name=='ball': s += [ellipse(12,12,176,176,0),path('M20 63 Q100 108 178 64 Q190 106 177 142 Q100 96 24 147 Z',1),path('M65 21 Q110 97 64 181 Q100 193 139 181 Q96 97 140 20 Z',5)]
 elif name=='kite': s += [poly([[101,13],[173,83],[98,151],[29,85]],2),poly([[101,13],[173,83],[101,83]],1),poly([[101,83],[98,151],[29,85]],0),path('M98 150 Q170 172 94 191 L91 185 Q142 176 91 157 Z',3)]
 elif name=='umbrella': s += [path('M10 96 Q29 12 100 12 Q171 12 190 96 Q164 71 139 96 Q121 74 100 96 Q81 74 60 96 Q34 73 10 96 Z',2),path('M98 93 L108 93 L108 160 Q110 183 82 188 Q53 185 57 167 L69 167 Q66 178 82 177 Q99 175 98 160 Z',3)]
 elif name=='clock': s += [ellipse(14,14,172,172,0),ellipse(28,28,144,144,6),poly([[96,42],[106,42],[106,101],[146,125],[140,134],[96,105]],3),ellipse(91,91,18,18,5)]
 elif name=='key': s += [ellipse(19,16,92,92,1),ellipse(40,37,49,49,6),poly([[81,83],[94,74],[182,163],[168,178],[152,162],[138,176],[124,161],[140,148]],1)]
 elif name=='guitar': s += [ellipse(31,95,115,99,1),ellipse(53,60,91,75,1),poly([[100,92],[117,98],[160,26],[143,18]],5),rect(144,7,24,36,3),ellipse(79,101,35,35,3)]
 elif name=='drum': s += [rect(24,58,152,99,2),ellipse(24,41,152,43,1),ellipse(24,133,152,43,1),poly([[32,80],[60,140],[96,83],[132,140],[163,80]],0)]
 elif name=='piano':
  s += [rect(10,49,180,110,3),rect(18,69,164,80,6,2)]
  for i in range(7): s.append(rect(19+i*23,69,21,78,6,1))
  for i in [0,1,3,4,5]: s.append(rect(34+i*23,69,13,46,3,1))
 elif name=='bell': s += [ellipse(78,18,44,45,1),path('M35 133 Q53 116 51 77 Q59 37 100 37 Q141 37 149 77 Q147 117 165 133 Z',1),ellipse(81,133,38,35,5),rect(25,130,151,16,1)]
 else: raise ValueError(name)
 return s

THEMES = ['garden','forest','beach','ocean','night','snow','space','town','farm','desert','rain','party']

def transformed(shapes,x,y,scale):
 out=deepcopy(shapes)
 for shape in out: shape['transform']=[round(x,3),round(y,3),round(scale,4)]
 return out

def scene(name, variant):
 theme=THEMES[variant%12]; s=[]
 if theme in ['ocean','beach']:
  s += [path('M0 375 Q75 340 150 375 T300 375 T450 375 T600 375 L600 600 L0 600 Z',0)]
 else: s += [path('M0 475 Q140 392 300 466 Q440 390 600 473 L600 600 L0 600 Z',4)]
 if theme in ['night','space']:
  s += transformed(motif('moon'),420,18,.62)
  for x,y in [(45,62),(172,43),(298,103),(397,68),(531,234)]: s.append(star(x,y,17,1))
 elif theme=='rain':
  s += transformed(motif('cloud'),50,15,.8)+transformed(motif('cloud'),328,34,.75)
  for x in [72,161,260,355,470,540]: s.append(path(f'M{x} 135 Q{x-24} 174 {x} 176 Q{x+24} 174 {x} 135 Z',0))
 else:
  s += transformed(motif('sun'),430,15,.6)+transformed(motif('cloud'),28,36,.7)
 if theme=='garden': s += transformed(motif('flower'),30,365,.72)+transformed(motif('butterfly'),422,340,.68)
 if theme=='forest': s += transformed(motif('tree'),0,225,1.1)+transformed(motif('mushroom'),430,396,.67)
 if theme=='beach': s += transformed(motif('umbrella'),10,315,.9)+transformed(motif('boat'),427,366,.7)
 if theme=='ocean': s += transformed(motif('fish'),12,436,.65)+transformed(motif('star'),490,447,.42)
 if theme=='snow':
  s += transformed(motif('tree'),8,296,.85)
  for x,y in [(45,217),(517,258),(145,315),(461,356)]: s.append(star(x,y,12,6))
 if theme=='space': s += transformed(motif('rocket'),13,325,.78)+transformed(motif('star'),435,415,.5)
 if theme=='town': s += transformed(motif('house'),10,270,.95)+transformed(motif('car'),422,427,.75)
 if theme=='farm': s += transformed(motif('tractor'),1,410,.8)+transformed(motif('carrot'),451,365,.72)
 if theme=='desert': s += transformed(motif('mountain'),375,251,1.05)+transformed(motif('sun'),4,160,.45)
 if theme=='party':
  for i in range(8): s.append(poly([[i*75,23],[i*75+38,83],[i*75+75,23]],i))
  s += transformed(motif('cake'),13,390,.73)+transformed(motif('ball'),451,370,.69)
 if theme=='rain': s += transformed(motif('umbrella'),424,350,.85)+transformed(motif('flower'),8,420,.65)
 # The central subject changes position/scale deliberately with each composition.
 s += transformed(motif(name),156+(variant%3)*10,188+(variant%4)*9,1.43+(variant%2)*.12)
 for i,shape in enumerate(s): shape['id']=f'r{i}'
 return {'width':600,'height':600,'theme':theme,'subject':name,'shapes':s}

def shape_icon(kind,color):
 c=list(PALETTE).index(color) if color in PALETTE else 0
 if kind=='circle': s=[ellipse(20,20,160,160,c)]
 elif kind=='square': s=[rect(25,25,150,150,c,2)]
 elif kind=='rectangle': s=[rect(15,50,170,100,c,2)]
 elif kind=='triangle': s=[poly([[100,15],[185,185],[15,185]],c)]
 elif kind=='star': s=[star(100,100,95,c)]
 else: s=[path('M100 176 Q0 96 23 45 Q67 3 100 50 Q133 3 176 45 Q200 96 100 176 Z',c)]
 s[0]['color']=color
 return {'width':200,'height':200,'shapes':s}
