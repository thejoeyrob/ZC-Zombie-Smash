#!/usr/bin/env python3
"""Draws a simple, colourful console skin for a boss (or Joey) from scratch, to the game's fixed cabinet.

Clean frame, bold colour, a motif for the character, a name plate and a faint portrait behind the
controls. Every size matches the game: screen window, joystick, FIRE, grenade and MENU sockets.

  python3 scripts/make-skin.py            draws all eight into the current folder as console-<id>.webp
  python3 scripts/make-skin.py debo       draws one
"""
import math
import random
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, S = 900, 1600, 2  # drawn at 2x then reduced for smooth edges
WIN = (76, 102, 824, 1161)
FONT = '/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf'
SOCKETS = [('c', 198, 1371, 109), ('c', 704, 1371, 109), ('c', 450, 1303, 53), ('r', 450, 1455, (84, 36))]


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


SKINS = {
    'jordan': dict(name='JORDAN', top=(74, 12, 4), bot=(22, 4, 2), a='#ff9a36', b='#ffd23e', motif='flames', sprite='boss-jordan-stage1.webp'),
    'glowinghumanity': dict(name='GLOWING HUMANITY', top=(30, 8, 62), bot=(6, 26, 12), a='#9fff57', b='#ff4fd8', motif='drips', sprite='boss-glowinghumanity-stage1.webp'),
    'debo': dict(name='DEBO', top=(40, 30, 10), bot=(12, 9, 5), a='#f1c25d', b='#ff3b30', motif='chains', sprite='boss-debo-stage1.webp'),
    'caffeinatedsloth': dict(name='CAFFEINATED SLOTH', top=(70, 38, 14), bot=(24, 13, 6), a='#ffb766', b='#4fe0ff', motif='beans', sprite='boss-caffeinatedsloth-stage1.webp'),
    'discoman': dict(name='DISCO MAN', top=(58, 10, 96), bot=(16, 4, 36), a='#e98aff', b='#55e0ff', motif='balls', sprite='boss-discoman-stage1.webp'),
    'fatamy': dict(name='FAT AMY', top=(92, 8, 46), bot=(28, 2, 16), a='#ff83bd', b='#ff3b5c', motif='hearts', sprite='boss-fatamy-stage1.webp'),
    'drmantis': dict(name='DR MANTIS', top=(10, 54, 20), bot=(3, 16, 7), a='#92e158', b='#ffd23e', motif='hexes', sprite='boss-drmantis-stage1.webp'),
    'joeyrob': dict(name='JOEY ROB', top=(16, 38, 80), bot=(6, 12, 30), a='#ffd23e', b='#e23a3a', motif='flag', sprite='joey-reaction-close.webp'),
}


def sc(v):
    return int(round(v * S))


def gradient(top, bot):
    t = np.linspace(0, 1, H * S)[:, None, None]
    g = np.array(top, np.float32) * (1 - t) + np.array(bot, np.float32) * t
    return Image.fromarray(np.tile(g, (1, W * S, 1)).astype(np.uint8))


def glow_line(im, box, radius, color, width, blur=10, alpha=0.9):
    layer = Image.new('RGBA', im.size, color + (0,))
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([sc(v) for v in box], radius=sc(radius), outline=255, width=sc(width))
    layer.putalpha(mask.filter(ImageFilter.GaussianBlur(sc(blur))).point(lambda v: int(v * alpha)))
    im.alpha_composite(layer)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([sc(v) for v in box], radius=sc(radius), outline=color + (255,), width=sc(width))


