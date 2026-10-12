#!/usr/bin/env python3
"""Fits a painted console skin to the game's fixed cabinet.

The artist paints white placeholder shapes where the game draws the screen and the controls.
This script (1) resizes the picture to 900 x 1600, (2) stretches it so the white window lands exactly on the
game's screen window, (3) nudges the area around each control so its socket sits exactly under the
game's joystick, FIRE, grenade and MENU button, and (4) paints the placeholders dark so no white shows.

  python3 scripts/fit-skin.py input.png console-<id>.webp
"""
import sys
import numpy as np
import cv2

W, H = 900, 1600
REF_WIN = (76, 102, 824, 1161)  # left, top, right, bottom of the game screen window
# (name, centre x, centre y, width, height, shape) of the controls the game draws, in skin pixels
CONTROLS = [
    ('joystick', 198, 1371, 217, 217, 'circle'),
    ('fire', 704, 1371, 217, 217, 'circle'),
    ('grenade', 450, 1303, 106, 106, 'circle'),
    ('menu', 450, 1455, 167, 72, 'rect'),
]


def white_mask(img, thr=242):
    return ((img[:, :, 0] > thr) & (img[:, :, 1] > thr) & (img[:, :, 2] > thr)).astype(np.uint8)


def components(mask, min_area=400):
    n, lab, stats, cent = cv2.connectedComponentsWithStats(mask, connectivity=8)
    out = [(stats[i, 4], stats[i, :4], cent[i]) for i in range(1, n) if stats[i, 4] > min_area]
    return sorted(out, key=lambda c: -c[0]), lab


def stretch_to_window(img, win, row_y):
    """Stretches the picture so the white window lands on the game's window and the joystick/FIRE row on the game's row."""
    l, t, r, b = win
    xs = np.interp(np.arange(W), [0, 76, 824, W], [0, l, r, W]).astype(np.float32)
    ys = np.interp(np.arange(H), [0, 102, 1161, 1371, H], [0, t, b, row_y, H]).astype(np.float32)
    mx = np.tile(xs[None, :], (H, 1))
    my = np.tile(ys[:, None], (1, W))
    return cv2.remap(img, mx, my, cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)


def nudge_control(img, ctrl, found):
    """Moves and resizes the area around a placeholder so it matches the game's control."""
    _, cx, cy, tw, th, shape = ctrl
    (x, y, w, h), (ax, ay) = found
    kx, ky = w / tw, h / th
    pad = int(1.9 * max(tw, th) / 2) + 6
    x0, x1 = max(0, cx - pad), min(W, cx + pad)
    y0, y1 = max(0, cy - pad), min(H, cy + pad)
    gx, gy = np.meshgrid(np.arange(x0, x1, dtype=np.float32), np.arange(y0, y1, dtype=np.float32))
    dx, dy = gx - cx, gy - cy
    if shape == 'circle':
        rn = np.hypot(dx / (tw / 2), dy / (th / 2))
    else:
        rn = np.maximum(np.abs(dx) / (tw / 2), np.abs(dy) / (th / 2))
    t = np.clip((rn - 1.15) / (1.9 - 1.15), 0, 1)
    t = t * t * (3 - 2 * t)
    qx = (1 - t) * (ax + dx * kx) + t * gx
    qy = (1 - t) * (ay + dy * ky) + t * gy
    patch = cv2.remap(img, qx.astype(np.float32), qy.astype(np.float32), cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
    img[y0:y1, x0:x1] = patch
    return img


def paint_dark(img, mask, kind):
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return
    cx, cy = xs.mean(), ys.mean()
    rad = max(np.ptp(xs), np.ptp(ys)) / 2 + 1
    d = np.hypot(xs - cx, ys - cy) / rad
    if kind == 'window':
        col = np.array([8, 14, 11], np.float32)
        img[ys, xs] = col
    else:
        inner, outer = np.array([20, 25, 28], np.float32), np.array([7, 10, 12], np.float32)
        t = np.clip(d, 0, 1)[:, None]
        img[ys, xs] = inner * (1 - t) + outer * t


def fit(src, dst):
    img = cv2.imread(src, cv2.IMREAD_COLOR)
    img = cv2.resize(img, (W, H), interpolation=cv2.INTER_AREA)
    comps, lab = components(white_mask(img))
    if not comps:
        raise SystemExit('No white placeholder shapes found in ' + src)
    x, y, w, h = comps[0][1]
    win = (int(x), int(y), int(x + w), int(y + h))
    # The two big round placeholders (joystick on the left, FIRE on the right) give the row of controls.
    rounds = [c for c in comps[1:] if 15000 < c[0] < 60000]
    left = [c for c in rounds if c[2][0] < W / 2]
    right = [c for c in rounds if c[2][0] >= W / 2]
    row_y = float(np.mean([max(left, key=lambda c: c[0])[2][1], max(right, key=lambda c: c[0])[2][1]])) if left and right else 1371.0
    img = stretch_to_window(img, win, row_y)
    # Find the control placeholders in the stretched picture, match each to the nearest game control.
    comps, lab = components(white_mask(img))
    small = [c for c in comps[1:] if c[0] < 60000]
    for ctrl in CONTROLS:
        _, cx, cy, tw, th, shape = ctrl
        best = min(small, key=lambda c: np.hypot(c[2][0] - cx, c[2][1] - cy), default=None)
        if best is None or np.hypot(best[2][0] - cx, best[2][1] - cy) > 160:
            print('  no placeholder found near', ctrl[0])
            continue
        img = nudge_control(img, ctrl, (tuple(int(v) for v in best[1]), tuple(best[2])))
    # Paint every placeholder dark (a little wider than the white, to cover the soft edge).
    mask = white_mask(img, 235)
    n_lab, lab2 = cv2.connectedComponents(mask, connectivity=8)
    for i in range(1, n_lab):
        comp = (lab2 == i).astype(np.uint8)
        if comp.sum() < 200:
            continue
        grow = cv2.dilate(comp, np.ones((7, 7), np.uint8))
        light = (img.min(axis=2) > 190).astype(np.uint8)
        region = (grow & light) | comp
        big = comp.sum() > 60000
        paint_dark(img, region.astype(bool), 'window' if big else 'socket')
    # Painted highlights left in the gap between the grenade and MENU sockets read as stray white shapes: remove them.
    gap = np.zeros(img.shape[:2], np.uint8)
    gap[1358:1418, 395:505] = 1
    bright = ((img.min(axis=2) > 165).astype(np.uint8) & gap)
    if bright.sum():
        bright = cv2.dilate(bright, np.ones((9, 9), np.uint8))
        img = cv2.inpaint(img, bright, 5, cv2.INPAINT_TELEA)
    cv2.imwrite(dst, img, [cv2.IMWRITE_WEBP_QUALITY, 88] if dst.lower().endswith('.webp') else [])
    print(f'{src} -> {dst}: window was {win}, now {REF_WIN}')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    fit(sys.argv[1], sys.argv[2])
