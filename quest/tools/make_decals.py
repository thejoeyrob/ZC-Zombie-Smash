#!/usr/bin/env python3
"""Bold retro sticker decals for the arcade control decks (turtles-card / POG style): die-cut white border, thick black outline, halftone dots."""
import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

OUT = os.path.join(os.path.dirname(__file__), "..", "vr-art")
FONT = "/usr/share/fonts/truetype/freefont/FreeSansBoldOblique.ttf"
S = 1024
random.seed(7)


def font(sz):
    return ImageFont.truetype(FONT, sz)


def burst(cx, cy, r1, r2, n, rot=0.0, jitter=0.0):
    pts = []
    for i in range(n * 2):
        a = rot + math.pi * i / n
        r = (r1 if i % 2 == 0 else r2) * (1 + random.uniform(-jitter, jitter))
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def halftone(img, mask, col, step=26, rmax=9):
    d = ImageDraw.Draw(img)
    for y in range(0, S, step):
        for x in range(0, S, step):
            xx = x + (step // 2 if (y // step) % 2 else 0)
            k = 1.0 - xx / S
            r = rmax * k * 0.9
            if r > 1.5 and xx < S and mask.getpixel((xx, y)) > 200:
                d.ellipse((xx - r, y - r, xx + r, y + r), fill=col)


def finish(body, name):
    """body: RGBA with the artwork (black outline included). Adds the white die-cut border and saves."""
    a = body.split()[3]
    border = a.filter(ImageFilter.MaxFilter(31))
    border = border.filter(ImageFilter.GaussianBlur(2)).point(lambda v: 255 if v > 100 else 0)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    white = Image.new("RGBA", (S, S), (255, 255, 255, 255))
    out.paste(white, (0, 0), border)
    out.alpha_composite(body)
    bbox = out.getbbox()
    out = out.crop(bbox)
    sq = max(out.size)
    canvas = Image.new("RGBA", (sq, sq), (0, 0, 0, 0))
    canvas.paste(out, ((sq - out.width) // 2, (sq - out.height) // 2))
    canvas = canvas.resize((512, 512), Image.LANCZOS)
    canvas.save(os.path.join(OUT, name))


def text_centered(d, txt, cy, sz, fill, stroke=14, cx=S // 2, skew=0):
    f = font(sz)
    w = d.textlength(txt, font=f)
    d.text((cx - w / 2, cy - sz * 0.55), txt, font=f, fill=fill, stroke_width=stroke, stroke_fill=(10, 10, 14, 255))


def layered(fill, accent, shape_pts, txt, tsz, tcol, name, sub=None, rot_text=0, extra=None):
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.polygon(shape_pts, fill=(10, 10, 14, 255))
    inner = Image.new("L", (S, S), 0)
    ImageDraw.Draw(inner).polygon(shape_pts, fill=255)
    inner = inner.filter(ImageFilter.MinFilter(41))
    d.bitmap((0, 0), inner, fill=fill)
    halftone(body, inner, accent)
    if extra:
        extra(d, inner)
    d = ImageDraw.Draw(body)
    t = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    td = ImageDraw.Draw(t)
    text_centered(td, txt, S // 2 - (40 if sub else 0), tsz, tcol)
    if sub:
        text_centered(td, sub, S // 2 + 170, int(tsz * 0.42), (255, 255, 255, 255), 10)
    if rot_text:
        t = t.rotate(rot_text, resample=Image.BICUBIC, center=(S // 2, S // 2))
    body.alpha_composite(t)
    finish(body, name)


def bolt(cx, cy, s):
    p = [(0, -1.0), (-0.45, 0.05), (-0.08, 0.05), (-0.3, 1.0), (0.5, -0.15), (0.12, -0.15), (0.35, -1.0)]
    return [(cx + x * s, cy + y * s) for x, y in p]


def main():
    spikes = lambda n, r1, r2, rot=0.0, j=0.0: burst(S // 2, S // 2, r1, r2, n, rot, j)
    layered((255, 214, 0, 255), (255, 120, 0, 255), spikes(14, 480, 350, 0.1, 0.03), "MOVE", 270, (255, 255, 255, 255), "decal-move.png", sub="◀  STICK  ▶", rot_text=-6)
    layered((255, 40, 60, 255), (255, 200, 0, 255), spikes(11, 490, 330, 0.0, 0.08), "FIRE!", 360, (255, 244, 90, 255), "decal-fire.png", rot_text=-8)
    layered((20, 160, 255, 255), (0, 240, 255, 255), spikes(18, 480, 390, 0.0, 0.0), "BOMB", 270, (255, 255, 255, 255), "decal-grenade.png", sub="GRENADE", rot_text=5)
    layered((120, 255, 20, 255), (0, 170, 80, 255), spikes(10, 480, 380, 0.3, 0.0), "LOCK", 280, (20, 20, 30, 255), "decal-lock.png", sub="ON / OFF", rot_text=-4)
    layered((255, 46, 147, 255), (160, 0, 255, 255), spikes(16, 470, 370, 0.05, 0.0), "MENU", 270, (255, 255, 255, 255), "decal-menu.png", rot_text=4)

    def skull(d, inner):
        d.ellipse((330, 250, 700, 600), fill=(250, 250, 240, 255), outline=(10, 10, 14, 255), width=14)
        d.rectangle((420, 560, 610, 700), fill=(250, 250, 240, 255), outline=(10, 10, 14, 255), width=14)
        for x in (460, 515, 570):
            d.line((x, 600, x, 695), fill=(10, 10, 14, 255), width=10)
        for x in (440, 590):
            d.ellipse((x - 55, 380, x + 55, 500), fill=(10, 10, 14, 255))
            d.ellipse((x - 18, 425, x + 18, 465), fill=(120, 255, 20, 255))
        d.polygon([(515, 505), (490, 565), (540, 565)], fill=(10, 10, 14, 255))
    layered((160, 40, 255, 255), (255, 46, 147, 255), spikes(13, 490, 400, 0.0, 0.05), "", 10, (255, 255, 255, 255), "decal-skull.png", extra=skull)

    def boltx(d, inner):
        d.polygon(bolt(S // 2, S // 2, 330), fill=(255, 240, 40, 255), outline=(10, 10, 14, 255))
        d.line(bolt(S // 2, S // 2, 330) + [bolt(S // 2, S // 2, 330)[0]], fill=(10, 10, 14, 255), width=16)
    layered((0, 220, 255, 255), (255, 46, 147, 255), spikes(9, 495, 330, 0.0, 0.1), "", 10, (255, 255, 255, 255), "decal-bolt.png", extra=boltx)
    layered((255, 120, 0, 255), (255, 230, 0, 255), spikes(12, 490, 360, 0.2, 0.0), "1UP", 360, (255, 255, 255, 255), "decal-1up.png", rot_text=-10)
    layered((255, 46, 147, 255), (255, 214, 0, 255), spikes(15, 490, 370, 0.0, 0.0), "SMASH", 240, (255, 255, 255, 255), "decal-smash.png", sub="ZOMBIES!", rot_text=7)
    # POG discs: a round milk-cap with concentric rings and a bold face
    for i, (c1, c2, face) in enumerate([((255, 214, 0), (255, 46, 147), "Z"), ((0, 220, 255), (160, 40, 255), "★"), ((120, 255, 20), (255, 90, 0), "!"), ((255, 40, 60), (255, 240, 120), "☠")]):
        body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(body)
        d.ellipse((60, 60, S - 60, S - 60), fill=(10, 10, 14, 255))
        r = 440
        for k in range(8):
            col = c1 if k % 2 == 0 else c2
            rr = r - k * 52
            d.ellipse((S // 2 - rr, S // 2 - rr, S // 2 + rr, S // 2 + rr), fill=col + (255,))
        d.ellipse((S // 2 - 130, S // 2 - 130, S // 2 + 130, S // 2 + 130), fill=(10, 10, 14, 255))
        f = font(240)
        w = d.textlength(face, font=f)
        try:
            d.text((S // 2 - w / 2, S // 2 - 150), face, font=f, fill=(255, 255, 255, 255))
        except Exception:
            pass
        finish(body, "decal-pog-%d.png" % (i + 1))


if __name__ == "__main__":
    main()
