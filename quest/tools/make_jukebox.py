#!/usr/bin/env python3
"""Paints the jukebox as rendered artwork: front, glowing neon arcs, side slice and three brass buttons (quest/vr-art/jukebox-*.png)."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "vr-art")
K = 2                      # supersampling
W, H = 900 * K, 1950 * K
FONT = "/usr/share/fonts/truetype/freefont/FreeSansBoldOblique.ttf"
random.seed(3)


def S(v):
    return int(v * K)


def silhouette():
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.pieslice((0, 0, W, S(900)), 180, 360, fill=255)
    d.rectangle((0, S(450), W, H), fill=255)
    return m


def vgrad(w, h, stops):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                a, b = stops[i], stops[i + 1]
                k = (t - a[0]) / max(1e-6, b[0] - a[0])
                c = tuple(int(a[1][j] + (b[1][j] - a[1][j]) * k) for j in range(3))
                break
        for x in range(w):
            px[x, y] = c
    return img


def hgrad_overlay(img, box, light=0.35):
    """Soft cylindrical shading across a box: dark at both edges, bright toward the left-centre."""
    x0, y0, x1, y1 = box
    w = x1 - x0
    ov = Image.new("L", (w, 1))
    for x in range(w):
        t = x / (w - 1)
        v = 0.5 + 0.5 * math.cos((t - 0.35) * math.pi * 1.6)
        ov.putpixel((x, 0), int(255 * max(0, min(1, v))))
    ov = ov.resize((w, y1 - y0))
    white = Image.new("RGB", (w, y1 - y0), (255, 255, 255))
    black = Image.new("RGB", (w, y1 - y0), (0, 0, 0))
    region = img.crop(box)
    lit = Image.composite(white, region, ov.point(lambda v: int(v * light)))
    shade = Image.composite(black, lit, ov.point(lambda v: int((255 - v) * 0.35)))
    img.paste(shade, box)


def glow(layer, radius, strength=1.0):
    b = layer.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        a = b.split()[3].point(lambda v: min(255, int(v * strength)))
        b.putalpha(a)
    return b


def arcs_layer(mask):
    """Neon arcs: five bands running up the sides and round the arch."""
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cols = [(255, 40, 70), (255, 150, 20), (255, 240, 60), (60, 255, 120), (40, 200, 255)]
    for i, c in enumerate(cols):
        r = 395 - i * 34
        d.arc((S(450 - r), S(450 - r), S(450 + r), S(450 + r)), 180, 360, fill=c + (255,), width=S(20))
        d.line((S(450 - r), S(450), S(450 - r), S(1020)), fill=c + (255,), width=S(20))
        d.line((S(450 + r), S(450), S(450 + r), S(1020)), fill=c + (255,), width=S(20))
    soft = glow(lay, S(14), 1.6)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(soft)
    out.alpha_composite(lay)
    # hot white core line in each tube
    core = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    for i in range(5):
        r = 395 - i * 34
        cd.arc((S(450 - r), S(450 - r), S(450 + r), S(450 + r)), 180, 360, fill=(255, 255, 255, 170), width=S(6))
        cd.line((S(450 - r), S(450), S(450 - r), S(1020)), fill=(255, 255, 255, 170), width=S(6))
        cd.line((S(450 + r), S(450), S(450 + r), S(1020)), fill=(255, 255, 255, 170), width=S(6))
    out.alpha_composite(core)
    out.putalpha(ImageChops.multiply(out.split()[3], mask))
    return out


def chrome_bar(d, box, vertical=False):
    x0, y0, x1, y1 = box
    n = (x1 - x0) if vertical else (y1 - y0)
    for i in range(n):
        t = i / max(1, n - 1)
        v = int(70 + 185 * (0.5 + 0.5 * math.sin(t * math.pi * 2.0 + 0.6)) ** 1.5)
        if vertical:
            d.line((x0 + i, y0, x0 + i, y1), fill=(v, v, min(255, v + 12), 255))
        else:
            d.line((x0, y0 + i, x1, y0 + i), fill=(v, v, min(255, v + 12), 255))


def front(mask):
    img = vgrad(W, H, [(0, (120, 14, 38)), (0.5, (96, 8, 28)), (1, (60, 4, 16))]).convert("RGBA")
    d = ImageDraw.Draw(img)
    # lacquer sheen
    hgrad_overlay_img = img.convert("RGB")
    hgrad_overlay(hgrad_overlay_img, (0, 0, W, H), 0.28)
    img = hgrad_overlay_img.convert("RGBA")
    d = ImageDraw.Draw(img)
    # outer chrome edge (follows the arch)
    edge = Image.new("L", (W, H), 0)
    ed = ImageDraw.Draw(edge)
    ed.pieslice((0, 0, W, S(900)), 180, 360, fill=255)
    ed.rectangle((0, S(450), W, H), fill=255)
    inner = Image.new("L", (W, H), 0)
    idr = ImageDraw.Draw(inner)
    idr.pieslice((S(26), S(26), W - S(26), S(900) - S(26)), 180, 360, fill=255)
    idr.rectangle((S(26), S(450), W - S(26), H), fill=255)
    rim = ImageChops.subtract(edge, inner)
    chrome = Image.new("RGBA", (W, H))
    cd = ImageDraw.Draw(chrome)
    chrome_bar(cd, (0, 0, W, H), vertical=True)
    img.paste(chrome, (0, 0), rim)
    # dark neon channel behind the arcs
    chan = Image.new("L", (W, H), 0)
    cdr = ImageDraw.Draw(chan)
    cdr.pieslice((S(40), S(40), W - S(40), S(860)), 180, 360, fill=255)
    cdr.rectangle((S(40), S(450), W - S(40), S(1040)), fill=255)
    img.paste(Image.new("RGBA", (W, H), (22, 4, 12, 255)), (0, 0), chan)
    # the amber window
    win = Image.new("L", (W, H), 0)
    wd = ImageDraw.Draw(win)
    wd.pieslice((S(190), S(210), S(710), S(730)), 180, 360, fill=255)
    wd.rectangle((S(190), S(470), S(710), S(1010)), fill=255)
    glass = vgrad(W, H, [(0, (255, 200, 90)), (0.35, (255, 150, 40)), (0.6, (200, 80, 20)), (1, (110, 30, 10))]).convert("RGBA")
    img.paste(glass, (0, 0), win)
    wd2 = ImageDraw.Draw(img)
    # records stacked on the shelf, a big vinyl disc in the middle and a chrome tone arm
    cx, cy, R = S(450), S(640), S(150)
    for i in range(14, 0, -1):
        rr = R + i * S(3)
    d2 = ImageDraw.Draw(img)
    for k in range(7):
        y = S(900) + k * S(12)
        d2.rounded_rectangle((S(215) + k * S(6), y, S(685) - k * S(6), y + S(10)), S(5), fill=(14, 14, 18, 255), outline=(60, 60, 70, 255))
    d2.ellipse((cx - R, cy - R, cx + R, cy + R), fill=(12, 12, 16, 255))
    for g in range(8, 140, 7):
        d2.ellipse((cx - S(g), cy - S(g), cx + S(g), cy + S(g)), outline=(40, 40, 52, 255), width=1)
    d2.ellipse((cx - S(52), cy - S(52), cx + S(52), cy + S(52)), fill=(210, 30, 60, 255))
    d2.ellipse((cx - S(46), cy - S(46), cx + S(46), cy + S(46)), outline=(255, 210, 210, 255), width=S(2))
    d2.ellipse((cx - S(8), cy - S(8), cx + S(8), cy + S(8)), fill=(230, 230, 235, 255))
    d2.polygon([(cx + S(150), cy - S(165)), (cx + S(170), cy - S(150)), (cx + S(28), cy - S(10)), (cx + S(14), cy - S(26))], fill=(215, 218, 228, 255), outline=(40, 40, 50, 255))
    d2.ellipse((cx + S(150), cy - S(180), cx + S(190), cy - S(140)), fill=(235, 235, 240, 255), outline=(40, 40, 50, 255), width=S(2))
    # window glare
    gl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    gd.polygon([(S(215), S(300)), (S(420), S(240)), (S(300), S(700)), (S(215), S(720))], fill=(255, 255, 255, 55))
    gl.putalpha(ImageChops.multiply(gl.split()[3], win))
    img.alpha_composite(gl)
    # window frame
    wf = Image.new("L", (W, H), 0)
    wfd = ImageDraw.Draw(wf)
    wfd.pieslice((S(172), S(192), S(728), S(748)), 180, 360, fill=255)
    wfd.rectangle((S(172), S(470), S(728), S(1028)), fill=255)
    ring = ImageChops.subtract(wf, win)
    c2 = Image.new("RGBA", (W, H))
    chrome_bar(ImageDraw.Draw(c2), (0, 0, W, H), vertical=False)
    img.paste(c2, (0, 0), ring)
    # selector plate: chrome, with the dark display inset and three button seats
    d3 = ImageDraw.Draw(img)
    plate = (S(110), S(1052), S(790), S(1290))
    c3 = Image.new("RGBA", (W, H))
    chrome_bar(ImageDraw.Draw(c3), (0, plate[1], W, plate[3]), vertical=False)
    pm = Image.new("L", (W, H), 0)
    ImageDraw.Draw(pm).rounded_rectangle(plate, S(26), fill=255)
    img.paste(c3, (0, 0), pm)
    d3.rounded_rectangle((S(140), S(1072), S(760), S(1180)), S(14), fill=(4, 18, 8, 255), outline=(30, 30, 36, 255), width=S(4))
    for y in range(S(1076), S(1176), S(4)):
        d3.line((S(146), y, S(754), y), fill=(8, 38, 16, 255), width=1)
    for bx in (250, 450, 650):
        d3.ellipse((S(bx - 52), S(1175), S(bx + 52), S(1279)), fill=(30, 30, 34, 255))
    # speaker grille: dark cloth with a diamond weave, and chrome bars
    gm = Image.new("L", (W, H), 0)
    ImageDraw.Draw(gm).rounded_rectangle((S(110), S(1330), S(790), S(1790)), S(20), fill=255)
    gr = Image.new("RGBA", (W, H), (14, 8, 10, 255))
    gdr = ImageDraw.Draw(gr)
    step = S(14)
    for y in range(S(1330), S(1790), step):
        for x in range(S(110), S(790), step):
            gdr.polygon([(x + step // 2, y), (x + step, y + step // 2), (x + step // 2, y + step), (x, y + step // 2)], outline=(46, 30, 24, 255))
    img.paste(gr, (0, 0), gm)
    for i in range(6):
        y = S(1380) + i * S(76)
        cb = Image.new("RGBA", (W, H))
        chrome_bar(ImageDraw.Draw(cb), (S(110), y, S(790), y + S(14)), vertical=False)
        bm = Image.new("L", (W, H), 0)
        ImageDraw.Draw(bm).rounded_rectangle((S(110), y, S(790), y + S(14)), S(7), fill=255)
        img.paste(cb, (0, 0), bm)
    # kick plate
    kb = Image.new("RGBA", (W, H))
    chrome_bar(ImageDraw.Draw(kb), (0, S(1830), W, H), vertical=False)
    km = Image.new("L", (W, H), 0)
    ImageDraw.Draw(km).rectangle((S(26), S(1830), W - S(26), H), fill=255)
    img.paste(kb, (0, 0), km)
    # title across the crown
    f = ImageFont.truetype(FONT, S(78))
    t = "JUKEBOX"
    tw = ImageDraw.Draw(img).textlength(t, font=f)
    tl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    tdr = ImageDraw.Draw(tl)
    tdr.text(((W - tw) / 2, S(112)), t, font=f, fill=(255, 226, 120, 255), stroke_width=S(5), stroke_fill=(70, 10, 20, 255))
    img.alpha_composite(tl)
    # grain and edge vignette for a rendered, not flat, look
    g = Image.effect_noise((W, H), 18).convert("L").point(lambda v: v)
    gl2 = Image.merge("RGBA", (g, g, g, Image.new("L", (W, H), 14)))
    img.alpha_composite(gl2)
    img.putalpha(mask)
    return img


def side(mask):
    img = vgrad(W, H, [(0, (70, 8, 22)), (1, (36, 3, 10))]).convert("RGBA")
    d = ImageDraw.Draw(img)
    for x in range(0, W, S(28)):
        d.line((x, 0, x, H), fill=(80, 12, 28, 255), width=S(2))
    img.putalpha(mask)
    return img


def button(sym, path):
    n = 256
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((6, 6, n - 6, n - 6), fill=(24, 24, 28, 255))
    for r in range(110, 0, -1):
        t = r / 110
        c = (int(255 * (0.55 + 0.45 * (1 - t))), int(215 * (0.5 + 0.5 * (1 - t))), int(70 * (0.4 + 0.6 * (1 - t))), 255)
        d.ellipse((n / 2 - r, n / 2 - r - (1 - t) * 10 + 8, n / 2 + r, n / 2 + r - (1 - t) * 10 + 8), fill=c)
    d.ellipse((n / 2 - 100, n / 2 - 100, n / 2 + 100, n / 2 + 100), outline=(255, 244, 190, 255), width=6)
    k = (60, 30, 4, 255)
    cx = cy = n // 2
    if sym == "prev":
        d.polygon([(cx - 50, cy), (cx + 5, cy - 45), (cx + 5, cy + 45)], fill=k)
        d.polygon([(cx + 5, cy), (cx + 60, cy - 45), (cx + 60, cy + 45)], fill=k)
    elif sym == "next":
        d.polygon([(cx + 50, cy), (cx - 5, cy - 45), (cx - 5, cy + 45)], fill=k)
        d.polygon([(cx - 5, cy), (cx - 60, cy - 45), (cx - 60, cy + 45)], fill=k)
    else:
        d.rectangle((cx - 40, cy - 45, cx - 12, cy + 45), fill=k)
        d.rectangle((cx + 12, cy - 45, cx + 40, cy + 45), fill=k)
    im.save(path)


def main():
    mask = silhouette()
    fr = front(mask).resize((900, 1950), Image.LANCZOS)
    fr.save(os.path.join(OUT, "jukebox-front.png"))
    arcs_layer(mask).resize((900, 1950), Image.LANCZOS).save(os.path.join(OUT, "jukebox-neon.png"))
    side(mask).resize((450, 975), Image.LANCZOS).save(os.path.join(OUT, "jukebox-side.png"))
    for s in ("prev", "play", "next"):
        button(s, os.path.join(OUT, "jukebox-btn-%s.png" % s))


main()
