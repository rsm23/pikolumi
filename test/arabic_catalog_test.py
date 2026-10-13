"""Curriculum contracts: coverage and joins, independent of answer ordering."""
import collections
import json
from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import arabic_curriculum as ar

class ArabicCurriculumTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=json.loads((ROOT/'assets/content/catalog.json').read_text())

    def test_every_consonant_has_three_distinct_short_vowels(self):
        lessons=[ar.lesson(i) for i in range(160)]
        sounds=[x for x in lessons if x['kind']=='short-vowel']
        self.assertEqual({x['target'] for x in sounds},{c+v for c in ar.LETTERS[1:] for v in ar.VOWELS})
        self.assertEqual(len(sounds),81)
        for lesson in sounds:
            self.assertEqual(len(set(lesson['choices'])),4)
            self.assertEqual(lesson['target'],lesson['consonant']+lesson['vowel'])
            self.assertEqual(ar.audio()[lesson['cue']],lesson['target'])

    def test_form_curriculum_respects_six_right_joining_letters(self):
        self.assertEqual(ar.RIGHT_ONLY,set('ادذرزو'))
        self.assertEqual(len(ar.DUAL),22)
        for c in ar.LETTERS:
            f=ar.forms(c)
            self.assertEqual(len(f),2 if c in ar.RIGHT_ONLY else 3)
            if c in ar.RIGHT_ONLY:
                self.assertEqual(f,[c,'\u200d'+c])
            else:
                self.assertEqual(f,[c+'\u200d','\u200d'+c+'\u200d','\u200d'+c])

    def test_word_traces_have_real_contexts_and_pen_breaks(self):
        traces=[x['config']['locales']['ar'] for x in self.catalog['activities']
                if x['section']=='tracing' and x['config'].get('locales',{}).get('ar',{}).get('arabicLesson')=='word']
        self.assertEqual(len(traces),24)
        self.assertEqual(len({x['glyph'] for x in traces}),24)
        observed=set()
        for trace in traces:
            letters=trace['glyph'];joins=trace['joins']
            self.assertEqual(''.join(x['letter'] for x in joins),letters)
            for j,join in enumerate(joins):
                incoming=j>0 and letters[j-1] not in ar.RIGHT_ONLY
                outgoing=j<len(letters)-1 and letters[j] not in ar.RIGHT_ONLY
                form='medial' if incoming and outgoing else 'final' if incoming else 'initial' if outgoing else 'isolated'
                self.assertEqual(join['form'],form)
                self.assertEqual(join['joinsNext'],outgoing)
                observed.add(form)
            groups=1+sum(c in ar.RIGHT_ONLY for c in letters[:-1])
            # Every connected body is one path, with dots/marks as extra paths.
            self.assertGreaterEqual(len(trace['strokes']),groups)
            for path in trace['strokes']:
                self.assertGreaterEqual(len(path),2)
                self.assertTrue(all(0<=x<=220 and 0<=y<=220 for x,y in path))
        self.assertEqual(observed,{'isolated','initial','medial','final'})

    def test_catalog_retains_stable_id_counts_and_arabic_cue_contract(self):
        activities=self.catalog['activities']
        self.assertEqual(len(activities),2400)
        self.assertEqual(len({x['id'] for x in activities}),2400)
        letter_activities=[x for x in activities if x['section']=='letters']
        kinds=collections.Counter(x['config']['locales']['ar']['arabicLesson'] for x in letter_activities)
        self.assertEqual(kinds,{'name':28,'forms':28,'medial':22,'ligature':1,'short-vowel':81})
        for activity in letter_activities:
            self.assertIn(activity['cue']['ar'],ar.audio())

if __name__=='__main__':unittest.main()
