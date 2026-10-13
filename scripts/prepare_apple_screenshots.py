#!/usr/bin/env python3
"""Encode native captures without alpha, preserving every RGB pixel."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / 'docs/release/screenshots/apple'
DEVICES = {
    'ios-phone': ('iphone-dynamic-island-medium', (1206, 2622)),
    'ios-tablet': ('ipad-13-inch', (2064, 2752)),
}
SCENES = ['library', 'coloring', 'puzzle', 'math']
LOCALES = ['en', 'fr', 'es', 'pt', 'ar']
SPECIFICATION = 'https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    records = []
    for folder, (slot, dimensions) in DEVICES.items():
        for locale in LOCALES:
            for index, scene in enumerate(SCENES, 1):
                source = ROOT / f'docs/qa/screenshots/{folder}/{locale}-{scene}.png'
                destination = DESTINATION / slot / locale / f'{index:02}-{scene}.png'
                with Image.open(source) as capture:
                    assert capture.size == dimensions, f'Unexpected native dimensions: {source}'
                    assert capture.mode in ('RGB', 'RGBA'), f'Unexpected image mode: {source}'
                    if capture.mode == 'RGBA':
                        assert capture.getchannel('A').getextrema() == (255, 255), f'Transparency: {source}'
                    rgb = capture.convert('RGB')
                    expected_pixels = rgb.tobytes()
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    rgb.save(destination, format='PNG')
                with Image.open(destination) as encoded:
                    assert encoded.mode == 'RGB' and encoded.size == dimensions
                    assert encoded.tobytes() == expected_pixels, f'Pixels changed: {destination}'
                records.append({
                    'locale': locale, 'deviceSlot': slot, 'scene': scene, 'order': index,
                    'source': str(source.relative_to(ROOT)), 'sourceSha256': digest(source),
                    'path': str(destination.relative_to(ROOT)), 'sha256': digest(destination),
                    'width': dimensions[0], 'height': dimensions[1], 'mode': 'RGB',
                    'decodedRGBPixelsMatchSource': True,
                })
    manifest = {
        'preparedAtUTC': datetime.now(timezone.utc).isoformat(),
        'specificationURL': SPECIFICATION,
        'screenshots': records,
        'encodingOnly': True, 'uploaded': False,
        'captureMethod': 'Native Flutter integration capture; isolated profiles and silent audio; banner unavailable fixture',
        'humanCompositionApproval': 'pending',
    }
    (DESTINATION / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Prepared {len(records)} native RGB screenshots; all decoded pixels match the captures.')


if __name__ == '__main__':
    main()
