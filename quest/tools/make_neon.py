#!/usr/bin/env python3
"""Neon tube signs: thin glowing letters with a white-hot core, on transparent background."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import make_signs as ms

OUT = os.path.join(os.path.dirname(__file__), "..", "vr-art")


def neon(text, name, col, size=230, w=2000, h=600):
    """Glass-tube neon: a 1950s tube face (Monoton), a hot white core, a tight inner glow and a wide soft bloom."""
    f = ms.fnt("Monoton-Regular.ttf", size)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((w // 2, h // 2), text, font=f, fill=255, anchor="mm")
    tube = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tube.paste(Image.new("RGBA", (w, h), col + (255,)), (0, 0), mask)
    core = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    core.paste(Image.new("RGBA", (w, h), (255, 255, 255, 255)), (0, 0), mask.filter(ImageFilter.MinFilter(5)))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for r, k in [(34, 0.8), (16, 1.0), (7, 1.2)]:
        g = tube.filter(ImageFilter.GaussianBlur(r))
        g.putalpha(g.split()[3].point(lambda v, k=k: min(255, int(v * 2.2 * k))))
        out.alpha_composite(g)
    out.alpha_composite(tube)
    out.alpha_composite(core.filter(ImageFilter.GaussianBlur(1)))
    out.save(os.path.join(OUT, name))


neon("ARCADE", "neon-arcade.png", (70, 130, 255), 250)
neon("GAME ON", "neon-gameon.png", (255, 60, 150), 240)
neon("HIGH SCORES", "neon-scores.png", (255, 190, 40), 150)
neon("PLAYER 1", "neon-player1.png", (60, 240, 255), 240)
