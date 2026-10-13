#!/usr/bin/env python3
"""Back up the existing upload key and its plain-text recovery information locally."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--destination', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    source = root / 'android/key.properties'
    properties = dict(line.split('=', 1) for line in source.read_text().splitlines()
                      if '=' in line and not line.lstrip().startswith('#'))
    key = Path(properties['storeFile']).expanduser()
    if not key.is_absolute():
        key = root / 'android/app' / key
    if not key.is_file():
        raise SystemExit('Existing upload keystore missing; no replacement key was created.')
    timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    destination = (args.destination or Path.home() / '.config/pikolumi/signing/backups' / timestamp).resolve()
    if destination.is_relative_to(root):
        raise SystemExit('Signing backups must be outside the project and Git repository.')
    destination.mkdir(parents=True, mode=0o700, exist_ok=False)
    destination.chmod(0o700)
    for name, original in [('pikolumi-upload.jks', key), ('key.properties', source)]:
        shutil.copy2(original, destination / name)
        (destination / name).chmod(0o600)
    keytool = shutil.which('keytool')
    if not keytool:
        candidate = Path('/opt/homebrew/opt/openjdk@25/bin/keytool')
        keytool = str(candidate) if candidate.exists() else None
    if not keytool:
        raise SystemExit('JKS/configuration copied; install a JDK to export the remaining recovery files.')
    env = os.environ.copy()
    env.update(PIKO_STORE_PASS=properties['storePassword'],
               PIKO_KEY_PASS=properties['keyPassword'])

    def run(command):
        return subprocess.run(command, env=env, capture_output=True, check=True, text=True).stdout

    p12 = destination / 'pikolumi-upload.p12'
    run([keytool, '-importkeystore', '-srckeystore', str(key),
         '-srcstorepass:env', 'PIKO_STORE_PASS', '-srckeypass:env', 'PIKO_KEY_PASS',
         '-srcalias', properties['keyAlias'], '-destkeystore', str(p12),
         '-deststoretype', 'PKCS12', '-deststorepass:env', 'PIKO_STORE_PASS',
         '-destkeypass:env', 'PIKO_STORE_PASS', '-noprompt'])
    p12.chmod(0o600)
    pem = destination / 'pikolumi-upload-private-key-and-certificate.pem'
    run(['openssl', 'pkcs12', '-in', str(p12), '-passin', 'env:PIKO_STORE_PASS',
         '-nodes', '-out', str(pem)])
    pem.chmod(0o600)
    run(['openssl', 'pkey', '-in', str(pem), '-check', '-noout'])
    certificate = destination / 'pikolumi-upload-certificate.pem'
    run([keytool, '-exportcert', '-rfc', '-keystore', str(key),
         '-storepass:env', 'PIKO_STORE_PASS', '-alias', properties['keyAlias'],
         '-file', str(certificate)])
    certificate.chmod(0o600)
    details = run([keytool, '-list', '-v', '-keystore', str(key),
                   '-storepass:env', 'PIKO_STORE_PASS', '-alias', properties['keyAlias']])
    recovery = destination / 'ANDROID-SIGNING-RECOVERY.txt'
    recovery.write_text('Pikolumi Android signing recovery\n'
                        'Package: com.seifelmoulouk.pikolumi\n\n'
                        + source.read_text() + '\n' + details
                        + '\nRestore android/key.properties with the recovered JKS path. '
                        'Retain this key for updates. The PEM is an unencrypted private key. '
                        'Keep all these files outside source control.\n')
    recovery.chmod(0o600)
    files = {p.name: {'bytes': p.stat().st_size,
                     'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
             for p in destination.iterdir() if p.is_file()}
    manifest = destination / 'manifest.json'
    manifest.write_text(json.dumps({'createdAtUTC': timestamp,
                                   'package': 'com.seifelmoulouk.pikolumi',
                                   'files': files}, indent=2) + '\n')
    manifest.chmod(0o600)
    print(f'Existing signing key backed up and verified: {destination}')


if __name__ == '__main__':
    main()
