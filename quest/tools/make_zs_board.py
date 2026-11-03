#!/usr/bin/env python3
"""Draws the Zombie Smash race board: a loop of 28 squares round the edge of an 8x8 grid, with the rules in the middle.
Output vr-art/boardgame-zs.jpg. The squares' positions are mirrored in scripts/board_game.gd (MARGIN, CELL, the loop order, the square kinds)."""
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
random.seed(11)
S, MARGIN, CELL = 1024, 72, 110
F = lambda n, sz: ImageFont.truetype(n, sz)
bold = F("DejaVuSans-Bold.ttf", 30)
title = F("DejaVuSans-Bold.ttf", 66)
small = F("DejaVuSans-Bold.ttf", 22)
sym = F("DejaVuSans.ttf", 56)
img = Image.new("RGB", (S, S), (22, 34, 30))
d = ImageDraw.Draw(img)
# loop order: up the left edge, along the top, down the right edge, back along the bottom
cells = [(r, 0) for r in range(7, -1, -1)] + [(0, c) for c in range(1, 8)] + [(r, 7) for r in range(1, 8)] + [(7, c) for c in range(6, 0, -1)]
assert len(cells) == 28
KIND = {}
for i in (4, 13, 22): KIND[i] = "grenade"
for i in (6, 11, 17, 24): KIND[i] = "zombie"
for i in (3, 9, 15, 20, 26): KIND[i] = "heart"
BOSS = {8: "jordan", 14: "debo", 19: "drmantis", 25: "discoman"}
for i in BOSS: KIND[i] = "boss"
COL = {"normal": (214, 196, 150), "grenade": (230, 150, 50), "zombie": (120, 170, 80), "heart": (225, 90, 130), "boss": (140, 70, 170), "start": (60, 160, 110)}
for i, (r, c) in enumerate(cells):
    x0, y0 = MARGIN + c * CELL, MARGIN + r * CELL
    k = KIND.get(i, "start" if i == 0 else "normal")
    d.rectangle([x0, y0, x0 + CELL, y0 + CELL], fill=COL[k], outline=(30, 20, 16), width=4)
    d.rectangle([x0 + 6, y0 + 6, x0 + CELL - 6, y0 + CELL - 6], outline=tuple(int(v * 0.6) for v in COL[k]), width=2)
    cx, cy = x0 + CELL // 2, y0 + CELL // 2 + 4
    if k == "grenade":
        d.ellipse([cx - 22, cy - 18, cx + 22, cy + 26], fill=(70, 80, 40), outline=(20, 20, 10), width=3)
        d.rectangle([cx - 8, cy - 32, cx + 8, cy - 16], fill=(120, 120, 120))
        d.ellipse([cx + 4, cy - 40, cx + 24, cy - 24], outline=(210, 210, 210), width=3)
        d.text((cx - 18, y0 + 6), "+3", font=small, fill=(40, 20, 0))
    elif k == "zombie":
        d.text((cx - 28, cy - 38), "☠", font=sym, fill=(30, 50, 20))
        d.text((cx - 18, y0 + CELL - 30), "-2", font=small, fill=(30, 50, 20))
    elif k == "heart":
        d.text((cx - 28, cy - 38), "♥", font=sym, fill=(120, 10, 40))
        d.text((cx - 38, y0 + CELL - 30), "AGAIN", font=small, fill=(100, 10, 40))
    elif k == "boss":
        b = BOSS[i]
        try:
            fig = Image.open(f"vr-art/bobble-{b}-front.png").convert("RGBA")
            fig.thumbnail((CELL - 22, CELL - 22))
            img.paste(fig, (cx - fig.width // 2, cy - fig.height // 2 - 4), fig)
        except Exception as e:
            print("no boss art", b, e)
        d.text((x0 + 6, y0 + CELL - 28), "MISS", font=small, fill=(255, 235, 255))
    elif k == "start":
        d.text((cx - 38, cy - 18), "START", font=small, fill=(10, 50, 30))
        d.text((cx - 36, cy + 8), "FINISH", font=small, fill=(10, 50, 30))
    if k not in ("start",):
        d.text((x0 + CELL - 34, y0 + 4), str(i), font=small, fill=tuple(int(v * 0.45) for v in COL[k]))
# the middle: title and rules
mx0, my0, mx1, my1 = MARGIN + CELL + 14, MARGIN + CELL + 14, MARGIN + 7 * CELL - 14, MARGIN + 7 * CELL - 14
d.rounded_rectangle([mx0, my0, mx1, my1], 24, fill=(14, 20, 24), outline=(230, 190, 80), width=5)
d.text(((mx0 + mx1) // 2, my0 + 62), "ZOMBIE SMASH", font=title, fill=(120, 230, 70), anchor="mm")
d.text(((mx0 + mx1) // 2, my0 + 128), "RACE TO THE LAB", font=bold, fill=(255, 120, 150), anchor="mm")
rules = [("Roll the die and race round once.", (230, 230, 230)),
         ("GRENADE  jump forward 3", (255, 170, 60)),
         ("ZOMBIE  run back 2", (150, 210, 100)),
         ("HEART  roll again", (255, 110, 150)),
         ("BOSS  miss your next turn", (200, 130, 230)),
         ("First back to START wins!", (255, 235, 130))]
y = my0 + 200
for t, col in rules:
    d.text(((mx0 + mx1) // 2, y), t, font=small, fill=col, anchor="mm")
    y += 40
# the whole cast along the bottom of the panel
ids = ["jordan", "glowinghumanity", "debo", "caffeinatedsloth", "discoman", "fatamy", "drmantis"]
slot = (mx1 - mx0 - 30) // len(ids)
for k, b in enumerate(ids):
    try:
        fig = Image.open(f"vr-art/bobble-{b}-front.png").convert("RGBA")
        fig.thumbnail((slot - 8, 190))
        img.paste(fig, (mx0 + 15 + k * slot + (slot - fig.width) // 2, my1 - 22 - fig.height), fig)
    except Exception as e:
        print("no art", b)
# wear: paper grain, stains, scuffed edges
a = np.asarray(img).astype(np.float32)
a += np.random.RandomState(5).normal(0, 7, (S, S, 1))
yy, xx = np.mgrid[0:S, 0:S]
a *= (1.0 - 0.3 * (((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / (S * S / 2)) ** 1.2)[..., None]
stain = np.zeros((S, S), np.float32)
for _ in range(10):
    cx, cy, r = random.randint(0, S), random.randint(0, S), random.randint(40, 140)
    stain += np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * r * r))) * random.uniform(0.04, 0.1)
a *= (1.0 - stain)[..., None]
Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.5)).save("vr-art/boardgame-zs.jpg", quality=93)
print("ok")
