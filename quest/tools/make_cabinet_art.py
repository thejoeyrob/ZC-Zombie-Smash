#!/usr/bin/env python3
"""Cabinet art for the VR arcade.
1) Traces each side-art picture's outline into a polygon, so the 3D cabinet body is exactly the art's shape (data/cab_profiles.json).
2) Paints side art and marquees for the machines ChatGPT did not draw (Jordan, Glowing Humanity, Debo, Caffeinated Sloth)."""
import json, sys, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps
from scipy import ndimage as ndi

ROOT = "/home/user/ZC-Zombie-Smash"
ART = ROOT + "/quest/vr-art"
FONT = "/tmp/claude-0/barlow900.ttf"
THEMES = ["mantis", "disco", "fatamy", "pinball"]


def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    a, b = np.array(pts[0]), np.array(pts[-1])
    ab = b - a
    n = np.hypot(*ab) or 1e-9
    d = [abs(ab[0] * (p[1] - a[1]) - ab[1] * (p[0] - a[0])) / n for p in pts[1:-1]]
    i = int(np.argmax(d))
    if d[i] > eps:
        left = rdp(pts[:i + 2], eps)
        right = rdp(pts[i + 1:], eps)
        return left[:-1] + right
    return [pts[0], pts[-1]]


def profile(alpha):
    H, W = alpha.shape
    rows = [y for y in range(H) if alpha[y].any()]
    y0, y1 = rows[0], rows[-1]
    left, right = [], []
    for y in range(y0, y1 + 1, 6):
        xs = np.where(alpha[y])[0]
        if len(xs):
            left.append((xs.min() / W, y / H))
            right.append((xs.max() / W, y / H))
    poly = rdp(left, 0.004) + rdp(right[::-1], 0.004)
    def med(side, v0, v1):
        vals = []
        for y in range(int(v0 * H), int(v1 * H), 5):
            xs = np.where(alpha[y])[0]
            if len(xs):
                vals.append((xs.min() if side == "l" else xs.max()) / W)
        return float(np.median(vals))
    def pct(side, v0, v1, q):
        vals = []
        for y in range(int(v0 * H), int(v1 * H), 5):
            xs = np.where(alpha[y])[0]
            if len(xs):
                vals.append((xs.min() if side == "l" else xs.max()) / W)
        return float(np.percentile(vals, q))
    return {"poly": [[round(float(x), 4), round(float(y), 4)] for x, y in poly],
            "front_low": med("r", 0.78, 0.92), "back_low": med("l", 0.55, 0.9), "top_v": y0 / H,
            "front_body": pct("r", 0.6, 0.93, 10), "back_body": pct("l", 0.5, 0.9, 90)}


def silhouette_alpha(name):
    im = Image.open(f"{ART}/side-{name}.png").convert("RGBA")
    return np.asarray(im)[:, :, 3] > 128, im


