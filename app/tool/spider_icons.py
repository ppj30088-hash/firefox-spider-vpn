"""Makes the Spider Firefox VPN icons from tool/spider/logo-source.jpg (the
silver spider emblem and the SPIDER wordmark on black).

The emblem alone (no wordmark: it cannot be read at icon sizes, and the app's
name stands beside the logo anyway) is cut out of the picture, its dark
background keyed out, and used for:

- Android (android/app/src/main/res): the adaptive launcher icon (black
  background layer + emblem foreground layer), the legacy ic_launcher.png, and
  the status bar / Quick Settings icon (drawable-*/ic_stat_logo.png, a white
  silhouette).
- The app's logo (assets/logo.png), beside its name, and the emblem alone
  (assets/spider_emblem*.png) in the home page's button.
- The web dashboard's icon (../core/internal/service/web/icon.png).

Run from app/ (needs Pillow and NumPy):

    python tool/spider_icons.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, '..')
CORE = os.path.join(APP, '..', 'core')
RES = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')
SOURCE = os.path.join(HERE, 'spider', 'logo-source.jpg')

BLACK = (0, 0, 0, 255)
DENSITY = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
# The emblem's height as a share of the 108 dp adaptive canvas (the launcher
# shows the middle 66-72 dp, so 0.60 keeps the whole emblem inside).
ART = 0.60
# The emblem's rectangle in the 640 px source (above the wordmark).
EMBLEM_BOX = (196, 30, 454, 466)


def emblem():
    """The emblem, silver on transparent: the dark background keyed out."""
    im = Image.open(SOURCE).convert('RGB').crop(EMBLEM_BOX)
    rgb = np.asarray(im).astype(float)
    lum = rgb.mean(axis=2)
    alpha = np.clip((lum - 14) / 34, 0, 1)
    out = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(out, 'RGBA')
    return img.crop(img.getchannel('A').point(lambda v: 255 if v > 24 else 0).getbbox())


def art_layer(art, size, share):
    """The art's larger side is [share] of [size], centered, transparent."""
    scale = size * share / max(art.size)
    w, h = max(1, round(art.width * scale)), max(1, round(art.height * scale))
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    layer.alpha_composite(art.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2))
    return layer


def rounded(img, radius):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=radius, fill=255)
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def tile(art, size, share=0.78):
    """A black rounded tile with the emblem in it."""
    base = Image.new('RGBA', (size, size), BLACK)
    base.alpha_composite(art_layer(art, size, share))
    return rounded(base, size // 5)


def launcher_tile(art, size):
    """The visible middle of the adaptive icon, rounded (legacy Android)."""
    canvas = round(size * 108 / 72)
    full = Image.new('RGBA', (canvas, canvas), BLACK)
    full.alpha_composite(art_layer(art, canvas, ART))
    cut = (canvas - size) // 2
    return rounded(full.crop((cut, cut, cut + size, cut + size)), size // 5)


def silhouette(art, dp):
    """The status bar icon: the emblem in white, thickened a little so the
    legs stay visible, in a dp x dp square."""
    out = {}
    for dpi, k in DENSITY.items():
        px = round(dp * k)
        layer = art_layer(art, px * 4, 0.92)
        alpha = layer.getchannel('A').point(lambda v: 255 if v > 60 else 0)
        alpha = alpha.filter(ImageFilter.MaxFilter(5)).resize((px, px), Image.LANCZOS)
        icon = Image.new('RGBA', (px, px), (255, 255, 255, 0))
        icon.putalpha(alpha)
        out[dpi] = icon
    return out


def main():
    art = emblem()
    for dpi, k in DENSITY.items():
        folder = os.path.join(RES, 'mipmap-' + dpi)
        os.makedirs(folder, exist_ok=True)
        px = round(108 * k)
        art_layer(art, px, ART).save(os.path.join(folder, 'ic_launcher_foreground.png'), optimize=True)
        Image.new('RGBA', (px, px), BLACK).save(os.path.join(folder, 'ic_launcher_background.png'), optimize=True)
        launcher_tile(art, round(48 * k)).save(os.path.join(folder, 'ic_launcher.png'), optimize=True)

    for dpi, icon in silhouette(art, 24).items():
        folder = os.path.join(RES, 'drawable-' + dpi)
        os.makedirs(folder, exist_ok=True)
        icon.save(os.path.join(folder, 'ic_stat_logo.png'), optimize=True)

    tile(art, 256).save(os.path.join(APP, 'assets', 'logo.png'), optimize=True)
    # The emblem alone, transparent, for the home page's button: silver for
    # the dark theme, dark steel for the light one.
    for name, rgb in (('spider_emblem', None), ('spider_emblem_dark', (36, 40, 52))):
        e = art.copy()
        if rgb:
            e = Image.new('RGBA', art.size, rgb + (0,))
            e.putalpha(art.getchannel('A'))
        k = 400 / e.height
        e.resize((round(e.width * k), 400), Image.LANCZOS).save(
            os.path.join(APP, 'assets', name + '.png'), optimize=True)
    tile(art, 192).save(os.path.join(CORE, 'internal', 'service', 'web', 'icon.png'), optimize=True)


if __name__ == '__main__':
    main()
