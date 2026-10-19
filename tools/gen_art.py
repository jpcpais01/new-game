#!/usr/bin/env python3
"""Generates every bitmap in assets/sprites and assets/icon.

Neon look: each shape is a signed-distance field turned into a white-hot tube,
a coloured halo and a faint inner fill. Effect textures are white so the game
can tint them. Rerun after editing: python3 tools/gen_art.py
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SPR = os.path.join(ROOT, "assets", "sprites")
ICO = os.path.join(ROOT, "assets", "icon")


def grid(size):
    y, x = np.mgrid[0:size, 0:size].astype(np.float64)
    c = (size - 1) / 2.0
    return x - c, y - c


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / max(l2, 1e-9), 0.0, 1.0)
    qx, qy = ax + t * dx - px, ay + t * dy - py
    return np.sqrt(qx * qx + qy * qy)


def poly_inside(px, py, pts):
    inside = np.zeros(px.shape, dtype=bool)
    n = len(pts)
    for i in range(n):
        ax, ay = pts[i]
        bx, by = pts[(i + 1) % n]
        cond = (ay > py) != (by > py)
        xint = (bx - ax) * (py - ay) / np.where(by - ay == 0, 1e-9, by - ay) + ax
        inside ^= cond & (px < xint)
    return inside


def regular(n, r=1.0, rot=0.0):
    return [(r * math.cos(rot + 2 * math.pi * i / n), r * math.sin(rot + 2 * math.pi * i / n)) for i in range(n)]


def star(n, r1, r2, rot=0.0):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = rot + math.pi * i / n
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def neon(shapes, color, size=128, radius=40.0, line=3.4, glow=9.0, fill=0.22, core_white=0.6,
         lines=(), glow_amt=0.9):
    """shapes: closed polygons in unit coords; lines: open polylines in unit coords."""
    px, py = grid(size)
    d = np.full(px.shape, 1e9)
    inside = np.zeros(px.shape, dtype=bool)
    for pts in shapes:
        sp = [(x * radius, y * radius) for x, y in pts]
        n = len(sp)
        for i in range(n):
            d = np.minimum(d, seg_dist(px, py, *sp[i], *sp[(i + 1) % n]))
        inside ^= poly_inside(px, py, sp)
    for pts in lines:
        sp = [(x * radius, y * radius) for x, y in pts]
        for i in range(len(sp) - 1):
            d = np.minimum(d, seg_dist(px, py, *sp[i], *sp[i + 1]))
    core = np.clip(1.0 - (d - line * 0.5) / 1.3, 0.0, 1.0)
    halo = np.exp(-d / glow) * glow_amt
    # Fade the halo out before the texture edge so it never clips.
    rr = np.sqrt(px * px + py * py) / (size * 0.5)
    halo *= np.clip((1.0 - rr) / 0.18, 0.0, 1.0)
    fil = inside * fill * (0.55 + 0.45 * np.clip(np.sqrt(px * px + py * py) / radius, 0, 1))
    col = np.array(color, dtype=np.float64)
    white = np.ones(3)
    tube_rgb = col * (1 - core_white) + white * core_white
    a_core = core
    a_halo = halo * (1 - core)
    a_fill = fil * (1 - core) * (1 - np.clip(halo, 0, 1) * 0.5)
    alpha = np.clip(a_core + a_halo + a_fill, 0, 1)
    rgb = (tube_rgb[None, None, :] * a_core[..., None]
           + col[None, None, :] * a_halo[..., None]
           + (col * 0.55)[None, None, :] * a_fill[..., None])
    rgb = rgb / np.maximum(alpha, 1e-6)[..., None]
    return to_img(rgb, alpha)


def to_img(rgb, alpha):
    out = np.zeros(alpha.shape + (4,), dtype=np.uint8)
    out[..., :3] = np.clip(rgb * 255 + 0.5, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def white_img(alpha):
    rgb = np.ones(alpha.shape + (3,))
    return to_img(rgb, np.clip(alpha, 0, 1))


def save(img, name, folder=SPR):
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, name + ".png"))


# --- shapes (unit radius, pointing +x) ---------------------------------------
SHIP = [(1.0, 0.0), (-0.72, 0.74), (-0.38, 0.0), (-0.72, -0.74)]
DIAMOND = [(1.0, 0.0), (0.0, 0.74), (-1.0, 0.0), (0.0, -0.74)]
DART = [(1.0, 0.0), (-0.75, 0.62), (-0.42, 0.0), (-0.75, -0.62)]
BOWTIE = [(-0.8, -0.8), (0.0, -0.22), (0.8, -0.8), (0.8, 0.8), (0.0, 0.22), (-0.8, 0.8)]
BLADE = [(1.0, 0.0), (0.0, 0.26), (-1.0, 0.0), (0.0, -0.26)]
GEM = [(0.0, -1.0), (0.66, 0.0), (0.0, 1.0), (-0.66, 0.0)]

ENEMIES = {
    # name: (shapes, colour, extra kwargs)
    "drifter": ([DIAMOND], (1.0, 0.3, 0.65), {}),
    "dart": ([DART], (1.0, 0.84, 0.22), {}),
    "splitter": ([regular(5, 1.0, -math.pi / 2), regular(5, 0.45, math.pi / 2)], (0.35, 1.0, 0.45), {}),
    "mite": ([regular(3, 1.0)], (0.72, 1.0, 0.3), {"line": 3.0}),
    "weaver": ([BOWTIE], (0.6, 0.48, 1.0), {}),
    "brute": ([regular(6, 1.0), regular(6, 0.55)], (1.0, 0.55, 0.18), {"line": 4.2}),
    "spitter": ([star(4, 1.0, 0.42)], (0.88, 0.35, 1.0), {}),
    "bomber": ([star(9, 1.0, 0.7)], (1.0, 0.24, 0.24), {}),
    "warden": ([regular(8, 1.0, math.pi / 8), regular(4, 0.5, math.pi / 4), regular(8, 0.78, math.pi / 8)],
               (1.0, 0.8, 0.35), {"line": 4.4, "glow": 12.0}),
    "eclipse": ([regular(40, 1.0), regular(40, 0.62), star(12, 0.5, 0.3)], (1.0, 0.3, 0.88),
                {"line": 4.6, "glow": 13.0, "fill": 0.42}),
}


def enemy_sprites():
    for name, (shapes, col, kw) in ENEMIES.items():
        save(neon(shapes, col, **kw), "e_" + name)
        # White silhouette used for the hit flash.
        px, py = grid(128)
        inside = np.zeros(px.shape, dtype=bool)
        d = np.full(px.shape, 1e9)
        for pts in shapes:
            sp = [(x * 40.0, y * 40.0) for x, y in pts]
            inside ^= poly_inside(px, py, sp)
            for i in range(len(sp)):
                d = np.minimum(d, seg_dist(px, py, *sp[i], *sp[(i + 1) % len(sp)]))
        a = np.maximum(inside * 0.85, np.clip(1.0 - (d - 2.5) / 1.5, 0, 1)) + np.exp(-d / 6.0) * 0.5
        save(white_img(a), "w_" + name)


def fx_sprites():
    # Soft dot.
    px, py = grid(32)
    r = np.sqrt(px * px + py * py) / 16.0
    save(white_img(np.exp(-r * r * 5.0) * np.clip((1 - r) / 0.2, 0, 1)), "spark")
    # Big soft glow.
    px, py = grid(128)
    r = np.sqrt(px * px + py * py) / 64.0
    save(white_img(np.clip(1 - r, 0, 1) ** 2.2), "glow")
    # Thin ring with halo (radius 0.86 of half size).
    px, py = grid(256)
    r = np.sqrt(px * px + py * py)
    d = np.abs(r - 110.0)
    a = np.clip(1 - (d - 1.6) / 1.4, 0, 1) + np.exp(-d / 7.0) * 0.55
    a *= np.clip((128 - r) / 8.0, 0, 1)
    save(white_img(a), "ring")
    # Soft filled disc (shockwave body).
    a = np.clip((r - 40) / 72.0, 0, 1) ** 2 * np.clip((114 - r) / 6.0, 0, 1)
    save(white_img(a * 0.8), "disc")
    # Bolt: capsule pointing +x.
    w, h = 64, 24
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    d = seg_dist(x, y, 14, h / 2 - 0.5, w - 14, h / 2 - 0.5)
    a = np.clip(1 - (d - 3.0) / 1.3, 0, 1) + np.exp(-d / 3.5) * 0.7
    save(white_img(a), "bolt")
    # Streak: tapered line for sparks.
    w, h = 64, 12
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    t = x / (w - 1)
    width = 0.6 + 2.4 * t
    d = np.abs(y - (h - 1) / 2) / width
    a = np.exp(-d * d * 1.6) * np.clip(t * 1.4, 0, 1) * np.clip((1 - t) / 0.08, 0, 1)
    save(white_img(a), "streak")
    # Beam profile (across the beam = y), stretched along x at runtime.
    w, h = 8, 64
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    d = np.abs(y - (h - 1) / 2) / (h / 2)
    a = np.exp(-d * d * 9.0) * 0.8 + np.clip(1 - d / 0.16, 0, 1)
    save(white_img(a), "beam")
    # Orb (enemy bullet): hot core + halo.
    px, py = grid(48)
    r = np.sqrt(px * px + py * py)
    a = np.clip(1 - (r - 6) / 1.5, 0, 1) + np.exp(-np.maximum(r - 6, 0) / 4.0) * 0.8
    a *= np.clip((24 - r) / 4, 0, 1)
    core = np.clip(1 - (r - 4) / 2, 0, 1)
    rgb = np.ones((48, 48, 3))
    img = to_img(rgb, np.clip(a, 0, 1))
    save(img, "orb")
    save(white_img(core), "orb_core")
    # Hexagon cell used for the warp-in portal.
    save(neon([regular(6, 1.0, math.pi / 6)], (1, 1, 1), size=128, radius=52, line=2.4, glow=7, fill=0.0,
              core_white=1.0), "portal")


def player_sprites():
    save(neon([SHIP], (0.35, 0.95, 1.0), radius=40, line=4.0, glow=10, fill=0.35, core_white=0.75), "ship")
    save(neon([BLADE], (0.55, 1.0, 1.0), size=96, radius=40, line=3.0, glow=6, fill=0.5, core_white=0.8), "blade")
    save(neon([DART], (1.0, 0.75, 0.35), size=64, radius=20, line=2.6, glow=5, fill=0.5, core_white=0.8),
         "missile")
    # Gem: white-hot so it can be tinted per tier.
    save(neon([GEM], (1, 1, 1), size=48, radius=15, line=2.4, glow=4.5, fill=0.55, core_white=1.0), "gem")
    # Pickups.
    heart = []
    for i in range(48):
        t = 2 * math.pi * i / 48
        hx = 16 * math.sin(t) ** 3
        hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        heart.append((hx / 17.0, hy / 17.0))
    save(neon([heart], (1.0, 0.35, 0.45), size=96, radius=34, line=3.6, glow=7, fill=0.5), "p_heart")
    mag = [(-0.8, -0.9), (-0.8, 0.15), (-0.55, 0.62), (0.0, 0.85), (0.55, 0.62), (0.8, 0.15), (0.8, -0.9)]
    save(neon([], (0.4, 0.8, 1.0), size=96, radius=32, line=4.5, glow=7, lines=[mag]), "p_magnet")
    save(neon([star(5, 1.0, 0.45, -math.pi / 2)], (1.0, 0.9, 0.4), size=96, radius=36, line=3.6, glow=8, fill=0.5),
         "p_core")


ICONS = {
    # id: (closed shapes, open lines, colour)
    "pulse": ([[(0.1, -0.25), (0.75, 0.0), (0.1, 0.25)]], [[(-0.85, -0.45), (-0.1, -0.45)], [(-0.85, 0.0), (0.05, 0.0)],
                                                          [(-0.85, 0.45), (-0.1, 0.45)]], (0.35, 0.95, 1.0)),
    "orbit": ([regular(32, 0.32)], [[(math.cos(a) * 0.82, math.sin(a) * 0.82) for a in np.linspace(0.3, 2.6, 12)],
                                    [(math.cos(a) * 0.82, math.sin(a) * 0.82) for a in np.linspace(3.4, 5.7, 12)]],
              (0.55, 1.0, 1.0)),
    "arc": ([], [[(-0.2, -0.95), (-0.55, 0.05), (0.05, 0.0), (-0.3, 0.95)], [(0.25, -0.9), (0.62, -0.3), (0.4, -0.15),
                                                                          (0.75, 0.4)]], (0.75, 0.7, 1.0)),
    "nova": ([regular(32, 0.25), regular(40, 0.58), regular(48, 0.9)], [], (1.0, 0.55, 0.9)),
    "seeker": ([[(0.9, -0.5), (0.25, -0.55), (0.6, 0.0)]],
               [[(-0.85, 0.75), (-0.4, 0.2), (0.0, -0.1), (0.62, -0.5)]], (1.0, 0.72, 0.3)),
    "lance": ([[(0.95, 0.0), (0.55, 0.22), (-0.9, 0.12), (-0.9, -0.12), (0.55, -0.22)]], [], (1.0, 0.95, 0.6)),
    "vitality": ([[(-0.25, -0.85), (0.25, -0.85), (0.25, -0.25), (0.85, -0.25), (0.85, 0.25), (0.25, 0.25),
                   (0.25, 0.85), (-0.25, 0.85), (-0.25, 0.25), (-0.85, 0.25), (-0.85, -0.25), (-0.25, -0.25)]], [],
                 (1.0, 0.35, 0.45)),
    "thrusters": ([], [[(-0.7, -0.75), (0.05, 0.0), (-0.7, 0.75)], [(0.0, -0.75), (0.75, 0.0), (0.0, 0.75)]],
                  (0.4, 1.0, 0.7)),
    "magnet": ([], [[(-0.7, -0.85), (-0.7, 0.1), (-0.45, 0.6), (0.0, 0.8), (0.45, 0.6), (0.7, 0.1), (0.7, -0.85)],
                    [(-0.95, -0.85), (-0.45, -0.85)], [(0.45, -0.85), (0.95, -0.85)]], (0.4, 0.8, 1.0)),
    "overclock": ([regular(36, 0.85)], [[(0.0, -0.55), (0.0, 0.0), (0.42, 0.28)]], (1.0, 0.85, 0.3)),
    "amplifier": ([[(0.0, -0.9), (0.75, -0.1), (0.3, -0.1), (0.3, 0.85), (-0.3, 0.85), (-0.3, -0.1), (-0.75, -0.1)]],
                  [], (1.0, 0.45, 0.35)),
    "lens": ([regular(32, 0.4)], [[(0.6, 0.0), (0.95, 0.0)], [(-0.6, 0.0), (-0.95, 0.0)], [(0.0, 0.6), (0.0, 0.95)],
                                  [(0.0, -0.6), (0.0, -0.95)]], (0.6, 0.9, 1.0)),
    "plating": ([[(0.0, -0.9), (0.75, -0.6), (0.65, 0.25), (0.0, 0.9), (-0.65, 0.25), (-0.75, -0.6)]], [],
                (0.6, 0.75, 1.0)),
    "fortune": ([star(5, 0.95, 0.42, -math.pi / 2)], [], (1.0, 0.85, 0.35)),
    "scholar": ([GEM, [(0.0, -0.45), (0.3, 0.0), (0.0, 0.45), (-0.3, 0.0)]], [], (0.5, 1.0, 0.65)),
    "renewal": ([regular(36, 0.85)], [[(0.0, -0.45), (0.0, 0.45)], [(-0.45, 0.0), (0.45, 0.0)]], (0.4, 1.0, 0.55)),
    "heal": ([[(-0.25, -0.85), (0.25, -0.85), (0.25, -0.25), (0.85, -0.25), (0.85, 0.25), (0.25, 0.25),
               (0.25, 0.85), (-0.25, 0.85), (-0.25, 0.25), (-0.85, 0.25), (-0.85, -0.25), (-0.25, -0.25)]], [],
             (0.4, 1.0, 0.6)),
    "flux": ([GEM], [], (1.0, 0.5, 1.0)),
    # Forge (permanent upgrades)
    "hull": ([[(0.0, -0.9), (0.75, -0.6), (0.65, 0.25), (0.0, 0.9), (-0.65, 0.25), (-0.75, -0.6)]],
             [[(-0.35, 0.0), (0.35, 0.0)], [(0.0, -0.35), (0.0, 0.35)]], (1.0, 0.4, 0.5)),
    "power": ([[(0.15, -0.95), (-0.55, 0.12), (-0.02, 0.12), (-0.15, 0.95), (0.55, -0.12), (0.02, -0.12)]], [],
              (1.0, 0.75, 0.3)),
    "engine": ([SHIP], [], (0.35, 0.95, 1.0)),
    "greed": ([GEM, regular(28, 0.95)], [], (1.0, 0.5, 1.0)),
    "revive": ([], [[(math.cos(a) * 0.75, math.sin(a) * 0.75) for a in np.linspace(-2.6, 2.3, 18)],
                    [(0.48, 0.4), (0.5, 0.75), (0.85, 0.66)]], (0.4, 1.0, 0.7)),
    "reroll": ([], [[(math.cos(a) * 0.7, math.sin(a) * 0.7) for a in np.linspace(-0.4, 2.6, 14)],
                    [(math.cos(a) * 0.7, math.sin(a) * 0.7) for a in np.linspace(2.75, 5.75, 14)],
                    [(0.45, 0.35), (0.7, -0.05), (0.95, 0.35)]], (0.7, 0.6, 1.0)),
}


def spiral(arms, r0, r1, turns, rot=0.0, steps=18):
    out = []
    for k in range(arms):
        a0 = rot + 2 * math.pi * k / arms
        out.append([((r0 + (r1 - r0) * t) * math.cos(a0 + turns * t * 2 * math.pi),
                     (r0 + (r1 - r0) * t) * math.sin(a0 + turns * t * 2 * math.pi))
                    for t in np.linspace(0, 1, steps)])
    return out


def rays(n, r0, r1, rot=0.0):
    return [[(r0 * math.cos(rot + 2 * math.pi * k / n), r0 * math.sin(rot + 2 * math.pi * k / n)),
             (r1 * math.cos(rot + 2 * math.pi * k / n), r1 * math.sin(rot + 2 * math.pi * k / n))] for k in range(n)]


# Evolved weapons: richer silhouettes in the evolution's colour.
EVO_ICONS = {
    "pulse_evo": ([star(8, 0.95, 0.42, -math.pi / 2), regular(24, 0.2)], [], (1.0, 0.82, 0.4)),
    "orbit_evo": ([regular(32, 0.22)], spiral(2, 0.36, 0.92, 0.55) + [[(math.cos(a) * 0.5, math.sin(a) * 0.5)
                                                                    for a in np.linspace(0, 2 * math.pi, 25)]],
                  (0.78, 0.5, 1.0)),
    "arc_evo": ([[(-0.85, 0.5), (-0.85, -0.4), (-0.42, 0.0), (0.0, -0.8), (0.42, 0.0), (0.85, -0.4), (0.85, 0.5)]],
                [[(-0.15, 0.62), (0.12, 0.62), (-0.08, 0.95)]], (1.0, 0.92, 0.45)),
    "nova_evo": ([regular(24, 0.16)], spiral(3, 0.24, 0.95, 0.42), (0.7, 0.38, 1.0)),
    "seeker_evo": ([[(0.0, -0.95), (0.16, -0.62), (-0.16, -0.62)], [(0.78, -0.6), (0.68, -0.25), (0.45, -0.5)],
                    [(-0.78, -0.6), (-0.68, -0.25), (-0.45, -0.5)]],
                   [[(0.0, 0.9), (0.0, -0.6)], [(0.0, 0.5), (0.6, -0.4)], [(0.0, 0.5), (-0.6, -0.4)]],
                   (0.45, 1.0, 0.5)),
    "lance_evo": ([regular(6, 0.24, math.pi / 6)], rays(6, 0.36, 0.95, -math.pi / 2), (1.0, 0.6, 0.85)),
}

# Prism Cache: an isometric cube of light.
CUBE = regular(6, 1.0, math.pi / 6)
CUBE_LINES = [[(0.0, 0.0), (math.cos(math.pi / 6 + k * 2 * math.pi / 3), math.sin(math.pi / 6 + k * 2 * math.pi / 3))]
              for k in range(3)]


def crescent(r_out=0.95, r_in=0.66, shift=0.42, steps=28):
    """A crescent whose horns point +x."""
    a0 = math.acos(0.42)
    outer = [(r_out * math.cos(a), r_out * math.sin(a)) for a in np.linspace(a0, 2 * math.pi - a0, steps)]
    ex, ey = outer[-1]
    # Inner arc around (shift, 0) from the last horn back to the first.
    b0 = math.atan2(ey, ex - shift)
    b1 = math.atan2(outer[0][1], outer[0][0] - shift)
    if b1 < b0:
        b1 += 2 * math.pi
    inner = [(shift + r_in * math.cos(b), r_in * math.sin(b)) for b in np.linspace(b0, b1, steps)][::-1]
    inner = [(shift + r_in * math.cos(b), r_in * math.sin(b)) for b in np.linspace(b1 - 2 * math.pi, b0, steps)][::-1]
    return outer + inner


# Hangar ships (pointing +x): shapes, open lines, colour.
SHIPS = {
    "lumen": ([SHIP], [], (0.35, 0.95, 1.0)),
    "vesper": ([[(1.0, 0.0), (0.35, 0.55), (-0.6, 0.85), (-0.85, 0.4), (-0.55, 0.0), (-0.85, -0.4), (-0.6, -0.85),
                 (0.35, -0.55)]], [[(0.55, 0.0), (-0.05, 0.38), (-0.25, 0.0), (-0.05, -0.38), (0.55, 0.0)]],
               (0.45, 1.0, 0.75)),
    "kestrel": ([[(1.0, 0.0), (-0.2, 0.25), (-0.9, 0.9), (-0.55, 0.15), (-0.75, 0.0), (-0.55, -0.15), (-0.9, -0.9),
                  (-0.2, -0.25)]], [], (1.0, 0.68, 0.3)),
    "strix": ([[(1.0, 0.32), (0.2, 0.2), (0.05, 0.0), (0.2, -0.2), (1.0, -0.32), (-0.1, -0.7), (-0.8, -0.45),
                (-0.5, 0.0), (-0.8, 0.45), (-0.1, 0.7)]], [[(-0.35, 0.0), (0.0, 0.0)]], (0.78, 0.62, 1.0)),
    "halcyon": ([regular(28, 0.72), [(0.5, 0.0), (-0.32, 0.36), (-0.15, 0.0), (-0.32, -0.36)]],
                [[(0.72, 0.0), (1.0, 0.0)], [(-0.72, 0.0), (-0.95, 0.0)]], (1.0, 0.5, 0.88)),
    "aurora": ([[(1.0, 0.0), (0.1, 0.12), (-0.35, 0.95), (-0.5, 0.95), (-0.3, 0.1), (-0.85, 0.08), (-0.85, -0.08),
                 (-0.3, -0.1), (-0.5, -0.95), (-0.35, -0.95), (0.1, -0.12)]], [], (1.0, 0.92, 0.55)),
    "nyx": ([crescent(), [(0.32, 0.0), (0.12, 0.16), (-0.08, 0.0), (0.12, -0.16)]], [], (1.0, 0.3, 0.5)),
}

# Overdrive icons, one per ship.
OD_ICONS = {
    "lumen": ([star(12, 0.95, 0.42)], [], (0.35, 0.95, 1.0)),
    "vesper": ([regular(6, 0.92, math.pi / 6), regular(6, 0.55, math.pi / 6)], [], (0.45, 1.0, 0.75)),
    "kestrel": ([[(0.9, -0.55), (0.3, -0.75), (0.5, -0.35)], [(0.95, 0.1), (0.4, -0.05), (0.55, 0.3)],
                 [(0.7, 0.75), (0.15, 0.5), (0.3, 0.85)]],
                [[(-0.9, -0.3), (0.5, -0.6)], [(-0.9, 0.2), (0.6, 0.1)], [(-0.8, 0.75), (0.4, 0.7)]],
                (1.0, 0.68, 0.3)),
    "strix": ([[(0.15, -0.95), (-0.5, 0.1), (-0.02, 0.1), (-0.2, 0.95), (0.55, -0.15), (0.05, -0.15),
                (0.35, -0.95)]], [], (0.78, 0.62, 1.0)),
    "halcyon": ([regular(32, 0.36)], spiral(4, 0.48, 0.98, 0.3), (1.0, 0.5, 0.88)),
    "aurora": ([regular(8, 0.26, math.pi / 8)], rays(8, 0.4, 0.98), (1.0, 0.92, 0.55)),
    "nyx": ([crescent(0.95, 0.7, 0.36)], [[(-0.05, 0.0), (-0.05, -0.42)], [(-0.05, 0.0), (0.22, 0.2)]],
            (1.0, 0.3, 0.5)),
}


def ship_sprites():
    for name, (shapes, lines, col) in SHIPS.items():
        save(neon(shapes, col, radius=40, line=4.0, glow=10, fill=0.35, core_white=0.75, lines=lines),
             "ship_" + name)
        save(neon(shapes, col, size=320, radius=110, line=8.0, glow=24, fill=0.32, core_white=0.75, lines=lines),
             "ship_big_" + name)
        save(neon(shapes, col, size=96, radius=34, line=3.6, glow=6.5, fill=0.3, lines=lines), "i_ship_" + name)
    for name, (shapes, lines, col) in OD_ICONS.items():
        save(neon(shapes, col, size=96, radius=34, line=3.8, glow=8.0, fill=0.35, lines=lines, core_white=0.75),
             "i_od_" + name)


def icons():
    for name, (shapes, lines, col) in ICONS.items():
        save(neon(shapes, col, size=96, radius=34, line=3.6, glow=6.5, fill=0.3, lines=lines), "i_" + name)
    for name, (shapes, lines, col) in EVO_ICONS.items():
        save(neon(shapes, col, size=96, radius=34, line=3.8, glow=8.0, fill=0.38, lines=lines, core_white=0.7),
             "i_" + name)
    save(neon([CUBE], (1.0, 0.85, 0.35), size=96, radius=32, line=3.6, glow=8, fill=0.45, lines=CUBE_LINES),
         "p_chest")
    save(neon([CUBE, regular(6, 0.5, math.pi / 6)], (1.0, 0.45, 0.95), size=96, radius=34, line=3.8, glow=9,
              fill=0.5, lines=CUBE_LINES), "p_bigchest")
    save(neon([CUBE], (1.0, 0.85, 0.35), size=256, radius=92, line=7.0, glow=18, fill=0.4, lines=CUBE_LINES),
         "chest_big")


def app_icon():
    def bg(size):
        px, py = grid(size)
        r = np.sqrt(px * px + py * py) / (size * 0.5)
        top = np.array([0.08, 0.04, 0.18])
        mid = np.array([0.02, 0.01, 0.06])
        t = np.clip(r, 0, 1)[..., None]
        rgb = top * (1 - t) + mid * t
        # faint grid
        g = ((np.abs((px % (size / 8.0)) - size / 16.0) < size / 400.0 + 0.6) |
             (np.abs((py % (size / 8.0)) - size / 16.0) < size / 400.0 + 0.6))
        rgb = rgb + g[..., None] * np.array([0.05, 0.1, 0.2]) * (1 - t)
        return rgb

    def fg(size, scale):
        rot = [(-y, -x) for x, y in SHIP]  # point up
        return neon([rot], (0.35, 0.95, 1.0), size=size, radius=size * scale, line=size * 0.035,
                    glow=size * 0.06, fill=0.4, core_white=0.75)

    os.makedirs(ICO, exist_ok=True)
    for size, name in ((192, "icon_192"), (512, "icon_512")):
        b = bg(size)
        f = np.asarray(fg(size, 0.3)).astype(np.float64) / 255.0
        a = f[..., 3:4]
        rgb = b * (1 - a) + f[..., :3] * a
        to_img(rgb, np.ones((size, size))).save(os.path.join(ICO, name + ".png"))
    to_img(bg(432), np.ones((432, 432))).save(os.path.join(ICO, "icon_bg_432.png"))
    fg(432, 0.2).save(os.path.join(ICO, "icon_fg_432.png"))


if __name__ == "__main__":
    enemy_sprites()
    fx_sprites()
    player_sprites()
    icons()
    ship_sprites()
    app_icon()
    print("art ok")
