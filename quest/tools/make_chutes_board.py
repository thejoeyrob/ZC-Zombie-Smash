#!/usr/bin/env python3
"""Draws the Chutes & Ladders board used on the lounge table: a worn, old printed game board (numbered 1-100, ladders, chutes)."""
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
random.seed(7)
S = 1024
M = 56
C = (S - 2 * M) // 10
img = Image.new("RGB", (S, S), (196, 170, 120))
d = ImageDraw.Draw(img)
pal = [(214, 120, 72), (233, 196, 106), (88, 150, 140), (198, 84, 84), (120, 160, 90)]
font = ImageFont.truetype("LiberationSerif-Bold.ttf", 30)
big = ImageFont.truetype("LiberationSerif-Bold.ttf", 44)
def centre(n):
    r = (n - 1) // 10
    c = (n - 1) % 10
    if r % 2 == 1: c = 9 - c
    return (M + c * C + C // 2, S - M - r * C - C // 2)
for n in range(1, 101):
    cx, cy = centre(n)
    col = pal[(n + (n - 1) // 10) % len(pal)]
    d.rectangle([cx - C // 2, cy - C // 2, cx + C // 2, cy + C // 2], fill=col, outline=(60, 40, 25), width=3)
    d.text((cx - C // 2 + 7, cy - C // 2 + 4), str(n), font=font, fill=(50, 30, 20))
def ladder(a, b):
    (x1, y1), (x2, y2) = centre(a), centre(b)
    dx, dy = x2 - x1, y2 - y1
    L = math.hypot(dx, dy)
    nx, ny = -dy / L * 14, dx / L * 14
    for s in (-1, 1):
        d.line([x1 + s * nx, y1 + s * ny, x2 + s * nx, y2 + s * ny], fill=(92, 58, 28), width=9)
    k = int(L // 34)
    for i in range(1, k):
        t = i / k
        px, py = x1 + dx * t, y1 + dy * t
        d.line([px - nx, py - ny, px + nx, py + ny], fill=(120, 78, 38), width=7)
def chute(a, b, col):
    (x1, y1), (x2, y2) = centre(a), centre(b)
    pts = []
    for i in range(41):
        t = i / 40
        wob = math.sin(t * math.pi * 2.5) * 38 * (1 - t * 0.3)
        px = x1 + (x2 - x1) * t + wob
        py = y1 + (y2 - y1) * t
        pts.append((px, py))
    d.line(pts, fill=(40, 25, 15), width=30)
    d.line(pts, fill=col, width=22)
    d.line([(p[0] - 5, p[1]) for p in pts], fill=tuple(min(255, c + 50) for c in col), width=5)
    d.ellipse([x1 - 24, y1 - 24, x1 + 24, y1 + 24], fill=(40, 25, 15))
    d.ellipse([x1 - 19, y1 - 19, x1 + 19, y1 + 19], fill=col)
for a, b in [(4, 25), (9, 31), (21, 42), (28, 84), (51, 67), (71, 91), (80, 100)]:
    ladder(a, b)
for a, b, col in [(16, 6, (200, 60, 60)), (47, 26, (230, 170, 40)), (49, 11, (70, 130, 190)), (56, 53, (200, 60, 60)), (62, 19, (230, 170, 40)), (87, 24, (70, 130, 190)), (93, 73, (200, 60, 60)), (98, 78, (230, 170, 40))]:
    chute(a, b, col)
d.text((M + 5, 6), "CHUTES & LADDERS", font=big, fill=(60, 36, 22))
# age it: paper grain, stains, worn edges and a darkened rim
a = np.asarray(img).astype(np.float32)
noise = np.random.RandomState(3).normal(0, 9, (S, S, 1))
a += noise
yy, xx = np.mgrid[0:S, 0:S]
vig = 1.0 - 0.35 * (((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / (S * S / 2)) ** 1.1
a *= vig[..., None]
stain = np.zeros((S, S), np.float32)
for _ in range(14):
    cx, cy, r = random.randint(0, S), random.randint(0, S), random.randint(40, 160)
    stain += np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * r * r))) * random.uniform(0.04, 0.12)
a *= (1.0 - stain)[..., None]
out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
out.save("vr-art/boardgame-chutes.jpg", quality=92)
print("ok")
