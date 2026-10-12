#!/usr/bin/env python3
"""Fits a painted console skin to the game's fixed cabinet.

The artist paints white placeholder shapes where the game draws the screen and the controls.
This script (1) resizes the picture to 900 x 1600, (2) moves the window and control row to the game's positions without scaling the art (blank window rows are
added or removed and a quiet strip of the deck is cut), (3) lifts any socket that sits far from the game's control out as a rigid patch and sets it under that
control (nothing is warped), and (4) paints the placeholders dark so no white shows.

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


def drop_rows(img, y0, n):
    """Removes n rows starting at y0 and blends the seam so it does not show."""
    out = np.concatenate([img[:y0], img[y0 + n :]], axis=0)
    fade = 14
    for k in range(fade):
        a = (k + 1) / (fade + 1)
        y = y0 - fade + k
        out[y] = ((1 - a) * img[y] + a * img[y + n]).astype(np.uint8)
    return out


def add_rows(img, y, n):
    """Repeats the row at y n times (used inside the blank window only)."""
    return np.concatenate([img[:y], np.repeat(img[y : y + 1], n, axis=0), img[y:]], axis=0)


def calm_band(img, lo, hi, n):
    """Finds the n-row band between lo and hi with the least detail, so removing it costs the artwork nothing."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32)
    energy = np.abs(np.diff(gray, axis=0)).mean(axis=1)
    csum = np.concatenate([[0], np.cumsum(energy)])
    best = min(range(lo, hi - n), key=lambda y: csum[y + n] - csum[y])
    return best


def fit_vertical(img, win, row_y):
    """Brings the window bottom and the joystick row to the game's positions WITHOUT scaling the artwork:
    blank window rows are added or removed, and a quiet band of the deck is cut out."""
    l, t, r, b = win
    delta = REF_WIN[3] - b
    mid = (t + b) // 2
    if delta > 0:
        img = add_rows(img, mid, delta)
    elif delta < 0:
        img = drop_rows(img, mid, -delta)
    row_y = row_y + delta
    extra = int(round(row_y - 1371))
    if extra > 2:
        # Only the strip between the window and the tops of the sockets can be cut; any leftover offset is
        # absorbed by the local nudge around each control.
        lo, hi = REF_WIN[3] + 20, 1371 - 118
        extra = min(extra, hi - lo - 4)
        y0 = calm_band(img, lo, hi, extra)
        img = drop_rows(img, y0, extra)
    elif extra < -2:
        y0 = calm_band(img, REF_WIN[3] + 20, 1371 - 118, 1)
        img = np.concatenate([img[:y0], np.repeat(img[y0 : y0 + 1], -extra, axis=0), img[y0:]], axis=0)
    return cv2.resize(img[:H], (W, H)) if img.shape[0] >= H else np.pad(img, ((0, H - img.shape[0]), (0, 0), (0, 0)), mode='edge')


def nudge_control(img, ctrl, found):
    """Moves a socket that sits more than a few pixels away from the game's control. The socket and its ring
    are lifted out as one rigid patch (nothing is stretched), the gap it leaves is filled from the
    surroundings and the patch is set down under the game's control."""
    _, cx, cy, tw, th, shape = ctrl
    (x, y, w, h), (ax, ay) = found
    ax, ay = int(round(ax)), int(round(ay))
    if np.hypot(ax - cx, ay - cy) <= 10:
        return img
    R = int(max(tw, th) / 2 * 1.2) + 6
    yy, xx = np.mgrid[0:H, 0:W]
    src = (np.hypot(xx - ax, yy - ay) <= R).astype(np.uint8)
    # Copy the patch (with a soft edge) before the gap is filled.
    patch = img[ay - R : ay + R + 1, ax - R : ax + R + 1].copy() if ay - R >= 0 and ay + R < H and ax - R >= 0 and ax + R < W else None
    if patch is None:
        return img
    soft = cv2.GaussianBlur(src[ay - R : ay + R + 1, ax - R : ax + R + 1].astype(np.float32), (0, 0), 5)
    soft = np.clip(soft * 1.6 - 0.3, 0, 1)[..., None]
    filled = cv2.inpaint(img, cv2.dilate(src, np.ones((5, 5), np.uint8)), 7, cv2.INPAINT_TELEA)
    y0, x0 = cy - R, cx - R
    y1, x1 = y0 + 2 * R + 1, x0 + 2 * R + 1
    if y0 < 0 or x0 < 0 or y1 > H or x1 > W:
        return img
    region = filled[y0:y1, x0:x1].astype(np.float32)
    filled[y0:y1, x0:x1] = (region * (1 - soft) + patch.astype(np.float32) * soft).astype(np.uint8)
    return filled


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
    img = fit_vertical(img, win, row_y)
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
