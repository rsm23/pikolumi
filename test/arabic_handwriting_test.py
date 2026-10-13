"""Regression checks for the reported upward strokes and compressed word guides."""
import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class ArabicHandwritingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        catalog=json.loads((ROOT/'assets/content/catalog.json').read_text())
        cls.traces=[e['config']['locales']['ar'] for e in catalog['activities']
                    if e['section']=='tracing' and 'locales' in e['config']]

    def test_tah_and_zah_ascenders_go_from_top_to_baseline(self):
        for index in [15,16,42,43]:
            paths=self.traces[index]['strokes']
            vertical=[p for p in paths if max(x for x,y in p)-min(x for x,y in p)<5
                      and max(y for x,y in p)-min(y for x,y in p)>60]
            self.assertEqual(len(vertical),1)
            self.assertLess(vertical[0][0][1],vertical[0][-1][1])

    def test_word_letters_keep_isolated_proportions(self):
        # The three letters of ورد cannot join; compare و alone and within the word.
        single=self.traces[26]['strokes'][0]
        word=self.traces[74]['strokes'][0]
        def ratio(points):
            return ((max(x for x,y in points)-min(x for x,y in points)) /
                    (max(y for x,y in points)-min(y for x,y in points)))
        self.assertAlmostEqual(ratio(single),ratio(word),places=3)

    def test_letter_eyes_close_and_ha_mim_loops_are_clockwise(self):
        for index in [19,20,26]:
            path=self.traces[index]['strokes'][0]
            self.assertIn(path[0],path[1:],msg=self.traces[index]['glyph'])
        for index in [23,25]:
            path=self.traces[index]['strokes'][0]
            self.assertEqual(path[0],path[-1])
            signed_area=sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(path,path[1:]))
            self.assertGreater(signed_area,0)  # Clockwise in canvas y-down coordinates.

    def test_all_arabic_paths_have_complete_ordered_body_and_marks(self):
        self.assertEqual(len(self.traces),80)
        dot_counts=[0,1,2,3,1,0,1,0,1,0,1,0,3,0,1,0,1,0,1,1,2,0,0,0,1,0,0,2]
        for index,trace in enumerate(self.traces):
            kinds=trace.get('strokeKinds',[])
            self.assertEqual(len(kinds),len(trace['strokes']))
            self.assertIn('body',kinds)
            if index<28:self.assertEqual(kinds.count('dot'),dot_counts[index])
            if 28<=index<56:self.assertEqual(kinds.count('vowel'),1)
            if 'dot' in kinds:
                self.assertNotIn('body',kinds[kinds.index('dot'):])
            self.assertTrue(all(len(path)>=2 for path in trace['strokes']))
            self.assertTrue(all(0<=x<=220 and 0<=y<=220 for path in trace['strokes'] for x,y in path))

if __name__=='__main__':unittest.main()
