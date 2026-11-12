#!/usr/bin/env python3
"""Textures for the modern room, drawn from scratch: polished concrete, painted plaster and oak acoustic slats.
Each makes vr-art/pbr-<name>-c.jpg (colour), -n.png (bumps) and -r.jpg (roughness), the names VRBuild.pbr() looks for."""
import numpy as np
from PIL import Image, ImageFilter
rs = np.random.RandomState(12)

def noise(size, scale, seed):
    r = np.random.RandomState(seed)
    small = r.rand(max(2, size // scale), max(2, size // scale)).astype(np.float32)
    im = Image.fromarray((small * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
    return np.asarray(im).astype(np.float32) / 255.0

def fbm(size, seed, octaves=(256, 96, 32, 12), weights=(0.45, 0.3, 0.17, 0.08)):
    a = np.zeros((size, size), np.float32)
    for k, (sc, w) in enumerate(zip(octaves, weights)):
        a += noise(size, sc, seed + k) * w
    return a

def normal_from_height(h, strength):
    gy, gx = np.gradient(h)
    n = np.dstack((-gx * strength, -gy * strength, np.ones_like(h)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)

def save(name, col, rough, h, ns):
    Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)).save(f"vr-art/pbr-{name}-c.jpg", quality=92)
    Image.fromarray(np.clip(rough * 255, 0, 255).astype(np.uint8)).save(f"vr-art/pbr-{name}-r.jpg", quality=90)
    Image.fromarray(normal_from_height(h, ns)).save(f"vr-art/pbr-{name}-n.png")

S = 1024
# ---- polished concrete: soft cloudy mottling, fine pores, faint saw-cut joints ----
m = fbm(S, 1)
fine = noise(S, 3, 9) * 0.5 + noise(S, 2, 10) * 0.5
base = 0.50 + (m - 0.5) * 0.30 + (fine - 0.5) * 0.05
col = np.dstack([base * 196, base * 198, base * 202])
for p in (0, S // 2):                                              # saw-cut joints
    col[p:p + 3, :, :] *= 0.72
    col[:, p:p + 3, :] *= 0.72
rough = 0.30 + (1 - m) * 0.22 + (fine - 0.5) * 0.08
rough[:3, :] = 0.7; rough[:, :3] = 0.7
h = fine * 0.15 + m * 0.3
save("concrete", col, rough, h, 2.0)

# ---- painted plaster: very fine eggshell texture, barely there ----
f = noise(S, 2, 21) * 0.6 + noise(S, 5, 22) * 0.4
m2 = fbm(S, 30, octaves=(256, 64, 16, 6))
base = 0.90 + (m2 - 0.5) * 0.04 + (f - 0.5) * 0.03
col = np.dstack([base * 232, base * 228, base * 220])
save("plaster", col, 0.85 + (f - 0.5) * 0.06, f * 0.5, 0.8)

# ---- oak acoustic slats: vertical oak battens with dark gaps and a felt backing ----
H, W = S, S
slat, gap = 56, 14
col = np.zeros((H, W, 3), np.float32)
h = np.zeros((H, W), np.float32)
rough = np.full((H, W), 0.6, np.float32)
x = 0
i = 0
while x < W:
    w = min(slat, W - x)
    tone = 0.92 + rs.rand() * 0.16
    yy = np.arange(H)[:, None]
    grain = (np.sin(yy * 0.021 + i * 1.7 + np.sin(yy * 0.004 + i) * 3.0) * 0.5 + 0.5) * 0.12 + noise(S, 3, 40 + i)[:, :w] * 0.06
    base = np.array([196, 150, 98], np.float32)
    col[:, x:x + w, :] = base * (tone + grain[..., None] - 0.1)
    h[:, x:x + w] = 1.0
    col[:, x + w - 3:x + w, :] *= 0.8
    x += w
    if x < W:
        g = min(gap, W - x)
        col[:, x:x + g, :] = np.array([34, 32, 30], np.float32)           # the felt in the gaps
        h[:, x:x + g] = 0.0
        rough[:, x:x + g] = 0.95
        x += g
    i += 1
h = np.asarray(Image.fromarray((h * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255.0
save("oakslat", col, rough, h, 6.0)
print("ok")
