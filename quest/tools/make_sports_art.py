#!/usr/bin/env python3
"""Art for the sports hall: vr-art/dartboard.png (a regulation board, radius 225 mm = 512 px), vr-art/axe-target.png (a painted wood target)
and vr-art/lane-wood.png (a bowling lane: 39 maple boards, arrows and range dots). Geometry is mirrored in scripts/darts_game.gd / axe_game.gd."""
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
random.seed(5)
rs = np.random.RandomState(5)

# ---- dartboard: sector order clockwise from the top ----
ORDER = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
S = 1024; C = S // 2; K = 512 / 225.0            # px per mm
img = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
def ring(r_mm, fill): d.ellipse([C - r_mm * K, C - r_mm * K, C + r_mm * K, C + r_mm * K], fill=fill)
ring(225, (14, 14, 16, 255))                                         # the black surround with the numbers
BLACK, CREAM, RED, GREEN = (24, 24, 26), (232, 214, 170), (200, 34, 40), (24, 140, 70)
def wedge(r_out, r_in, a0, a1, fill):
    pts = []
    for t in np.linspace(a0, a1, 14): pts.append((C + math.sin(t) * r_out * K, C - math.cos(t) * r_out * K))
    for t in np.linspace(a1, a0, 14): pts.append((C + math.sin(t) * r_in * K, C - math.cos(t) * r_in * K))
    d.polygon(pts, fill=fill)
for i in range(20):
    a0 = math.radians(i * 18 - 9); a1 = math.radians(i * 18 + 9)
    dark = i % 2 == 0
    base = BLACK if dark else CREAM
    col = RED if dark else GREEN
    wedge(170, 162, a0, a1, col); wedge(162, 107, a0, a1, base); wedge(107, 99, a0, a1, col); wedge(99, 31.8, a0, a1, base)
ring(31.8, GREEN); ring(12.7, RED)
# wire
wire = (190, 190, 196, 255)
for r in (170, 162, 107, 99, 31.8, 12.7): d.ellipse([C - r * K, C - r * K, C + r * K, C + r * K], outline=wire, width=2)
for i in range(20):
    a = math.radians(i * 18 - 9); d.line([(C + math.sin(a) * 12.7 * K, C - math.cos(a) * 12.7 * K), (C + math.sin(a) * 170 * K, C - math.cos(a) * 170 * K)], fill=wire, width=2)
font = ImageFont.truetype("DejaVuSans-Bold.ttf", 46)
for i, n in enumerate(ORDER):
    a = math.radians(i * 18); x = C + math.sin(a) * 196 * K; y = C - math.cos(a) * 196 * K
    w = d.textlength(str(n), font=font); d.text((x - w / 2, y - 26), str(n), font=font, fill=(236, 236, 230))
img.filter(ImageFilter.GaussianBlur(0.6)).save("vr-art/dartboard.png")

# ---- axe target: wood planks, rings 1-5 (blue bullseye ring), two blue clutch dots in the top corners ----
S = 1024
a = np.zeros((S, S, 3), np.float32)
for p in range(8):
    base = np.array([176, 138, 92]) + rs.randint(-14, 14, 3)
    y0, y1 = p * S // 8, (p + 1) * S // 8
    xx = np.arange(S)[None, :]
    grain = np.sin(xx * 0.05 + p * 3.1 + np.sin(np.arange(y1 - y0)[:, None] * 0.11) * 2.0) * 9 + rs.rand(y1 - y0, S) * 14
    a[y0:y1] = base + grain[..., None]
a[:, :, 0] = np.clip(a[:, :, 0], 0, 255)
img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA"); d = ImageDraw.Draw(img)
for p in range(1, 8): d.line([(0, p * S // 8), (S, p * S // 8)], fill=(70, 46, 28, 255), width=4)
M = S / 1.2                                                     # px per metre on a 1.2 m board
cx, cy = S / 2, S / 2 + 0.06 * M
radii = [0.381, 0.305, 0.229, 0.152, 0.076]; cols = [(30, 30, 34), (190, 36, 36), (30, 30, 34), (190, 36, 36), (36, 88, 190)]
for r, c in zip(radii, cols):
    d.ellipse([cx - r * M, cy - r * M, cx + r * M, cy + r * M], fill=c + (255,), outline=(240, 240, 235, 255), width=6)
f2 = ImageFont.truetype("DejaVuSans-Bold.ttf", 34)
for r, n in zip(radii, (1, 2, 3, 4, 5)):
    rr = r - 0.038
    d.text((cx - 10, cy - 18 if n == 5 else cy - rr * M - 18), str(n), font=f2, fill=(245, 245, 240, 255))
for sx in (-1, 1):
    x, y = cx + sx * 0.33 * M, cy - 0.31 * M
    d.ellipse([x - 0.045 * M, y - 0.045 * M, x + 0.045 * M, y + 0.045 * M], fill=(36, 88, 190, 255), outline=(240, 240, 235, 255), width=5)
    d.text((x - 10, y - 20), "7", font=f2, fill=(245, 245, 240, 255))
d.rectangle([0, 0, S - 1, S - 1], outline=(60, 38, 22, 255), width=14)
img.save("vr-art/axe-target.png")

# ---- lane: 39 boards across 512 px, 2048 px long (the map is stretched along the lane); arrows at 4.5 m, dots, foul-line gloss ----
W, L = 512, 2048
a = np.zeros((L, W, 3), np.float32)
bw = W / 39.0
for b in range(39):
    x0, x1 = int(b * bw), int((b + 1) * bw)
    tone = np.array([222, 176, 112]) + rs.randint(-12, 12, 3)
    streak = (np.sin(np.arange(L)[:, None] * 0.013 + b * 1.7) * 6 + rs.rand(L, x1 - x0) * 8)
    a[:, x0:x1] = tone + streak[..., None]
    a[:, x0:x0 + 1] *= 0.78
img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(img)
def y_of(m): return int(L - m / 18.0 * L)                      # metres from the foul line (0) to the pins (18) -> the far end is the top of the picture
for m in (4.5, 4.5):
    pass
for k in range(-3, 4):                                           # seven arrows in a V
    x = W // 2 + k * (W // 8); y = y_of(4.5 + (3 - abs(k)) * 0.35)
    d.polygon([(x, y - 20), (x - 9, y + 12), (x + 9, y + 12)], fill=(90, 52, 28))
for k in (-3, -2, -1, 0, 1, 2, 3):                               # range dots
    x = W // 2 + k * (W // 8); y = y_of(3.0); d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(90, 52, 28))
d.rectangle([0, y_of(0.0) - 8, W, y_of(0.0)], fill=(40, 30, 24))  # foul line
img.filter(ImageFilter.GaussianBlur(0.5)).save("vr-art/lane-wood.png")
print("ok")
