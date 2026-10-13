"""Release evidence is platform-specific and never inferred from simulator checks."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import build_release as release


class ReleaseGateTests(unittest.TestCase):
    def satisfied(self, platform):
        return {key: True for key in release.COMMON_GATES + release.PLATFORM_GATES[platform]}

    def test_android_is_independent_of_ios_hardware_and_ad_exception(self):
        evidence = self.satisfied('android')
        evidence.update({key: False for key in release.PLATFORM_GATES['ios']})
        self.assertEqual(release.missing_gates(evidence, 'android'), [])
        self.assertIn('physicalIOSQA', release.missing_gates(evidence, 'ios'))
        self.assertIn('appleKidsAdExceptionVerified', release.missing_gates(evidence, 'ios'))

    def test_ios_requires_its_own_ad_exception_without_android_dependencies(self):
        evidence = self.satisfied('ios')
        evidence.update({key: False for key in release.PLATFORM_GATES['android']})
        self.assertEqual(release.missing_gates(evidence, 'ios'), [])
        evidence['appleKidsAdExceptionVerified'] = False
        self.assertEqual(release.missing_gates(evidence, 'ios'), ['appleKidsAdExceptionVerified'])

    def test_legacy_aggregates_and_truthy_values_cannot_approve_a_release(self):
        evidence = {key: True for key in release.COMMON_GATES}
        evidence.update(phoneTabletQA=True, privacyDeclarationsReviewed=True, adDismissalVerified=True)
        self.assertEqual(release.missing_gates(evidence, 'android'), list(release.PLATFORM_GATES['android']))
        evidence = self.satisfied('android')
        evidence['pronunciationReviewed'] = 'true'
        self.assertEqual(release.missing_gates(evidence, 'android'), ['pronunciationReviewed'])

    def test_incomplete_evidence_prevents_production_config_and_build(self):
        with tempfile.TemporaryDirectory(prefix='pikolumi-gates-') as directory:
            root = Path(directory)
            (root / 'docs/release').mkdir(parents=True)
            (root / 'docs/release/readiness.json').write_text(json.dumps({}))
            with patch.object(release, 'ROOT', root), patch.object(release.subprocess, 'run') as run:
                with self.assertRaisesRegex(SystemExit, 'Public release held'):
                    release.main(['android'])
                run.assert_not_called()
                self.assertFalse((root / 'config/production.local.json').exists())


if __name__ == '__main__':
    unittest.main()
