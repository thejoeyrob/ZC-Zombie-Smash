#!/usr/bin/env python3
"""Draws the Frustration / Trouble board used on the lounge table (vr-art/boardgame-trouble.jpg).
The 28 track spaces are the edge cells of an 8x8 grid; the positions are mirrored in scripts/board_game.gd (MARGIN, CELL, TRACK, START, LANES, HOMES)."""
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
random.seed(7)
S, MARGIN, CELL = 1024, 72, 110
title = ImageFont.truetype("DejaVuSans-Bold.ttf", 54)
small = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
tiny = ImageFont.truetype("DejaVuSans-Bold.ttf", 15)
COL = [(86, 200, 70), (226, 52, 52), (250, 160, 34), (170, 108, 250)]      # seat colours: green, red, amber, purple (match the stools)
TRACK = ([(0, 7 - n) for n in range(8)] + [(n - 7, 0) for n in range(8, 15)] + [(7, n - 14) for n in range(15, 22)] + [(7 - (n - 21), 7) for n in range(22, 28)])
assert len(TRACK) == 28
START = [24, 3, 10, 17]
LANES = [[(5, 6), (5, 5), (5, 4), (5, 3)], [(1, 5), (2, 5), (3, 5), (4, 5)], [(2, 1), (2, 2), (2, 3), (2, 4)], [(6, 2), (5, 2), (4, 2), (3, 2)]]
HOMES = [[(1, 6), (2, 6), (3, 6), (4, 6)], [(1, 1), (1, 2), (1, 3), (1, 4)], [(3, 1), (4, 1), (5, 1), (6, 1)], [(6, 3), (6, 4), (6, 5), (6, 6)]]
img = Image.new("RGB", (S, S), (44, 30, 22))
a = np.asarray(img).astype(np.float32)
yy, xx = np.mgrid[0:S, 0:S]
grain = (np.sin(yy * 0.18 + np.sin(xx * 0.011) * 5.0) * 0.5 + 0.5) * 14 + np.random.RandomState(3).rand(S, S) * 8
a += grain[..., None] * np.array([1.0, 0.8, 0.6])
img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(img)
d.rounded_rectangle([34, 34, S - 34, S - 34], radius=40, fill=(30, 66, 58), outline=(12, 24, 20), width=8)
d.rounded_rectangle([MARGIN - 8, MARGIN - 8, S - MARGIN + 8, S - MARGIN + 8], radius=30, outline=(190, 150, 70), width=4)
def centre(c, r): return (MARGIN + (c + 0.5) * CELL, MARGIN + (r + 0.5) * CELL)
def hole(c, r, fill, rad=34, ring=None):
    x, y = centre(c, r)
    d.ellipse([x - rad - 5, y - rad - 5, x + rad + 5, y + rad + 5], fill=(15, 14, 12))
    d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=fill, outline=ring or (10, 10, 10), width=3)
    d.ellipse([x - rad + 9, y - rad + 9, x + rad - 9, y + rad - 9], outline=tuple(int(v * 0.55) for v in fill), width=3)
for n, (c, r) in enumerate(TRACK):
    s = START.index(n) if n in START else -1
    hole(c, r, COL[s] if s >= 0 else (232, 224, 196), 36 if s >= 0 else 32)
    if s >= 0:
        x, y = centre(c, r)
        d.text((x - 7, y - 14), "S", font=small, fill=(20, 20, 20))
for s in range(4):
    for i, (c, r) in enumerate(LANES[s]):
        hole(c, r, tuple(int(v * 0.8 + 40) for v in COL[s]), 30)
        x, y = centre(c, r)
        d.text((x - 6, y - 14), str(i + 1), font=small, fill=(25, 25, 25))
    for (c, r) in HOMES[s]:
        hole(c, r, tuple(int(v * 0.45) for v in COL[s]), 30, tuple(int(v * 0.9) for v in COL[s]))
# the middle: the Pop-O-Matic dome sits here
cx, cy = MARGIN + 4.0 * CELL, MARGIN + 4.0 * CELL
d.ellipse([cx - 100, cy - 100, cx + 100, cy + 100], fill=(22, 18, 16), outline=(190, 150, 70), width=6)
d.ellipse([cx - 84, cy - 84, cx + 84, cy + 84], outline=(190, 150, 70), width=2)
w = d.textlength("TROUBLE", font=title)
d.text((cx - w / 2, cy - 30), "TROUBLE", font=title, fill=(226, 196, 120))
w2 = d.textlength("FRUSTRATION", font=tiny)
d.text((cx - w2 / 2, cy + 36), "FRUSTRATION", font=tiny, fill=(200, 170, 110))
w3 = d.textlength("ROLL A 6 TO START", font=small)
d.text((cx - w3 / 2, S - 62), "ROLL A 6 TO START  -  SEND THEM HOME  -  FIRST FULL HOME WINS", font=small, fill=(226, 196, 120)) if False else d.text((cx - w3 / 2 - 140, S - 58), "ROLL A 6 TO START", font=small, fill=(226, 196, 120))
a = np.asarray(img.filter(ImageFilter.GaussianBlur(0.5))).astype(np.float32)
Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save("vr-art/boardgame-trouble.jpg", quality=93)
print("ok")
