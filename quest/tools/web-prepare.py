#!/usr/bin/env python3
"""Makes a lighter copy of the project for the browser build: pictures capped at 1024 px on the long side, no music, no story videos.
Usage: web-prepare.py <quest dir> <output dir>"""
import os, shutil, sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
if os.path.exists(dst):
    shutil.rmtree(dst)
shutil.copytree(src, dst, ignore=shutil.ignore_patterns("build", "android", "addons", ".godot", "tests", "tools", "art-source", "art-hires", "fonts-src", "vr-art", "*.ogv", "mus-*.wav"))
CAP = 1024
n = 0
for root, _, files in os.walk(os.path.join(dst, "assets")):
    for f in files:
        p = os.path.join(root, f)
        if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
            try:
                im = Image.open(p)
                if max(im.size) > CAP:
                    k = CAP / max(im.size)
                    ext = f.lower().rsplit(".", 1)[1]
                    im2 = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
                    if ext in ("jpg", "jpeg"):
                        im2.convert("RGB").save(p, quality=90)
                    elif ext == "png":
                        im2.save(p, optimize=True)
                    else:
                        im2.save(p, quality=92)
                    n += 1
            except Exception as e:
                print("skip", p, e)
print("shrunk", n, "pictures")
