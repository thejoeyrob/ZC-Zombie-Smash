#!/usr/bin/env python3
"""A picture frame that reads as real: mitred walnut moulding with a gold lip, a dark mat, bevelled edges, wood grain and a soft shadow.
frame-poster.png (780 x 1140, window 660 x 990) and frame-wide.png (1440 x 620, window 1280 x 460)."""
import os, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = os.path.join(os.path.dirname(__file__), "..", "vr-art")
random.seed(4)


def moulding(w, h, win, lit=1.0):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x0, y0, x1, y1 = win
    px = img.load()
    B = x0                      # moulding thickness
    for y in range(h):
        for x in range(w):
            if x0 <= x < x1 and y0 <= y < y1:
                continue
            # which side of the mitre is this on
            dx0, dx1, dy0, dy1 = x - 0, w - 1 - x, y - 0, h - 1 - y
            m = min(dx0, dx1, dy0, dy1)
            side = [dx0, dx1, dy0, dy1].index(m)
            t = m / B                                                # 0 outer .. 1 inner
            # profile: thin dark outer line, rounded wood, gold lip, dark mat
            if t < 0.05:
                c = (14, 10, 8)
            elif t < 0.72:
                u = (t - 0.05) / 0.67
                bevel = 0.5 + 0.5 * __import__("math").cos(u * 3.14159)         # bright on the rounded crest, darker at both ends
                base = 62 + 70 * (1 - bevel)
                lightdir = {0: 1.25, 2: 1.2, 1: 0.62, 3: 0.55}[side]           # lit from the upper left
                g = base * lightdir * lit
                c = (int(g * 1.0), int(g * 0.66), int(g * 0.42))
            elif t < 0.80:
                u = (t - 0.72) / 0.08
                g = 200 + 40 * (1 - u)
                lightdir = {0: 1.1, 2: 1.1, 1: 0.7, 3: 0.65}[side]
                c = (int(g * lightdir), int(g * 0.78 * lightdir), int(g * 0.3 * lightdir))
            else:
                u = (t - 0.80) / 0.20
                g = 26 + 14 * u
                c = (int(g), int(g * 0.95), int(g * 1.1))
            px[x, y] = c + (255,)
    # wood grain over the moulding only
    grain = Image.new("L", (w, h), 128)
    gd = ImageDraw.Draw(grain)
    for i in range(900):
        yy = random.randint(0, h)
        xx = random.randint(0, w)
        ln = random.randint(30, 160)
        v = random.randint(90, 170)
        if random.random() < 0.5:
            gd.line((xx, yy, xx + ln, yy + random.randint(-2, 2)), fill=v, width=1)
        else:
            gd.line((xx, yy, xx + random.randint(-2, 2), yy + ln), fill=v, width=1)
    grain = grain.filter(ImageFilter.GaussianBlur(0.8))
    shade = ImageChops.subtract(grain, Image.new("L", (w, h), 128))
    shade_img = Image.merge("RGBA", (shade, shade, shade, Image.new("L", (w, h), 0)))
    r, g, b, a = img.split()
    boost = shade.point(lambda v: int(v * 0.5))
    r = ImageChops.add(r, boost)
    g = ImageChops.add(g, boost.point(lambda v: int(v * 0.8)))
    b = ImageChops.add(b, boost.point(lambda v: int(v * 0.6)))
    return Image.merge("RGBA", (r, g, b, a))


def make(name, w, h, border):
    pad = 40                                                          # room for the soft shadow
    W, H = w + pad * 2, h + pad * 2
    win = (border, border, w - border, h - border)
    fr = moulding(w, h, win)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).rectangle((pad + 8, pad + 14, pad + w + 8, pad + h + 14), fill=170)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", (W, H), (0, 0, 0, 255)), (0, 0), sh.filter(ImageFilter.GaussianBlur(14)))
    out.alpha_composite(shadow)
    out.alpha_composite(fr, (pad, pad))
    # inner shadow cast by the frame onto the picture
    inner = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ring = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(ring)
    d.rectangle((0, 0, W, H), fill=140)
    d.rectangle((pad + border, pad + border, pad + w - border, pad + h - border), fill=0)
    ring = ring.filter(ImageFilter.GaussianBlur(10))
    clip = Image.new("L", (W, H), 0)
    ImageDraw.Draw(clip).rectangle((pad + border, pad + border, pad + w - border, pad + h - border), fill=255)
    inner.paste(Image.new("RGBA", (W, H), (0, 0, 0, 255)), (0, 0), ImageChops.multiply(ring, clip))
    out.alpha_composite(inner)
    out.save(os.path.join(OUT, name))
    print(name, out.size, "window", (pad + border, pad + border, pad + w - border, pad + h - border))


make("frame-poster.png", 780, 1140, 60)
make("frame-wide.png", 1440, 620, 80)

# a soft diagonal glare for the glass
g = Image.new("RGBA", (512, 768), (0, 0, 0, 0))
d = ImageDraw.Draw(g)
d.polygon([(0, 0), (260, 0), (0, 420)], fill=(255, 255, 255, 38))
d.polygon([(330, 0), (400, 0), (0, 600), (0, 520)], fill=(255, 255, 255, 18))
g.filter(ImageFilter.GaussianBlur(6)).save(os.path.join(OUT, "glass-glare.png"))
