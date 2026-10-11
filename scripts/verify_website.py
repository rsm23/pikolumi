#!/usr/bin/env python3
import json,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[1]
config=json.loads((root/'config/site.json').read_text())
for locale in ['en','fr','es','pt','ar']:
 url=f'{config["baseURL"]}/{locale}.html'
 with urllib.request.urlopen(url,timeout=15) as response:
  body=response.read().decode()
  assert response.status==200 and config['supportEmail'] in body
  assert 'PUBLIC SUPPORT' not in body
  if locale=='ar':assert 'dir="rtl"' in body
  print(locale,response.status)
with urllib.request.urlopen('https://seifelmoulouk.com/app-ads.txt',timeout=15) as response:
 assert 'google.com, pub-3316613733634147, DIRECT, f08c47fec0942fa0' in response.read().decode()
print('Published support/privacy pages and publisher line verified.')
