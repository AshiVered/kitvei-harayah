"""Cut Rav Kook out of the 1924 public-domain photo (Library of Congress, npcc.25595)
and save a head-and-shoulders RGBA cutout for the app icon.

Usage: python tools/make_portrait.py <photo.jpg>
Writes tools/source/portrait_cutout.png
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools", "source", "portrait_cutout.png")

# Head-and-shoulders crop in the original 2149x3515 photo (x0, y0, x1, y1).
CROP = (430, 60, 1930, 1560)


def main():
    src = sys.argv[1]
    data = np.fromfile(src, dtype=np.uint8)  # handles non-ASCII paths on Windows
    img = cv2.imdecode(data, cv2.IMREAD_COLOR)
    x0, y0, x1, y1 = CROP
    crop = img[y0:y1, x0:x1].copy()
    h, w = crop.shape[:2]
    scale = 600 / w
    small = cv2.resize(crop, (600, int(h * scale)), interpolation=cv2.INTER_AREA)
    sh, sw = small.shape[:2]

    mask = np.full((sh, sw), cv2.GC_PR_BGD, np.uint8)
    # Hints: frame edges are background; head, beard and coat centre are foreground.
    mask[:8, :] = mask[:, :8] = mask[:, -8:] = cv2.GC_BGD
    cv2.ellipse(mask, (int(sw * 0.50), int(sh * 0.28)), (int(sw * 0.17), int(sh * 0.17)), 0, 0, 360, cv2.GC_PR_FGD, -1)
    cv2.ellipse(mask, (int(sw * 0.50), int(sh * 0.28)), (int(sw * 0.10), int(sh * 0.12)), 0, 0, 360, cv2.GC_FGD, -1)
    cv2.ellipse(mask, (int(sw * 0.50), int(sh * 0.55)), (int(sw * 0.08), int(sh * 0.12)), 0, 0, 360, cv2.GC_FGD, -1)
    cv2.rectangle(mask, (int(sw * 0.22), int(sh * 0.72)), (int(sw * 0.78), sh - 1), cv2.GC_PR_FGD, -1)
    cv2.rectangle(mask, (int(sw * 0.38), int(sh * 0.80)), (int(sw * 0.62), sh - 1), cv2.GC_FGD, -1)
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(small, mask, None, bgd, fgd, 8, cv2.GC_INIT_WITH_MASK)
    alpha = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)

    # keep the largest component, smooth the edge, scale back up
    n, labels, stats, _ = cv2.connectedComponentsWithStats(alpha)
    if n > 1:
        biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        alpha = np.where(labels == biggest, 255, 0).astype(np.uint8)
    alpha = cv2.morphologyEx(alpha, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    # fill interior holes (e.g. background seen through the spectacle lenses)
    flood = alpha.copy()
    ff_mask = np.zeros((sh + 2, sw + 2), np.uint8)
    cv2.floodFill(flood, ff_mask, (0, 0), 255)
    alpha = alpha | cv2.bitwise_not(flood)
    alpha = cv2.resize(alpha, (w, h), interpolation=cv2.INTER_LINEAR)
    alpha = cv2.GaussianBlur(alpha, (0, 0), 4)

    rgb = cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)
    out = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    sys.stdout.reconfigure(encoding="utf-8")
    print("wrote", OUT, out.size)


if __name__ == "__main__":
    main()
