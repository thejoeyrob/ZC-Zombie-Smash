#!/usr/bin/env python3
"""Builds the arcade's final artwork from the best pictures we have (quest/art-source): cabinet side art cut to each cabinet outline,
marquees, the framed posters and the wall brick set. Run it, then tools/sync-assets.sh."""
import json, os, glob
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import make_signs as ms

H = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(H, "..", "art-source")
OUT = os.path.join(H, "..", "vr-art")
PROF = json.load(open(os.path.join(H, "..", "data", "cab_profiles.json")))


def cover(im, w, h, fx=0.5, fy=0.5):
    k = max(w / im.width, h / im.height)
    r = im.resize((int(im.width * k) + 1, int(im.height * k) + 1), Image.LANCZOS)
    x = int((r.width - w) * fx)
    y = int((r.height - h) * fy)
    return r.crop((x, y, x + w, y + h))


def mask_for(key, W=1000, H2=2000):
    m = Image.new("L", (W * 2, H2 * 2), 0)
    ImageDraw.Draw(m).polygon([(p[0] * W * 2, p[1] * H2 * 2) for p in PROF[key]["poly"]], fill=255)
    return m.resize((W, H2), Image.LANCZOS)


def side(key, art, title=None, tpos=(430, 560), tsize=118):
    W, H2 = 1000, 2000
    img = cover(art.convert("RGB"), W, H2, 0.5, 0.4).convert("RGBA")
    if title:
        shade = Image.new("RGBA", (W, H2), (0, 0, 0, 0))
        ImageDraw.Draw(shade).rectangle((0, int(H2 * 0.18), W, int(H2 * 0.40)), fill=(0, 0, 0, 90))
        img.alpha_composite(shade.filter(ImageFilter.GaussianBlur(40)))
        f = ms.font(ms.BARLOW, tsize)
        lines = title.split("\n")
        for i, t in enumerate(lines):
            ms.extruded(img, (tpos[0], tpos[1] + i * int(tsize * 1.05)), t, f, (255, 245, 170), (255, 170, 30), (110, 45, 5, 255), (25, 10, 2, 255), 10, 7)
    m = mask_for(key)
    edge = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(9)))
    img.paste(Image.new("RGBA", (W, H2), (255, 200, 80, 255)), (0, 0), edge)
    img.putalpha(m)
    return img


def marquee(art, title, fy=0.3, size=330, fx=0.5):
    """Character on the left, name on the right: the picture is never covered by the lettering."""
    W, H2 = 3072, 1023
    art = art.convert("RGB")
    base = cover(art, W, H2, 0.5, fy).filter(ImageFilter.GaussianBlur(14))
    base = Image.eval(base, lambda v: int(v * 0.45)).convert("RGBA")
    sharp = cover(art, 1100, H2 - 30, fx, fy).convert("RGBA")
    fade = Image.new("L", sharp.size, 255)
    fd = ImageDraw.Draw(fade)
    for x in range(sharp.width - 240, sharp.width):
        fd.line((x, 0, x, sharp.height), fill=int(255 * (sharp.width - x) / 240))
    sharp.putalpha(fade)
    base.alpha_composite(sharp, (20, 15))
    base.alpha_composite(sharp.transpose(Image.FLIP_LEFT_RIGHT), (W - 1120, 15)) if False else None
    ms.extruded(base, (1100 + (W - 1100) // 2, H2 // 2), title, ms.font(ms.BARLOW, size), (255, 245, 170), (255, 160, 20), (110, 45, 5, 255), (25, 10, 2, 255), 18, 12)
    d = ImageDraw.Draw(base)
    d.rectangle((6, 6, W - 7, H2 - 7), outline=(255, 190, 70, 255), width=14)
    return base.convert("RGB")


def poster_frame(art, name):
    im = cover(art.convert("RGB"), 1024, 1536, 0.5, 0.3)
    im.save(os.path.join(OUT, name), quality=92)


def run():
    P = lambda n: Image.open(os.path.join(SRC, n))
    debo = P("debo-side-chatgpt.png")
    # side art: the new Debo painting, three posters cut to the outline, and the three strongest ChatGPT machines
    side("debo", debo).save(os.path.join(OUT, "side-debo.png"))
    side("jordan", P("poster-2.png")).save(os.path.join(OUT, "side-jordan.png"))
    side("glowinghumanity", P("poster-5.png")).save(os.path.join(OUT, "side-glowinghumanity.png"))
    side("caffeinatedsloth", P("poster-6.png")).save(os.path.join(OUT, "side-caffeinatedsloth.png"))
    for n in ["disco", "fatamy", "mantis", "joeyrob"]:
        if n != "joeyrob":
            Image.open(os.path.join(SRC, "chatgpt-round3", "side-%s.png" % n)).save(os.path.join(OUT, "side-%s.png" % n))
        Image.open(os.path.join(SRC, "chatgpt-round2", "marquee-%s.jpg" % n)).convert("RGB").save(os.path.join(OUT, "marquee-%s.jpg" % n), quality=95)
    # headers for the other four: the ChatGPT originals, untouched
    for n in ["debo", "jordan", "glowinghumanity", "caffeinatedsloth"]:
        Image.open(os.path.join(SRC, "chatgpt-round2", "marquee-%s.jpg" % n)).save(os.path.join(OUT, "marquee-%s.jpg" % n), quality=95)
    # framed wall pictures, one set size (2:3)
    for i in range(1, 7):
        poster_frame(P("poster-%d.png" % i), "poster-%d.jpg" % i)
    poster_frame(debo, "poster-debo.jpg")
    poster_frame(Image.open(os.path.join(SRC, "radiant-poster.png")), "poster-radiant.jpg")
    for n in ["fatamy", "glowing"]:
        poster_frame(Image.open(os.path.join(SRC, "comics", "comic-%s.png" % n)), "poster-comic-%s.jpg" % n)
    # the brick wall set
    for n in ["wall-brick.jpg", "wall-brick-normal.png", "wall-brick-roughness.png"]:
        Image.open(os.path.join(SRC, "chatgpt-round2", n)).convert("RGB").save(os.path.join(OUT, n.replace("wall-brick", "wall-brick-hd")), quality=92)
    print("assembled")


run()
