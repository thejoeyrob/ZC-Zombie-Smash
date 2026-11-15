"""Recolour the yellow joystick ball of retro-stick.png into other colours and patterns.
Usage: python3 art-pipeline/make-stick-toppers.py   (writes retro-stick-<id>.png next to retro-stick.png)"""
import numpy as np
from PIL import Image, ImageFilter
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = Image.open(os.path.join(ROOT, 'retro-stick.png')).convert('RGBA')
A = np.array(SRC).astype(float) / 255
H_, W_ = A.shape[:2]; FW = W_ // 3
rgb, alpha = A[..., :3], A[..., 3]
mx, mn = rgb.max(-1), rgb.min(-1); d = mx - mn
sat = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0); val = mx
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
hue = np.zeros_like(mx); m = d > 1e-6
hue = np.where(m & (mx == r), ((g - b) / np.maximum(d, 1e-6)) % 6, hue)
hue = np.where(m & (mx == g), (b - r) / np.maximum(d, 1e-6) + 2, hue)
hue = np.where(m & (mx == b), (r - g) / np.maximum(d, 1e-6) + 4, hue)
hue *= 60

def sstep(x, a, bb): t = np.clip((x - a) / (bb - a), 0, 1); return t * t * (3 - 2 * t)
# how "yellow ball" each pixel is: warm hue, saturated or (specular) bright and near the ball
ball = sstep(sat, 0.28, 0.55) * sstep(val, 0.3, 0.5) * ((hue > 20) & (hue < 80)) * alpha
# bright specular highlights have low saturation: keep them if they sit inside the ball's blob
core = Image.fromarray((ball > 0.5).astype(np.uint8) * 255)
filled = np.array(core.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))) > 0
spec = filled & (sat < 0.28) & (val > 0.7)
ball = np.maximum(ball, spec * alpha)

def frame_geometry(f):
    sl = ball[:, f * FW:(f + 1) * FW] > 0.5
    ys, xs = np.nonzero(sl)
    cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
    return cx, cy, (xs.max() - xs.min()) / 2, (ys.max() - ys.min()) / 2

GEO = [frame_geometry(f) for f in range(3)]

def disc_mask():
    yy, xx = np.mgrid[0:H_, 0:FW]; m = np.zeros((H_, W_))
    for f in range(3):
        cx, cy, rx, ry = GEO[f]
        x = xx - cx; y = yy - cy
        dist = np.sqrt(x * x + y * y)
        m[:, f * FW:(f + 1) * FW] = np.clip((rx + 1.3 - dist), 0, 1)
    return m * (alpha > 0.5)
DISC = disc_mask()

def smooth_noise(shape, scale, seed):
    g = np.random.default_rng(seed)
    small = g.random((max(2, int(shape[0] / scale) + 2), max(2, int(shape[1] / scale) + 2)))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((shape[1], shape[0]), Image.BICUBIC)
    return np.array(img).astype(float) / 255

def hsv2rgb(h, s, v):
    h = (h % 360) / 60; i = np.floor(h).astype(int) % 6; f = h - np.floor(h)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    out = np.zeros(h.shape + (3,))
    for k, (rr, gg, bb) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        sel = i == k; out[..., 0][sel] = rr[sel]; out[..., 1][sel] = gg[sel]; out[..., 2][sel] = bb[sel]
    return out

# solid colours: (hue, saturation scale, value scale)
SOLID = {'red': (2, 1.0, 1.0), 'blue': (214, 0.9, 0.95), 'green': (128, 0.9, 0.9), 'grey': (0, 0.0, 0.82)}

