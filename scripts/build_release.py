#!/usr/bin/env python3
"""A release build requires recorded evidence; QA has a separate path."""
import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMON_GATES = (
    'catalogValidated', 'contentReviewed', 'pronunciationReviewed',
    'assetRightsVerified', 'supportPagesPublished',
)
PLATFORM_GATES = {
    'android': (
        'physicalAndroidQA', 'androidPhoneTabletQA',
        'androidPrivacyDeclarationsReviewed', 'androidAdDismissalVerified',
        'androidFamiliesSDKVerified',
    ),
    'ios': (
        'physicalIOSQA', 'iosPhoneTabletQA',
        'iosPrivacyDeclarationsReviewed', 'iosAdDismissalVerified',
        'appleKidsAdExceptionVerified', 'iosSigningReady',
    ),
}


def missing_gates(evidence, platform):
    required = COMMON_GATES + PLATFORM_GATES[platform]
    return [key for key in required if evidence.get(key) is not True]


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('platform', choices=PLATFORM_GATES)
    args = parser.parse_args(argv)
    evidence = json.loads((ROOT / 'docs/release/readiness.json').read_text())
    failed = missing_gates(evidence, args.platform)
    if failed:
        raise SystemExit(
            'Public release held: ' + ', '.join(failed) +
            '. See docs/release/STATUS.md; no build/upload was attempted.'
        )
    config = json.loads((ROOT / 'config/ads.json').read_text())
    config['ADS_PRODUCTION'] = True
    config['IOS_KIDS_ADS_VERIFIED'] = args.platform == 'ios'
    config['SUPPORT_URL'] = evidence['supportURL']
    local = ROOT / 'config/production.local.json'
    local.write_text(json.dumps(config, indent=2) + '\n')
    subprocess.run([
        str(ROOT / 'scripts/flutter.sh'), 'build',
        'appbundle' if args.platform == 'android' else 'ipa', '--release',
        '--dart-define-from-file=' + str(local),
    ], cwd=ROOT, check=True)
    print('Artifact built. Submission, approval and public availability still require separate verified steps.')


if __name__ == '__main__':
    main()
