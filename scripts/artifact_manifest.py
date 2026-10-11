#!/usr/bin/env python3
"""Record the exact local QA packages without implying release approval."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['Pikolumi-1.0.0-QA.apk', 'Pikolumi-1.0.0-QA.aab',
         'Pikolumi-1.0.0-QA.ipa', 'Pikolumi-1.0.0-Simulator.zip']
config = json.loads((ROOT / 'config/ads.json').read_text())
assert config['ADS_PRODUCTION'] is False
assert config['IOS_KIDS_ADS_VERIFIED'] is False
artifacts = []
if (ROOT / 'output/qa/Pikolumi-1.0.0-Pixel-QA.apk').is_file():
    NAMES.append('Pikolumi-1.0.0-Pixel-QA.apk')
for name in NAMES:
    path = ROOT / 'output/qa' / name
    artifacts.append({'path': str(path.relative_to(ROOT)),
                      'bytes': path.stat().st_size,
                      'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
source = hashlib.sha256()
paths = [ROOT / name for name in ['pubspec.yaml', 'pubspec.lock', 'config/ads.json', 'config/qa-export-options.plist', 'android/app/build.gradle.kts', 'android/gradle.properties', 'android/settings.gradle.kts', 'android/gradle/wrapper/gradle-wrapper.properties']]
for folder in ['lib', 'assets', 'android/app/src/main', 'ios/Runner']:
    paths.extend(p for p in (ROOT / folder).rglob('*') if p.is_file() and not p.name.startswith('GeneratedPluginRegistrant'))
paths.append(ROOT / 'ios/Runner.xcodeproj/project.pbxproj')
for path in sorted(paths):
    source.update(str(path.relative_to(ROOT)).encode())
    source.update(hashlib.sha256(path.read_bytes()).digest())
result = {'builtAtUTC': datetime.now(timezone.utc).isoformat(),
          'bundleIdentifier': 'com.seifelmoulouk.pikolumi',
          'version': '1.0.0', 'build': 1, 'testAdsOnly': True,
          'submitted': False, 'sourceDigest': source.hexdigest(),
          'artifacts': artifacts}
(ROOT / 'docs/release/qa-artifacts.json').write_text(json.dumps(result, indent=2) + '\n')
print('Recorded QA artifacts and SHA-256 hashes; no submission performed.')
