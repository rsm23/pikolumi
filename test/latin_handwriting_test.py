"""Curriculum regressions for manuscript direction and uniform letter layout."""
import json, unittest
import math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class LatinHandwritingTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.traces=[e for e in json.loads((ROOT/'assets/content/catalog.json').read_text())['activities'] if e['section']=='tracing']
 def test_every_model_has_complete_ordered_offline_narration(self):
  audio=json.loads((ROOT/'assets/content/audio_manifest.json').read_text())
  alphabets={lang:[e['config']['locales'][lang]['glyph'] for e in self.traces[:80] if len(e['config']['locales'][lang]['glyph'].split())==1] for lang in ['en','fr','es','pt']}
  for activity in self.traces[:80]:
   for lang,cfg in activity['config']['locales'].items():
    cues=cfg.get('traceCues',[activity['cue'][lang]])
    if lang!='ar':
     self.assertEqual(cues,[f'letter_{alphabets[lang].index(glyph)}.mp3' for glyph in cfg['glyph'].split()])
    for cue in cues:
     self.assertIn(cue,audio[lang])
     self.assertTrue((ROOT/'assets/audio'/lang/cue).is_file())
 def test_a_has_two_downstrokes_then_crossbar(self):
  for lang in ['en','fr','es','pt']:
   cfg=self.traces[0]['config']['locales'][lang];p=cfg['strokes']
   self.assertEqual(len(p),3,lang)
   self.assertLess(p[0][0][1],p[0][-1][1],lang)
   self.assertLess(p[1][0][1],p[1][-1][1],lang)
   self.assertLess(p[2][0][0],p[2][-1][0],lang)
 def test_spines_start_at_top(self):
  for i in [1,3,4,5,7,8,10,12,13,15,17]:
   cfg=self.traces[i]['config']['locales']['en'];p=cfg['strokes'][0]
   self.assertLess(p[0][1],p[-1][1],cfg['glyph'])
 def test_sequences_keep_letter_aspect_ratios(self):
  def ratio(paths):
   pts=[p for s in paths for p in s];return (max(p[0] for p in pts)-min(p[0] for p in pts))/(max(p[1] for p in pts)-min(p[1] for p in pts))
  single=self.traces[0]['config']['locales']['en']['strokes']
  seq=self.traces[26]['config']['locales']['en']['strokes']
  self.assertAlmostEqual(ratio(single),ratio(seq[:len(single)]),places=3)
 def test_all_glyphs_keep_their_shape_spacing_and_accents(self):
  singles={}
  for lang in ['en','fr','es','pt']:
   for e in self.traces[:80]:
    cfg=e['config']['locales'][lang]
    for glyph,(start,end) in zip(cfg['glyph'].split(),cfg['glyphStrokeRanges']):
     pts=[p for path in cfg['strokes'][start:end] for p in path]
     width=max(p[0] for p in pts)-min(p[0] for p in pts);height=max(p[1] for p in pts)-min(p[1] for p in pts)
     ratio=width/height
     if glyph in singles:self.assertAlmostEqual(ratio,singles[glyph],delta=.0001,msg=f'{lang}: {cfg["glyph"]}')
     else:singles[glyph]=ratio
     self.assertTrue(all(0<=v<=220 for p in pts for v in p))
     kinds=cfg['strokeKinds'][start:end]
     self.assertEqual(kinds[-1]=='accent',glyph in 'ÑÉÈÊÇÁÃÍÓÕÚ')
     if kinds[-1]=='accent':
      body=[p for s in cfg['strokes'][start:end-1] for p in s];accent=cfg['strokes'][end-1]
      if glyph=='Ç':self.assertGreater(max(p[1] for p in accent),max(p[1] for p in body))
      else:self.assertLess(max(p[1] for p in accent),min(p[1] for p in body))
    for path in cfg['strokes']:
     self.assertLessEqual(max(math.dist(a,b) for a,b in zip(path,path[1:])),5)
  self.assertEqual(len(singles),37)
 def test_closed_round_models_and_expected_pen_lifts(self):
  expected=[3,2,1,2,4,3,1,3,3,2,2,1,2,2,1,2,2,2,1,2,1,1,1,2,2,1]
  for i,count in enumerate(expected):self.assertEqual(len(self.traces[i]['config']['locales']['en']['strokes']),count)
  for index in [14,16,80]:
   cfg=self.traces[index]['config'];cfg=cfg['locales']['en'] if 'locales' in cfg else cfg
   path=cfg['strokes'][0];self.assertEqual(path[0],path[-1])
   area=sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(path,path[1:]))
   self.assertLess(area,0)
if __name__=='__main__':unittest.main()
