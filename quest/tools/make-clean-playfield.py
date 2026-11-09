#!/usr/bin/env python3
"""Makes vr-art/playfield-clean.jpg: the zombie pinball playfield artwork with the parts that are built as real 3D objects
(pop bumpers, flippers, slingshots, target banks, the two ramps) painted out, so the scenery underneath is flat paint and every
moving or raised part on the table is a real object. Table units are the game's 400 x 800; the artwork is 887 x 1774.
Run once and commit the result:  python3 quest/tools/make-clean-playfield.py"""
import cv2, numpy as np, os
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, "..", "vr-art", "playfield-pinball.jpg")
dst = os.path.join(here, "..", "vr-art", "playfield-clean.jpg")
img = cv2.imread(src)
h, w = img.shape[:2]
k = w / 400.0
def P(x, y): return (int(round(x * k)), int(round(y * k)))
mask = np.zeros((h, w), np.uint8)
# only the two printed flippers are painted out (they are real moving parts now); the pop bumpers, slingshots, targets and ramps are
# covered by their larger 3D versions, so the artwork around them stays untouched
for a, b in [((121, 696), (178, 718)), ((279, 696), (222, 718))]:
    cv2.line(mask, P(*a), P(*b), 255, int(34 * k))
mask = cv2.dilate(mask, np.ones((7, 7), np.uint8))
# paint out with a clean dark metal plate (crisp, no smearing): the real 3D parts stand on it
rng = np.random.default_rng(7)
plate = np.zeros((h, w, 3), np.float32)
plate[:] = (30, 24, 20)                                              # BGR: very dark warm steel
grain = rng.normal(0, 4.0, (h, w, 1)).astype(np.float32)
grain = cv2.GaussianBlur(grain[..., 0], (0, 0), 0.8)[..., None] * 2.5
streak = cv2.GaussianBlur(rng.normal(0, 1, (h, 1)).astype(np.float32).repeat(w, 1), (0, 0), 1.2)[..., None] * 3.0   # faint brushed look
plate = plate + grain + streak
edge = cv2.morphologyEx(mask, cv2.MORPH_GRADIENT, np.ones((5, 5), np.uint8))
m = (mask.astype(np.float32) / 255.0)[..., None]
out = img.astype(np.float32) * (1 - m) + plate * m
e = (edge.astype(np.float32) / 255.0)[..., None]
out = out * (1 - 0.55 * e) + np.array([80, 70, 62], np.float32) * 0.55 * e      # a thin steel lip around each plate
cv2.imwrite(dst, np.clip(out, 0, 255).astype(np.uint8), [cv2.IMWRITE_JPEG_QUALITY, 92])
cv2.imwrite("/tmp/claude-0/clean-preview.png", cv2.resize(np.clip(out, 0, 255).astype(np.uint8), (w // 2, h // 2)))
print("wrote", dst)
