#!/usr/bin/env python3
"""Package Flutter-rendered art into a silent, offline review library."""
import hashlib
import html
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'docs/qa/art-review'
IMAGES = DEST / 'images'
catalog = json.loads((ROOT / 'assets/content/catalog.json').read_text())
art = json.loads((ROOT / 'assets/content/art.json').read_text())
font = ImageFont.truetype(str(ROOT / 'assets/fonts/Nunito.ttf'), 18)


def contact_sheet(ids, filename, columns=6):
    rows = (len(ids) + columns - 1) // columns
    image = Image.new('RGB', (columns * 230, rows * 250), '#fbf7ee')
    draw = ImageDraw.Draw(image)
    for index, key in enumerate(ids):
        x, y = index % columns * 230, index // columns * 250
        thumbnail = Image.open(IMAGES / f'{key}.png').convert('RGB')
        thumbnail.thumbnail((216, 216))
        image.paste(thumbnail, (x + 7, y + 5))
        draw.text((x + 10, y + 224), key, fill='#344850', font=font)
    image.save(DEST / filename)


motifs = [key for key in art if not key.startswith(('scene_', 'puzzle_')) and '_' not in key]
coloring = [a for a in catalog['activities'] if a['section'] == 'coloring']
puzzles = [a for a in catalog['activities'] if a['section'] == 'jigsaw']
contact_sheet(motifs, 'motifs.png')
for group, activities in [('coloring', coloring), ('puzzles', puzzles)]:
    for start in range(0, len(activities), 24):
        contact_sheet([a['config']['scene'] for a in activities[start:start + 24]],
                      f'{group}-{start // 24 + 1:02}.png')

