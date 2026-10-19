#!/usr/bin/env python3
"""Generates every bitmap Prisma uses: gem tiles, effect sprites, UI icons
and the app icon. Run from the repo root: python3 tools/gen_art.py

Everything is rendered at 4x and box-filtered down (premultiplied) so edges
are clean at any scale. Output goes to assets/.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join(ROOT, "assets", "tiles")
ICONS = os.path.join(ROOT, "assets", "icons")
APPICON = os.path.join(ROOT, "assets", "icon")
SS = 4

GEMS = ["ff4d6d", "ffb238", "3ee38a", "35cfff", "9c6bff", "ff6bd5"]


def hex_rgb(h):
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def downsample(rgba, factor):
    """Premultiplied box filter: rgba float array HxWx4 in [0,1]."""
    h, w, _ = rgba.shape
    pm = rgba.copy()
    pm[..., :3] *= pm[..., 3:4]
    pm = pm.reshape(h // factor, factor, w // factor, factor, 4).mean(axis=(1, 3))
    a = pm[..., 3:4]
    rgb = np.where(a > 1e-6, pm[..., :3] / np.maximum(a, 1e-6), 0)
    return np.concatenate([rgb, a], axis=-1)


def save(rgba, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    img.save(path, optimize=True)


def rounded_box(n, half, radius):
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float64) + 0.5
    px, py = xs - n / 2, ys - n / 2
    qx = np.abs(px) - half + radius
    qy = np.abs(py) - half + radius
    out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    ins = np.minimum(np.maximum(qx, qy), 0)
    return out + ins - radius, xs / n, ys / n


def gem_tile(color_hex, size=128):
    n = size * SS
    base = hex_rgb(color_hex)
    d, u, v = rounded_box(n, n / 2 - 1.5 * SS, n * 0.2)
    gy, gx = np.gradient(d)
    gl = np.sqrt(gx ** 2 + gy ** 2) + 1e-9
    nx, ny = gx / gl, gy / gl
    light = np.array([-0.62, -0.78])
    shade = nx * light[0] + ny * light[1]

    bevel = n * 0.12
    face_t = smoothstep(-bevel - 1.5 * SS, -bevel + 1.5 * SS, d)  # 0 face .. 1 bevel
    # Face: gentle vertical gradient, brighter at the top.
    face = base[None, None, :] * (1.12 - 0.26 * v[..., None])
    face = face + (1 - face) * (0.10 * (1 - v[..., None]))
    # Bevel: lit from the top-left.
    lit = np.clip(shade, 0, 1)[..., None]
    dark = np.clip(-shade, 0, 1)[..., None]
    bev = base[None, None, :] + (1 - base[None, None, :]) * lit * 0.55
    bev = bev * (1 - dark * 0.45)
    rgb = face * (1 - face_t[..., None]) + bev * face_t[..., None]

    # Facet line where the face meets the bevel.
    facet = np.exp(-((d + bevel) / (1.2 * SS)) ** 2) * np.clip(shade * 0.5 + 0.5, 0, 1)
    rgb = rgb + (1 - rgb) * facet[..., None] * 0.35

    # Glossy highlight in the upper half of the face.
    ex = (u - 0.42) / 0.30
    ey = (v - 0.30) / 0.15
    e = np.sqrt(ex ** 2 + ey ** 2)
    gloss = (1 - smoothstep(0.35, 1.0, e)) * (1 - face_t) * 0.28
    rgb = rgb + (1 - rgb) * gloss[..., None]
    # Specular sparkle.
    sd = np.sqrt((u - 0.26) ** 2 + (v - 0.24) ** 2)
    spec = (1 - smoothstep(0.015, 0.05, sd)) * 0.9
    rgb = rgb + (1 - rgb) * spec[..., None]

    # Dark rim for definition.
    rim = smoothstep(-2.5 * SS, 0, d)
    rgb = rgb * (1 - rim[..., None] * 0.45)

    alpha = np.clip(-d / SS * 0.9 + 0.5, 0, 1)
    rgba = np.concatenate([np.clip(rgb, 0, 1), alpha[..., None]], axis=-1)
    return downsample(rgba, SS)


def white_tile(size=128):
    """Shape-only tile (white) used for flashes and tinted overlays."""
    n = size * SS
    d, u, v = rounded_box(n, n / 2 - 1.5 * SS, n * 0.2)
    alpha = np.clip(-d / SS * 0.9 + 0.5, 0, 1)
    rgb = np.ones((n, n, 3))
    return downsample(np.concatenate([rgb, alpha[..., None]], axis=-1), SS)


def ghost_tile(size=128):
    n = size * SS
    d, u, v = rounded_box(n, n / 2 - 3 * SS, n * 0.2)
    w = 3.2 * SS
    ring = np.exp(-((d + w) / w) ** 2)
    fill = np.where(d < 0, 0.22, 0.0)
    alpha = np.clip(ring * 0.95 + fill, 0, 1) * np.clip(-d / SS + 0.5 + w / SS * 2, 0, 1)
    rgb = np.ones((n, n, 3))
    return downsample(np.concatenate([rgb, alpha[..., None]], axis=-1), SS)


def slot_tile(size=128):
    n = size * SS
    d, u, v = rounded_box(n, n / 2 - 3 * SS, n * 0.18)
    inside = np.clip(-d / SS + 0.5, 0, 1)
    # Inner shadow at the top edge, faint light at the bottom: reads as a recess.
    top = smoothstep(0.45, 0.0, v) * smoothstep(-n * 0.08, 0, d)
    bottom = smoothstep(0.55, 1.0, v) * smoothstep(-n * 0.05, 0, d)
    rgb = np.ones((n, n, 3)) * (1 - top[..., None])
    alpha = inside * (0.055 + top * 0.18 + bottom * 0.05)
    return downsample(np.concatenate([rgb, alpha[..., None]], axis=-1), SS)


def radial(size, fn):
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64) + 0.5
    x = (xs / size) * 2 - 1
    y = (ys / size) * 2 - 1
    a = np.clip(fn(x, y), 0, 1)
    rgb = np.ones((size, size, 3))
    return np.concatenate([rgb, a[..., None]], axis=-1)


def beam(w=256, h=64):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64) + 0.5
    y = ys / h * 2 - 1
    x = xs / w * 2 - 1
    a = np.exp(-(y / 0.32) ** 2) * (1 - smoothstep(0.75, 1.0, np.abs(x)))
    core = np.exp(-(y / 0.08) ** 2) * (1 - smoothstep(0.85, 1.0, np.abs(x)))
    a = np.clip(a * 0.7 + core, 0, 1)
    return np.concatenate([np.ones((h, w, 3)), a[..., None]], axis=-1)


# ---------------------------------------------------------------- icons ----

def icon_canvas(size=96):
    n = size * SS
    img = Image.new("L", (n, n), 0)
    return img, ImageDraw.Draw(img), n


def icon_save(img, size, name):
    small = img.resize((size, size), Image.LANCZOS)
    a = np.asarray(small).astype(np.float64) / 255.0
    rgba = np.concatenate([np.ones(a.shape + (3,)), a[..., None]], axis=-1)
    save(rgba, os.path.join(ICONS, name + ".png"))


def draw_icons(size=96):
    def k(v):
        return v * size * SS / 96.0

    # pause
    img, d, n = icon_canvas(size)
    d.rounded_rectangle([k(26), k(20), k(42), k(76)], radius=k(6), fill=255)
    d.rounded_rectangle([k(54), k(20), k(70), k(76)], radius=k(6), fill=255)
    icon_save(img, size, "pause")

    # play
    img, d, n = icon_canvas(size)
    d.polygon([(k(30), k(18)), (k(30), k(78)), (k(80), k(48))], fill=255)
    img = img.filter(ImageFilter.GaussianBlur(k(1.5)))
    img = img.point(lambda p: 255 if p > 110 else int(p * 255 / 110))
    icon_save(img, size, "play")

    # home
    img, d, n = icon_canvas(size)
    d.polygon([(k(48), k(14)), (k(86), k(48)), (k(76), k(48)), (k(76), k(82)),
               (k(58), k(82)), (k(58), k(60)), (k(38), k(60)), (k(38), k(82)),
               (k(20), k(82)), (k(20), k(48)), (k(10), k(48))], fill=255)
    icon_save(img, size, "home")

    # replay (circular arrow)
    img, d, n = icon_canvas(size)
    d.arc([k(16), k(16), k(80), k(80)], start=-60, end=230, fill=255, width=int(k(12)))
    d.polygon([(k(62), k(6)), (k(84), k(26)), (k(56), k(34))], fill=255)
    icon_save(img, size, "replay")

    # gear
    img, d, n = icon_canvas(size)
    c = n / 2
    for i in range(8):
        ang = i * math.pi / 4
        pts = []
        for da, rr in ((-0.2, k(30)), (-0.13, k(44)), (0.13, k(44)), (0.2, k(30))):
            pts.append((c + math.cos(ang + da) * rr, c + math.sin(ang + da) * rr))
        d.polygon(pts, fill=255)
    d.ellipse([c - k(32), c - k(32), c + k(32), c + k(32)], fill=255)
    d.ellipse([c - k(13), c - k(13), c + k(13), c + k(13)], fill=0)
    icon_save(img, size, "gear")

    # stats bars
    img, d, n = icon_canvas(size)
    d.rounded_rectangle([k(14), k(50), k(32), k(82)], radius=k(5), fill=255)
    d.rounded_rectangle([k(39), k(28), k(57), k(82)], radius=k(5), fill=255)
    d.rounded_rectangle([k(64), k(12), k(82), k(82)], radius=k(5), fill=255)
    icon_save(img, size, "stats")

    # sparkle (what's new)
    img, d, n = icon_canvas(size)

    def star4(cx, cy, r, t):
        pts = []
        for i in range(8):
            ang = i * math.pi / 4 - math.pi / 2
            rr = r if i % 2 == 0 else r * t
            pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
        d.polygon(pts, fill=255)
    star4(k(42), k(52), k(36), 0.3)
    star4(k(76), k(22), k(16), 0.32)
    icon_save(img, size, "sparkle")

    # crown
    img, d, n = icon_canvas(size)
    d.polygon([(k(12), k(30)), (k(30), k(52)), (k(48), k(18)), (k(66), k(52)),
               (k(84), k(30)), (k(78), k(72)), (k(18), k(72))], fill=255)
    d.rounded_rectangle([k(18), k(76), k(78), k(86)], radius=k(4), fill=255)
    for x, y in ((12, 28), (48, 15), (84, 28)):
        d.ellipse([k(x - 7), k(y - 7), k(x + 7), k(y + 7)], fill=255)
    icon_save(img, size, "crown")

    # flame
    img, d, n = icon_canvas(size)

    def flame(cx, base_y, half_w, height, fill):
        pts = []
        steps = 60
        tip = base_y - height
        body = base_y - half_w
        for i in range(steps + 1):  # right side, tip -> widest point
            s = i / steps
            y = tip + (body - tip) * s
            w = half_w * (s ** 0.75)
            pts.append((cx + w + half_w * 0.18 * math.sin(s * math.pi) * (1 - s), y))
        for i in range(steps + 1):  # bottom semicircle
            a = i / steps * math.pi
            pts.append((cx + math.cos(a) * half_w, body + math.sin(a) * half_w))
        for i in range(steps, -1, -1):  # left side back up
            s = i / steps
            y = tip + (body - tip) * s
            w = half_w * (s ** 0.75)
            pts.append((cx - w + half_w * 0.18 * math.sin(s * math.pi) * (1 - s), y))
        d.polygon(pts, fill=fill)
    flame(k(48), k(88), k(28), k(80), 255)
    flame(k(50), k(86), k(11), k(34), 0)
    icon_save(img, size, "flame")

    # calendar
    img, d, n = icon_canvas(size)
    d.rounded_rectangle([k(12), k(20), k(84), k(84)], radius=k(10), fill=255)
    d.rectangle([k(20), k(38), k(76), k(76)], fill=0)
    d.rounded_rectangle([k(26), k(10), k(36), k(30)], radius=k(4), fill=255)
    d.rounded_rectangle([k(60), k(10), k(70), k(30)], radius=k(4), fill=255)
    for gx in range(3):
        for gy in range(2):
            x0 = k(26 + gx * 17)
            y0 = k(44 + gy * 16)
            d.rounded_rectangle([x0, y0, x0 + k(11), y0 + k(10)], radius=k(2), fill=255)
    icon_save(img, size, "calendar")

    # close
    img, d, n = icon_canvas(size)
    d.line([k(24), k(24), k(72), k(72)], fill=255, width=int(k(12)))
    d.line([k(72), k(24), k(24), k(72)], fill=255, width=int(k(12)))
    for x, y in ((24, 24), (72, 72), (72, 24), (24, 72)):
        d.ellipse([k(x - 6), k(y - 6), k(x + 6), k(y + 6)], fill=255)
    icon_save(img, size, "close")

    # trophy-ish medal (stats/best)
    img, d, n = icon_canvas(size)
    d.polygon([(k(30), k(8)), (k(44), k(8)), (k(52), k(36)), (k(40), k(40))], fill=255)
    d.polygon([(k(66), k(8)), (k(52), k(8)), (k(44), k(36)), (k(56), k(40))], fill=255)
    d.ellipse([k(22), k(34), k(74), k(86)], fill=255)
    d.ellipse([k(34), k(46), k(62), k(74)], fill=0)
    icon_save(img, size, "medal")

    # sound (speaker)
    img, d, n = icon_canvas(size)
    d.polygon([(k(10), k(36)), (k(28), k(36)), (k(50), k(16)), (k(50), k(80)), (k(28), k(60)), (k(10), k(60))], fill=255)
    d.arc([k(44), k(28), k(72), k(68)], start=-55, end=55, fill=255, width=int(k(8)))
    d.arc([k(48), k(14), k(90), k(82)], start=-55, end=55, fill=255, width=int(k(8)))
    icon_save(img, size, "sound")

    # music note
    img, d, n = icon_canvas(size)
    d.ellipse([k(14), k(58), k(42), k(82)], fill=255)
    d.ellipse([k(54), k(50), k(82), k(74)], fill=255)
    d.rectangle([k(34), k(18), k(42), k(70)], fill=255)
    d.rectangle([k(74), k(10), k(82), k(62)], fill=255)
    d.polygon([(k(34), k(18)), (k(82), k(8)), (k(82), k(22)), (k(34), k(32))], fill=255)
    icon_save(img, size, "music")

    # vibrate (phone with waves)
    img, d, n = icon_canvas(size)
    d.rounded_rectangle([k(32), k(12), k(64), k(84)], radius=k(8), fill=255)
    d.rounded_rectangle([k(38), k(20), k(58), k(70)], radius=k(3), fill=0)
    for x0 in (14, 76):
        d.line([k(x0 + 3), k(30), k(x0 + 3), k(66)], fill=255, width=int(k(6)))
    icon_save(img, size, "vibrate")


# ------------------------------------------------------------ app icon ----

def app_icon():
    os.makedirs(APPICON, exist_ok=True)
    size = 432
    n = size * SS
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float64) + 0.5
    u, v = xs / n, ys / n
    # Background: deep indigo with an aurora glow.
    top = hex_rgb("1a1146")
    bot = hex_rgb("07061a")
    bg = top[None, None, :] * (1 - v[..., None]) + bot[None, None, :] * v[..., None]
    glow = np.exp(-(((u - 0.5) / 0.45) ** 2 + ((v - 0.42) / 0.38) ** 2))
    bg = bg + np.array([0.35, 0.22, 0.75])[None, None, :] * glow[..., None] * 0.55
    bg_rgba = np.concatenate([np.clip(bg, 0, 1), np.ones((n, n, 1))], axis=-1)
    bg_small = downsample(bg_rgba, SS)
    save(bg_small, os.path.join(APPICON, "icon_bg_432.png"))

    # Foreground: a 2x2 cluster of gems + one floating gem, inside the
    # adaptive-icon safe zone (centre 66%).
    fg = np.zeros((size, size, 4))
    tile = 112
    layout = [(0, 0, 0), (1, 0, 3), (0, 1, 4), (1, 1, 5)]
    ox = size // 2 - tile
    oy = size // 2 - tile + 18
    for gx, gy, ci in layout:
        t = gem_tile(GEMS[ci], tile)
        _blit(fg, t, ox + gx * tile, oy + gy * tile)
    t = gem_tile(GEMS[1], 72)
    _blit(fg, t, ox + 2 * tile - 24, oy - 72 + 6)
    # soft glow behind
    save(fg, os.path.join(APPICON, "icon_fg_432.png"))

    # Legacy square icon = bg + fg composited with rounded corners.
    comp = _over(bg_small.copy(), fg)
    for out, name in ((192, "icon_192.png"), (512, "icon_512.png")):
        img = Image.fromarray((np.clip(comp, 0, 1) * 255).astype(np.uint8), "RGBA").resize((out, out), Image.LANCZOS)
        img.save(os.path.join(APPICON, name), optimize=True)


def _blit(dst, src, x, y):
    h, w, _ = src.shape
    region = dst[y:y + h, x:x + w]
    a = src[..., 3:4]
    out_a = a + region[..., 3:4] * (1 - a)
    out_rgb = (src[..., :3] * a + region[..., :3] * region[..., 3:4] * (1 - a)) / np.maximum(out_a, 1e-6)
    dst[y:y + h, x:x + w] = np.concatenate([out_rgb, out_a], axis=-1)


def _over(dst, src):
    _blit(dst, src, 0, 0)
    return dst


def main():
    os.makedirs(TILES, exist_ok=True)
    for i, c in enumerate(GEMS):
        save(gem_tile(c), os.path.join(TILES, "gem_%d.png" % (i + 1)))
    save(white_tile(), os.path.join(TILES, "white.png"))
    save(ghost_tile(), os.path.join(TILES, "ghost.png"))
    save(slot_tile(), os.path.join(TILES, "slot.png"))
    save(radial(128, lambda x, y: np.exp(-(x * x + y * y) / (2 * 0.33 ** 2)) * (1 - smoothstep(0.85, 1, np.sqrt(x * x + y * y)))),
         os.path.join(TILES, "glow.png"))
    save(radial(128, lambda x, y: np.clip(np.exp(-np.abs(x) / 0.035) * np.exp(-(y / 0.6) ** 2)
                                          + np.exp(-np.abs(y) / 0.035) * np.exp(-(x / 0.6) ** 2)
                                          + np.exp(-(x * x + y * y) / 0.012), 0, 1)),
         os.path.join(TILES, "spark.png"))
    save(radial(256, lambda x, y: np.exp(-((np.sqrt(x * x + y * y) - 0.82) / 0.07) ** 2)),
         os.path.join(TILES, "ring.png"))
    save(beam(), os.path.join(TILES, "beam.png"))
    draw_icons()
    app_icon()
    print("art generated")


if __name__ == "__main__":
    main()