def pattern_rgb(name, u, v, seed=1):
    """u, v in -1..1 across the ball; returns an (h, w, 3) colour field."""
    ang = np.arctan2(v, u); rad = np.sqrt(u * u + v * v)
    # wrap the pattern round the sphere a little so stripes bend at the edges
    uu = np.arcsin(np.clip(u, -.98, .98)) / 1.4; vv = np.arcsin(np.clip(v, -.98, .98)) / 1.4
    if name == 'camo':
        n1 = smooth_noise(u.shape, 24, seed); n2 = smooth_noise(u.shape, 12, seed + 1); n = n1 * 0.7 + n2 * 0.3
        out = np.zeros(u.shape + (3,)); out[:] = (0.36, 0.42, 0.20)
        out[n > 0.46] = (0.52, 0.46, 0.27); out[n > 0.58] = (0.22, 0.27, 0.12); out[n > 0.70] = (0.08, 0.09, 0.05)
        return out
    if name == 'candy':
        t = ((uu * 1.0 + vv * 1.0) * 5.5 + np.sin(rad * 3.2) * 0.6)
        k = (np.floor(t) % 2 == 0)
        out = np.zeros(u.shape + (3,)); out[k] = (0.93, 0.12, 0.17); out[~k] = (0.98, 0.96, 0.93)
        return out
    if name == 'checker':
        k = ((np.floor(u * 2.5 + 0.5) + np.floor(v * 2.5 + 0.5)) % 2 == 0)
        out = np.zeros(u.shape + (3,)); out[k] = (0.97, 0.97, 0.97); out[~k] = (0.07, 0.07, 0.09)
        return out
    if name == 'rainbow':
        hue_ = (uu * 140 + vv * 140 + 180 + rad * 40)
        return hsv2rgb(hue_, np.full(u.shape, 0.78), np.full(u.shape, 0.98))
    if name == 'galaxy':
        n = smooth_noise(u.shape, 30, seed) * 0.6 + smooth_noise(u.shape, 10, seed + 3) * 0.4
        base = np.stack([0.10 + n * 0.45, 0.04 + n * 0.12, 0.28 + n * 0.55], -1)
        g = np.random.default_rng(seed); stars = (g.random(u.shape) > 0.993).astype(float)
        stars = np.array(Image.fromarray((stars * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))).astype(float) / 255
        return np.clip(base + stars[..., None] * 0.9, 0, 1)
    if name == 'lava':
        n = smooth_noise(u.shape, 30, seed + 5); n2 = smooth_noise(u.shape, 14, seed + 9)
        crack = np.abs(((n * 0.75 + n2 * 0.25) * 3.2) % 1 - 0.5)
        glow = np.clip(1 - crack * 7, 0, 1) ** 1.5
        out = np.zeros(u.shape + (3,)); out[:] = (0.09, 0.07, 0.07)
        out += glow[..., None] * np.array([1.0, 0.45, 0.05]) * 0.95
        return np.clip(out, 0, 1)
    raise KeyError(name)

PATTERNS = ['camo', 'candy', 'checker', 'rainbow', 'galaxy', 'lava']

def build(name):
    out = rgb.copy()
    w = DISC[..., None]
    if name in SOLID:
        hh, ss, vs = SOLID[name]
        new_s = np.clip(sat * ss, 0, 1); new_v = np.clip(val * vs + (1 - vs) * 0 , 0, 1)
        col = hsv2rgb(np.full(hue.shape, float(hh)), new_s, new_v)
        if name == 'grey':   # keep the highlight, neutral body
            col = np.stack([new_v] * 3, -1)
        out = out * (1 - w) + col * w
    else:
        col = np.zeros_like(rgb)
        yy, xx = np.mgrid[0:H_, 0:FW]
        for f in range(3):
            cx, cy, rx, ry = GEO[f]
            u = (xx - cx) / rx; v = (yy - cy) / ry
            P = pattern_rgb(name, u, v, 3 + f * 0)
            # lighting from the original ball: darker where it was darker, white where it was specular
            light = np.clip(val[:, f * FW:(f + 1) * FW] / 0.92, 0, 1.15)[..., None]
            sp = np.clip((0.55 - sat[:, f * FW:(f + 1) * FW]) / 0.45, 0, 1)[..., None] * (val[:, f * FW:(f + 1) * FW][..., None] > 0.75)
            col[:, f * FW:(f + 1) * FW] = np.clip(P * light * (1 - sp) + sp * 1.0, 0, 1)
        out = out * (1 - w) + col * w
    res = np.concatenate([np.clip(out, 0, 1), alpha[..., None]], -1)
    return Image.fromarray((res * 255).round().astype(np.uint8))

if __name__ == '__main__':
    outdir = sys.argv[1] if len(sys.argv) > 1 else ROOT
    for n in list(SOLID) + PATTERNS:
        build(n).save(os.path.join(outdir, f'retro-stick-{n}.png'), optimize=True)
    print('wrote', len(SOLID) + len(PATTERNS), 'toppers; geometry', GEO)
