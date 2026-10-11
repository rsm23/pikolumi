#!/usr/bin/env python3
"""Create a dedicated local upload key once. Never print the password."""
from pathlib import Path
import secrets,os,subprocess
root=Path(__file__).resolve().parents[1]
folder=Path.home()/'.config/pikolumi/signing';folder.mkdir(parents=True,exist_ok=True);os.chmod(folder,0o700)
key=folder/'pikolumi-upload.jks';properties=root/'android/key.properties'
if properties.exists():
 print('Existing Pikolumi signing configuration preserved.');raise SystemExit(0)
if key.exists():raise SystemExit('Key already exists without configuration; restore its password instead of overwriting it.')
password=secrets.token_urlsafe(32)
env=os.environ.copy();env['PIKOLUMI_KEY_PASSWORD']=password
subprocess.run(['/opt/homebrew/opt/openjdk@25/bin/keytool','-genkeypair','-v','-keystore',str(key),'-storepass:env','PIKOLUMI_KEY_PASSWORD','-keypass:env','PIKOLUMI_KEY_PASSWORD','-alias','pikolumi-upload','-keyalg','RSA','-keysize','4096','-validity','10000','-dname','CN=Pikolumi Upload, OU=Mobile, O=Pikolumi, C=FR'],env=env,check=True,capture_output=True)
properties.write_text(f'storeFile={key}\nstorePassword={password}\nkeyPassword={password}\nkeyAlias=pikolumi-upload\n')
os.chmod(properties,0o600);os.chmod(key,0o600)
backup=folder/'key.properties';backup.write_text(properties.read_text());os.chmod(backup,0o600)
print('Dedicated upload key created. Key and credentials are outside version control; back up the signing directory securely.')