def motif(layer, kind, a, b, rnd):
    d = ImageDraw.Draw(layer)
    A, B = a + (255,), b + (255,)
    if kind == 'flames':
        for x in range(-20, W + 20, 46):
            for lvl, col, hgt in ((0, rgb('#e23a1a'), 150), (1, a, 105), (2, b, 62)):
                h = hgt * rnd.uniform(0.7, 1.25)
                cx = x + rnd.uniform(-8, 8)
                pts = [(cx - 24 + lvl * 6, H), (cx - 18 + lvl * 5, H - h * 0.5), (cx + rnd.uniform(-8, 8), H - h), (cx + 16 - lvl * 5, H - h * 0.45), (cx + 24 - lvl * 6, H)]
                d.polygon([(sc(px), sc(py)) for px, py in pts], fill=col + (255,))
        for side in (30, W - 30):
            for y in range(200, 1100, 130):
                h = rnd.uniform(46, 80)
                pts = [(side - 11, y + h), (side - 8, y + h * 0.4), (side + rnd.uniform(-3, 3), y), (side + 8, y + h * 0.45), (side + 11, y + h)]
                d.polygon([(sc(px), sc(py)) for px, py in pts], fill=a + (255,))
    elif kind == 'drips':
        for edge_y, up in ((0, 1), (1175, 1)):
            x = 10
            while x < W:
                w = rnd.uniform(18, 34)
                h = rnd.uniform(24, 110)
                col = a if rnd.random() < 0.6 else b
                d.rounded_rectangle((sc(x), sc(edge_y), sc(x + w), sc(edge_y + h)), radius=sc(w / 2), fill=col + (255,))
                d.ellipse((sc(x - 3), sc(edge_y + h - w * 0.7), sc(x + w + 3), sc(edge_y + h + w * 0.5)), fill=col + (255,))
                x += w + rnd.uniform(10, 40)
        for side in (34, W - 34):
            for y in range(150, 1120, 95):
                d.ellipse((sc(side - 9), sc(y), sc(side + 9), sc(y + 22)), fill=(a if (y // 95) % 2 else b) + (255,))
    elif kind == 'chains':
        for side in (34, W - 34):
            for i, y in enumerate(range(100, 1180, 46)):
                if i % 2 == 0:
                    d.rounded_rectangle((sc(side - 13), sc(y), sc(side + 13), sc(y + 58)), radius=sc(13), outline=a + (255,), width=sc(7))
                else:
                    d.rounded_rectangle((sc(side - 7), sc(y + 6), sc(side + 7), sc(y + 52)), radius=sc(7), outline=rgb('#b8891f') + (255,), width=sc(6))
        for x in range(30, W, 52):
            d.rounded_rectangle((sc(x), sc(1560), sc(x + 40), sc(1584)), radius=sc(12), outline=a + (255,), width=sc(6))
        d.polygon([(sc(x), sc(y)) for x, y in [(380, 24), (400, 62), (426, 38), (450, 70), (474, 38), (500, 62), (520, 24), (520, 80), (380, 80)]], fill=a + (255,))
    elif kind == 'beans':
        for _ in range(70):
            x, y = rnd.uniform(0, W), rnd.uniform(0, H)
            if WIN[0] - 8 < x < WIN[2] + 8 and WIN[1] - 8 < y < WIN[3] + 8:
                continue
            ang = rnd.uniform(0, 180)
            bean = Image.new('RGBA', (sc(60), sc(60)), (0, 0, 0, 0))
            bd = ImageDraw.Draw(bean)
            bd.ellipse((sc(10), sc(18), sc(50), sc(42)), fill=(rgb('#8a5a2b') if rnd.random() < 0.5 else b) + (255,))
            bd.line((sc(14), sc(30), sc(46), sc(30)), fill=(40, 22, 8, 255), width=sc(3))
            bean = bean.rotate(ang, resample=Image.BICUBIC)
            layer.alpha_composite(bean, (sc(x - 30), sc(y - 30)))
    elif kind == 'balls':
        for side, cols in ((10, 1), (W - 62, 1)):
            for y in range(100, 1170, 54):
                for k in range(1):
                    cx = side + 26
                    col = a if (y // 54) % 2 else b
                    d.ellipse((sc(cx - 22), sc(y), sc(cx + 22), sc(y + 44)), fill=col + (255,))
                    d.line((sc(cx - 22), sc(y + 22), sc(cx + 22), sc(y + 22)), fill=(255, 255, 255, 200), width=sc(2))
                    d.line((sc(cx), sc(y), sc(cx), sc(y + 44)), fill=(255, 255, 255, 200), width=sc(2))
                    d.ellipse((sc(cx - 12), sc(y + 6), sc(cx - 4), sc(y + 14)), fill=(255, 255, 255, 255))
        for _ in range(60):
            x, y = rnd.uniform(0, W), rnd.uniform(1175, 1600)
            s = rnd.uniform(8, 20)
            d.polygon([(sc(x), sc(y - s)), (sc(x + s * 0.3), sc(y - s * 0.3)), (sc(x + s), sc(y)), (sc(x + s * 0.3), sc(y + s * 0.3)), (sc(x), sc(y + s)), (sc(x - s * 0.3), sc(y + s * 0.3)), (sc(x - s), sc(y)), (sc(x - s * 0.3), sc(y - s * 0.3))], fill=(255, 255, 255, 230))
    elif kind == 'hearts':
        for _ in range(48):
            x, y = rnd.uniform(0, W), rnd.uniform(0, H)
            if WIN[0] - 8 < x < WIN[2] + 8 and WIN[1] - 8 < y < WIN[3] + 8:
                continue
            s = rnd.uniform(14, 34)
            col = a if rnd.random() < 0.6 else b
            d.ellipse((sc(x - s), sc(y - s), sc(x), sc(y)), fill=col + (255,))
            d.ellipse((sc(x), sc(y - s), sc(x + s), sc(y)), fill=col + (255,))
            d.polygon([(sc(x - s), sc(y - s * 0.35)), (sc(x + s), sc(y - s * 0.35)), (sc(x), sc(y + s * 1.1))], fill=col + (255,))
    elif kind == 'hexes':
        r = 38
        for row in range(-1, int(H / (r * 1.5)) + 2):
            for col in range(-1, int(W / (r * 1.75)) + 2):
                cx = col * r * 1.75 + (r * 0.875 if row % 2 else 0)
                cy = row * r * 1.5
                pts = [(cx + r * 0.92 * math.cos(math.radians(60 * k + 30)), cy + r * 0.92 * math.sin(math.radians(60 * k + 30))) for k in range(6)]
                d.polygon([(sc(px), sc(py)) for px, py in pts], outline=(a if (row + col) % 3 else b) + (255,), width=sc(3))
    elif kind == 'flag':
        d.polygon([(0, 0), (sc(W), 0), (sc(W), sc(H)), (0, sc(H))], fill=(0, 0, 0, 0))
        for off, col, wd in ((0, (255, 255, 255), 70), (0, b, 36)):
            d.line((0, 0, sc(W), sc(H)), fill=col + (255,), width=sc(wd))
            d.line((0, sc(H), sc(W), 0), fill=col + (255,), width=sc(wd))
        d.rectangle((sc(W / 2 - 60), 0, sc(W / 2 + 60), sc(H)), fill=(255, 255, 255, 255))
        d.rectangle((0, sc(H / 2 - 60), sc(W), sc(H / 2 + 60)), fill=(255, 255, 255, 255))
        d.rectangle((sc(W / 2 - 34), 0, sc(W / 2 + 34), sc(H)), fill=b + (255,))
        d.rectangle((0, sc(H / 2 - 34), sc(W), sc(H / 2 + 34)), fill=b + (255,))


def make(sid):
    cfg = SKINS[sid]
    a, b = rgb(cfg['a']), rgb(cfg['b'])
    rnd = random.Random(sid)
    bright = lambda c: tuple(min(255, int(v * 2.3 + 14)) for v in c)
    base = gradient(bright(cfg['top']), bright(cfg['bot'])).convert('RGBA')
    # soft accent washes down the rails and across the deck so the whole skin carries the character's colour
    wash = Image.new('RGBA', base.size, a + (0,))
    wm = Image.new('L', base.size, 0)
    wd = ImageDraw.Draw(wm)
    wd.rectangle((0, 0, sc(70), sc(H)), fill=120)
    wd.rectangle((sc(W - 70), 0, sc(W), sc(H)), fill=120)
    wd.rectangle((0, sc(1175), sc(W), sc(H)), fill=70)
    wash.putalpha(wm.filter(ImageFilter.GaussianBlur(sc(14))))
    base.alpha_composite(wash)
    # motif at low strength so it colours the frame without cluttering it
    m = Image.new('RGBA', base.size, (0, 0, 0, 0))
    motif(m, cfg['motif'], a, b, rnd)
    m.putalpha(m.split()[3].point(lambda v: int(v * (0.95 if cfg['motif'] in ('flames', 'drips', 'chains', 'balls') else 0.5))))
    base.alpha_composite(m)
    # faint portrait behind the controls
    sp = Image.open(cfg['sprite']).convert('RGBA')
    sp = sp.crop(sp.getbbox())
    h = 400
    sp = sp.resize((int(sp.width * h / sp.height), h), Image.LANCZOS)
    if sp.width > 760:
        sp = sp.resize((760, int(sp.height * 760 / sp.width)), Image.LANCZOS)
    sp = sp.resize((sp.width * S, sp.height * S), Image.LANCZOS)
    pos = (sc(450) - sp.width // 2, sc(1192))
    pa = Image.new('L', base.size, 0)
    pa.paste(sp.split()[3], pos)
    glow = Image.new('RGBA', base.size, a + (0,))
    glow.putalpha(pa.filter(ImageFilter.GaussianBlur(sc(20))).point(lambda v: int(v * 0.8)))
    base.alpha_composite(glow)
    # panels: the deck and the rails get a translucent dark overlay so the colour reads but stays calm
    ov = Image.new('RGBA', base.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.rectangle((0, sc(1175), sc(W), sc(H)), fill=(0, 0, 0, 70))
    od.rectangle((0, 0, sc(W), sc(88)), fill=(0, 0, 0, 150))
    base.alpha_composite(ov)
    layer = Image.new('RGBA', base.size, (0, 0, 0, 0))
    layer.paste(sp, pos)
    la = layer.split()[3].point(lambda v: int(v * 0.9))
    layer.putalpha(la)
    base.alpha_composite(layer)
    d = ImageDraw.Draw(base)
    # screen bezel and window
    l, t, r, bt = WIN
    d.rounded_rectangle((sc(l - 18), sc(t - 18), sc(r + 18), sc(bt + 18)), radius=sc(14), fill=(10, 12, 14, 255))
    glow_line(base, (l - 16, t - 16, r + 16, bt + 16), 12, a, 7, blur=9)
    d = ImageDraw.Draw(base)
    d.rectangle((sc(l), sc(t), sc(r), sc(bt)), fill=(8, 14, 11, 255))
    d.rectangle((sc(l - 4), sc(t - 4), sc(r + 4), sc(bt + 4)), outline=(0, 0, 0, 255), width=sc(4))
    # outer border
    glow_line(base, (7, 7, W - 7, H - 7), 36, a, 9, blur=12)
    glow_line(base, (22, 22, W - 22, H - 22), 28, b, 3, blur=5, alpha=0.7)
    d = ImageDraw.Draw(base)
    # deck rim
    # name plate between the screen and the controls
    name = cfg['name']
    for size in (46, 42, 38, 34, 30, 26):
        f = ImageFont.truetype(FONT, sc(size))
        if d.textlength(name, font=f) <= sc(740):
            break
    d.text((sc(W / 2), sc(1214)), name, font=f, fill=a + (255,), stroke_width=sc(6), stroke_fill=(0, 0, 0, 255), anchor='mm')
    # sockets under the controls
    for kind, x, y, s in SOCKETS:
        if kind == 'c':
            for rad, col in ((s + 12, (0, 0, 0)), (s + 8, b), (s + 3, a), (s, (12, 15, 18))):
                d.ellipse((sc(x - rad), sc(y - rad), sc(x + rad), sc(y + rad)), fill=col + (255,))
            for rad in range(s, 0, -4):
                g = int(10 + 18 * (1 - rad / s))
                d.ellipse((sc(x - rad), sc(y - rad), sc(x + rad), sc(y + rad)), fill=(g, g + 3, g + 5, 255))
        else:
            w, h2 = s
            for pad, col in ((12, (0, 0, 0)), (8, b), (3, a), (0, (12, 15, 18))):
                d.rounded_rectangle((sc(x - w - pad), sc(y - h2 - pad), sc(x + w + pad), sc(y + h2 + pad)), radius=sc(22 + pad), fill=col + (255,))
    # rivets
    for x, y in ((40, 40), (W - 40, 40), (40, H - 40), (W - 40, H - 40)):
        d.ellipse((sc(x - 12), sc(y - 12), sc(x + 12), sc(y + 12)), fill=(20, 20, 22, 255), outline=a + (255,), width=sc(3))
    out = base.convert('RGB').resize((W, H), Image.LANCZOS)
    out.save(f'console-{sid}.webp', quality=90, method=6)
    print('wrote console-' + sid + '.webp')


if __name__ == '__main__':
    for sid in sys.argv[1:] or SKINS:
        make(sid)
