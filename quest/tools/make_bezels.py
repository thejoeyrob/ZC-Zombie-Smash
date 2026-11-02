#!/usr/bin/env python3
"""Cuts each boss's ornate console skin (the frames from the phone game) down to a screen bezel for the arcade machines.
Writes vr-art/bezel-<boss>.jpg (the top of the skin, up to its lower edge) and data/bezels.json (window rectangle in pixels)."""
import json, os
from PIL import Image
H = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(H, "..", "..")
OUT = os.path.join(H, "..", "vr-art")
res = {}
for b in ["jordan", "glowinghumanity", "debo", "caffeinatedsloth", "discoman", "fatamy", "drmantis", "joeyrob"]:
    im = Image.open(os.path.join(ROOT, "console-%s.webp" % b)).convert("RGB")
    W, Hh = im.size
    px = im.load()
    dark = lambda x, y: sum(px[x, y]) < 40
    cx, cy = W // 2, int(Hh * 0.28)
    assert dark(cx, cy), b
    x0 = cx
    while x0 > 0 and dark(x0 - 1, cy): x0 -= 1
    x1 = cx
    while x1 < W - 1 and dark(x1 + 1, cy): x1 += 1
    y0 = cy
    while y0 > 0 and dark(cx, y0 - 1): y0 -= 1
    y1 = cy
    while y1 < Hh - 1 and dark(cx, y1 + 1): y1 += 1
    border = int(min(x0, W - 1 - x1) * 0.9)
    bottom = min(Hh, y1 + 1 + max(border, 40))
    im.crop((0, 0, W, bottom)).save(os.path.join(OUT, "bezel-%s.jpg" % b), quality=93)
    res[b] = {"w": W, "h": bottom, "win": [x0, y0, x1 + 1, y1 + 1]}
    print(b, W, bottom, res[b]["win"], "window aspect", round((x1 + 1 - x0) / (y1 + 1 - y0), 3))
json.dump(res, open(os.path.join(H, "..", "data", "bezels.json"), "w"), indent=1)
