"""Smooth, proportionate Naskh motor guides, with explicit pen order.

Coordinates are authored centre lines, not traced copies of a font or worksheet.
The letter model and practice board consume the same geometry.
"""
import math
from copy import deepcopy

REVISION = 3

def curve(start, *segments):
    result = [list(start)]
    for segment in segments:
        a = result[-1]
        if segment[0] == 'L':
            b = segment[1:]; length = math.dist(a, b)
            n = max(1, math.ceil(length / 2))
            result.extend([[round(a[k] + (b[k]-a[k])*i/n, 3) for k in (0, 1)] for i in range(1,n+1)])
        else:
            assert segment[0] == 'C'
            b,c,d = segment[1:3],segment[3:5],segment[5:7]
            n = max(8, math.ceil((math.dist(a,b)+math.dist(b,c)+math.dist(c,d))/2))
            for i in range(1,n+1):
                t=i/n;u=1-t
                result.append([round(u**3*a[k]+3*u*u*t*b[k]+3*u*t*t*c[k]+t**3*d[k],3) for k in (0,1)])
    return result

def dot(x,y): return [[x-1,y],[x+1,y]]
def body(points):return ('body',points)
def mark(points):return ('dot',points)
def stem(points):return ('body',points)

def isolated(letter):
    bowl = curve((178,92),('C',188,145,165,159,110,159),('C',54,159,30,154,34,100))
    jim = curve((72,66),('C',78,53,107,64,152,66),('C',120,77,65,92,65,134),('C',64,170,103,184,158,166))
    dal = curve((94,72),('C',113,77,141,109,144,128),('C',125,141,92,145,58,142))
    ra = curve((149,87),('C',174,125,136,176,64,178))
    sin = curve((184,93),('C',187,123,170,133,155,105),('C',158,134,137,140,126,108),('C',127,131,119,157,105,169),('C',80,191,35,181,34,140))
    sad = curve((85,120),('C',111,81,153,65,173,85),('C',197,118,153,134,85,130),('C',82,157,61,180,42,170),('C',23,161,24,145,27,126))
    tah = curve((60,135),('C',90,104,139,76,160,91),('C',181,109,178,132,141,136),('C',112,140,76,139,48,139))
    ayn = curve((139,77),('C',112,46,82,65,92,85),('C',104,100,125,100,151,91),('C',100,110,61,130,69,157),('C',76,187,128,186,162,167))
    fa = curve((154,102),('C',132,105,122,96,128,78),('C',139,49,166,64,168,92),('C',169,107,160,110,154,102),('C',177,139,151,157,110,159),('C',61,162,32,155,33,109))
    qaf = curve((158,99),('C',135,106,121,95,127,77),('C',139,50,168,60,171,94),('C',171,108,162,111,158,99),('C',180,151,148,179,101,180),('C',50,181,28,155,35,120))
    kaf = curve((165,35),('C',167,71,164,108,164,148),('C',123,157,61,166,39,149),('C',29,140,31,122,35,112))
    kaf_small = curve((121,79),('C',104,85,94,92,115,96),('C',111,102,103,106,91,110))
    lam = curve((152,35),('C',156,84,164,146,137,169),('C',108,196,57,179,49,153),('C',44,141,45,131,47,122))
    mim_head = curve((122,97),('C',127,72,153,73,158,98),('C',161,120,122,129,122,97))
    mim_tail = curve((155,112),('C',130,123,98,123,81,129),('C',76,147,76,168,80,188))
    nun = curve((169,99),('C',183,143,154,179,113,180),('C',65,182,35,160,40,119))
    ha = curve((83,93),('C',85,64,113,62,134,81),('C',155,108,145,147,112,151),('C',77,153,69,125,83,93))
    waw_head = curve((148,100),('C',121,109,107,98,117,77),('C',137,48,163,69,157,106),('C',151,107,147,104,148,100))
    waw_tail = curve((148,100),('C',158,141,118,178,60,181))
    ya = curve((153,71),('C',177,83,172,102,143,110),('C',120,116,116,122,154,133),('C',187,144,150,181,110,182),('C', 60,184,32,164,34,125))
    paths = {
        'ا':[body(curve((111,34),('C',112,82,116,123,112,166)))],
        'ب':[body(bowl),mark(dot(109,184))],
        'ت':[body(bowl),mark(dot(128,68)),mark(dot(102,68))],
        'ث':[body(bowl),mark(dot(128,68)),mark(dot(102,68)),mark(dot(115,46))],
        'ج':[body(jim),mark(dot(110,134))], 'ح':[body(jim)], 'خ':[body(jim),mark(dot(111,42))],
        'د':[body(dal)], 'ذ':[body(dal),mark(dot(107,45))],
        'ر':[body(ra)],'ز':[body(ra),mark(dot(142,55))],
        'س':[body(sin)],'ش':[body(sin),mark(dot(157,72)),mark(dot(131,72)),mark(dot(144,50))],
        'ص':[body(sad)],'ض':[body(sad),mark(dot(145,58))],
        'ط':[body(tah),stem(curve((91,34),('L',91,131)))],
        'ظ':[body(tah),stem(curve((91,34),('L',91,131))),mark(dot(143,65))],
        'ع':[body(ayn)],'غ':[body(ayn),mark(dot(117,38))],
        'ف':[body(fa),mark(dot(151,39))],'ق':[body(qaf),mark(dot(169,38)),mark(dot(144,38))],
        'ك':[body(kaf),body(kaf_small)],'ل':[body(lam)],
        'م':[body(mim_head),body(mim_tail)],'ن':[body(nun),mark(dot(113,84))],
        'ه':[body(ha)],'و':[body(waw_head),body(waw_tail)],
        'ي':[body(ya),mark(dot(125,204)),mark(dot(98,204))],
    }
    return deepcopy(paths[letter])


