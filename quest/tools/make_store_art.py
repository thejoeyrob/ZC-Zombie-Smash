#!/usr/bin/env python3
"""Store art for the Meta Horizon store, made from real renders of the game (render them with
`godot --path quest --rendering-driver opengl3 --resolution 2560x1440 -- --shots=DIR --views=overview,backwall,arc_l,hall_lanes,hall_axes,pinball,cab_front`).
Usage: python3 quest/tools/make_store_art.py SHOTS_DIR   ->   quest/store-art/*.png
Sizes: cover landscape 2560x1440, square 1440x1440, portrait 1008x1344, hero 3000x900, icon 512x512, plus screenshots at 2560x1440."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import make_signs as ms

SH = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "store-art")
os.makedirs(os.path.join(OUT, "screenshots"), exist_ok=True)
shot = lambda n: Image.open(os.path.join(SH, n + ".png")).convert("RGB")
TITLE, TAG = "FATTY'S GAME SHACK", "ARCADE  •  PINBALL  •  DARTS  •  AXES  •  BOWLING  •  FRIENDS"


def fit(img, w, h, focus=(0.5, 0.5)):
    r = max(w / img.width, h / img.height)
    im = img.resize((int(img.width * r) + 1, int(img.height * r) + 1), Image.LANCZOS)
    x = int((im.width - w) * focus[0]); y = int((im.height - h) * focus[1])
    return im.crop((x, y, x + w, y + h))


def shade(img, top=0.0, bottom=0.78):
    w, h = img.size
    g = Image.new("L", (1, h))
    for y in range(h):
        k = y / (h - 1)
        g.putpixel((0, y), int(255 * (top * (1 - k) + bottom * k)))
    g = g.resize((w, h))
    return Image.composite(Image.new("RGB", (w, h), (4, 3, 12)), img, g)


def glow_text(img, text, size, xy, fill, glow, anchor="mm", stroke=6, max_w=None):
    f = ms.font(ms.BARLOW, size)
    while max_w and f.getlength(text) > max_w and size > 20:       # never let a title run off the edge of the picture
        size -= 6
        f = ms.font(ms.BARLOW, size)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(xy, text, font=f, fill=glow + (255,), anchor=anchor, stroke_width=stroke + 14, stroke_fill=glow + (255,))
    layer = layer.filter(ImageFilter.GaussianBlur(size // 8))
    base = img.convert("RGBA"); base.alpha_composite(layer)
    d = ImageDraw.Draw(base)
    d.text(xy, text, font=f, fill=(12, 8, 24, 255), anchor=anchor, stroke_width=stroke + 4, stroke_fill=(12, 8, 24, 255))
    d.text(xy, text, font=f, fill=fill + (255,), anchor=anchor)
    return base.convert("RGB")


def cover(w, h, shot_name, focus, title_size, tag_size, title_y, name):
    im = ImageEnhance.Color(fit(shot(shot_name), w, h, focus)).enhance(1.15)
    im = shade(im, 0.05, 0.82)
    im = glow_text(im, TITLE, title_size, (w // 2, int(h * title_y)), (255, 233, 138), (255, 120, 30), max_w=w * 0.9)
    im = glow_text(im, TAG, tag_size, (w // 2, int(h * title_y) + int(title_size * 0.78)), (150, 235, 255), (20, 120, 220), stroke=3, max_w=w * 0.92)
    im.save(os.path.join(OUT, name), optimize=True)


cover(2560, 1440, "overview", (0.5, 0.45), 300, 62, 0.80, "cover-landscape-2560x1440.png")
cover(1440, 1440, "overview", (0.45, 0.4), 190, 38, 0.82, "cover-square-1440x1440.png")
cover(1008, 1344, "backwall", (0.5, 0.5), 150, 28, 0.80, "cover-portrait-1008x1344.png")
# hero banner
hero = shade(fit(shot("hall_lanes"), 3000, 900, (0.5, 0.55)), 0.2, 0.6)
hero = glow_text(hero, TITLE, 230, (1500, 450), (255, 233, 138), (255, 120, 30))
hero.save(os.path.join(OUT, "hero-3000x900.png"), optimize=True)
# icon: the red FKBC-style cabinet is not the brand; use the title initials on the neon arcade
ic = shade(fit(shot("arc_l"), 512, 512, (0.55, 0.5)), 0.1, 0.55)
ic = glow_text(ic, "FGS", 230, (256, 256), (255, 233, 138), (255, 120, 30), stroke=3)
ic.save(os.path.join(OUT, "icon-512x512.png"), optimize=True)
for i, n in enumerate(["overview", "backwall", "arc_l", "hall_lanes", "hall_axes", "pinball", "cab_front"], 1):
    shot(n).save(os.path.join(OUT, "screenshots", "%02d-%s.png" % (i, n)), optimize=True)
print("ok")
