#!/usr/bin/env python3
"""Archive SDK declarations from the exact signed QA IPA, without inferring traffic."""
import hashlib
import json
import plistlib
import re
import subprocess
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'docs/release/qa-artifacts.json').read_text())
artifact = next(a for a in manifest['artifacts'] if a['path'].endswith('.ipa'))
path = ROOT / artifact['path']
assert hashlib.sha256(path.read_bytes()).hexdigest() == artifact['sha256']
with zipfile.ZipFile(path) as archive:
    versions = {
        name: plistlib.loads(archive.read(name))['CFBundleShortVersionString']
        for name in archive.namelist()
        if name.endswith('/Info.plist') and any(
            framework in name for framework in
            ['GoogleMobileAds.framework/', 'UserMessagingPlatform.framework/']
        )
    }
    privacy = {
        name: plistlib.loads(archive.read(name))
        for name in archive.namelist() if name.endswith('/PrivacyInfo.xcprivacy')
    }
assert len(versions) == 2 and privacy
android = next(a for a in manifest['artifacts'] if a['path'].endswith('-QA.apk'))
android_path = ROOT / android['path']
assert hashlib.sha256(android_path.read_bytes()).hexdigest() == android['sha256']
aapt = Path.home() / 'Library/Android/sdk/build-tools/36.0.0/aapt'
permission_dump = subprocess.run(
    [str(aapt), 'dump', 'permissions', str(android_path)],
    capture_output=True, text=True, check=True,
).stdout
permissions = re.findall(r"uses-permission: name='([^']+)'", permission_dump)
for forbidden in [
    'com.google.android.gms.permission.AD_ID',
    'android.permission.ACCESS_ADSERVICES_AD_ID',
    'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
    'android.permission.ACCESS_ADSERVICES_TOPICS',
]:
    assert forbidden not in permissions, f'Unexpected advertising permission: {forbidden}'
result = {
    'checkedAtUTC': datetime.now(timezone.utc).isoformat(),
    'artifact': artifact['path'],
    'artifactSha256': artifact['sha256'],
    'sourceDigest': manifest['sourceDigest'],
    'sdkVersions': versions,
    'privacyManifests': privacy,
    'androidManifest': {
        'artifact': android['path'],
        'artifactSha256': android['sha256'],
        'permissions': permissions,
        'advertisingIdentifierPermissionsAbsent': True,
        'runtimeDataCollectionVerified': False,
    },
    'sources': [
        'https://developers.google.com/admob/ios/privacy/data-disclosure',
        'https://developers.google.com/admob/android/privacy/play-data-disclosure',
    ],
    'findings': [
        'The bundled GoogleMobileAds privacy manifest declares linked coarse location, advertising data, product interaction and a tracking-linked device identifier category.',
        'The absence of ATT and the child-directed flags do not alone prove the absence of every SDK identifier or data collection path.',
        'These are SDK declarations from the signed QA IPA, not packet-capture proof of exact runtime collection or final store answers.',
    ],
    'finalPrivacyDeclarationsVerified': False,
}
(ROOT / 'docs/release/qa-privacy-manifest-audit.json').write_text(
    json.dumps(result, indent=2) + '\n'
)
print(f'Archived {len(privacy)} privacy manifests from the signed QA IPA.')
