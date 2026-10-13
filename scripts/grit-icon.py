#!/usr/bin/env python3
"""Cleans and grits an icon picture: python3 scripts/grit-icon.py in.png out-1024.png

Crops the rounded border, fills the see-through corners, enlarges to 1024, then adds local contrast, a darker
vignette, grain and dirt."""
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
lab = cv2.cvtColor(np.array(x), cv2.COLOR_RGB2LAB)
lab[..., 0] = cv2.createCLAHE(clipLimit=2.4, tileGridSize=(6, 6)).apply(lab[..., 0])
f = cv2.cvtColor(lab, cv2.COLOR_LAB2RGB).astype(np.float32) / 255
hsv = cv2.cvtColor((f * 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
green = ((hsv[..., 0] > 35) & (hsv[..., 0] < 75) & (hsv[..., 1] > 90)).astype(np.float32)
green = cv2.GaussianBlur(green, (0, 0), 2)
hsv[..., 1] = np.clip(hsv[..., 1] * (1.05 + 0.4 * green), 0, 255)
hsv[..., 2] = np.clip(hsv[..., 2] * (0.92 + 0.3 * green), 0, 255)
f = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB).astype(np.float32) / 255
H = W = 1024
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
f *= (1 - 0.5 * np.clip((((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) - 0.35, 0, 1))[..., None]
rng = np.random.default_rng(5)
f += (cv2.GaussianBlur(rng.normal(0, 1, (H, W)).astype(np.float32), (0, 0), 0.7) * 0.07)[..., None]
blot = cv2.GaussianBlur(rng.normal(0, 1, (H, W)).astype(np.float32), (0, 0), 14)
f += ((blot / blot.std()) * 0.05)[..., None]
f = np.clip((f - 0.5) * 1.12 + 0.5, 0, 1)
Image.fromarray((f * 255).astype(np.uint8)).save(sys.argv[2])