def paint_side(boss, template_alpha, accent, arena, sprite):
    W, H = 512, 1024
    mask = np.asarray(Image.fromarray((template_alpha * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)) > 128
    ac = tuple(int(accent[i:i + 2], 16) for i in (1, 3, 5))
    bg = Image.open(arena).convert("RGB")
    bg = ImageOps.fit(bg, (W, H)).filter(ImageFilter.GaussianBlur(3))
    bg = Image.blend(bg, Image.new("RGB", (W, H), tuple(int(c * 0.25) for c in ac)), 0.5)
    # darker toward the top, brighter glow toward the middle
    grad = Image.linear_gradient("L").resize((W, H)).point(lambda v: int(255 - v * 0.55))
    bg = Image.composite(bg, Image.new("RGB", (W, H), (6, 6, 12)), grad)
    sp = Image.open(sprite).convert("RGBA")
    bb = sp.getbbox()
    sp = sp.crop(bb)
    s = 0.95 * W / sp.width
    sp = sp.resize((int(sp.width * s), int(sp.height * s)), Image.LANCZOS)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow.paste(sp, ((W - sp.width) // 2 + 8, int(H * 0.38)), sp)
    halo = glow.split()[3].filter(ImageFilter.GaussianBlur(14))
    bg = Image.composite(Image.new("RGB", (W, H), ac), bg, halo.point(lambda v: int(v * 0.5)))
    bg.paste(glow.convert("RGB"), (0, 0), glow.split()[3])
    f = ImageFont.truetype(FONT, 78)
    d = ImageDraw.Draw(bg)
    txt = boss["name"]
    tw = d.textlength(txt, font=f)
    if tw > W - 80:
        f = ImageFont.truetype(FONT, int(78 * (W - 80) / tw))
        tw = d.textlength(txt, font=f)
    d.text(((W - tw) / 2 + 40, int(H * 0.24)), txt, font=f, fill=ac, stroke_width=5, stroke_fill=(0, 0, 0))
    rgba = np.dstack([np.asarray(bg), (mask * 255).astype(np.uint8)])
    out = Image.fromarray(rgba, "RGBA")
    # neon edge
    edge = ndi.binary_dilation(mask, iterations=5) & ~ndi.binary_erosion(mask, iterations=3)
    arr = np.asarray(out).copy()
    arr[edge & mask] = (*ac, 255)
    return Image.fromarray(arr, "RGBA")


def paint_marquee(boss, accent, arena, sprite):
    W, H = 1024, 341
    ac = tuple(int(accent[i:i + 2], 16) for i in (1, 3, 5))
    bg = ImageOps.fit(Image.open(arena).convert("RGB"), (W, H), centering=(0.5, 0.3)).filter(ImageFilter.GaussianBlur(2))
    bg = Image.blend(bg, Image.new("RGB", (W, H), tuple(int(c * 0.3) for c in ac)), 0.55)
    sp = Image.open(sprite).convert("RGBA")
    sp = sp.crop(sp.getbbox())
    s = H * 0.98 / sp.height
    sp = sp.resize((int(sp.width * s), int(sp.height * s)), Image.LANCZOS)
    bg.paste(sp, (18, H - sp.height - 2), sp)
    spf = ImageOps.mirror(sp)
    bg.paste(spf, (W - spf.width - 18, H - spf.height - 2), spf)
    d = ImageDraw.Draw(bg)
    f = ImageFont.truetype(FONT, 190)
    txt = boss["name"]
    tw = d.textlength(txt, font=f)
    if tw > W * 0.58:
        f = ImageFont.truetype(FONT, int(190 * W * 0.58 / tw))
        tw = d.textlength(txt, font=f)
    d.text(((W - tw) / 2, H * 0.22), txt, font=f, fill=ac, stroke_width=8, stroke_fill=(0, 0, 0))
    d.rectangle([3, 3, W - 4, H - 4], outline=ac, width=6)
    return bg


def main():
    profiles = {}
    for n in THEMES:
        alpha, _ = silhouette_alpha(n)
        profiles[n] = profile(alpha)
        print(n, len(profiles[n]["poly"]), "pts", round(profiles[n]["front_low"], 2), round(profiles[n]["back_low"], 2))
    data = json.load(open(ROOT + "/quest/data/zs_data.json"))
    tmpl_alpha, _ = silhouette_alpha("fatamy")
    for b in data["BOSSES"]:
        if b["id"] in ("jordan", "glowinghumanity", "debo", "caffeinatedsloth"):
            arena = f"{ROOT}/arena-{b['id']}.webp"
            sprite = f"{ROOT}/{b['sprites'][0]}"
            paint_side(b, tmpl_alpha, b["accent"], arena, sprite).save(f"{ART}/side-{b['id']}.png")
            paint_marquee(b, b["accent"], arena, sprite).save(f"{ART}/marquee-{b['id']}.jpg", quality=88)
            profiles[b["id"]] = profiles["fatamy"]
    json.dump(profiles, open(ROOT + "/quest/data/cab_profiles.json", "w"))


main()
