"""Shrinks in-game sprites that were drawn far larger than the screen ever shows them.
Canvas backing is 2 px per game unit, so a sprite needs about 2.5 source pixels per unit; the originals had 6 to 10.
Run once on original art: python3 scripts/fit-sprites.py   (rewrites the .webp files and art-bounds.json)"""
import json, glob, math, os
from PIL import Image
B = json.load(open('art-bounds.json'))
H = {'normal': 61, 'runner': 61, 'helmet': 67, 'toxic': 70, 'armored': 75, 'berserker': 73, 'brute': 94, 'titan': 109, 'fuse': 75, 'bulwark': 88}
SKIP = ('player-victory', 'player-portrait', 'joey-reaction', 'player-reaction')
def factor(name, b):
    stem = name[:-5]
    bw, bh = b[2], b[3]
    if stem.startswith('zombie-') and stem[7:] in H:
        h = H[stem[7:]]; w = h * 0.82; return min(1, 2.5 * min(w / bw, h / bh))
    if stem.startswith('boss-'): return 0.5
    if stem.startswith('player-') and not stem.startswith(SKIP): return max(0.5, min(1, 2.5 * min(70 / bw, 91 / bh)))
    if stem.startswith('pickup-'): return max(0.3, min(1, 2.5 * 24 / max(bw, bh)))
    if stem.startswith(('bullet-', 'fx-')): return max(0.3, min(1, 2.5 * 24 / max(bw, bh)))
    if stem.startswith('weapon-'): return 0.5
    if stem == 'prop-barrel': return 0.4
    return 1
saved = 0
for name in sorted(B):
    if name not in os.listdir('.') : continue
    f = factor(name, B[name])
    if f >= 0.97: continue
    im = Image.open(name).convert('RGBA'); w, h = im.size
    nw, nh = max(1, round(w * f)), max(1, round(h * f))
    small = im.convert('RGBa').resize((nw, nh), Image.LANCZOS).convert('RGBA')
    x, y, bw, bh = B[name]
    sx, sy = nw / w, nh / h
    nx, ny = max(0, math.floor(x * sx)), max(0, math.floor(y * sy))
    B[name] = [nx, ny, min(nw - nx, math.ceil((x + bw) * sx) - nx), min(nh - ny, math.ceil((y + bh) * sy) - ny)]
    before = os.path.getsize(name)
    small.save(name, quality=94, method=6)
    saved += before - os.path.getsize(name)
    print(f'{name:40s} {w}x{h} -> {nw}x{nh}')
json.dump(B, open('art-bounds.json', 'w'), separators=(',', ':'))
print('decoded memory before/after is in the docs; file bytes saved:', saved // 1000, 'KB')
