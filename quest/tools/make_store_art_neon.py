#!/usr/bin/env python3
"""Meta store art in the owner's neon badge style (see docs/ART_STYLE.md).

Inputs : store-art/reference/logo-style-target.png (the badge), store-art/screenshots/*.png (game renders),
         six cube faces in CUBE_DIR (rendered with vr_main --cube, see docs/META-APP.md).
Outputs: store-art/meta/<slot>.* with the exact sizes the Developer Dashboard asks for.
Run from the repo root:  python3 quest/tools/make_store_art_neon.py CUBE_DIR
"""
import os, sys
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

Q = os.path.join(os.path.dirname(__file__), "..")
SA = os.path.join(Q, "store-art")
OUT = os.path.join(SA, "meta")
os.makedirs(OUT, exist_ok=True)
BADGE = Image.open(os.path.join(SA, "reference", "logo-style-target.png")).convert("RGB")
SHOT = Image.open(os.path.join(SA, "screenshots", "01-overview.png")).convert("RGB")
NAVY = (9, 4, 28)


def badge_cutout(size):
    """The badge with a solid disc and a soft neon glow outside it (alpha from brightness), for compositing."""
    b = BADGE.resize((size, size), Image.LANCZOS)
    px = b.load()
    a = Image.new("L", (size, size), 0)
    ap = a.load()
    for y in range(size):
        for x in range(size):
            r, g, bl = px[x, y]
            ap[x, y] = min(255, max(0, int((max(r, g, bl) - 26) * 2.2)))
    disc = Image.new("L", (size, size), 0)
    ImageDraw.Draw(disc).ellipse((size * 0.02, size * 0.02, size * 0.98, size * 0.98), fill=255)
    disc = disc.filter(ImageFilter.GaussianBlur(size * 0.004))
    alpha = ImageChops.lighter(a, disc)
    out = b.convert("RGBA")
    out.putalpha(alpha)
    return out


def backdrop(w, h, focus=(0.5, 0.55), dark=0.42):
    s = max(w / SHOT.width, h / SHOT.height)
    im = SHOT.resize((int(SHOT.width * s) + 1, int(SHOT.height * s) + 1), Image.LANCZOS)
    x = int((im.width - w) * focus[0]); y = int((im.height - h) * focus[1])
    im = im.crop((x, y, x + w, y + h)).filter(ImageFilter.GaussianBlur(max(2, w // 500)))
    im = ImageEnhance.Brightness(im).enhance(dark)
    # navy vignette and a magenta/cyan wash from the sides, like the neon in the room
    v = Image.new("L", (w, h), 0)
    ImageDraw.Draw(v).ellipse((-w * 0.25, -h * 0.35, w * 1.25, h * 1.35), fill=255)
    v = v.filter(ImageFilter.GaussianBlur(min(w, h) * 0.18))
    im = Image.composite(im, Image.new("RGB", (w, h), NAVY), v)
    wash = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(wash)
    d.ellipse((-w * 0.30, h * 0.25, w * 0.25, h * 1.15), fill=(120, 20, 150))
    d.ellipse((w * 0.75, h * 0.25, w * 1.30, h * 1.15), fill=(0, 110, 150))
    wash = wash.filter(ImageFilter.GaussianBlur(min(w, h) * 0.12))
    return ImageChops.screen(im, ImageEnhance.Brightness(wash).enhance(0.55))


def glow_behind(canvas, cx, cy, size):
    g = Image.new("RGB", canvas.size, (0, 0, 0))
    d = ImageDraw.Draw(g)
    r = size * 0.55
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(150, 20, 130))
    r2 = size * 0.46
    d.ellipse((cx - r2, cy - r2, cx + r2, cy + r2), fill=(20, 140, 190))
    g = g.filter(ImageFilter.GaussianBlur(size * 0.10))
    return ImageChops.screen(canvas, ImageEnhance.Brightness(g).enhance(0.55))


def cover(w, h, badge_size, cy=0.5, focus=(0.5, 0.55)):
    c = backdrop(w, h, focus)
    cx, cyp = w // 2, int(h * cy)
    c = glow_behind(c, cx, cyp, badge_size)
    bc = badge_cutout(badge_size)
    c = c.convert("RGBA")
    c.alpha_composite(bc, (cx - badge_size // 2, cyp - badge_size // 2))
    return c.convert("RGB")


def save(im, name):
    p = os.path.join(OUT, name)
    im.save(p, optimize=True)
    print(name, im.size, im.mode, round(os.path.getsize(p) / 1e6, 2), "MB")


save(cover(2560, 1440, 1240), "cover-landscape-2560x1440.png")
save(cover(1440, 1440, 1180), "cover-square-1440x1440.png", ) if False else None
save(cover(1440, 1440, 1180, focus=(0.5, 0.55)), "cover-square-1440x1440.png")
save(cover(1008, 1344, 980, cy=0.5, focus=(0.5, 0.55)), "cover-portrait-1008x1344.png")
save(cover(3000, 900, 860, focus=(0.5, 0.5)), "hero-3000x900.png")
save(BADGE.resize((512, 512), Image.LANCZOS), "icon-512x512.png")

# spatialised tile: solid background, transparent foreground with the badge inside the 392 px safe area
bgt = backdrop(512, 512, (0.5, 0.55), dark=0.5)
bgt = glow_behind(bgt, 256, 256, 400)
save(bgt, "tile-background-512x512.png")
fg = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
fg.alpha_composite(badge_cutout(392), (60, 60))
save(fg, "tile-foreground-512x512.png")

# screenshots: five real scenes, 2560x1440, 24-bit
for i, n in enumerate(["01-overview", "02-backwall", "04-hall_lanes", "05-hall_axes", "06-pinball"], 1):
    im = Image.open(os.path.join(SA, "screenshots", n + ".png")).convert("RGB")
    assert im.size == (2560, 1440), im.size
    save(im, "screenshot-%d-%s.png" % (i, n.split("-", 1)[1]))

# 360 preview: six faces and one cube strip
if len(sys.argv) > 1:
    cd = sys.argv[1]
    order = ["right", "left", "up", "down", "front", "back"]
    faces = {k: Image.open(os.path.join(cd, "cube_%s.png" % k)).convert("RGB") for k in order}
    for k, f in faces.items():
        f.save(os.path.join(OUT, "preview360-%s-1024.jpg" % k), quality=90, optimize=True)
    strip = Image.new("RGB", (1024 * 6, 1024))
    for i, k in enumerate(order):
        strip.paste(faces[k], (i * 1024, 0))
    for q in (90, 86, 82):
        p = os.path.join(OUT, "preview360-cubestrip-6144x1024.jpg")
        strip.save(p, quality=q, optimize=True, subsampling=0 if q > 85 else 2)
        mb = os.path.getsize(p) / 1e6
        print("cubestrip q", q, round(mb, 2), "MB")
        if mb <= 2.3:
            break
