#!/usr/bin/env python3
"""A release build requires recorded evidence; QA has a separate path."""
import argparse,json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('platform',choices=['android','ios']);args=p.parse_args()
evidence=json.loads((root/'docs/release/readiness.json').read_text())
required=['catalogValidated','contentReviewed','pronunciationReviewed','assetRightsVerified','physicalAndroidQA','physicalIOSQA','phoneTabletQA','privacyDeclarationsReviewed','supportPagesPublished','adDismissalVerified']
if args.platform=='ios':required+=['appleKidsAdExceptionVerified','iosSigningReady']
failed=[key for key in required if evidence.get(key) is not True]
if failed:raise SystemExit('Public release held: '+', '.join(failed)+'. See docs/release/STATUS.md; no build/upload was attempted.')
config=json.loads((root/'config/ads.json').read_text());config['ADS_PRODUCTION']=True;config['IOS_KIDS_ADS_VERIFIED']=args.platform=='ios'
config['SUPPORT_URL']=evidence['supportURL']
local=root/'config/production.local.json';local.write_text(json.dumps(config,indent=2)+'\n')
subprocess.run([str(root/'scripts/flutter.sh'),'build','appbundle' if args.platform=='android' else 'ipa','--release','--dart-define-from-file='+str(local)],cwd=root,check=True)
print('Artifact built. Submission, approval and public availability still require separate verified steps.')
