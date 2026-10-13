#!/usr/bin/env python3
"""Cleans, grits and makes an icon pop: python3 scripts/grit-icon.py in.png out-1024.png

Crops the rounded border, fills the see-through corners, enlarges to 1024, cuts the subject out (GrabCut), then
darkens and saturates the background, lifts the subject with local contrast and colour, blooms the glowing
parts, adds a thin rim light, and finishes with grain."""
import sys
import numpy as np
import cv2
from PIL import Image, ImageFilter

im = Image.open(sys.argv[1]).convert('RGBA')
w, h = im.size
inset = int(w * 0.012)
im = im.crop((inset, inset, w - inset, h - inset))
if abs(im.width / im.height - 1) > 0.03:  # make it square by trimming the longer side
    side = min(im.size)
    left = (im.width - side) // 2
    top = int((im.height - side) * 0.4)
    im = im.crop((left, top, left + side, top + side))
a = np.array(im)
mask = cv2.dilate((a[..., 3] < 250).astype(np.uint8) * 255, np.ones((5, 5), np.uint8))
rgb = cv2.inpaint(cv2.cvtColor(a[..., :3], cv2.COLOR_RGB2BGR), mask, 9, cv2.INPAINT_TELEA)
x = Image.fromarray(cv2.cvtColor(rgb, cv2.COLOR_BGR2RGB)).resize((1024, 1024), Image.LANCZOS)
x = x.filter(ImageFilter.UnsharpMask(radius=3, percent=90, threshold=2))
img = np.array(x)
H = W = 1024

# --- cut the subject out
small = cv2.resize(img, (256, 256))
gc = np.zeros((256, 256), np.uint8)
rect = (int(256 * 0.06), int(256 * 0.04), int(256 * 0.88), int(256 * 0.94))
bgd, fgd = np.zeros((1, 65)), np.zeros((1, 65))
cv2.grabCut(cv2.cvtColor(small, cv2.COLOR_RGB2BGR), gc, rect, bgd, fgd, 6, cv2.GC_INIT_WITH_RECT)
fg = np.where((gc == 1) | (gc == 3), 1.0, 0.0).astype(np.float32)
fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
fg = cv2.GaussianBlur(cv2.resize(fg, (W, H)), (0, 0), 6)
fg = np.clip((fg - 0.5) * 3 + 0.5, 0, 1)
# the figure runs off the bottom edge: keep the cut-out going to the border so no rim shows across the chest
yy0, xx0 = np.mgrid[0:H, 0:W].astype(np.float32)
ramp = np.clip((yy0 / H - 0.66) / 0.14, 0, 1) * np.clip((xx0 / W - 0.07) / 0.05, 0, 1) * np.clip((0.93 - xx0 / W) / 0.05, 0, 1)
fg = np.maximum(fg, ramp)[..., None]

def adjust(rgb8, sat, val, contrast=1.0, clahe=0.0):
    if clahe:
        lab = cv2.cvtColor(rgb8, cv2.COLOR_RGB2LAB)
        lab[..., 0] = cv2.createCLAHE(clipLimit=clahe, tileGridSize=(6, 6)).apply(lab[..., 0])
        rgb8 = cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)
    hsv = cv2.cvtColor(rgb8, cv2.COLOR_RGB2HSV).astype(np.float32)
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 255)
    hsv[..., 2] = np.clip(hsv[..., 2] * val, 0, 255)
    out = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB).astype(np.float32) / 255
    return np.clip((out - 0.5) * contrast + 0.5, 0, 1)

subject = adjust(img, 1.3, 1.1, 1.12, 2.4)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
background = adjust(img, 1.7, 0.62, 1.1, 1.5)
background *= (1 - 0.35 * np.clip((((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) - 0.2, 0, 1))[..., None]
f = subject * fg + background * (1 - fg)

# --- bloom on the bright glowing greens (the eyes)
hsv = cv2.cvtColor((np.clip(f, 0, 1) * 255).astype(np.uint8), cv2.COLOR_RGB2HSV)
glow = ((hsv[..., 0] > 38) & (hsv[..., 0] < 75) & (hsv[..., 1] > 110) & (hsv[..., 2] > 170)).astype(np.float32)
bloom = cv2.GaussianBlur(glow, (0, 0), 16)[..., None] * np.array([0.25, 1.0, 0.2], np.float32)
f = 1 - (1 - f) * (1 - 0.9 * bloom)

# --- thin warm rim light just outside the subject, and a dark halo to separate it
edge = cv2.GaussianBlur(fg[..., 0], (0, 0), 3) - cv2.GaussianBlur(fg[..., 0], (0, 0), 14)
rim = np.clip(edge * 2.2, 0, 1)[..., None] * np.array([1.0, 0.55, 0.25], np.float32)
f = 1 - (1 - f) * (1 - 0.55 * rim)
halo = np.clip(cv2.GaussianBlur(fg[..., 0], (0, 0), 22) - fg[..., 0], 0, 1)[..., None]
f *= 1 - 0.35 * halo

# --- grit
rng = np.random.default_rng(5)
f += (cv2.GaussianBlur(rng.normal(0, 1, (H, W)).astype(np.float32), (0, 0), 0.7) * 0.05)[..., None]
blot = cv2.GaussianBlur(rng.normal(0, 1, (H, W)).astype(np.float32), (0, 0), 14)
f += ((blot / blot.std()) * 0.035)[..., None] * (1 - 0.5 * fg)
f = np.clip((f - 0.5) * 1.08 + 0.5, 0, 1)
Image.fromarray((f * 255).astype(np.uint8)).save(sys.argv[2])
