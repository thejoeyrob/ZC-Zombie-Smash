#!/usr/bin/env python3
"""Cabinet art for the two driving machines: marquees (3072x1023) and side panels (887x1774) for ROAD RUSH and BIG RIG.
Output: vr-art/marquee-roadrush.jpg, marquee-bigrig.jpg, side-roadrush-flat.png, side-bigrig-flat.png. All drawn from scratch here."""
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
random.seed(3)
F = lambda sz: ImageFont.truetype("DejaVuSans-Bold.ttf", sz)

def grad(w, h, top, bot):
    a = np.zeros((h, w, 3), np.float32)
    for y in range(h):
        k = y / (h - 1)
        a[y, :, :] = np.array(top) * (1 - k) + np.array(bot) * k
    return Image.fromarray(a.astype(np.uint8))

def road(img, horizon, vx, w, h, col_road, col_edge, col_line, sway=0.0):
    d = ImageDraw.Draw(img)
    for i in range(40):
        k0, k1 = (i / 40) ** 2.0, ((i + 1) / 40) ** 2.0
        y0, y1 = horizon + (h - horizon) * k0, horizon + (h - horizon) * k1
        w0, w1 = 20 + (w * 0.9) * k0, 20 + (w * 0.9) * k1
        c0 = vx + sway * (1 - k0) * w * 0.3
        c1 = vx + sway * (1 - k1) * w * 0.3
        band = (i % 2 == 0)
        d.polygon([(c0 - w0, y0), (c0 + w0, y0), (c1 + w1, y1), (c1 - w1, y1)], fill=col_road if band else tuple(int(v * 0.9) for v in col_road))
        e0, e1 = w0 * 0.07, w1 * 0.07
        d.polygon([(c0 - w0, y0), (c0 - w0 + e0, y0), (c1 - w1 + e1, y1), (c1 - w1, y1)], fill=col_edge if band else (240, 240, 240))
        d.polygon([(c0 + w0 - e0, y0), (c0 + w0, y0), (c1 + w1, y1), (c1 + w1 - e1, y1)], fill=col_edge if band else (240, 240, 240))
        if band:
            l0, l1 = w0 * 0.025, w1 * 0.025
            d.polygon([(c0 - l0, y0), (c0 + l0, y0), (c1 + l1, y1), (c1 - l1, y1)], fill=col_line)

def title(img, text, size, y, fill, glow, stroke=10):
    d = ImageDraw.Draw(img)
    f = F(size)
    w = d.textlength(text, font=f)
    x = (img.width - w) / 2
    g = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.text((x, y), text, font=f, fill=glow + (255,), stroke_width=stroke + 8, stroke_fill=glow + (255,))
    g = g.filter(ImageFilter.GaussianBlur(14))
    img.paste(g, (0, 0), g)
    d.text((x, y), text, font=f, fill=fill, stroke_width=stroke, stroke_fill=(15, 10, 30))
    d.text((x, y), text, font=f, fill=fill)

def sports_car(d, cx, cy, s, body=(220, 30, 60)):
    # a low rear view of a sports car
    d.polygon([(cx - 120 * s, cy), (cx - 90 * s, cy - 40 * s), (cx - 50 * s, cy - 70 * s), (cx + 50 * s, cy - 70 * s), (cx + 90 * s, cy - 40 * s), (cx + 120 * s, cy)], fill=body)
    d.polygon([(cx - 48 * s, cy - 66 * s), (cx + 48 * s, cy - 66 * s), (cx + 66 * s, cy - 40 * s), (cx - 66 * s, cy - 40 * s)], fill=(30, 40, 70))
    d.rectangle([cx - 125 * s, cy - 6 * s, cx + 125 * s, cy + 22 * s], fill=tuple(int(c * 0.6) for c in body))
    for sx in (-1, 1):
        d.rectangle([cx + sx * 95 * s - 22 * s, cy - 30 * s, cx + sx * 95 * s + 22 * s, cy - 14 * s], fill=(255, 60, 40))
        d.rectangle([cx + sx * 105 * s - 24 * s, cy + 8 * s, cx + sx * 105 * s + 24 * s, cy + 46 * s], fill=(15, 15, 18))
    d.rectangle([cx - 90 * s, cy - 78 * s, cx + 90 * s, cy - 70 * s], fill=tuple(int(c * 0.5) for c in body))

