#!/usr/bin/env python3
"""Joey Rob's own arcade machine: side art cut to the cabinet outline and a header, built from the player artwork."""
import json, math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import make_signs as ms

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "vr-art")
ROOT = os.path.join(HERE, "..", "..")
random.seed(21)
hero = Image.open(os.path.join(ROOT, "player-victory.webp")).convert("RGBA")


def backdrop(w, h):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        d.line((0, y, w, y), fill=(int(20 + 40 * (1 - t)), int(40 + 70 * (1 - t)), int(26 + 30 * (1 - t))))
    cam = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cam)
    for _ in range(60):
        x, y = random.randint(-50, w), random.randint(-50, h)
        r = random.randint(40, 120)
        col = random.choice([(34, 60, 30), (58, 78, 40), (20, 34, 20), (80, 96, 50)])
        cd.ellipse((x - r, y - r * 0.6, x + r, y + r * 0.6), fill=col + (140,))
    img = img.convert("RGBA")
    img.alpha_composite(cam.filter(ImageFilter.GaussianBlur(4)))
    return img


def side():
    W, H = 512, 1024
    prof = json.load(open(os.path.join(HERE, "..", "data", "cab_profiles.json")))["fatamy"]["poly"]
    mask = Image.new("L", (W * 2, H * 2), 0)
    ImageDraw.Draw(mask).polygon([(p[0] * W * 2, p[1] * H * 2) for p in prof], fill=255)
    mask = mask.resize((W, H), Image.LANCZOS)
    img = backdrop(W, H)
    # searchlight cone and the hero
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.polygon([(W * 0.5, 40), (W * 0.1, H), (W * 0.9, H)], fill=(255, 245, 190, 60))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(18)))
    hh = int(H * 0.58)
    h2 = hero.resize((hh, hh), Image.LANCZOS)
    img.alpha_composite(h2, ((W - hh) // 2 + 10, int(H * 0.40)))
    d = ImageDraw.Draw(img)
    f = ms.font(ms.BARLOW, 150)
    ms.extruded(img, (W // 2 + 30, 170), "JOEY", f, (255, 240, 130), (255, 150, 20), (110, 50, 5, 255), (30, 12, 2, 255), 10, 7)
    ms.extruded(img, (W // 2 + 30, 300), "ROB", f, (255, 240, 130), (255, 150, 20), (110, 50, 5, 255), (30, 12, 2, 255), 10, 7)
    d = ImageDraw.Draw(img)
    d.text((W // 2 + 30, 385), "HOLD THE LINE", font=ms.font(ms.BARLOW, 44), fill=(255, 255, 255, 235), anchor="mm", stroke_width=3, stroke_fill=(0, 0, 0, 255))
    edge = mask.filter(ImageFilter.MinFilter(9))
    rim = ImageChops.subtract(mask, edge)
    img.paste(Image.new("RGBA", (W, H), (255, 190, 60, 255)), (0, 0), rim)
    img.putalpha(mask)
    img.save(os.path.join(OUT, "side-joeyrob.png"))


def marquee():
    W, H = 1024, 341
    img = backdrop(W, H)
    d = ImageDraw.Draw(img)
    for i in range(0, W, 64):
        d.line((i, 0, i - 120, H), fill=(255, 255, 255, 18), width=14)
    h2 = hero.resize((330, 330), Image.LANCZOS)
    img.alpha_composite(h2, (30, 6))
    img.alpha_composite(h2.transpose(Image.FLIP_LEFT_RIGHT), (W - 360, 6))
    f = ms.font(ms.BARLOW, 210)
    ms.extruded(img, (W // 2, 150), "JOEY ROB", f, (255, 240, 130), (255, 150, 20), (110, 50, 5, 255), (30, 12, 2, 255), 12, 8)
    d = ImageDraw.Draw(img)
    d.text((W // 2, 300), "THE LAST LINE OF DEFENCE", font=ms.font(ms.BARLOW, 46), fill=(255, 255, 255, 235), anchor="mm", stroke_width=3, stroke_fill=(0, 0, 0, 255))
    d.rectangle((4, 4, W - 5, H - 5), outline=(255, 190, 60, 255), width=8)
    img.convert("RGB").save(os.path.join(OUT, "marquee-joeyrob.jpg"), quality=92)


side()
marquee()
