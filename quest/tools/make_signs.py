#!/usr/bin/env python3
"""Paints the signage: the Zombie Smash banner over the door, the Fatty's Game Shack logo (and its frosted door decal) and the EXIT sign."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "vr-art")
OBL = "/usr/share/fonts/truetype/freefont/FreeSansBoldOblique.ttf"
random.seed(5)


def font(path, sz):
    try:
        return ImageFont.truetype(path, sz)
    except Exception:
        return ImageFont.truetype(OBL, sz)


def glow(img, radius, k=1.0):
    b = img.filter(ImageFilter.GaussianBlur(radius))
    if k != 1.0:
        b.putalpha(b.split()[3].point(lambda v: min(255, int(v * k))))
    return b


FONTS = os.path.join(HERE, "..", "fonts-src")
ANTON = os.path.join(FONTS, "Anton-Regular.ttf")
BARLOW = ANTON            # the display face for everything in the arcade: tall, bold, poster-like


def fnt(name, sz):
    return ImageFont.truetype(os.path.join(FONTS, name), sz)


def extruded(canvas, xy, txt, f, face_top, face_bot, side, outline, depth=14, stroke=8, anchor="mm", glow_col=None):
    """Poster-quality lettering: soft drop shadow, a stepped extrusion with edge light, a coloured outline,
    a metallic face with a bright band and a dark lower band, a bevel highlight along the top and left, and an optional glow."""
    w, h = canvas.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text(xy, txt, font=f, fill=255, anchor=anchor)
    bb = mask.getbbox()
    if bb is None:
        return
    # glow
    if glow_col is not None:
        g = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        g.paste(Image.new("RGBA", (w, h), glow_col + (255,)), (0, 0), mask.filter(ImageFilter.MaxFilter(9)))
        g = g.filter(ImageFilter.GaussianBlur(max(6, depth)))
        canvas.alpha_composite(g)
    # drop shadow
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sm = ImageChops.offset(mask.filter(ImageFilter.MaxFilter(stroke * 2 + 1)), int(depth * 0.9), int(depth * 1.3))
    sh.paste(Image.new("RGBA", (w, h), (0, 0, 0, 170)), (0, 0), sm.filter(ImageFilter.GaussianBlur(depth * 0.6)))
    canvas.alpha_composite(sh)
    # stepped extrusion
    ext = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    big = mask.filter(ImageFilter.MaxFilter(stroke * 2 + 1)) if stroke > 0 else mask
    for i in range(depth, 0, -1):
        shade = tuple(int(side[j] * (0.55 + 0.45 * (1 - i / depth))) for j in range(3)) + (255,)
        ext.paste(Image.new("RGBA", (w, h), shade), (0, 0), ImageChops.offset(big, int(i * 0.5), i))
    canvas.alpha_composite(ext)
    # outline: dark outer line, then a thin light line inside it
    outer = mask.filter(ImageFilter.MaxFilter(stroke * 2 + 1))
    inner = mask.filter(ImageFilter.MaxFilter(max(3, stroke) | 1))
    canvas.paste(Image.new("RGBA", (w, h), tuple(outline[:3]) + (255,)), (0, 0), outer)
    light = tuple(min(255, c + 90) for c in face_top)
    canvas.paste(Image.new("RGBA", (w, h), light + (255,)), (0, 0), inner)
    # face: vertical gradient with a bright band near the top and a dark band near the bottom
    face = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(face)
    y0, y1 = bb[1], bb[3]
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        k = t * 1.0
        c = [face_top[j] + (face_bot[j] - face_top[j]) * k for j in range(3)]
        if t < 0.42:
            c = [min(255, v + 55 * (1 - t / 0.42)) for v in c]
        if 0.46 < t < 0.52:
            c = [v * 0.82 for v in c]
        if t > 0.5:
            c = [v * (1.0 - 0.18 * (t - 0.5) * 2) for v in c]
        gd.line((0, y, w, y), fill=tuple(int(max(0, min(255, v))) for v in c) + (255,))
    canvas.paste(face, (0, 0), mask)
    # bevel: light along the top-left edges, shade along the bottom-right
    up = ImageChops.subtract(mask, ImageChops.offset(mask, 0, max(2, stroke // 3)))
    left = ImageChops.subtract(mask, ImageChops.offset(mask, max(2, stroke // 4), 0))
    hl = ImageChops.lighter(up, left)
    canvas.paste(Image.new("RGBA", (w, h), (255, 255, 255, 255)), (0, 0), hl.point(lambda v: int(v * 0.75)))
    dn = ImageChops.subtract(mask, ImageChops.offset(mask, 0, -max(2, stroke // 3)))
    canvas.paste(Image.new("RGBA", (w, h), (0, 0, 0, 255)), (0, 0), dn.point(lambda v: int(v * 0.45)))


def banner():
    W, H = 1536, 512
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # dark sign board with a neon edge
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((8, 8, W - 8, H - 8), 60, fill=(8, 6, 16, 255), outline=(255, 70, 190, 255), width=12)
    d.rounded_rectangle((34, 34, W - 34, H - 34), 44, outline=(60, 240, 255, 255), width=6)
    for _ in range(90):
        x, y = random.randint(60, W - 60), random.randint(60, H - 60)
        r = random.choice([1, 1, 2, 3])
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, random.randint(60, 200)))
    f = font(BARLOW, 245)
    sm = font(BARLOW, 66)
    extruded(img, (455, 270), "ZOMBIE", fnt("RubikWetPaint-Regular.ttf", 128), (150, 255, 90), (20, 150, 40), (15, 80, 25, 255), (8, 30, 10, 255), 14, 9, glow_col=(60, 255, 60))
    extruded(img, (1060, 270), "SMASH", fnt("Chango-Regular.ttf", 128), (255, 120, 90), (180, 10, 20), (100, 5, 10, 255), (30, 2, 4, 255), 14, 9, glow_col=(255, 40, 20))
    d = ImageDraw.Draw(img)
    d.text((W // 2, 450), "HOLD THE LINE", font=sm, fill=(255, 226, 150, 255), anchor="mm", stroke_width=4, stroke_fill=(0, 0, 0, 255))
    # slime drips from the top edge
    for x, hh in [(110, 70), (760, 52), (1480, 66), (60, 40), (1000, 44)]:
        d.rounded_rectangle((x - 16, 20, x + 16, 20 + hh), 16, fill=(110, 255, 60, 255))
        d.ellipse((x - 24, 20 + hh - 14, x + 24, 20 + hh + 34), fill=(110, 255, 60, 255))
    img.save(os.path.join(OUT, "zs-banner.png"))


def fatty():
    N = 1024
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((10, 10, N - 10, N - 10), fill=(20, 8, 40, 255), outline=(255, 70, 190, 255), width=18)
    d.ellipse((50, 50, N - 50, N - 50), outline=(60, 240, 255, 255), width=8)
    # starburst behind the name
    cx, cy = N // 2, 400
    pts = []
    for i in range(40):
        a = math.pi * 2 * i / 40
        r = 400 if i % 2 == 0 else 310
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r * 0.62))
    d.polygon(pts, fill=(255, 190, 30, 255))
    d.polygon([(cx + (x - cx) * 0.9, cy + (y - cy) * 0.9) for x, y in pts], fill=(255, 100, 40, 255))
    f = font(BARLOW, 250)
    extruded(img, (N // 2, 400), "FATTY'S", fnt("Chango-Regular.ttf", 138), (255, 245, 150), (255, 170, 20), (150, 20, 90, 255), (40, 4, 30, 255), 14, 9)
    # ribbon with GAME SHACK
    d = ImageDraw.Draw(img)
    d.polygon([(110, 610), (914, 610), (880, 700), (914, 790), (110, 790), (144, 700)], fill=(255, 60, 150, 255), outline=(40, 4, 30, 255))
    d.line([(110, 610), (914, 610), (880, 700), (914, 790), (110, 790), (144, 700), (110, 610)], fill=(40, 4, 30, 255), width=8)
    d.text((N // 2, 702), "GAME SHACK", font=fnt("Bungee-Regular.ttf", 112), fill=(255, 255, 255, 255), anchor="mm", stroke_width=6, stroke_fill=(40, 4, 30, 255))
    # a little joystick and two buttons under the ribbon
    d.rectangle((492, 820, 532, 900), fill=(220, 220, 230, 255), outline=(30, 30, 40, 255), width=4)
    d.ellipse((470, 790, 554, 874), fill=(255, 220, 30, 255), outline=(30, 30, 40, 255), width=5)
    d.rounded_rectangle((420, 890, 604, 930), 14, fill=(40, 40, 60, 255), outline=(255, 255, 255, 255), width=3)
    for bx, col in [(380, (230, 40, 50, 255)), (644, (40, 150, 250, 255))]:
        d.ellipse((bx - 30, 860, bx + 30, 920), fill=col, outline=(30, 30, 40, 255), width=5)
    d.text((N // 2, 960), "EST. 1985  -  ZOMBIES WELCOME", font=fnt("BebasNeue-Regular.ttf", 56), fill=(255, 226, 150, 255), anchor="mm")
    img.save(os.path.join(OUT, "fatty-logo.png"))
    # frosted-vinyl door decal: the same logo in white, dark areas see-through
    lum = img.convert("L")
    a = img.split()[3]
    dec_a = ImageChops.multiply(a, lum.point(lambda v: max(0, min(255, int((v - 40) * 2.2)))))
    dec = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    dec.putalpha(dec_a.point(lambda v: int(v * 0.92)))
    # solid ring for the edge
    ring = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse((10, 10, N - 10, N - 10), outline=(255, 255, 255, 235), width=20)
    dec.alpha_composite(ring)
    dec.save(os.path.join(OUT, "fatty-decal.png"))


def exit_sign():
    W, H = 1024, 512
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((6, 6, W - 6, H - 6), 40, fill=(6, 40, 14, 255), outline=(190, 200, 200, 255), width=12)
    d.rounded_rectangle((26, 26, W - 26, H - 26), 28, outline=(60, 255, 110, 255), width=5)
    f = font(BARLOW, 215)
    extruded(img, (250, 165), "EXIT", fnt("Bungee-Regular.ttf", 150), (220, 255, 220), (70, 255, 120), (10, 100, 40, 255), (2, 30, 10, 255), 8, 6)
    d = ImageDraw.Draw(img)
    # the running man, and something chasing him
    def runner(ox, oy, s, col, zombie=False):
        d.ellipse((ox - 14 * s, oy - 52 * s, ox + 14 * s, oy - 24 * s), fill=col)
        lw = int(11 * s)
        d.line([(ox, oy - 22 * s), (ox - 4 * s, oy + 14 * s)], fill=col, width=lw)
        arm = [(ox - 3 * s, oy - 16 * s), (ox + (34 if zombie else 28) * s, oy - 18 * s)] if zombie else [(ox - 3 * s, oy - 16 * s), (ox - 34 * s, oy - 4 * s)]
        d.line(arm, fill=col, width=lw)
        d.line([(ox - 3 * s, oy - 16 * s), (ox + 30 * s, oy - 36 * s)] if not zombie else [(ox - 3 * s, oy - 12 * s), (ox + 34 * s, oy - 4 * s)], fill=col, width=lw)
        d.line([(ox - 4 * s, oy + 14 * s), (ox + 28 * s, oy + 30 * s), (ox + 22 * s, oy + 62 * s)], fill=col, width=lw)
        d.line([(ox - 4 * s, oy + 14 * s), (ox - 34 * s, oy + 40 * s), (ox - 56 * s, oy + 36 * s)], fill=col, width=lw)
    runner(690, 160, 2.0, (235, 255, 240, 255))
    runner(870, 160, 1.9, (120, 200, 90, 255), True)
    d.polygon([(430, 125), (490, 125), (490, 95), (555, 160), (490, 225), (490, 195), (430, 195)], fill=(60, 255, 110, 255))
    d.text((W // 2, 340), "TO ZOMBIELAND", font=fnt("Bungee-Regular.ttf", 74), fill=(255, 245, 160, 255), anchor="mm", stroke_width=5, stroke_fill=(0, 20, 5, 255))
    d.text((W // 2, 435), "THEY ARE FRIENDLY.  MOSTLY.  NO REFUNDS ON BRAINS.", font=fnt("BebasNeue-Regular.ttf", 42), fill=(180, 255, 200, 255), anchor="mm")
    img.save(os.path.join(OUT, "exit-sign.png"))


if __name__ == "__main__":
    banner()
    fatty()
    exit_sign()
