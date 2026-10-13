#!/usr/bin/env python3
"""Inspect exact signed packages; SDK declarations are not a traffic capture."""
import argparse
import hashlib
import json
import plistlib
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'
IDENTIFIER = 'com.seifelmoulouk.pikolumi'
FORBIDDEN_PERMISSIONS = {
    'com.google.android.gms.permission.AD_ID',
    'android.permission.ACCESS_ADSERVICES_AD_ID',
    'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
    'android.permission.ACCESS_ADSERVICES_TOPICS',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.READ_PHONE_STATE',
    'android.permission.READ_CONTACTS',
    'android.permission.CAMERA',
    'android.permission.RECORD_AUDIO',
}


def artifact(path):
    return {
        'path': str(path.resolve().relative_to(ROOT)),
        'bytes': path.stat().st_size,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def check_assets(archive, prefix):
    paths = [p for p in (ROOT / 'assets').rglob('*') if p.is_file()]
    for path in paths:
        name = prefix + str(path.relative_to(ROOT))
        assert archive.read(name) == path.read_bytes(), name
    return len(paths)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--aab', type=Path, required=True)
    parser.add_argument('--ipa', type=Path, required=True)
    parser.add_argument('--bundletool', type=Path, required=True)
    parser.add_argument('--java', default='java')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    config = json.loads((ROOT / 'config/ads.json').read_text())
    assert config['ADS_PRODUCTION'] is False
    assert config['IOS_KIDS_ADS_VERIFIED'] is False
    android = artifact(args.aab)
    xml = subprocess.run([
        args.java, '-jar', str(args.bundletool), 'dump', 'manifest',
        '--bundle=' + str(args.aab),
    ], check=True, capture_output=True, text=True).stdout
    manifest = ET.fromstring(xml)
    assert manifest.get('package') == IDENTIFIER
    permissions = sorted({p.get(ANDROID + 'name') for p in
                          manifest.findall('uses-permission')})
    assert not (set(permissions) & FORBIDDEN_PERMISSIONS)
    application = manifest.find('application')
    assert application.get(ANDROID + 'allowBackup') == 'false'
    assert application.get(ANDROID + 'usesCleartextTraffic', 'false') == 'false'
    metadata = {e.get(ANDROID + 'name'): e.get(ANDROID + 'value')
                for e in application.findall('meta-data')}
    assert metadata['com.google.android.gms.ads.APPLICATION_ID'] == config['ANDROID_APP_ID']
    with zipfile.ZipFile(args.aab) as archive:
        properties = dict(line.split('=', 1) for line in archive.read(
            'base/root/play-services-ads.properties').decode().splitlines())
        assert properties['version'] == '25.5.0'
        android['bundledAssetFilesVerified'] = check_assets(archive, 'base/assets/flutter_assets/')
    android.update({
        'googleMobileAdsVersion': properties['version'],
        'permissions': permissions,
        'advertisingIdAndLocationPermissionsAbsent': True,
        'backupDisabled': True,
        'cleartextTrafficDisabled': True,
        'minimumSDK': manifest.find('uses-sdk').get(ANDROID + 'minSdkVersion'),
        'targetSDK': manifest.find('uses-sdk').get(ANDROID + 'targetSdkVersion'),
        'admobAppId': metadata['com.google.android.gms.ads.APPLICATION_ID'],
    })
    ios = artifact(args.ipa)
    with zipfile.ZipFile(args.ipa) as archive:
        main_info = next(n for n in archive.namelist() if
                         n.startswith('Payload/') and n.count('/') == 2 and n.endswith('/Info.plist'))
        app_prefix = main_info.removesuffix('Info.plist')
        info = plistlib.loads(archive.read(main_info))
        assert info['CFBundleIdentifier'] == IDENTIFIER
        assert info['GADApplicationIdentifier'] == config['IOS_APP_ID']
        assert info['GADDelayAppMeasurementInit'] is True
        assert 'NSUserTrackingUsageDescription' not in info
        versions = {n: plistlib.loads(archive.read(n))['CFBundleShortVersionString']
                    for n in archive.namelist() if n.endswith('/Info.plist') and
                    any(f in n for f in ['GoogleMobileAds.framework/', 'UserMessagingPlatform.framework/'])}
        privacy = {n: plistlib.loads(archive.read(n)) for n in archive.namelist()
                   if n.endswith('/PrivacyInfo.xcprivacy')}
        assert len(versions) == 2 and privacy
        ios['bundledAssetFilesVerified'] = check_assets(archive, app_prefix + 'Frameworks/App.framework/flutter_assets/')
        with tempfile.TemporaryDirectory(prefix='pikolumi-privacy-') as folder:
            archive.extractall(folder)
            subprocess.run(['codesign', '--verify', '--deep', '--strict',
                            str(Path(folder) / app_prefix)], check=True, capture_output=True)
    ios.update({'sdkVersions': versions, 'privacyManifests': privacy,
                'admobAppId': info['GADApplicationIdentifier'],
                'trackingUsageDescriptionAbsent': True,
                'measurementInitializationDelayed': True,
                'distributionSignatureVerified': True})
    report = {
        'checkedAtUTC': datetime.now(timezone.utc).isoformat(),
        'bundleIdentifier': IDENTIFIER,
        'testAdsOnly': True,
        'submitted': False,
        'android': android,
        'ios': ios,
        'runtimeTrafficInspected': False,
        'appleKidsAdvertisingExceptionVerified': False,
        'sources': [
            'https://developers.google.com/admob/android/privacy/play-data-disclosure',
            'https://developers.google.com/admob/ios/privacy/data-disclosure?hl=en',
            'https://support.google.com/googleplay/android-developer/answer/12955712?hl=en',
            'https://developer.apple.com/app-store/review/guidelines/#kids-category',
        ],
    }
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print('Exact package versions, privacy manifests, permissions, assets and iOS signature audited.')


if __name__ == '__main__':
    main()
