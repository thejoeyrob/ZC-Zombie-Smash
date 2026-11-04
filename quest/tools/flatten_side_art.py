#!/usr/bin/env python3
"""Standard cabinet: every machine has the same side shape, so the side artwork is made fully opaque here.
Transparent areas (the cut-out silhouette of each original picture) are filled by extending the nearest painted colour, softly blurred,
and the standard outline then crops the picture. Output: vr-art/side-<id>-flat.png"""
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi
for k in ["debo", "mantis", "caffeinatedsloth", "disco", "joeyrob", "fatamy", "jordan", "glowinghumanity", "pinball", "zs", "jw"]:
    try:
        im = Image.open(f"vr-art/side-{k}.png").convert("RGBA")
    except FileNotFoundError:
        continue
    a = np.asarray(im).astype(np.float32)
    opaque = a[:, :, 3] > 200
    idx = ndi.distance_transform_edt(~opaque, return_distances=False, return_indices=True)
    filled = a[idx[0], idx[1], :3]
    soft = np.asarray(Image.fromarray(filled.astype(np.uint8)).filter(ImageFilter.GaussianBlur(14))).astype(np.float32)
    out = np.where(opaque[..., None], a[:, :, :3], soft)
    # keep a feathered edge so the art meets the filled colour without a seam
    alpha = ndi.gaussian_filter(a[:, :, 3] / 255.0, 2.0)[..., None]
    out = out * alpha + soft * (1 - alpha)
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(f"vr-art/side-{k}-flat.png", optimize=True)
    print(k, "filled", round(100 * float((~opaque).mean())), "% transparent")
