"""Generates the app icon and launch images (flat PNGs; iOS 6 adds the icon gloss and rounding itself)."""
import random
from PIL import Image, ImageDraw

def grad(d, box, top, bot):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        d.line([(x0, y), (x1, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

def icon(n):
    im = Image.new("RGB", (n, n))
    d = ImageDraw.Draw(im)
    grad(d, (0, 0, n, n), (22, 28, 40), (4, 5, 8))
    s = n / 100.0
    blue, hi = (52, 152, 255), (150, 215, 255)
    d.ellipse([14*s, 14*s, 86*s, 86*s], fill=(6, 8, 12), outline=blue, width=max(2, int(3*s)))
    for pts in ([(50, 22), (42, 34), (58, 34)], [(50, 78), (42, 66), (58, 66)], [(22, 50), (34, 42), (34, 58)], [(78, 50), (66, 42), (66, 58)]):
        d.polygon([(x*s, y*s) for x, y in pts], fill=hi)
    d.ellipse([36*s, 36*s, 64*s, 64*s], fill=(30, 112, 226), outline=hi, width=max(1, int(1.5*s)))
    d.ellipse([40*s, 38*s, 60*s, 50*s], fill=(100, 190, 255))
    return im

def launch(w, h, scale):
    im = Image.new("RGB", (w, h), (7, 9, 13))
    d = ImageDraw.Draw(im)
    sb, nb, tb = 20 * scale, 44 * scale, 49 * scale
    d.rectangle([0, 0, w, sb], fill=(0, 0, 0))
    grad(d, (0, sb, w, sb + nb), (26, 31, 42), (8, 10, 14))
    d.line([(0, sb + nb - 1), (w, sb + nb - 1)], fill=(52, 152, 255))
    grad(d, (0, h - tb, w, h), (14, 17, 23), (3, 4, 6))
    d.line([(0, h - tb), (w, h - tb)], fill=(44, 58, 82))
    return im

icon(57).save("res/Icon.png")
icon(114).save("res/Icon@2x.png")
launch(320, 480, 1).save("res/Default.png")
launch(640, 960, 2).save("res/Default@2x.png")
launch(640, 1136, 2).save("res/Default-568h@2x.png")

# Rounded 512 px copy for the README and GitHub (on the device iOS adds its own rounding and gloss to Icon.png)
import os
from PIL import ImageDraw as _ImageDraw
os.makedirs("docs", exist_ok=True)
_i = icon(512).convert("RGBA")
_m = Image.new("L", _i.size, 0)
_ImageDraw.Draw(_m).rounded_rectangle([0, 0, 511, 511], radius=115, fill=255)
_i.putalpha(_m)
_i.save("docs/icon.png")