results, errors = [], []
for activity in puzzles:
    key, size = activity['config']['scene'], activity['config']['size']
    pixels = np.asarray(Image.open(IMAGES / f'{key}.png').convert('RGB'))
    height, width = pixels.shape[:2]
    hashes, low_detail = set(), []
    for row in range(size):
        for column in range(size):
            tile = pixels[row * height // size:(row + 1) * height // size,
                          column * width // size:(column + 1) * width // size]
            hashes.add(hashlib.sha256(tile.tobytes()).hexdigest())
            variation = float(np.mean(np.std(tile, axis=(0, 1))))
            if variation < 3:
                low_detail.append([row, column, round(variation, 2)])
    result = {'activity': activity['id'], 'scene': key, 'grid': size,
              'distinctTiles': len(hashes), 'lowDetailTiles': low_detail}
    results.append(result)
    if low_detail or len(hashes) != size * size:
        errors.append(result)
report = {'catalogVersion': catalog['version'], 'puzzles': len(puzzles),
          'tiles': sum(a['config']['size'] ** 2 for a in puzzles),
          'errors': errors, 'passed': not errors,
          'method': 'Pixel hashes identify duplicate tiles; per-tile RGB variation detects flat-color tiles. This is not human art approval.',
          'puzzleResults': results}
(DEST / 'tile-validation.json').write_text(json.dumps(report, indent=2) + '\n')

cards = []
for section, activities in [('coloring', coloring), ('puzzles', puzzles)]:
    for activity in activities:
        key = activity['config']['scene']
        title = html.escape(activity['title']['en'])
        outline = (f'<a href="images/{key}-outline.png">Coloring outline</a>'
                   if section == 'coloring' else f"{activity['config']['size']} × {activity['config']['size']} pieces")
        cards.append(f'<figure data-section="{section}" data-search="{title.lower()} {activity["id"]}">'
                     f'<a href="images/{key}.png"><img loading="lazy" src="images/{key}.png" alt="{title}"></a>'
                     f'<figcaption><strong>{title}</strong><small>{activity["id"]}</small>{outline}</figcaption></figure>')
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pikolumi artwork library</title><style>
body{margin:32px auto;padding:0 24px;max-width:1440px;background:#fbf7ee;color:#344850;font:17px system-ui}
h1{font-size:36px}p{max-width:900px;line-height:1.6}a{color:#245e68}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}
input,select{font:inherit;padding:12px;border:1px solid #697d81;border-radius:8px;background:white;min-height:48px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:20px}figure{margin:0;padding:12px;background:white;border-radius:12px}
img{width:100%;height:220px;object-fit:contain}figcaption{line-height:1.6}small{display:block;color:#51666d}
[hidden]{display:none!important}.compare{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px}.compare img{height:360px}
@media(max-width:700px){.compare{grid-template-columns:repeat(2,minmax(0,1fr))}}
</style><h1>Pikolumi artwork library</h1>
<p>All 360 redesigned coloring pages and 120 picture puzzles, rendered with the app's own canvas. Each coloring page also has a printable outline preview. Original saved artwork retains its previous geometry. This page is silent.</p>
<p><a href="../PREVIEW.html">Native app screens</a> · <a href="motifs.png">All 60 drawings</a> · <a href="tile-validation.json">Puzzle tile checks</a></p>
<h2>Before and after</h2><div class="compare">
<figure><img src="before/coloring.png" alt="Previous coloring screen"><figcaption>Coloring · before</figcaption></figure>
<figure><img src="../screenshots/ios-phone/en-coloring.png" alt="Updated coloring screen"><figcaption>Coloring · after</figcaption></figure>
<figure><img src="before/puzzle.png" alt="Previous puzzle screen"><figcaption>Puzzle · before</figcaption></figure>
<figure><img src="../screenshots/ios-phone/en-puzzle.png" alt="Updated puzzle screen"><figcaption>Puzzle · after</figcaption></figure>
</div><h2>Browse every page</h2><nav><select aria-label="Section" id="section"><option value="all">All artwork</option value="coloring">Coloring</option><option value="puzzles">Puzzles</option></select><input id="search" type="search" placeholder="Find an animal or activity" aria-label="Find artwork"></nav><p id="count"></p><div class="grid">'''
page += ''.join(cards) + '''</div><script>
const section=document.getElementById('section'),search=document.getElementById('search'),cards=[...document.querySelectorAll('[data-section]')];
function filter(){let count=0;for(const card of cards){card.hidden=!(section.value==='all'||card.dataset.section===section.value)||!card.dataset.search.includes(search.value.toLowerCase());if(!card.hidden)count++}document.getElementById('count').textContent=count+' activities'}
section.addEventListener('change',filter);search.addEventListener('input',filter);filter();</script></html>'''
(DEST / 'index.html').write_text(page)
native = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pikolumi native previews</title>
<style>body{background:#fbf7ee;color:#344850;font:17px system-ui;margin:32px auto;max-width:1440px;padding:0 24px}h1{font-size:36px}h2{margin-top:40px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:20px}figure{margin:0;background:white;padding:12px;border-radius:12px}img{width:100%;height:340px;object-fit:contain}figcaption{padding-top:12px;text-align:center}a{color:#245e68}p{max-width:900px;line-height:1.6}</style>
<h1>Pikolumi native previews</h1><p>Updated artwork: 360 coloring pages and 120 picture puzzles. These 63 silent captures show five languages on a physical Pixel and iPhone/iPad simulators, plus an uncolored page on each. The isolated screenshot fixture uses the artist's palette and suppresses ads. Educational review, production ad checks and physical iOS QA remain pending.</p>
<p><a href="art-review/index.html">Browse all coloring pages and puzzles · before and after</a> · <a href="REPORT.md">QA report</a> · <a href="arabic-review/index.html">Arabic review</a> · <a href="language-review/index.html">All language reviews</a></p>'''
for folder, label in [('pixel-phone', 'Pixel 9 Pro XL · physical · profile'),
                      ('ios-phone', 'iPhone 18 Pro · simulator · debug'),
                      ('ios-tablet', 'iPad Pro 13-inch · simulator · debug')]:
    native += f'<h2>{label}</h2><div class="grid">'
    for locale in ['en', 'fr', 'es', 'pt', 'ar']:
        screens = ['library', 'coloring', 'puzzle', 'math']
        if locale == 'en':
            screens.insert(1, 'coloring-outline')
        for screen in screens:
            path = f'screenshots/{folder}/{locale}-{screen}.png'
            native += f'<figure><a href="{path}"><img loading="lazy" src="{path}" alt="{locale} {screen}"></a><figcaption>{locale.upper()} · {screen}</figcaption></figure>'
    native += '</div>'
(DEST.parent / 'PREVIEW.html').write_text(native + '</html>')
print(f'Built artwork review: {len(coloring)} coloring pages, {len(puzzles)} puzzles, {len(errors)} tile errors.')
raise SystemExit(bool(errors))
