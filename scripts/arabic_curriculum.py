"""Finite MSA literacy lessons. Logical text stays in Arabic reading order."""
LETTERS=list('ابتثجحخدذرزسشصضطظعغفقكلمنهوي')
NAMES=['أَلِف','بَاء','تَاء','ثَاء','جِيم','حَاء','خَاء','دَال','ذَال','رَاء','زَاي','سِين','شِين','صَاد','ضَاد','طَاء','ظَاء','عَيْن','غَيْن','فَاء','قَاف','كَاف','لَام','مِيم','نُون','هَاء','وَاو','يَاء']
RIGHT_ONLY=set('ادذرزو')
DUAL=[c for c in LETTERS if c not in RIGHT_ONLY]
VOWELS=['َ','ِ','ُ']
VOWEL_NAMES=['الفَتْحَة','الكَسْرَة','الضَّمَّة']
WORDS=['بَاب','بَيْت','بِنْت','بَنَات','نَبَات','ثَوْب','تُوت','تِين','كَتَبَ','كِتَاب','كَلْب','لَبَن',
       'لَيْل','مَال','نَمْل','نُور','نَوْم','وَلَد','وَرْد','دَرْس','بَرْد','بَدَل','تَمْر','سَمَك']
GUIDANCE={
'coloring':'اِخْتَرْ لَوْنًا. اِلْمِسْ شَكْلًا أَوِ ارْسُمْ بِالفُرْشَاة.',
'drawing':'اِتَّبِعِ الدَّلِيلَ، ثُمَّ ابْتَكِرْ رَسْمَكَ الخَاصّ.',
'tracing':'اِتَّبِعِ النِّقَاطَ بِالتَّرْتِيبِ، وَابْدَأْ مِنَ النُّقْطَةِ المُضِيئَة.',
'letters':'اِسْتَمِعْ وَانْظُرْ، ثُمَّ اخْتَرِ الحَرْفَ الصَّحِيح.',
'words':'اُنْظُرْ إِلَى الصُّورَةِ وَتَعَلَّمِ اسْمَهَا.',
'counting':'عُدَّ الأَشْيَاءَ، ثُمَّ اخْتَرِ العَدَد.',
'math':'حُلَّ المَسْأَلَةَ. يُمْكِنُكَ طَلَبُ تَلْمِيح.',
'shapes':'اُنْظُرْ جَيِّدًا، وَاخْتَرِ الشَّكْلَ أَوِ اللَّوْنَ المُنَاسِب.',
'sorting':'اُنْقُلْ كُلَّ صُورَةٍ إِلَى مَجْمُوعَتِهَا المُنَاسِبَة.',
'memory':'اِقْلِبْ بِطَاقَتَيْنِ، وَاعْثُرْ عَلَى جَمِيعِ الأَزْوَاجِ المُتَطَابِقَة.',
'jigsaw':'حَرِّكِ القِطَعَ لِتَكْوِينِ الصُّورَة.',
'patterns':'اِكْتَشِفِ العُنْصُرَ التَّالِيَ فِي النَّمَط.',
'mazes':'سَاعِدْ بِيكُو فِي الوُصُولِ إِلَى النَّجْمَةِ دُونَ عُبُورِ الجُدْرَان.',
'nature':'اِسْتَكْشِفِ الطَّبِيعَةَ، وَاخْتَرِ الإِجَابَةَ الصَّحِيحَة.',
'everyday':'اُنْظُرْ وَفَكِّرْ، وَاكْتَشِفْ مَهَارَةً مِنَ الحَيَاةِ اليَوْمِيَّة.',
'music':'اِسْتَمِعْ إِلَى النَّغَمَاتِ، ثُمَّ اعْزِفْهَا بِالتَّرْتِيبِ نَفْسِه.',
'great':'أَحْسَنْتَ!','again':'جَرِّبْ طَرِيقَةً أُخْرَى.','welcome':'قَلِيلٌ مِنَ الدَّهْشَةِ، كُلَّ يَوْم.'}
VOCABULARY=['قِطَّة','كَلْب','أَرْنَب','ثَعْلَب','دُبّ','أَسَد','فِيل','زَرَافَة','سُلَحْفَاة','سَمَكَة',
            'طَائِر','بُومَة','بِطْرِيق','فَرَاشَة','نَحْلَة','حَلَزُون','أُخْطُبُوط','حُوت','ضِفْدَع','قُنْفُذ',
            'تُفَّاحَة','كُمَّثْرَى','مَوْزَة','فَرَاوْلَة','جَزَرَة','بُرْتُقَالَة','بِطِّيخَة','خُبْز','كَعْكَة','كُوب',
            'سَيَّارَة','حَافِلَة','قِطَار','قَارِب','صَارُوخ','طَائِرَة','دَرَّاجَة','جَرَّار',
            'شَجَرَة','زَهْرَة','شَمْس','قَمَر','نَجْمَة','سَحَابَة','قَوْس قُزَح','وَرَقَة','جَبَل','فِطْر',
            'بَيْت','كِتَاب','قَلَم','كُرَة','طَائِرَة وَرَقِيَّة','مِظَلَّة','سَاعَة','مِفْتَاح','غِيتَار','طَبْل','بِيَانُو','جَرَس']