def contextual(letter, form):
    """Real joining forms; widths are authored advances, never stretched slots."""
    if form == 'isolated':
        paths=isolated(letter)
        # Natural advances use the actual written letter width plus a pen-lift gap.
        points=[p for _,path in paths for p in path]
        left=min(p[0] for p in points);right=max(p[0] for p in points)
        return right-left+30,[(kind,[[x-left+15,y] for x,y in path]) for kind,path in paths]
    incoming=form in ('medial','final');outgoing=form in ('initial','medial')
    marks=[]
    if letter in 'بتثني':
        if outgoing:
            width=72
            p=curve((width,120),('C',62,120,56,120,53,105),('C',53,87,46,88,47,107),('C',46,123,27,121,0,120)) if incoming else curve((54,86),('C',60,115,55,123,39,121),('L',0,120))
            center=48
        elif letter=='ي':
            width=175;p=curve((width,120),('C',160,123,136,116,117,124),('C',120,137,148,134,148,150),('C',142,177,91,184,57,173),('C',29,163,20,146,23,126));center=89
        else:
            width=160
            deep=182 if letter=='ن' else 158
            p=curve((width,120),('C',146,120,140,121,137,133),('C',126,deep,59,deep+8,28,deep-12),('C',9,deep-23,9,119,16,101));center=85
        if letter=='ب':marks=[mark(dot(center,151 if outgoing else 181))]
        if letter=='ن':marks=[mark(dot(center,79 if outgoing else 92))]
        if letter=='ت':marks=[mark(dot(center+13,77)),mark(dot(center-13,77))]
        if letter=='ث':marks=[mark(dot(center+13,77)),mark(dot(center-13,77)),mark(dot(center,55))]
        if letter=='ي':marks=[mark(dot(center+13,152 if outgoing else 201)),mark(dot(center-13,152 if outgoing else 201))]
        return width,[body(p)]+marks
    if letter=='ك':
        if form=='initial':
            width=105;p=curve((95,36),('L',35,74),('C',49,82,66,100,79,106),('C',75,123,42,121,0,120))
            return width,[body(p)]
        if form=='medial':
            width=105
            return width,[body(curve((95,36),('L',35,74),('C',49,82,66,100,79,106),('L',79,120))),body(curve((width,120),('L',0,120)))]
        width=165
        return width,[body(curve((148,34),('L',148,121))),body(curve((width,120),('L',148,120),('L',148,149),('C',100,162,28,163,16,143),('L',17,116))),body(curve((110,76),('C',94,83,87,89,104,94),('C',101,100,93,105,85,108)))]
    if letter=='ل':
        width=72 if outgoing else 152;stem_x=52 if outgoing else 128
        vertical=curve((stem_x,33),('L',stem_x,120))
        if form=='initial':return width,[body(curve((stem_x,33),('L',stem_x,120),('C',40,123,19,121,0,120)))]
        lower=curve((width,120),('L',0,120)) if outgoing else curve((width,120),('L',stem_x,120),('C',133,159,108,184,70,178),('C',35,175,13,155,20,127))
        return width,[body(vertical),body(lower)]
    if letter=='م':
        width=102 if outgoing else 150
        head=curve((52,111),('C',52,95,75,91,82,116),('C',75,134,52,134,52,111))
        entry=[body(curve((width,120),('L',82,120)))] if incoming else []
        tail=curve((78,124),('C',54,125,25,121,0,120)) if outgoing else curve((78,124),('C',56,128,36,131,31,141),('C',29,158,30,178,34,191))
        return width,entry+[body(head),body(tail)]
    if letter=='س':
        width=126 if outgoing else 185
        p=curve((width,120),('L',width-17,120),('C',width-9,86,width-24,85,width-25,105),('C',width-25,134,width-46,138,width-50,107),('C',width-48,139,width-72,143,width-78,109)) if incoming else curve((width-15,93),('C',width-10,125,width-28,134,width-36,107),('C',width-34,139,width-58,138,width-64,109))
        start=p[-1]
        ending=curve(start,('C',start[0]-3,125,25,122,0,120)) if outgoing else curve(start,('C',start[0]-4,167,60,189,33,173),('C',13,161,15,139,19,128))
        return width,[body(p+ending[1:])]
    if letter=='ا':
        width=60
        return width,[body(curve((39,33),('L',39,120))),body(curve((width,120),('L',39,120)))]
    if letter=='د':
        width=90
        return width,[body(curve((width,120),('C',67,119,63,89,36,73),('C',48,88,65,111,64,124),('C',46,135,25,138,9,134)))]
    if letter=='ر':
        width=86
        return width,[body(curve((width,120),('L',61,120),('C',59,153,36,174,7,179)))]
    if letter=='و':
        width=99
        return width,[body(curve((width,120),('L',70,119))),body(curve((70,116),('C',41,128,33,109,45,94),('C',62,75,80,92,71,126),('C',71,119,73,118,70,116))),body(curve((70,116),('C',60,156,34,177,7,181)))]
    raise ValueError(f'Unauthored Arabic word form: {letter}/{form}')


