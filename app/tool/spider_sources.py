"""Makes the picture files tool/app_icons.py draws every icon from, out of
tool/spider/logo-source.jpg (the silver spider emblem on black):

- logo-glyph.png: the emblem alone, 1024 px tall, transparent.
- logo-dock.png: the emblem on a black rounded tile, 512 px.
- logo-generic.png, logo-animated1.png to logo-animated4.png: the tray
  icons, the emblem in white (80 px, lower right corner left free for the
  status dot), the four frames fading in while connecting.

Run from app/ before tool/app_icons.py (needs Pillow and NumPy):

    python tool/spider_sources.py && python tool/app_icons.py
    python tool/spider_icons.py
"""
import os

from PIL import Image, ImageDraw

import spider_icons as si

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'spider')


def main():
    art = si.emblem()
    k = 1024 / art.height
    glyph = art.resize((round(art.width * k), 1024), Image.LANCZOS)
    canvas = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    canvas.alpha_composite(glyph, ((1024 - glyph.width) // 2, 0))
    canvas.save(os.path.join(OUT, 'logo-glyph.png'), optimize=True)

    dock = si.tile(art, 512, 0.72)
    dock.save(os.path.join(OUT, 'logo-dock.png'), optimize=True)

    # The tray's emblem: white, a little smaller so the dot fits beside it.
    white = Image.new('RGBA', art.size, (240, 242, 247, 0))
    white.putalpha(art.getchannel('A'))

    def tray(opacity):
        icon = si.art_layer(white, 80, 0.86)
        alpha = icon.getchannel('A').point(lambda v: round(v * opacity))
        icon.putalpha(alpha)
        return icon

    tray(1.0).save(os.path.join(OUT, 'logo-generic.png'), optimize=True)
    for i, opacity in enumerate((0.40, 0.62, 0.82, 1.0), start=1):
        tray(opacity).save(os.path.join(OUT, 'logo-animated%d.png' % i), optimize=True)


if __name__ == '__main__':
    main()
