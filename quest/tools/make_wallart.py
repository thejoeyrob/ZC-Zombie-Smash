#!/usr/bin/env python3
"""Glowing arcade wall art: back-lit pixel sprites (Pac-style chase, invaders, controller, joystick) and neon hexagon ceiling lights."""
import math, os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "vr-art")
PAC = ["..XXXX..", ".XXXXXX.", "XXXXXXXX", "XXXXXX..", "XXXX....", "XXXXXX..", ".XXXXXX.", "..XXXX.."]
GHOST = ["..XXXX..", ".XXXXXX.", "XXXXXXXX", "XWWXXWWX", "XWBXXWBX", "XXXXXXXX", "XXXXXXXX", "X.XX.XX."]
INV = ["..X....X..", "...X..X...", "..XXXXXX..", ".XX.XX.XX.", "XXXXXXXXXX", "X.XXXXXX.X", "X.X....X.X", "...XX.XX.."]
HEART = [".XX..XX.", "XXXXXXXX", "XXXXXXXX", "XXXXXXXX", ".XXXXXX.", "..XXXX..", "...XX..."]
PAD = ["..XXXXXXXXXX..", ".XXXXXXXXXXXX.", "XXX.XXXXXX.XXX", "XX...XXXX.X.XX", "XXX.XXXXXX.XXX", "XXXXXXXXXXXXXX", "XXXXX....XXXXX", ".XXX......XXX."]
STICK = ["...XX...", "..XXXX..", "..XXXX..", "...XX...", "...XX...", "...XX...", "XXXXXXXX", "XXXXXXXX"]


def sprite(rows, col, px=40, gap=5, eye=(255, 255, 255), pupil=(30, 60, 220)):
    h, w = len(rows), len(rows[0])
    im = Image.new("RGBA", (w * px, h * px), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == ".":
                continue
            fill = {"X": col, "W": eye, "B": pupil}[c]
            d.rectangle((x * px + gap, y * px + gap, (x + 1) * px - gap, (y + 1) * px - gap), fill=fill + (255,))
            d.rectangle((x * px + gap, y * px + gap, (x + 1) * px - gap, y * px + gap + 7), fill=(255, 255, 255, 70))
    return im


def glow(im, pad=60):
    big = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    big.paste(im, (pad, pad))
    g = big.filter(ImageFilter.GaussianBlur(22))
    g.putalpha(g.split()[3].point(lambda v: min(255, int(v * 1.6))))
    out = Image.new("RGBA", big.size, (0, 0, 0, 0))
    out.alpha_composite(g)
    out.alpha_composite(big)
    return out


def row(items, gap=40):
    w = sum(i.width for i in items) + gap * (len(items) - 1)
    h = max(i.height for i in items)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = 0
    for i in items:
        out.alpha_composite(i, (x, (h - i.height) // 2))
        x += i.width + gap
    return out


def dots(n, col):
    d = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    ImageDraw.Draw(d).ellipse((12, 12, 28, 28), fill=col + (255,))
    return row([d] * n, 24)


Y, P, C, G, R, V = (255, 224, 40), (255, 80, 190), (60, 225, 235), (110, 255, 80), (255, 60, 70), (170, 90, 255)
chase = row([sprite(PAC, Y), dots(3, Y), sprite(GHOST, P), sprite(GHOST, C)])
glow(chase).save(os.path.join(OUT, "wallart-chase.png"))
glow(row([sprite(INV, G), sprite(INV, V), sprite(INV, R)], 60)).save(os.path.join(OUT, "wallart-invaders.png"))
glow(sprite(PAD, V)).save(os.path.join(OUT, "wallart-pad.png"))
glow(sprite(STICK, R)).save(os.path.join(OUT, "wallart-stick.png"))
glow(sprite(HEART, R)).save(os.path.join(OUT, "wallart-heart.png"))


def hexes(name, cols):
    N = 1400
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = 150
    cells = [(0, 0), (1, 0), (-1, 0), (0.5, 1), (-0.5, 1), (0.5, -1), (-0.5, -1), (1.5, -1)]
    for i, (cx, cy) in enumerate(cells):
        x = N / 2 + cx * r * 1.75
        y = N / 2 + cy * r * 1.52
        pts = [(x + math.cos(math.radians(60 * k + 30)) * r, y + math.sin(math.radians(60 * k + 30)) * r) for k in range(6)]
        d.line(pts + [pts[0]], fill=cols[i % len(cols)] + (255,), width=14, joint="curve")
    g = im.filter(ImageFilter.GaussianBlur(20))
    g.putalpha(g.split()[3].point(lambda v: min(255, int(v * 1.8))))
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.alpha_composite(g)
    out.alpha_composite(im)
    core = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    for i, (cx, cy) in enumerate(cells):
        x = N / 2 + cx * r * 1.75
        y = N / 2 + cy * r * 1.52
        pts = [(x + math.cos(math.radians(60 * k + 30)) * r, y + math.sin(math.radians(60 * k + 30)) * r) for k in range(6)]
        cd.line(pts + [pts[0]], fill=(255, 255, 255, 200), width=5, joint="curve")
    out.alpha_composite(core)
    out.save(os.path.join(OUT, name))


hexes("hex-blue.png", [(70, 120, 255), (150, 90, 255)])
hexes("hex-pink.png", [(255, 60, 170), (255, 120, 60)])
