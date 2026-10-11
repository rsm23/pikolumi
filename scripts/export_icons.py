from PIL import Image
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
image=Image.open(root/'assets/art/app-icon.png').convert('RGB')
folder=root/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((folder/'Contents.json').read_text())['images']:
 if 'filename' in entry:
  size=round(float(entry['size'].split('x')[0])*float(entry['scale'].rstrip('x')))
  image.resize((size,size),Image.Resampling.LANCZOS).save(folder/entry['filename'])
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
 folder=root/f'android/app/src/main/res/mipmap-{density}';folder.mkdir(parents=True,exist_ok=True);image.resize((size,size),Image.Resampling.LANCZOS).save(folder/'ic_launcher.png')
(root/'docs/release').mkdir(parents=True,exist_ok=True)
image.resize((512,512),Image.Resampling.LANCZOS).save(root/'docs/release/play-icon.png')
for name,size in [('Icon-192.png',192),('Icon-512.png',512),('Icon-maskable-192.png',192),('Icon-maskable-512.png',512)]:image.resize((size,size),Image.Resampling.LANCZOS).save(root/'web/icons'/name)
image.resize((32,32),Image.Resampling.LANCZOS).save(root/'web/favicon.png')
