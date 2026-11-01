#!/usr/bin/env python3
"""Paints the signage: the Zombie Smash banner over the door, the Fatty's Game Shack logo (and its frosted door decal) and the EXIT sign."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "vr-art")
BARLOW = os.path.join(HERE, "..", "..", "font-barlow-condensed-900.woff2")
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


def extruded(canvas, xy, txt, f, face_top, face_bot, side, outline, depth=14, stroke=8, anchor="mm"):
    """3D-looking chunky lettering: a stack of offset copies for the extrusion, then a gradient face with an outline."""
    w, h = canvas.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(depth, 0, -1):
        d.text((xy[0] + i * 0.7, xy[1] + i), txt, font=f, fill=side, anchor=anchor, stroke_width=stroke, stroke_fill=outline)
    canvas.alpha_composite(layer)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text(xy, txt, font=f, fill=255, anchor=anchor)
    bb = mask.getbbox()
    face = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(face)
    for y in range(bb[1], bb[3]):
        t = (y - bb[1]) / max(1, bb[3] - bb[1])
        c = tuple(int(face_top[j] + (face_bot[j] - face_top[j]) * t) for j in range(3)) + (255,)
        gd.line((0, y, w, y), fill=c)
    top = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    top.paste(face, (0, 0), mask)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(out).text(xy, txt, font=f, fill=(0, 0, 0, 0), anchor=anchor, stroke_width=stroke, stroke_fill=outline)
    canvas.alpha_composite(out)
    canvas.alpha_composite(top)
    # a glint along the top of each letter
    hi = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(hi).text((xy[0], xy[1] - 4), txt, font=f, fill=(255, 255, 255, 90), anchor=anchor)
    hi = ImageChops.multiply(hi, Image.merge("RGBA", (mask, mask, mask, mask.point(lambda v: 255 if v else 0))).filter(ImageFilter.MinFilter(3)))
    canvas.alpha_composite(hi)


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
    extruded(img, (400, 265), "ZOMBIE", f, (120, 255, 70), (15, 150, 30), (10, 70, 20, 255), (5, 25, 8, 255), 16, 10)
    extruded(img, (1115, 265), "SMASH", f, (255, 80, 55), (165, 10, 15), (90, 5, 10, 255), (30, 2, 4, 255), 16, 10)
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
    extruded(img, (N // 2, 400), "FATTY'S", f, (255, 245, 150), (255, 170, 20), (150, 20, 90, 255), (40, 4, 30, 255), 14, 9)
    # ribbon with GAME SHACK
    d = ImageDraw.Draw(img)
    d.polygon([(110, 610), (914, 610), (880, 700), (914, 790), (110, 790), (144, 700)], fill=(255, 60, 150, 255), outline=(40, 4, 30, 255))
    d.line([(110, 610), (914, 610), (880, 700), (914, 790), (110, 790), (144, 700), (110, 610)], fill=(40, 4, 30, 255), width=8)
    d.text((N // 2, 702), "GAME SHACK", font=font(BARLOW, 150), fill=(255, 255, 255, 255), anchor="mm", stroke_width=6, stroke_fill=(40, 4, 30, 255))
    # a little joystick and two buttons under the ribbon
    d.rectangle((492, 820, 532, 900), fill=(220, 220, 230, 255), outline=(30, 30, 40, 255), width=4)
    d.ellipse((470, 790, 554, 874), fill=(255, 220, 30, 255), outline=(30, 30, 40, 255), width=5)
    d.rounded_rectangle((420, 890, 604, 930), 14, fill=(40, 40, 60, 255), outline=(255, 255, 255, 255), width=3)
    for bx, col in [(380, (230, 40, 50, 255)), (644, (40, 150, 250, 255))]:
        d.ellipse((bx - 30, 860, bx + 30, 920), fill=col, outline=(30, 30, 40, 255), width=5)
    d.text((N // 2, 960), "EST. 1985  -  ZOMBIES WELCOME", font=font(BARLOW, 50), fill=(255, 226, 150, 255), anchor="mm")
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
    extruded(img, (250, 165), "EXIT", f, (220, 255, 220), (70, 255, 120), (10, 100, 40, 255), (2, 30, 10, 255), 8, 6)
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
    d.text((W // 2, 340), "TO ZOMBIELAND", font=font(BARLOW, 100), fill=(255, 245, 160, 255), anchor="mm", stroke_width=5, stroke_fill=(0, 20, 5, 255))
    d.text((W // 2, 435), "THEY ARE FRIENDLY.  MOSTLY.  NO REFUNDS ON BRAINS.", font=font(BARLOW, 36), fill=(180, 255, 200, 255), anchor="mm")
    img.save(os.path.join(OUT, "exit-sign.png"))


banner()
fatty()
exit_sign()
