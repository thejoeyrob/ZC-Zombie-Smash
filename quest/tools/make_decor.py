#!/usr/bin/env python3
"""Early-90s arcade look: black neon walls, starry ceiling, painted pinball cabinet, the Zombie Smash poster, word stickers, JW logo with its colour squares."""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import make_signs as ms

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "vr-art")
ROOT = os.path.join(HERE, "..", "..")
random.seed(11)
NEON = [(255, 46, 147), (0, 229, 255), (255, 230, 0), (124, 255, 0), (160, 70, 255), (255, 122, 0)]


def wrap_draw(draw_fn, size):
    """Draw with wrap-around so the picture tiles."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    big = Image.new("RGBA", (size * 3, size * 3), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(big), size)
    return big.crop((size, size, size * 2, size * 2))


def wall():
    N = 1024
    base = Image.new("RGB", (N, N), (7, 5, 20))
    px = base.load()
    for y in range(N):
        for x in range(0, N, 1):
            pass
    shapes = []
    for i in range(26):
        shapes.append((random.randint(0, N), random.randint(0, N), random.choice(["tri", "ring", "zig", "squig", "plus", "dots"]), random.choice(NEON), random.randint(50, 120), random.uniform(0, 6.28)))

    def draw(d, n):
        for ox in range(3):
            for oy in range(3):
                for x, y, kind, col, sz, rot in shapes:
                    cx, cy = x + ox * n, y + oy * n
                    c = col + (255,)
                    w = 12
                    if kind == "tri":
                        pts = [(cx + math.cos(rot + k * 2.094) * sz, cy + math.sin(rot + k * 2.094) * sz) for k in range(3)]
                        d.line(pts + [pts[0]], fill=c, width=w, joint="curve")
                    elif kind == "ring":
                        d.ellipse((cx - sz * 0.6, cy - sz * 0.6, cx + sz * 0.6, cy + sz * 0.6), outline=c, width=w)
                    elif kind == "zig":
                        pts = [(cx - sz + k * sz / 2.0, cy + (sz / 3.0 if k % 2 else -sz / 3.0)) for k in range(5)]
                        d.line(pts, fill=c, width=w, joint="curve")
                    elif kind == "squig":
                        pts = [(cx - sz + k * 8, cy + math.sin(k * 0.6 + rot) * sz * 0.3) for k in range(int(sz * 2 / 8))]
                        d.line(pts, fill=c, width=w, joint="curve")
                    elif kind == "plus":
                        d.line((cx - sz * 0.5, cy, cx + sz * 0.5, cy), fill=c, width=w)
                        d.line((cx, cy - sz * 0.5, cx, cy + sz * 0.5), fill=c, width=w)
                    else:
                        for k in range(5):
                            for m in range(3):
                                d.ellipse((cx + k * 26, cy + m * 26, cx + k * 26 + 10, cy + m * 26 + 10), fill=c)
    neon = wrap_draw(draw, N)
    core = neon.copy()
    glow = neon.filter(ImageFilter.GaussianBlur(14))
    glow.putalpha(glow.split()[3].point(lambda v: min(255, int(v * 1.5))))
    img = base.convert("RGBA")
    # faint grid, like the floor-to-ceiling grid of a laser tag arena
    gd = ImageDraw.Draw(img)
    for i in range(0, N, 128):
        gd.line((i, 0, i, N), fill=(30, 24, 70, 255), width=2)
        gd.line((0, i, N, i), fill=(30, 24, 70, 255), width=2)
    img.alpha_composite(glow)
    # dim the core slightly so it reads as painted glow-in-the-dark neon
    core.putalpha(core.split()[3].point(lambda v: int(v * 0.95)))
    img.alpha_composite(core)
    img.convert("RGB").save(os.path.join(OUT, "wall90.jpg"), quality=90)


def ceiling():
    N = 1024
    img = Image.new("RGB", (N, N), (3, 3, 10))
    d = ImageDraw.Draw(img)
    for i in range(0, N, 256):
        d.line((i, 0, i, N), fill=(14, 12, 30), width=6)
        d.line((0, i, N, i), fill=(14, 12, 30), width=6)
    lights = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lights)
    for _ in range(160):
        x, y = random.randint(0, N), random.randint(0, N)
        c = random.choice(NEON + [(255, 255, 255)])
        r = random.choice([2, 2, 3, 4])
        ld.ellipse((x - r, y - r, x + r, y + r), fill=c + (255,))
    g = lights.filter(ImageFilter.GaussianBlur(6))
    img = img.convert("RGBA")
    img.alpha_composite(g)
    img.alpha_composite(lights)
    img.convert("RGB").save(os.path.join(OUT, "ceiling90.jpg"), quality=90)


def pin_cab():
    N = 1024
    img = Image.new("RGB", (N, N), (12, 8, 38))
    px = img.load()
    for y in range(N):
        t = y / N
        c = (int(18 + 40 * (1 - t)), int(8 + 6 * t), int(52 + 60 * (1 - t)))
        d = ImageDraw.Draw(img)
        d.line((0, y, N, y), fill=c)
    fl = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fl)
    for i in range(14):
        x = i * N / 14 + random.randint(-20, 20)
        h = random.randint(260, 520)
        col = random.choice([(255, 60, 120), (255, 150, 30), (255, 230, 60)])
        pts = [(x - 50, N), (x - 30, N - h * 0.5), (x, N - h), (x + 25, N - h * 0.55), (x + 55, N)]
        fd.polygon(pts, fill=col + (230,))
    fl = fl.filter(ImageFilter.GaussianBlur(3))
    img = img.convert("RGBA")
    img.alpha_composite(fl)
    # stars and a pinstripe
    d = ImageDraw.Draw(img)
    for _ in range(90):
        x, y = random.randint(0, N), random.randint(0, int(N * 0.7))
        r = random.choice([2, 3, 5])
        d.polygon([(x, y - r * 2), (x + r * 0.6, y - r * 0.6), (x + r * 2, y), (x + r * 0.6, y + r * 0.6), (x, y + r * 2), (x - r * 0.6, y + r * 0.6), (x - r * 2, y), (x - r * 0.6, y - r * 0.6)], fill=(255, 255, 255, 220))
    d.rectangle((0, 40, N, 56), fill=(0, 229, 255, 255))
    d.rectangle((0, 70, N, 78), fill=(255, 46, 147, 255))
    sheen = Image.new("L", (N, N), 0)
    sd = ImageDraw.Draw(sheen)
    sd.polygon([(0, 0), (N * 0.45, 0), (N * 0.1, N), (0, N)], fill=34)
    img.paste(Image.new("RGBA", (N, N), (255, 255, 255, 255)), (0, 0), sheen.filter(ImageFilter.GaussianBlur(30)))
    img.convert("RGB").save(os.path.join(OUT, "pin-cab.jpg"), quality=90)


def pin_front():
    W, H = 640, 320
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, W, H), 24, fill=(20, 14, 52, 255))
    for i in range(H):
        t = i / H
        d.line((30, i, W - 30, i), fill=(int(40 + 30 * t), int(30 + 20 * t), int(90 + 40 * t), 255)) if 10 < i < H - 10 else None
    # steel coin door
    d.rounded_rectangle((200, 60, 440, 260), 18, fill=(190, 194, 206, 255), outline=(40, 40, 60, 255), width=4)
    for y in range(64, 256, 3):
        v = int(150 + 80 * math.sin((y - 64) / 192 * math.pi * 3))
        d.line((204, y, 436, y), fill=(v, v, min(255, v + 10), 255))
    for cx in (270, 370):
        d.rounded_rectangle((cx - 30, 80, cx + 30, 160), 8, fill=(18, 18, 24, 255), outline=(255, 160, 40, 255), width=4)
        d.rectangle((cx - 4, 94, cx + 4, 146), fill=(255, 150, 20, 255))
        d.ellipse((cx - 24, 176, cx + 24, 224), fill=(220, 40, 50, 255), outline=(255, 220, 160, 255), width=4)
    f = ImageFont.truetype(os.path.join(ROOT, "font-barlow-condensed-900.woff2"), 54)
    d.text((W // 2, 30), "ZOMBIE PINBALL", font=f, fill=(255, 226, 120, 255), anchor="mm", stroke_width=3, stroke_fill=(60, 8, 24, 255))
    d.text((W // 2, 292), "INSERT COIN", font=ImageFont.truetype(os.path.join(ROOT, "font-barlow-condensed-900.woff2"), 38), fill=(0, 229, 255, 255), anchor="mm")
    img.save(os.path.join(OUT, "pin-front.png"))


def poster():
    W, H = 1500, 740
    bg = Image.open(os.path.join(ROOT, "title-bg.webp")).convert("RGB")
    k = max(W / bg.width, H / bg.height)
    bg = bg.resize((int(bg.width * k), int(bg.height * k)), Image.LANCZOS)
    bg = bg.crop(((bg.width - W) // 2, (bg.height - H) // 2, (bg.width - W) // 2 + W, (bg.height - H) // 2 + H))
    img = Image.eval(bg, lambda v: int(v * 0.62)).convert("RGBA")
    d = ImageDraw.Draw(img)
    vig = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vig).rectangle((0, 0, W, H), fill=140)
    ImageDraw.Draw(vig).rectangle((90, 70, W - 90, H - 70), fill=0)
    img.paste(Image.new("RGBA", (W, H), (0, 0, 0, 255)), (0, 0), vig.filter(ImageFilter.GaussianBlur(70)))
    f = ms.font(ms.BARLOW, 235)
    ms.extruded(img, (410, 270), "ZOMBIE", f, (120, 255, 70), (15, 150, 30), (10, 70, 20, 255), (5, 25, 8, 255), 18, 10)
    ms.extruded(img, (1110, 270), "SMASH", f, (255, 80, 55), (165, 10, 15), (90, 5, 10, 255), (30, 2, 4, 255), 18, 10)
    d = ImageDraw.Draw(img)
    d.text((W // 2, 560), "HOLD THE LINE", font=ms.font(ms.BARLOW, 120), fill=(255, 226, 150, 255), anchor="mm", stroke_width=6, stroke_fill=(0, 0, 0, 255))
    d.text((W // 2, 665), "THE ARCADE GAME  -  ONLY AT FATTY'S GAME SHACK", font=ms.font(ms.BARLOW, 54), fill=(255, 255, 255, 230), anchor="mm")
    d.rectangle((14, 14, W - 14, H - 14), outline=(255, 226, 150, 255), width=8)
    img.convert("RGB").save(os.path.join(OUT, "zs-poster.png"))


def words():
    f = ms.font(ms.BARLOW, 300)
    specs = [("MOVE", (255, 240, 60), (255, 130, 0), "move"), ("FIRE", (255, 120, 90), (220, 20, 40), "fire"), ("GRENADE", (110, 230, 255), (30, 110, 255), "grenade"),
             ("LOCK", (170, 255, 90), (20, 190, 80), "lock"), ("MENU", (255, 120, 210), (150, 60, 255), "menu")]
    for txt, top, bot, name in specs:
        W, H = 1100, 420
        body = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).text((W // 2, H // 2), txt, font=f, fill=255, anchor="mm")
        face = Image.new("RGBA", (W, H))
        fd = ImageDraw.Draw(face)
        bb = mask.getbbox()
        for y in range(bb[1], bb[3]):
            t = (y - bb[1]) / max(1, bb[3] - bb[1])
            fd.line((0, y, W, y), fill=tuple(int(top[j] + (bot[j] - top[j]) * t) for j in range(3)) + (255,))
        # dark outline, then the white die-cut sticker border round everything
        outline = mask.filter(ImageFilter.MaxFilter(15))
        body.paste(Image.new("RGBA", (W, H), (12, 8, 24, 255)), (0, 0), outline)
        body.paste(face, (0, 0), mask)
        border = body.split()[3].filter(ImageFilter.MaxFilter(25)).filter(ImageFilter.GaussianBlur(2)).point(lambda v: 255 if v > 90 else 0)
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        out.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0), border)
        out.alpha_composite(body)
        bbx = out.getbbox()
        out = out.crop(bbx)
        out.thumbnail((512, 512), Image.LANCZOS)
        out.save(os.path.join(OUT, "word-%s.png" % name))


def jw():
    src = os.path.join(ROOT, "intro-jw.png")
    im = Image.open(src).convert("RGBA")
    W, H = im.size
    d = ImageDraw.Draw(im)
    for l, t, w, h, col in [(50, 53.8, 9.71, 13.7, (203, 20, 18)), (61.5, 53.8, 9.71, 13.7, (14, 92, 247)), (72.7, 53.0, 9.35, 14.5, (235, 206, 33)), (83.8, 53.8, 9.71, 13.7, (16, 187, 61))]:
        x0, y0 = W * l / 100, H * t / 100
        d.rectangle((x0, y0, x0 + W * w / 100, y0 + H * h / 100), fill=col + (255,))
    im.save(os.path.join(OUT, "jw-logo.png"))


wall()
ceiling()
pin_cab()
pin_front()
poster()
words()
jw()