def bare(text): return ''.join(c for c in text if '\u0621'<=c<='\u064a' and c!='ـ')

def forms(letter):
    return [letter+'\u200d', '\u200d'+letter+'\u200d', '\u200d'+letter] if letter not in RIGHT_ONLY else [letter,'\u200d'+letter]

def lesson(index):
    if index<28:
        letter=LETTERS[index]
        return {'kind':'name','target':letter,'display':'','spokenOnly':True,'cue':f'letter_{index}.mp3',
                'question':'استمع إلى اسم الحرف واختره.','choices':[letter]+[LETTERS[(index+k)%28] for k in (5,11,17)]}
    if index<56:
        letter=LETTERS[index-28]
        return {'kind':'forms','target':letter,'display':'   '.join(forms(letter)),'spokenOnly':False,
                'cue':f'letter_{index-28}.mp3','question':'ما الحرف الذي تراه في هذه الأشكال؟',
                'choices':[letter]+[LETTERS[(index-28+k)%28] for k in (5,11,17)]}
    if index<79:
        j=index-56
        if j==22:
            return {'kind':'ligature','target':'لا','display':'ل + ا = ؟','spokenOnly':False,'cue':'lam_alif.mp3',
                    'question':'اختر شكل اللام والألف معًا.','choices':['لا','بل','با','لن']}
        letter=DUAL[j]
        # Real neighbours shape the target; its medial form is also shown separately.
        return {'kind':'medial','target':letter,'display':'ب'+letter+'ت'+'   '+forms(letter)[1],
                'spokenOnly':False,'cue':f'letter_{LETTERS.index(letter)}.mp3',
                'question':'ما الحرف في وسط هذا المقطع؟','choices':[letter]+[LETTERS[(LETTERS.index(letter)+k)%28] for k in (5,11,17)]}
    j=index-79
    consonant=LETTERS[1+j//3];vowel=j%3;target=consonant+VOWELS[vowel]
    return {'kind':'short-vowel','target':target,'display':'','spokenOnly':True,'cue':f'syllable_{j}.mp3',
            'question':'استمع إلى صوت الحرف مع الحركة، ثم اختره.',
            'choices':[consonant+v for v in VOWELS]+[LETTERS[1+(j//3+1)%27]+VOWELS[vowel]],
            'consonant':consonant,'vowel':VOWELS[vowel]}

# Authored contextual skeletons use a common y=120 baseline. Joined body segments
# meet there; letters ا د ر و break the pen path before the following letter.
# These are motor guides, not font outlines or a claim of calligraphic certification.
BODIES={
'ب':{'initial':[[170,85],[165,120],[0,120]],'medial':[[200,120],[160,120],[152,88],[145,120],[0,120]],'final':[[200,120],[165,120],[153,150],[110,166],[64,160],[35,135],[35,93]]},
'ن':{'initial':[[170,85],[165,120],[0,120]],'medial':[[200,120],[160,120],[152,88],[145,120],[0,120]],'final':[[200,120],[165,120],[153,157],[109,177],[65,171],[35,145],[35,99]]},
'ك':{'initial':[[175,35],[110,79],[158,113],[118,120],[0,120]],'medial':[[200,120],[165,120],[112,79],[174,35],[112,79],[149,111],[112,120],[0,120]],'final':[[200,120],[163,120],[163,28],[163,153],[58,156],[35,133],[35,104]]},
'ل':{'initial':[[160,28],[160,120],[0,120]],'medial':[[200,120],[160,120],[160,28],[160,120],[0,120]],'final':[[200,120],[155,120],[155,28],[155,143],[126,173],[82,180],[46,159],[40,118]]},
'م':{'initial':[[167,120],[144,90],[115,101],[125,128],[167,120],[0,120]],'medial':[[200,120],[167,120],[144,90],[115,101],[125,128],[167,120],[0,120]],'final':[[200,120],[157,120],[144,91],[118,99],[125,127],[157,120],[77,128],[65,182]]},
'س':{'initial':[[180,84],[177,120],[150,120],[141,90],[135,120],[108,120],[97,88],[90,120],[0,120]],'medial':[[200,120],[180,120],[177,85],[171,120],[149,120],[141,90],[135,120],[108,120],[97,88],[90,120],[0,120]],'final':[[200,120],[181,120],[177,86],[170,120],[149,120],[141,90],[135,120],[110,120],[98,88],[88,146],[61,173],[31,164],[23,130]]},
'ا':{'final':[[200,120],[113,120],[113,29]]},
'د':{'final':[[200,120],[156,120],[106,66],[156,120],[140,143],[62,145]]},
'ر':{'final':[[200,120],[153,120],[144,75],[153,120],[136,157],[94,181],[45,178]]},
'و':{'final':[[200,120],[149,120],[151,72],[133,53],[106,73],[110,103],[149,103],[149,134],[111,172],[53,180]]},
}
BODIES['ت']=BODIES['ب'];BODIES['ث']=BODIES['ب'];BODIES['ي']=BODIES['ن']
# Ascenders start at the top in their own stroke, avoiding an up/down retrace.
BODIES['ا']['final']=[[200,120],[113,120]]
BODIES['ل']['medial']=[[200,120],[0,120]]
BODIES['ل']['final']=[[200,120],[155,120],[155,143],[126,173],[82,180],[46,159],[40,118]]
BODIES['ك']['medial']=[[200,120],[118,120],[0,120]]
BODIES['ك']['final']=[[200,120],[163,120],[163,153],[58,156],[35,133],[35,104]]
BODIES['ر']['final']=[[200,120],[153,120],[136,157],[94,181],[45,178]]
EXTRAS={('ا','final'):[[[113,29],[113,120]]],
        ('ل','medial'):[[[160,28],[160,120]]],('ل','final'):[[[155,28],[155,120]]],
        ('ك','medial'):[[[175,35],[110,79],[158,113],[118,120]]],
        ('ك','final'):[[[163,28],[163,120]],[[126,67],[104,80],[123,92],[89,109]]]}
DOTS={'ب':[[[110,154],[116,154]]],'ت':[[[105,59],[111,59]],[[135,59],[141,59]]],
      'ث':[[[105,59],[111,59]],[[135,59],[141,59]],[[120,37],[126,37]]],
      'ن':[[[120,60],[126,60]]],'ي':[[[99,197],[105,197]],[[127,197],[133,197]]]}

def connected_strokes(word,isolated):
    letters=bare(word);count=len(letters);strokes=[];body=[];joins=[];marks=[]
    for j,c in enumerate(letters):
        incoming=j>0 and letters[j-1] not in RIGHT_ONLY
        outgoing=j<count-1 and c not in RIGHT_ONLY
        form='medial' if incoming and outgoing else 'final' if incoming else 'initial' if outgoing else 'isolated'
        joins.append({'letter':c,'form':form,'joinsNext':outgoing})
        paths=isolated[c] if form=='isolated' else [BODIES[c][form]]
        # Isolated dots are already in their authored paths; contextual dots are deferred.
        if form!='isolated':
            paths=paths+EXTRAS.get((c,form),[])+DOTS.get(c,[])
        def transform(path):
            return [[round(10+(count-1-j)*200/count+x/count,2),round(y*.82+12,2)] for x,y in path]
        primary=transform(paths[0])
        if incoming and body and primary[0]==body[-1]:body.extend(primary[1:])
        else:
            if body:strokes.append(body)
            body=primary
        for path in paths[1:]:marks.append(transform(path))
        if not outgoing:
            strokes.append(body);body=[]
    if body:strokes.append(body)
    return strokes+marks,joins

def legacy_tracing(index,isolated,sequence):
    if index<28:
        letter=LETTERS[index]
        return {'glyph':letter,'strokes':sequence([letter],isolated,True),'direction':'rtl','arabicLesson':'isolated'},f'letter_{index}.mp3'
    if index<56:
        j=index-28
        if j<27:
            letter=LETTERS[j+1];glyph=letter+'َ';paths=isolated[letter]+[[[125,12],[96,23]]]
            return {'glyph':glyph,'strokes':sequence([letter],{letter:paths},True),'direction':'rtl','arabicLesson':'fatha'},f'syllable_{j*3}.mp3'
        paths=isolated['ا']+[[[87,18],[99,11],[119,20],[134,13]]]
        return {'glyph':'آ','strokes':sequence(['ا'],{'ا':paths},True),'direction':'rtl','arabicLesson':'long-alif'},'long_alif.mp3'
    text=WORDS[index-56];strokes,joins=connected_strokes(text,isolated)
    return {'glyph':bare(text),'strokes':strokes,'direction':'rtl','arabicLesson':'word','joins':joins},f'trace_word_{index-56}.mp3'

def tracing(index,isolated,sequence):
    import json
    from pathlib import Path
    from arabic_handwriting import trace
    previous,cue=legacy_tracing(index,isolated,sequence)
    revised=trace(index,LETTERS,WORDS,RIGHT_ONLY)
    prior=json.loads((Path(__file__).parent/'data/arabic_trace_revision2.json').read_text())
    return {**previous,**revised,'legacyStrokes':previous['strokes'],
            'previousTraceRevisions':{'2':prior[str(index)]}},cue

def audio():
    result={f'letter_{i}.mp3':text for i,text in enumerate(NAMES)}
    result.update({f'syllable_{i*3+v}.mp3':c+mark for i,c in enumerate(LETTERS[1:]) for v,mark in enumerate(VOWELS)})
    result.update({f'trace_word_{i}.mp3':text for i,text in enumerate(WORDS)})
    result.update({'lam_alif.mp3':'لَام وَأَلِف. لَا.','long_alif.mp3':'أَلِف مَدّ. آ.'})
    return result