def rig(d, cx, cy, s, cab=(235, 150, 30)):
    # a front view of a big truck cab
    d.rectangle([cx - 150 * s, cy - 210 * s, cx + 150 * s, cy + 40 * s], fill=cab)
    d.rectangle([cx - 130 * s, cy - 195 * s, cx + 130 * s, cy - 90 * s], fill=(40, 60, 90))
    d.line([(cx, cy - 195 * s), (cx, cy - 90 * s)], fill=(20, 30, 45), width=int(8 * s))
    d.rectangle([cx - 150 * s, cy - 225 * s, cx + 150 * s, cy - 205 * s], fill=tuple(int(c * 0.7) for c in cab))
    for sx in (-1, 1):
        d.ellipse([cx + sx * 110 * s - 30 * s, cy - 70 * s, cx + sx * 110 * s + 30 * s, cy - 10 * s], fill=(255, 245, 190))
        d.rectangle([cx + sx * 175 * s - 12 * s, cy - 150 * s, cx + sx * 175 * s + 12 * s, cy - 40 * s], fill=(190, 190, 200))
    d.rectangle([cx - 100 * s, cy - 50 * s, cx + 100 * s, cy + 10 * s], fill=(190, 195, 205))
    for k in range(6):
        d.line([(cx - 100 * s, cy - 45 * s + k * 10 * s), (cx + 100 * s, cy - 45 * s + k * 10 * s)], fill=(90, 95, 105), width=int(3 * s))
    d.rectangle([cx - 160 * s, cy + 40 * s, cx + 160 * s, cy + 75 * s], fill=(30, 30, 34))

def stars(img, n, top, bottom):
    d = ImageDraw.Draw(img)
    for _ in range(n):
        x = random.randint(0, img.width - 1); y = random.randint(top, bottom)
        r = random.choice([1, 1, 2, 3])
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255))

# ---------------- ROAD RUSH ----------------
def rush_scene(w, h, horizon_k):
    img = grad(w, h, (40, 12, 90), (255, 120, 60))
    d = ImageDraw.Draw(img)
    hy = int(h * horizon_k)
    sun_r = int(min(w, h) * 0.22)
    d.ellipse([w // 2 - sun_r, hy - sun_r, w // 2 + sun_r, hy + sun_r], fill=(255, 220, 120))
    for k in range(7):
        y = hy - sun_r + int(k * sun_r / 3.2)
        d.rectangle([w // 2 - sun_r, y, w // 2 + sun_r, y + 3 + k * 2], fill=(255, 140, 70))
    d.rectangle([0, hy, w, h], fill=(25, 10, 50))
    for x in range(0, w, 30):                                  # a city skyline
        bh = random.randint(20, int(h * 0.12)); d.rectangle([x, hy - bh, x + 26, hy], fill=(30, 12, 55))
    road(img, hy, w // 2, w, h, (55, 52, 70), (230, 40, 70), (250, 240, 120), sway=0.35)
    return img, hy

img, hy = rush_scene(3072, 1023, 0.55)
d = ImageDraw.Draw(img)
sports_car(d, 1536, 960, 1.25)
title(img, "ROAD RUSH", 330, 60, (255, 250, 245), (255, 60, 140))
img.convert("RGB").save("vr-art/marquee-roadrush.jpg", quality=92)

img, hy = rush_scene(887, 1774, 0.5)
d = ImageDraw.Draw(img)
sports_car(d, 443, 1500, 1.9)
title(img, "ROAD", 210, 150, (255, 250, 245), (255, 60, 140))
title(img, "RUSH", 210, 370, (255, 250, 245), (255, 60, 140))
for k in range(14):
    x = random.randint(0, 887); y = random.randint(900, 1700)
    d.line([(x, y), (x, y + random.randint(60, 200))], fill=(255, 255, 255, 120), width=3)
img.convert("RGB").save("vr-art/side-roadrush-flat.png")

# ---------------- BIG RIG ----------------
def rig_scene(w, h, horizon_k):
    img = grad(w, h, (6, 10, 40), (40, 60, 110))
    stars(img, 160, 0, int(h * horizon_k) - 10)
    d = ImageDraw.Draw(img)
    hy = int(h * horizon_k)
    d.polygon([(0, hy), (w * 0.15, hy - h * 0.07), (w * 0.32, hy - h * 0.02), (w * 0.5, hy - h * 0.09), (w * 0.7, hy - h * 0.03), (w * 0.88, hy - h * 0.08), (w, hy)], fill=(14, 24, 48))
    d.rectangle([0, hy, w, h], fill=(16, 32, 26))
    road(img, hy, w // 2, w, h, (48, 50, 56), (230, 190, 40), (240, 240, 235), sway=-0.15)
    return img, hy

img, hy = rig_scene(3072, 1023, 0.52)
d = ImageDraw.Draw(img)
rig(d, 2650, 930, 1.15)
title(img, "BIG RIG", 320, 70, (255, 214, 90), (255, 140, 20))
d.text((430, 430), "DELIVER OR DIE", font=F(70), fill=(255, 255, 255))
img.convert("RGB").save("vr-art/marquee-bigrig.jpg", quality=92)

img, hy = rig_scene(887, 1774, 0.48)
d = ImageDraw.Draw(img)
rig(d, 443, 1560, 1.6)
title(img, "BIG", 240, 120, (255, 214, 90), (255, 140, 20))
title(img, "RIG", 240, 370, (255, 214, 90), (255, 140, 20))
img.convert("RGB").save("vr-art/side-bigrig-flat.png")
print("ok")
