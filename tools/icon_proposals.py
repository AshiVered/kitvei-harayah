"""Render several distinct icon proposals side by side for choosing.

Usage: python tools/icon_proposals.py <out_dir>
Needs tools/source/portrait_cutout.png (run tools/make_portrait.py first).
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "assets", "fonts", "FrankRuhlLibre.ttf")
CUTOUT = os.path.join(ROOT, "tools", "source", "portrait_cutout.png")
S = 1536
NAVY_TOP, NAVY_BOTTOM = (36, 55, 96), (15, 23, 44)
GOLD, GOLD_LIGHT, GOLD_DEEP = (224, 184, 102), (247, 222, 160), (164, 122, 48)
INK = (22, 28, 46)
CREAM_IN, CREAM_OUT = (251, 242, 218), (224, 198, 142)


def heb(s):  # visual order (no bidi in this PIL build)
    return s[::-1]


def font(size, weight=900):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([weight])
    return f


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgrad(size, stops):
    """stops: [(t, color), ...] top->bottom"""
    w, h = size
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        for k in range(len(stops) - 1):
            t0, c0 = stops[k]
            t1, c1 = stops[k + 1]
            if t0 <= t <= t1:
                c = lerp(c0, c1, (t - t0) / max(1e-6, t1 - t0))
                break
        else:
            c = stops[-1][1]
        d.line([(0, y), (w, y)], fill=c + (255,))
    return img


def rounded(img, frame=True):
    if frame:
        d = ImageDraw.Draw(img)
        m = int(S * 0.045)
        d.rounded_rectangle([m, m, S - m, S - m], radius=int(S * 0.15), outline=GOLD + (215,), width=int(S * 0.008))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.2), fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def inner_clip(layer):
    """Keep a layer inside the gold frame."""
    clip = Image.new("L", (S, S), 0)
    m = int(S * 0.055)
    ImageDraw.Draw(clip).rounded_rectangle([m, m, S - m, S - m], radius=int(S * 0.14), fill=255)
    layer.putalpha(ImageChops.multiply(layer.split()[3], clip))
    return layer


def gold_text(img, text, fnt, center):
    layer = Image.new("L", (S, S), 0)
    ImageDraw.Draw(layer).text(center, text, font=fnt, fill=255, anchor="mm")
    sh = Image.new("RGBA", (S, S), (3, 6, 14, 0))
    sh.putalpha(layer.filter(ImageFilter.GaussianBlur(S * 0.01)).point(lambda a: int(a * 0.75)))
    img.alpha_composite(sh, (0, int(S * 0.007)))
    box = layer.getbbox()
    grad = Image.new("RGBA", (S, S))
    if box:
        grad.paste(vgrad((S, box[3] - box[1]), [(0, GOLD_LIGHT), (1, GOLD_DEEP)]), (0, box[1]))
    grad.putalpha(layer)
    img.alpha_composite(grad)


def rays(cx, cy, n, inner, outer, alpha=(200, 110), width=(2.6, 1.6), start=math.pi, span=math.pi):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(n):
        ang = start + span * (i + 0.5) / n
        long = i % 2 == 0
        o = outer if long else outer * 0.8
        half = math.radians(width[0] if long else width[1])
        pts = [(cx + inner * math.cos(ang - half), cy + inner * math.sin(ang - half)),
               (cx + o * math.cos(ang), cy + o * math.sin(ang)),
               (cx + inner * math.cos(ang + half), cy + inner * math.sin(ang + half))]
        d.polygon(pts, fill=GOLD + (alpha[0] if long else alpha[1],))
    return layer


def portrait_disc(diameter, style="engraved"):
    """Portrait clipped to a circle. engraved = ink on cream; golden = warm gold tones."""
    cut = Image.open(CUTOUT).convert("RGBA")
    scale = diameter * 1.04 / cut.width
    cut = cut.resize((max(1, int(cut.width * scale)), max(1, int(cut.height * scale))), Image.LANCZOS)
    gray = ImageOps.autocontrast(cut.convert("L"), cutoff=1)
    if style == "golden":
        tinted = ImageOps.colorize(gray, black=(70, 42, 12), white=(255, 236, 180), mid=(196, 146, 66))
        bg_in, bg_out = (255, 226, 150), (222, 166, 70)
    else:
        tinted = ImageOps.colorize(gray, black=INK, white=(250, 238, 206), mid=(120, 98, 66))
        bg_in, bg_out = CREAM_IN, CREAM_OUT
    tinted.putalpha(cut.split()[3])
    disc = Image.new("RGBA", (diameter, diameter))
    dd = ImageDraw.Draw(disc)
    for k in range(diameter // 2, 0, -2):
        t = k / (diameter / 2)
        dd.ellipse([diameter / 2 - k, diameter / 2 - k, diameter / 2 + k, diameter / 2 + k],
                   fill=lerp(bg_in, bg_out, t ** 1.6) + (255,))
    disc.alpha_composite(tinted, ((diameter - tinted.width) // 2, int(diameter * 0.06)))
    mask = Image.new("L", (diameter, diameter), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, diameter - 1, diameter - 1], fill=255)
    out = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
    out.paste(disc, (0, 0), mask)
    return out


def medallion(img, cx, cy, r, style="engraved", ring=True):
    if ring:
        sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(sh).ellipse([cx - r, cy - r + S * 0.01, cx + r, cy + r + S * 0.01], fill=(3, 6, 14, 140))
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(S * 0.015)))
        d = ImageDraw.Draw(img)
        r1, r2 = r + int(S * 0.02), r + int(S * 0.011)
        d.ellipse([cx - r1, cy - r1, cx + r1, cy + r1], fill=GOLD_DEEP + (255,))
        d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=GOLD_LIGHT + (255,))
    img.alpha_composite(portrait_disc(2 * r, style), (cx - r, cy - r))


def hills(img, horizon, color_far, color_near):
    d = ImageDraw.Draw(img)
    far = [(0, horizon)]
    for x in range(0, S + 1, 8):
        far.append((x, horizon - S * 0.035 * (1 + math.sin(x / S * 5.2 + 0.6)) * 0.6))
    far += [(S, S), (0, S)]
    d.polygon(far, fill=color_far + (255,))
    near = [(0, horizon + S * 0.04)]
    for x in range(0, S + 1, 8):
        near.append((x, horizon + S * 0.03 - S * 0.03 * math.sin(x / S * 3.3 + 2.1)))
    near += [(S, S), (0, S)]
    d.polygon(near, fill=color_near + (255,))


# ---------------------------------------------------------------- proposals

def p_horizon():
    """Sunrise over hills; a small portrait medallion on the horizon beside the sun."""
    horizon = int(S * 0.64)
    img = vgrad((S, S), [(0, (30, 46, 88)), (0.45, (58, 62, 104)), (0.64, (196, 140, 86)), (1, (20, 26, 48))])
    sx = int(S * 0.40)
    img.alpha_composite(inner_clip(rays(sx, horizon, 17, S * 0.20, S * 0.56, alpha=(170, 90))))
    d = ImageDraw.Draw(img)
    r = int(S * 0.19)
    d.ellipse([sx - r, horizon - r, sx + r, horizon + r], fill=(250, 210, 120, 255))
    hills(img, horizon, (44, 52, 84), (24, 31, 56))
    medallion(img, int(S * 0.72), horizon - int(S * 0.075), int(S * 0.105))
    gold_text(img, heb("ראי״ה"), font(int(S * 0.15)), (S // 2, int(S * 0.84)))
    return rounded(img)


def p_face_sun():
    """The portrait is the rising sun: a golden disc on the horizon, rays from it."""
    horizon = int(S * 0.68)
    img = vgrad((S, S), [(0, (30, 46, 88)), (0.5, (54, 60, 102)), (0.68, (180, 128, 80)), (1, (18, 24, 46))])
    cx, r = S // 2, int(S * 0.255)
    cy = horizon - int(S * 0.19)
    img.alpha_composite(inner_clip(rays(cx, cy, 19, r * 1.05, S * 0.62, alpha=(170, 95), start=math.pi * 1.0, span=math.pi)))
    medallion(img, cx, cy, r, style="golden")
    hills(img, horizon, (40, 48, 80), (22, 29, 54))
    gold_text(img, heb("ראי״ה"), font(int(S * 0.15)), (cx, int(S * 0.86)))
    return rounded(img)


def p_figure_rising():
    """Proposal B without the sun: Rav Kook's figure rises above the horizon at dawn, no disc, no rays."""
    horizon = int(S * 0.70)
    img = vgrad((S, S), [(0, (30, 46, 88)), (0.48, (56, 62, 104)), (0.70, (190, 136, 84)), (1, (18, 24, 46))])
    cut = Image.open(CUTOUT).convert("RGBA")
    w = int(S * 0.70)
    cut = cut.resize((w, w), Image.LANCZOS)
    gray = ImageOps.autocontrast(cut.convert("L"), cutoff=1)
    fig = ImageOps.colorize(gray, black=(18, 16, 22), white=(255, 238, 196), mid=(150, 112, 66))
    alpha = cut.split()[3]
    fig.putalpha(alpha)
    x, y = (S - w) // 2, int(S * 0.12)
    # soft warm rim so the dark hat separates from the night sky
    rim = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow = Image.new("RGBA", (w, w), (246, 206, 130, 0))
    glow.putalpha(alpha.filter(ImageFilter.GaussianBlur(S * 0.018)).point(lambda a: int(a * 0.55)))
    rim.alpha_composite(glow, (x, y))
    img.alpha_composite(rim)
    img.alpha_composite(fig, (x, y))
    hills(img, horizon, (40, 48, 80), (22, 29, 54))
    gold_text(img, heb("ראי״ה"), font(int(S * 0.15)), (S // 2, int(S * 0.86)))
    return rounded(img)


def p_medallion_rising():
    """Proposal B without the sun, alternative: the portrait medallion (cream, not gold) on the horizon, no rays."""
    horizon = int(S * 0.68)
    img = vgrad((S, S), [(0, (30, 46, 88)), (0.5, (54, 60, 102)), (0.68, (180, 128, 80)), (1, (18, 24, 46))])
    cx, r = S // 2, int(S * 0.255)
    medallion(img, cx, horizon - int(S * 0.19), r)
    hills(img, horizon, (40, 48, 80), (22, 29, 54))
    gold_text(img, heb("ראי״ה"), font(int(S * 0.15)), (cx, int(S * 0.86)))
    return rounded(img)


def p_monogram():
    """Name only, with rays of light (אורות)."""
    img = vgrad((S, S), [(0, NAVY_TOP), (1, NAVY_BOTTOM)])
    cx, cy = S // 2, int(S * 0.60)
    img.alpha_composite(inner_clip(rays(cx, cy, 15, S * 0.12, S * 0.46, alpha=(185, 105))))
    gold_text(img, heb("ראי״ה"), font(int(S * 0.30)), (cx, cy))
    d = ImageDraw.Draw(img)
    y, w = int(S * 0.80), int(S * 0.15)
    d.line([(cx - w, y), (cx - S * 0.03, y)], fill=GOLD + (210,), width=int(S * 0.006))
    d.line([(cx + S * 0.03, y), (cx + w, y)], fill=GOLD + (210,), width=int(S * 0.006))
    q = S * 0.016
    d.polygon([(cx, y - q), (cx + q, y), (cx, y + q), (cx - q, y)], fill=GOLD + (255,))
    return rounded(img)


def p_seal():
    """A rabbinic seal: full name around a ring, engraved portrait in the centre."""
    img = vgrad((S, S), [(0, NAVY_TOP), (1, NAVY_BOTTOM)])
    d = ImageDraw.Draw(img)
    cx = cy = S // 2
    R = S * 0.42
    for rr, w, a in [(R, 0.012, 255), (R * 0.79, 0.007, 230)]:
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=GOLD + (a,), width=int(S * w))
    text = "הרב אברהם יצחק הכהן קוק"
    f = font(int(S * 0.064), 700)
    ring_r = R * 0.895
    span = math.radians(250)
    start = -math.pi / 2 + span / 2
    step = span / (len(text) - 1)
    for k, ch in enumerate(text):
        if ch == " ":
            continue
        ang = start - k * step
        x, y = cx + ring_r * math.cos(ang), cy + ring_r * math.sin(ang)
        tile = Image.new("RGBA", (int(S * 0.1), int(S * 0.1)), (0, 0, 0, 0))
        ImageDraw.Draw(tile).text((tile.width / 2, tile.height / 2), ch, font=f, fill=GOLD_LIGHT + (255,), anchor="mm")
        rot = tile.rotate(-math.degrees(ang) - 90, resample=Image.BICUBIC)
        img.alpha_composite(rot, (int(x - rot.width / 2), int(y - rot.height / 2)))
    for a in (math.pi / 2 - math.radians(40), math.pi / 2, math.pi / 2 + math.radians(40)):
        x, y = cx + ring_r * math.cos(a), cy + ring_r * math.sin(a)
        q = S * 0.013
        d.polygon([(x, y - q), (x + q, y), (x, y + q), (x - q, y)], fill=GOLD + (255,))
    medallion(img, cx, cy, int(R * 0.74), ring=False)
    return rounded(img, frame=False)


def p_jerusalem():
    """Sunrise behind the walls of Jerusalem and the Tower of David, with the name."""
    horizon = int(S * 0.62)
    img = vgrad((S, S), [(0, (30, 46, 88)), (0.42, (62, 64, 104)), (0.62, (206, 150, 90)), (1, (18, 24, 46))])
    sx = int(S * 0.36)
    img.alpha_composite(inner_clip(rays(sx, horizon, 17, S * 0.18, S * 0.55, alpha=(165, 90))))
    d = ImageDraw.Draw(img)
    r = int(S * 0.17)
    d.ellipse([sx - r, horizon - r, sx + r, horizon + r], fill=(250, 210, 122, 255))
    wall = (26, 33, 58)
    top = horizon - int(S * 0.04)
    d.rectangle([0, top, S, S], fill=wall + (255,))
    mw = int(S * 0.028)
    for x in range(0, S, mw * 2):  # crenellations
        d.rectangle([x, top - int(S * 0.025), x + mw, top], fill=wall + (255,))
    # Tower of David (minaret) and a domed tower
    tx = int(S * 0.70)
    d.rectangle([tx - S * 0.045, top - S * 0.22, tx + S * 0.045, top], fill=wall + (255,))
    d.rectangle([tx - S * 0.06, top - S * 0.24, tx + S * 0.06, top - S * 0.215], fill=wall + (255,))
    d.rectangle([tx - S * 0.03, top - S * 0.30, tx + S * 0.03, top - S * 0.24], fill=wall + (255,))
    d.polygon([(tx - S * 0.03, top - S * 0.30), (tx, top - S * 0.36), (tx + S * 0.03, top - S * 0.30)], fill=wall + (255,))
    dx = int(S * 0.20)
    d.rectangle([dx - S * 0.06, top - S * 0.08, dx + S * 0.06, top], fill=wall + (255,))
    d.pieslice([dx - S * 0.06, top - S * 0.14, dx + S * 0.06, top - S * 0.02], 180, 360, fill=wall + (255,))
    # gate arch
    gx = int(S * 0.47)
    d.pieslice([gx - S * 0.05, top + S * 0.03, gx + S * 0.05, top + S * 0.13], 180, 360, fill=(14, 19, 36, 255))
    d.rectangle([gx - S * 0.05, top + S * 0.08, gx + S * 0.05, top + S * 0.16], fill=(14, 19, 36, 255))
    gold_text(img, heb("ראי״ה"), font(int(S * 0.15)), (S // 2, int(S * 0.86)))
    return rounded(img)


def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    which = sys.argv[2] if len(sys.argv) > 2 else "all"
    if which == "b-nosun":
        props = [("ב׳ בלי שמש – דמות", p_figure_rising()), ("ב׳ בלי שמש – מדליון", p_medallion_rising())]
    else:
        props = [("א – אופק", p_horizon()), ("ב – הפנים כשמש", p_face_sun()), ("ג – מונוגרמה", p_monogram()),
                 ("ד – חותמת", p_seal()), ("ה – ירושלים", p_jerusalem())]
    cell, pad = 420, 24
    sheet = Image.new("RGBA", (pad + len(props) * (cell + pad), cell + 230), (238, 235, 228, 255))
    d = ImageDraw.Draw(sheet)
    lab = font(30, 700)
    for i, (name, im) in enumerate(props):
        x = pad + i * (cell + pad)
        sheet.alpha_composite(im.resize((cell, cell), Image.LANCZOS), (x, pad))
        for j, s in enumerate([64, 32, 16]):
            t = im.resize((s, s), Image.LANCZOS)
            sheet.alpha_composite(t, (x + 40 + j * 120 + (64 - s) // 2, cell + pad + 30 + (64 - s) // 2))
        d.text((x + cell // 2, cell + pad + 150), heb(name), font=lab, fill=(40, 40, 40), anchor="mm")
        im.resize((1024, 1024), Image.LANCZOS).save(os.path.join(out_dir, f"proposal_{i + 1}.png"))
    sheet.save(os.path.join(out_dir, "icon_proposals.png"))
    print("ok")


if __name__ == "__main__":
    main()
