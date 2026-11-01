#!/usr/bin/env python3
"""The social corner: bean bag fabric textures and a round board game ('Zombie Escape') for the low table."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter
import make_signs as ms

OUT = os.path.join(os.path.dirname(__file__), "..", "vr-art")
random.seed(8)


def bean(name, base):
    N = 512
    im = Image.new("RGB", (N, N), base)
    px = im.load()
    for y in range(N):
        for x in range(N):
            v = 0.9 + 0.1 * math.sin(x * 0.9) * math.sin(y * 0.9) + random.uniform(-0.04, 0.04)
            px[x, y] = tuple(max(0, min(255, int(c * v))) for c in base)
    d = ImageDraw.Draw(im)
    dark = tuple(int(c * 0.55) for c in base)
    for i in range(0, N, N // 4):          # panel seams with stitching
        d.line((i, 0, i, N), fill=dark, width=5)
        for s in range(0, N, 16):
            d.line((i - 6, s, i + 6, s + 7), fill=tuple(min(255, int(c * 1.5)) for c in base), width=2)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(OUT, name), quality=90)


for n, c in [("pink", (235, 55, 140)), ("cyan", (30, 190, 220)), ("amber", (240, 160, 30)), ("green", (110, 200, 40)), ("purple", (130, 70, 220)), ("red", (215, 40, 50))]:
    bean("bean-%s.jpg" % n, c)

# round board game
N = 1024
img = Image.new("RGB", (N, N), (20, 14, 40))
d = ImageDraw.Draw(img)
c = N // 2
d.ellipse((6, 6, N - 6, N - 6), fill=(32, 20, 64), outline=(255, 190, 60), width=10)
cols = [(255, 46, 147), (0, 229, 255), (255, 224, 40), (124, 255, 0), (160, 70, 255), (255, 122, 0)]
n = 36
for ring, (r0, r1) in enumerate([(380, 470), (280, 370)]):
    for i in range(n if ring == 0 else 28):
        step = 360 / (n if ring == 0 else 28)
        a0 = i * step
        d.pieslice((c - r1, c - r1, c + r1, c + r1), a0, a0 + step - 1.2, fill=cols[(i + ring) % len(cols)])
    d.ellipse((c - r0, c - r0, c + r0, c + r0), fill=(32, 20, 64))
for k in range(8):                       # little zombie heads on special squares
    a = math.radians(k * 45 + 10)
    x, y = c + math.cos(a) * 425, c + math.sin(a) * 425
    d.ellipse((x - 22, y - 22, x + 22, y + 22), fill=(110, 220, 70), outline=(0, 0, 0), width=3)
    d.ellipse((x - 11, y - 8, x - 3, y), fill=(0, 0, 0))
    d.ellipse((x + 3, y - 8, x + 11, y), fill=(0, 0, 0))
d.ellipse((c - 250, c - 250, c + 250, c + 250), fill=(18, 40, 26), outline=(110, 255, 60), width=8)
f = ms.font(ms.BARLOW, 120)
d.text((c, c - 70), "ZOMBIE", font=f, fill=(110, 255, 60), anchor="mm", stroke_width=6, stroke_fill=(0, 0, 0))
d.text((c, c + 40), "ESCAPE", font=f, fill=(255, 70, 70), anchor="mm", stroke_width=6, stroke_fill=(0, 0, 0))
d.text((c, c + 130), "FIRST TO THE DOOR WINS", font=ms.font(ms.BARLOW, 38), fill=(255, 230, 160), anchor="mm")
img.save(os.path.join(OUT, "boardgame.jpg"), quality=92)
