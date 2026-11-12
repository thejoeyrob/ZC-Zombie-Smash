#!/usr/bin/env python3
"""Neon tube signs for the sports hall: STRIKERS (green, with a bowling pin), DARTS (red, with a dartboard and dart) and ODIN'S AXE TOSS (amber, with the
Norse valknut). The letters are outlined in tube; the pictures are drawn in tube too. Output: vr-art/neon-strikers.png, neon-darts.png, neon-odin.png."""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import make_signs as ms

OUT = os.path.join(os.path.dirname(__file__), "..", "vr-art")
TUBE = 15        # tube width in pixels


def pin(d, cx, cy, h, w):
    prof = [(0.0, 0.0), (0.03, 0.08), (0.09, 0.115), (0.16, 0.105), (0.24, 0.07), (0.31, 0.075), (0.42, 0.14), (0.56, 0.2), (0.7, 0.2), (0.84, 0.15), (0.95, 0.11), (1.0, 0.0)]
    right = [(cx + p[1] * w * 2.4, cy - h / 2 + p[0] * h) for p in prof]
    left = [(cx - p[1] * w * 2.4, cy - h / 2 + p[0] * h) for p in reversed(prof)]
    d.line(right + left + [right[0]], fill=255, width=TUBE, joint="curve")
    for yy in (0.2, 0.26):      # the two stripes on the neck
        y = cy - h / 2 + yy * h
        d.line([(cx - w * 0.19, y), (cx + w * 0.19, y)], fill=255, width=TUBE - 4)


def dartboard(d, cx, cy, r):
    for k in (1.0, 0.78, 0.46, 0.14):
        d.ellipse([cx - r * k, cy - r * k, cx + r * k, cy + r * k], outline=255, width=TUBE - 3)
    for a in range(0, 360, 45):
        t = math.radians(a + 22.5)
        d.line([(cx + math.cos(t) * r * 0.46, cy + math.sin(t) * r * 0.46), (cx + math.cos(t) * r * 0.78, cy + math.sin(t) * r * 0.78)], fill=255, width=TUBE - 7)
    # the dart: barrel and flights, coming in from the upper right
    tip = (cx + r * 0.02, cy + r * 0.02)
    tail = (cx + r * 1.05, cy - r * 1.05)
    d.line([tip, tail], fill=255, width=TUBE - 3)
    for off in (-1, 1):
        ex = tail[0] + off * r * 0.22 + r * 0.16
        ey = tail[1] - off * r * 0.22 - r * 0.0
        d.line([(tail[0] - r * 0.12, tail[1] + r * 0.12), (ex + r * 0.1 * off, ey)], fill=255, width=TUBE - 6)


def valknut(d, cx, cy, s):
    """Three interlocked triangles (drawn overlapping at their corners, the way the Norse knot of Odin is usually shown)."""
    for k in range(3):
        a = math.radians(90 + k * 120)
        c = (cx + math.cos(a) * s * 0.40, cy - math.sin(a) * s * 0.40 + s * 0.06)
        pts = []
        for j in range(3):
            b = math.radians(90 + j * 120)
            pts.append((c[0] + math.cos(b) * s * 0.50, c[1] - math.sin(b) * s * 0.50))
        d.line(pts + [pts[0]], fill=255, width=TUBE - 2, joint="curve")


def sign(name, text, col, icon, size, h, icon_w):
    f = ms.font(ms.BARLOW, size)
    tw = int(f.getlength(text))
    w = icon_w + 110 + tw + 60
    text_mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(text_mask).text((icon_w + 110, h // 2), text, font=f, fill=255, anchor="lm", stroke_width=2)
    # the letters are outlined in tube: take the edge of each filled letter
    line = ImageChops.subtract(text_mask, text_mask.filter(ImageFilter.MinFilter(TUBE | 1)))
    icon_mask = Image.new("L", (w, h), 0)
    icon(ImageDraw.Draw(icon_mask), 60 + icon_w // 2, h // 2, icon_w)
    line = ImageChops.lighter(line, icon_mask)
    tube = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tube.paste(Image.new("RGBA", (w, h), col + (255,)), (0, 0), line)
    core = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    core.paste(Image.new("RGBA", (w, h), (255, 255, 255, 235)), (0, 0), line.filter(ImageFilter.MinFilter(5)))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for r, k in [(30, 0.9), (14, 1.0), (6, 1.0)]:
        g = tube.filter(ImageFilter.GaussianBlur(r))
        g.putalpha(g.split()[3].point(lambda v: min(255, int(v * 2.6 * k))))
        out.alpha_composite(g)
    out.alpha_composite(tube)
    out.alpha_composite(core)
    out.save(os.path.join(OUT, name))
    print(name, out.size, "aspect %.3f" % (w / h))


sign("neon-strikers.png", "STRIKERS", (60, 255, 110), lambda d, cx, cy, iw: pin(d, cx, cy, 400, 150), 330, 520, 170)
sign("neon-darts.png", "DARTS", (255, 70, 90), lambda d, cx, cy, iw: dartboard(d, cx, cy + 20, 150), 330, 520, 340)
sign("neon-odin.png", "ODIN'S AXE TOSS", (255, 160, 40), lambda d, cx, cy, iw: valknut(d, cx, cy, 250), 290, 520, 400)
