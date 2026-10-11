#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
.venv/bin/python scripts/validate_content.py
scripts/flutter.sh analyze
scripts/flutter.sh test
scripts/flutter.sh build apk --release --dart-define-from-file=config/ads.json
scripts/flutter.sh build appbundle --release --dart-define-from-file=config/ads.json
scripts/flutter.sh build ios --simulator --debug --dart-define-from-file=config/ads.json
scripts/flutter.sh build ipa --release --dart-define-from-file=config/ads.json --export-options-plist=config/qa-export-options.plist
mkdir -p output/qa
cp build/app/outputs/flutter-apk/app-release.apk output/qa/Pikolumi-1.0.0-QA.apk
cp build/app/outputs/bundle/release/app-release.aab output/qa/Pikolumi-1.0.0-QA.aab
cp build/ios/ipa/*.ipa output/qa/Pikolumi-1.0.0-QA.ipa
ditto -c -k --sequesterRsrc --keepParent build/ios/iphonesimulator/Runner.app output/qa/Pikolumi-1.0.0-Simulator.zip
.venv/bin/python scripts/artifact_manifest.py
printf '%s\n' 'QA builds use test ads. They are not authorized production submissions.'
