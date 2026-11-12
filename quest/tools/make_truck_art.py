#!/usr/bin/env python3
"""Cabinet art for the TRUCKIN' & DRIVIN' machine, made from the game's own artwork (vr-art/tt-*.png|jpg, copied from the Trakway-Trail repo):
marquee (3072x1023) and side panel (887x1774). Output: vr-art/marquee-truckin.jpg, vr-art/side-truckin-flat.png."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
V = "vr-art/"
cover = Image.open(V + "tt-cover.jpg").convert("RGB")
spr = Image.open(V + "tt-sprites.png").convert("RGBA")
ext = Image.open(V + "tt-extras.png").convert("RGBA")
F = lambda s: ImageFont.truetype("DejaVuSans-Bold.ttf", s)
RECTS = [[59, 16, 203, 287], [394, 4, 151, 310], [678, 16, 203, 287], [990, 16, 203, 287], [71, 329, 175, 285], [382, 330, 175, 281], [662, 362, 235, 221], [960, 386, 268, 141], [42, 638, 244, 302], [335, 642, 273, 298], [652, 637, 263, 303], [981, 655, 228, 234], [70, 940, 172, 265], [316, 940, 310, 275], [693, 940, 247, 293], [940, 951, 295, 266]]
def cut(i, h):
    x, y, w, hh = RECTS[i]
    im = spr.crop((x, y, x + w, y + hh))
    return im.resize((int(w * h / hh), h), Image.LANCZOS)

def text_glow(img, text, size, xy, fill, glow, stroke=14, anchor="mm"):
    f = F(size)
    g = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(g).text(xy, text, font=f, fill=glow + (255,), anchor=anchor, stroke_width=stroke + 10, stroke_fill=glow + (255,))
    g = g.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(g)
    d = ImageDraw.Draw(img)
    d.text(xy, text, font=f, fill=(20, 40, 44, 255), anchor=anchor, stroke_width=stroke, stroke_fill=(20, 40, 44, 255))
    d.text(xy, text, font=f, fill=fill + (255,), anchor=anchor)

# ---- marquee: the countryside from the cover, the teal rig on the road, the sheep and the taco, big lettering
W, H = 3072, 1023
m = Image.new("RGBA", (W, H))
band = cover.crop((0, 120, 1024, 120 + 341)).resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(3))
band = Image.eval(band, lambda v: int(v * 0.85))
m.paste(band.convert("RGBA"), (0, 0))
shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(shade)
for i in range(H):
    sd.line([(0, i), (W, i)], fill=(8, 28, 34, int(140 * (i / H) ** 1.5)))
m.alpha_composite(shade)
text_glow(m, "TRUCKIN'", 280, (1950, 330), (255, 233, 138), (255, 170, 40))
text_glow(m, "& DRIVIN'", 280, (2000, 700), (150, 255, 232), (20, 190, 170))
tr = cut(1, 600).rotate(90, expand=True)           # the trailer, lying down
cab = cut(0, 440).rotate(-90, expand=True)         # the cab in front of it, facing right
m.alpha_composite(tr, (50, 300))
m.alpha_composite(cab, (50 + tr.width - 30, 300 + (tr.height - cab.height) // 2))
m.alpha_composite(cut(8, 300), (2760, 90))
m.alpha_composite(cut(13, 360), (2700, 600))
m.alpha_composite(cut(11, 200), (1020, 760))
m.convert("RGB").save(V + "marquee-truckin.jpg", quality=92)

# ---- side panel (flat): the cover's portrait with the title across the top
w, h = 887, 1774
cw = int(1536 * w / h)
x0 = (1024 - cw) // 2
side = cover.crop((x0, 0, x0 + cw, 1536)).resize((w, h), Image.LANCZOS).convert("RGBA")
text_glow(side, "TRUCKIN'", 150, (w // 2, 150), (255, 233, 138), (255, 170, 40), stroke=9)
text_glow(side, "& DRIVIN'", 120, (w // 2, 290), (150, 255, 232), (20, 190, 170), stroke=8)
side.convert("RGB").save(V + "side-truckin-flat.png")
print("ok")
