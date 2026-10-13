"""Verify the shipped offline animation frames and their original Blender sources."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'assets/art/piko_3d/manifest.json').read_text())
assert manifest['identityRevision'] == 2
for path, digest in manifest['brandReferences'].items():
    assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, 'Brand reference changed'
decoded = 0
expected = {'idle':90,'celebrate':90,**{name:60 for name in ['wave','wink','nod','bow','wiggle','stretch','crayon','peek','flutter','hop']}}
assert set(manifest['clips']) == set(expected)
for name, clip in manifest['clips'].items():
    assert clip['fps'] == 30 and clip['frames'] == expected[name]
    sheets = []
    for entry in clip['sheets']:
        path = ROOT / entry['asset']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256']
        im = Image.open(path).convert('RGBA')
        assert im.size == (entry['width'], entry['height'])
        decoded += im.width * im.height * 4
        sheets.append(im)
    digests = set()
    for index in range(clip['frames']):
        sheet, local = index // 64, index % 64
        tile = clip['tile']
        x, y = (local % 8)*tile, (local // 8)*tile
        frame = sheets[sheet].crop((x, y, x+tile, y+tile))
        bounds = frame.getchannel('A').getbbox()
        assert bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < tile and bounds[3] < tile, (name, index, bounds)
        digests.add(hashlib.sha256(frame.tobytes()).hexdigest())
    assert len(digests) > clip['frames']*.83, 'Missing animated poses'
for path, digest in manifest['source'].items():
    assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest
assert decoded == manifest['decodedTextureBytes'] and decoded < 64 * 1024**2
sizes = {name:sum(s['width']*s['height']*4 for s in clip['sheets']) for name,clip in manifest['clips'].items()}
assert sizes['idle']+sizes['celebrate']+max(sizes[name] for name in manifest['reactions']) == manifest['maxResidentTextureBytes'] < 24*1024**2
print(json.dumps({'valid': True, 'frames': 780, 'decodedAllClipsMiB': decoded / 1024**2,
                  'normalResidentMiB':manifest['maxResidentTextureBytes']/1024**2,
                  'transparentUnclippedFrames': True, 'sourceHashesMatch': True}))
