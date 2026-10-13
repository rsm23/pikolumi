#!/usr/bin/env python3
"""Compose the Play feature graphic from the unchanged original Piko artwork."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SCALE = 3
SIZE = (1024, 500)


def font(size, weight=800):
    result = ImageFont.truetype(str(ROOT / 'assets/fonts/Nunito.ttf'), size * SCALE)
    result.set_variation_by_axes([weight])
    return result


def main():
    image = Image.new('RGBA', tuple(value * SCALE for value in SIZE), '#FBF7EE')
    draw = ImageDraw.Draw(image)

    def ellipse(box, color):
        draw.ellipse(tuple(round(value * SCALE) for value in box), fill=color)

    def line(points, color, width):
        draw.line([(round(x * SCALE), round(y * SCALE)) for x, y in points],
                  fill=color, width=width * SCALE, joint='curve')

    ellipse((560, -80, 1150, 510), '#D9F1EF')
    ellipse((640, 365, 1000, 465), '#C6E4E0')
    ellipse((70, 350, 87, 367), '#EF9785')
    ellipse((512, 52, 530, 70), '#B99BDD')
    line([(58, 84), (66, 66), (74, 84)], '#54B8B3', 5)
    line([(961, 109), (982, 109)], '#EF9785', 5)
    line([(972, 99), (972, 120)], '#EF9785', 5)

    draw.text((74 * SCALE, 133 * SCALE), 'Pikolumi', font=font(82), fill='#24545A')
    draw.text((79 * SCALE, 244 * SCALE), 'Color, Play & Learn',
              font=font(30, 700), fill='#3E7074')

    # These symbols depict the three core activities without store-rank claims.
    for index, (text, background, color) in enumerate([
        ('A', '#E6DDF3', '#70538F'),
        ('2', '#F9E7B2', '#856421'),
        ('+', '#F7D4C8', '#965642'),
    ]):
        x = 79 + index * 73
        draw.rounded_rectangle((x * SCALE, 312 * SCALE,
                                (x + 56) * SCALE, 370 * SCALE),
                               radius=15 * SCALE, fill=background)
        draw.text(((x + 28) * SCALE, 315 * SCALE), text,
                  font=font(36), fill=color, anchor='mt')

    piko = Image.open(ROOT / 'assets/art/piko.png').convert('RGBA')
    piko.thumbnail((380 * SCALE, 428 * SCALE), Image.Resampling.LANCZOS)
    image.alpha_composite(piko, (626 * SCALE, 41 * SCALE))
    output = ROOT / 'docs/release/play-feature.png'
    image.convert('RGB').resize(SIZE, Image.Resampling.LANCZOS).save(output)
    print(f'Created {output.relative_to(ROOT)}: {SIZE[0]}x{SIZE[1]}')


if __name__ == '__main__':
    main()