def normalize(parts):
    points=[p for _,path in parts for p in path]
    left,right=min(p[0] for p in points),max(p[0] for p in points)
    top,bottom=min(p[1] for p in points),max(p[1] for p in points)
    scale=min(186/max(right-left,1),174/max(bottom-top,1),1.)
    dx=110-(left+right)*scale/2;dy=110-(top+bottom)*scale/2
    strokes=[[[round(x*scale+dx,3),round(y*scale+dy,3)] for x,y in path] for _,path in parts]
    return {'strokes':strokes,'strokeKinds':[kind for kind,_ in parts],
            'guideWidth':round(10*scale,3),'traceRevision':REVISION,
            'geometryScale':round(scale,6),'preserveAspectRatio':True}


def trace(index,letters,words,right_only):
    if index<56:
        letter=letters[index if index<28 else index-27] if index!=55 else 'ا'
        parts=isolated(letter)
        if 28<=index<55:
            # A separate top margin keeps fatḥa above the letter's own dots.
            top=min(p[1] for _,path in parts for p in path)
            center=110
            parts.append(('vowel',curve((center+14,top-23),('L',center-13,top-14))))
        if index==55:
            parts.append(('vowel',curve((87,13),('C',98,3,106,24,121,13),('C',126,10,132,9,137,10))))
        return normalize(parts)
    text=words[index-56];letters_in_word=''.join(c for c in text if '\u0621'<=c<='\u064a')
    characters=[]
    for j,c in enumerate(letters_in_word):
        incoming=j>0 and letters_in_word[j-1] not in right_only
        outgoing=j<len(letters_in_word)-1 and c not in right_only
        form='medial' if incoming and outgoing else 'final' if incoming else 'initial' if outgoing else 'isolated'
        width,parts=contextual(c,form);characters.append((width,parts,outgoing))
    x=sum(width for width,_,_ in characters)+sum(18 for _,_,out in characters[:-1] if not out)
    main=[];dots=[]
    for width,parts,outgoing in characters:
        x-=width
        for kind,path in parts:
            transformed=(kind,[[px+x,py] for px,py in path])
            (dots if kind=='dot' else main).append(transformed)
        if not outgoing:x-=18
    return normalize(main+dots)
