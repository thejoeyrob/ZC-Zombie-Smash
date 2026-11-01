#!/usr/bin/env python3
"""Neon tube signs: thin glowing letters with a white-hot core, on transparent background."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import make_signs as ms

OUT = os.path.join(os.path.dirname(__file__), "..", "vr-art")


def neon(text, name, col, size=230, w=1400, h=420):
    f = ms.font(ms.BARLOW, size)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((w // 2, h // 2), text, font=f, fill=255, anchor="mm")
    line = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(17)))
    tube = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tube.paste(Image.new("RGBA", (w, h), col + (255,)), (0, 0), line)
    core = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    core.paste(Image.new("RGBA", (w, h), (255, 255, 255, 235)), (0, 0), line.filter(ImageFilter.MinFilter(5)))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for r, k in [(26, 0.9), (12, 1.0), (5, 1.0)]:
        g = tube.filter(ImageFilter.GaussianBlur(r))
        g.putalpha(g.split()[3].point(lambda v: min(255, int(v * 2.6 * k))))
        out.alpha_composite(g)
    out.alpha_composite(tube)
    out.alpha_composite(core)
    out.save(os.path.join(OUT, name))


neon("ARCADE", "neon-arcade.png", (70, 120, 255))
neon("GAME ON", "neon-gameon.png", (255, 60, 150), 220)
neon("HIGH SCORES", "neon-scores.png", (255, 190, 40), 190)
neon("PLAYER 1", "neon-player1.png", (60, 240, 255), 220)
