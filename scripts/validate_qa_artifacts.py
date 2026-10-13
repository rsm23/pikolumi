#!/usr/bin/env python3
"""Verify local test-ad packages, signatures and bundled source assets."""
import datetime
import hashlib
import json
import os
import plistlib
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'docs/release/qa-artifacts.json').read_text())
config = json.loads((ROOT / 'config/ads.json').read_text())
assert manifest['testAdsOnly'] and not manifest['submitted']
assert not config['ADS_PRODUCTION'] and not config['IOS_KIDS_ADS_VERIFIED']
for artifact in manifest['artifacts']:
    path = ROOT / artifact['path']
    assert path.stat().st_size == artifact['bytes']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == artifact['sha256']

java_home = Path('/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home')
environment = dict(os.environ, JAVA_HOME=str(java_home))
apk = ROOT / 'output/qa/Pikolumi-1.0.0-QA.apk'
aab = ROOT / 'output/qa/Pikolumi-1.0.0-QA.aab'
ipa = ROOT / 'output/qa/Pikolumi-1.0.0-QA.ipa'
log = ROOT / 'tmp/qa-artifact-validation.log'
log.parent.mkdir(exist_ok=True)
with log.open('w') as output:
    for command in [
        [str(Path.home() / 'Library/Android/sdk/build-tools/36.0.0/apksigner'), 'verify', '--verbose', str(apk)],
        [str(java_home / 'bin/jarsigner'), '-verify', str(aab)],
        [str(java_home / 'bin/java'), '-jar', str(ROOT / 'tmp/bundletool.jar'), 'validate', f'--bundle={aab}'],
    ]:
        subprocess.run(command, env=environment, stdout=output, stderr=subprocess.STDOUT, check=True)
    with tempfile.TemporaryDirectory(prefix='pikolumi-ipa-') as directory:
        with zipfile.ZipFile(ipa) as archive:
            archive.extractall(directory)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(Path(directory) / 'Payload/Runner.app')],
                       stdout=output, stderr=subprocess.STDOUT, check=True)

assets = [p for p in (ROOT / 'assets').rglob('*') if p.is_file() and not p.name.startswith('.')]
bundled = {}
packages = [
    ('android', apk, 'assets/flutter_assets/'),
    ('ios', ipa, 'Payload/Runner.app/Frameworks/App.framework/flutter_assets/'),
]
pixel = ROOT / 'output/qa/Pikolumi-1.0.0-Pixel-QA.apk'
if pixel.is_file():
    packages.append(('androidPixel', pixel, 'assets/flutter_assets/'))
for platform, package, prefix in packages:
    with zipfile.ZipFile(package) as archive:
        for path in assets:
            relative = str(path.relative_to(ROOT))
            assert archive.read(prefix + relative) == path.read_bytes(), f'{platform}: {relative} differs'
        bundled[platform] = {'bundledAssetFiles': len(assets), 'assetsMatchSource': True}
        if platform == 'ios':
            info = plistlib.loads(archive.read('Payload/Runner.app/Info.plist'))
            assert info['CFBundleIdentifier'] == manifest['bundleIdentifier']
            assert 'NSUserTrackingUsageDescription' not in info
            bundled[platform].update(bundleIdentifier=info['CFBundleIdentifier'], trackingUsageDescriptionPresent=False)
result = {
    'androidApkSignature': 'verified', 'androidBundleJarSignature': 'verified',
    'bundletoolVersion': '1.18.3', 'bundletoolValidation': 'passed',
    'iosExportedIpaSignature': 'verified_deep_strict', 'artifactSha256': 'verified',
    'uploaded': False, 'checkedAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'sourceDigest': manifest['sourceDigest'], 'bundledAssetsMatchSource': True,
    'catalogVersion': json.loads((ROOT / 'assets/content/catalog.json').read_text())['version'],
    'testAdsOnly': True,
}
(ROOT / 'docs/release/artifact-validation.json').write_text(json.dumps(result, indent=2) + '\n')
(ROOT / 'docs/release/bundled-assets-validation.json').write_text(json.dumps(bundled, indent=2) + '\n')
print(f'All package hashes and signatures verified; {len(assets)} bundled files match source on Android/iOS.')
