#!/usr/bin/env python3
"""Builds a solid 3D bobble-head figure from each three-view (front / side / back) character sheet.
The figure is the intersection of the three silhouettes (a visual hull), smoothed and meshed with marching cubes,
then textured by projecting the front, side and back pictures onto it. Output: quest/vr-art/bobble-<id>.obj and -atlas.jpg."""
import sys, numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure

SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/zips/b4b"
OUT = sys.argv[2] if len(sys.argv) > 2 else "quest/vr-art"
IDS = ["jordan", "glowinghumanity", "debo", "caffeinatedsloth", "discoman", "fatamy", "drmantis"]
HEIGHT_M = 0.36
CELL = 8            # picture pixels per voxel
H = 480             # every view is scaled to this many pixels tall


def cut(sheet):
    a = np.asarray(sheet.convert("RGB")).astype(float)
    bg = np.median(np.concatenate([a[:20, :20].reshape(-1, 3), a[-20:, -20:].reshape(-1, 3), a[:20, -20:].reshape(-1, 3)]), axis=0)
    W = a.shape[1] // 3
    views = []
    for k in range(3):
        sub = a[:, k * W:(k + 1) * W]
        fg = np.sqrt(((sub - bg) ** 2).sum(2)) > 38
        fg = ndi.binary_opening(fg, structure=np.ones((6, 6)))
        lab, cnt = ndi.label(fg)
        sizes = ndi.sum(fg, lab, range(1, cnt + 1))
        keep = lab == (1 + int(np.argmax(sizes)))
        keep = ndi.binary_fill_holes(ndi.binary_closing(keep, iterations=4))
        ys, xs = np.where(keep)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        rgb = sub[y0:y1, x0:x1]
        m = keep[y0:y1, x0:x1]
        # bleed the colours outward so grazing triangles never sample the grey background
        idx = ndi.distance_transform_edt(~m, return_distances=False, return_indices=True)
        rgb = rgb[idx[0], idx[1]]
        scale = H / rgb.shape[0]
        w = max(1, int(round(rgb.shape[1] * scale)))
        rgb_i = np.asarray(Image.fromarray(rgb.astype(np.uint8)).resize((w, H), Image.LANCZOS))
        m_i = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((w, H), Image.LANCZOS)) > 127
        views.append((rgb_i, m_i))
    return views


def build(name):
    sheet = Image.open(f"{SRC}/bobble-{name}-ref.png")
    (frgb, fm), (srgb, sm), (brgb, bm) = cut(sheet)
    # voxel grid: x across, y up, z front-to-back (front = +z); each view is centred on its own bounding box
    def cell(m):  # downsample a mask to voxel cells
        h, w = m.shape
        return m[:h // CELL * CELL, :w // CELL * CELL].reshape(h // CELL, CELL, w // CELL, CELL).mean((1, 3)) > 0.45
    F, S, B = cell(fm), cell(sm), cell(bm[:, ::-1])    # the back view is seen mirrored
    ny = F.shape[0]
    nx = max(F.shape[1], B.shape[1]) + 4
    nz = S.shape[1] + 4
    def pad(m, n):
        out = np.zeros((m.shape[0], n), bool)
        o = (n - m.shape[1]) // 2
        out[:, o:o + m.shape[1]] = m
        return out
    F, B, S = pad(F, nx), pad(B, nx), pad(S, nz)
    F = ndi.binary_dilation(F, iterations=1)
    B = ndi.binary_dilation(B, iterations=1)
    vol = F[:, :, None] & B[:, :, None] & S[:, None, :]       # [y, x, z]
    vol = np.pad(vol, 2)
    vol = vol.astype(float)
    vol = ndi.gaussian_filter(vol, 0.9)
    verts, faces, normals, _ = measure.marching_cubes(vol, 0.5)
    verts -= 2    # undo padding
    # voxel (y, x, z) -> metres, feet on y=0, centred on x and z
    cell_m = HEIGHT_M / ny
    X = (verts[:, 1] - nx / 2.0) * cell_m
    Y = (ny - verts[:, 0]) * cell_m       # picture rows run top to bottom
    Z = (verts[:, 2] - nz / 2.0) * cell_m
    P = np.stack([X, Y, Z], 1)
    N = np.stack([normals[:, 1], -normals[:, 0], normals[:, 2]], 1)
    faces = faces[:, ::-1]
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-6)
    # atlas: front | side | back, each H pixels tall
    wf, ws, wb = frgb.shape[1], srgb.shape[1], brgb.shape[1]
    atlas = np.concatenate([frgb, srgb, brgb], axis=1)
    AW = atlas.shape[1]
    Image.fromarray(atlas).save(f"{OUT}/bobble-{name}-atlas.jpg", quality=90)
    # the shader blends the three pictures by surface direction, so the mesh needs only positions and normals
    import json
    json.dump({"widths": [wf, ws, wb]}, open(f"{OUT}/bobble-{name}-atlas.json", "w"))
    lines = ["# bobble %s" % name]
    for p, n in zip(P, N):
        lines.append("v %.4f %.4f %.4f" % tuple(p))
    for n in N:
        lines.append("vn %.3f %.3f %.3f" % tuple(n))
    for t in faces:
        lines.append("f " + " ".join("%d//%d" % (int(i) + 1, int(i) + 1) for i in t))
    open(f"{OUT}/bobble-{name}.obj", "w").write("\n".join(lines))
    print(name, "tris", len(faces), "verts", len(P), "height", round(float(Y.max()), 3), "width", round(float(X.max() - X.min()), 3), "depth", round(float(Z.max() - Z.min()), 3))


if __name__ == "__main__":
    for n in IDS:
        build(n)
