"""Pack locally rendered Piko frames into bounded Flutter texture atlases."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/art/piko_3d'
DEST.mkdir(parents=True, exist_ok=True)
clips = {}
reactions = ('wave','wink','nod','bow','wiggle','stretch','crayon','peek','flutter','hop')
specs = [('idle',90,128),('celebrate',90,192)]+[(name,60,128) for name in reactions]
all_files = sorted((ROOT / 'tmp/piko-frames').glob('*/frame-*.png'))
assert len(all_files) == 780, f'Expected 780 frames, found {len(all_files)}'
bounds = [Image.open(path).getbbox() for path in all_files]
assert all(bounds), 'Empty animation frame'
left = min(b[0] for b in bounds)
top = min(b[1] for b in bounds)
right = max(b[2] for b in bounds)
bottom = max(b[3] for b in bounds)
assert left > 0 and top > 0 and right < 256 and bottom < 256, 'Clipped model'
size = max(right-left, bottom-top)+12
cx, cy = (left+right)/2, (top+bottom)/2
crop = (round(cx-size/2), round(cy-size/2), round(cx+size/2), round(cy+size/2))
decoded_bytes = 0
for clip, count, tile in specs:
    frames = sorted((ROOT / f'tmp/piko-frames/{clip}').glob('frame-*.png'))
    assert len(frames) == count
    hashes = [hashlib.sha256(f.read_bytes()).hexdigest() for f in frames]
    assert len(set(hashes)) > count*.83, 'Animation should contain distinct poses'
    sheets = []
    for start in range(0, count, 64):
        batch = frames[start:start+64]
        atlas = Image.new('RGBA', (tile*8, tile*((len(batch)+7)//8)))
        for index, path in enumerate(batch):
            im = Image.open(path).convert('RGBA').crop(crop).resize((tile, tile), Image.Resampling.LANCZOS)
            atlas.paste(im, ((index%8)*tile, (index//8)*tile))
        dest = DEST / f'{clip}_{start//64}.webp'
        atlas.save(dest, lossless=True, method=6)
        decoded_bytes += atlas.width*atlas.height*4
        sheets.append({'asset': str(dest.relative_to(ROOT)), 'width': atlas.width, 'height': atlas.height,
                       'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()})
    clips[clip] = {'fps': 30, 'frames': count, 'tile': tile, 'columns': 8, 'framesPerSheet': 64, 'sheets': sheets}
Image.open(ROOT / 'tmp/piko-frames/idle/frame-0001.png').convert('RGBA').crop(crop).resize((256, 256), Image.Resampling.LANCZOS).save(DEST / 'poster.webp', lossless=True, method=6)
manifest = {'schema': 2, 'identityRevision': 2,
            'origin': 'Local Blender articulated 3D relief, painted with the canonical Piko illustration',
            'viewScope': 'Front view with gentle depth motion; not a full turnaround model',
            'brandReferences': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in [ROOT / 'assets/art/piko.png', ROOT / 'assets/art/app-icon.png']},
            'crop': crop,
            'decodedTextureBytes': decoded_bytes,
            'maxResidentTextureBytes': int(23.5*1024**2),
            'residency': 'On-demand shared clips; normal navigation needs at most idle, celebration and one reaction together',
            'reactions': list(reactions), 'clips': clips,
            'source': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in (ROOT / 'art_source/piko').glob('*.blend')}}
(DEST / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
print(json.dumps({'frames': 780, 'decodedAllClipsMiB': round(decoded_bytes/1024**2, 2),
                  'normalResidentMiB': 23.5,
                  'bundledBytes': sum(p.stat().st_size for p in DEST.iterdir())}))
