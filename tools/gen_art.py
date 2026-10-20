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
    "phantom": ([[(1.0, 0.0), (0.1, 0.58), (-0.95, 0.4), (-0.5, 0.0), (-0.95, -0.4), (0.1, -0.58)],
                 regular(16, 0.2)], (0.55, 0.95, 1.0), {"fill": 0.12}),
    "sentinel": ([regular(24, 1.0), regular(3, 0.62), regular(12, 0.16)], (1.0, 0.42, 0.2), {"line": 3.8}),
    "bastion": ([regular(6, 1.0, math.pi / 6), regular(6, 0.64, math.pi / 6), regular(4, 0.26, math.pi / 4)],
                (0.35, 0.6, 1.0), {"line": 4.0, "fill": 0.3}),
    "warden": ([regular(8, 1.0, math.pi / 8), regular(4, 0.5, math.pi / 4), regular(8, 0.78, math.pi / 8)],
               (1.0, 0.8, 0.35), {"line": 4.4, "glow": 12.0}),
    "eclipse": ([regular(40, 1.0), regular(40, 0.62), star(12, 0.5, 0.3)], (1.0, 0.3, 0.88),
                {"line": 4.6, "glow": 13.0, "fill": 0.42}),
    "seraph": ([star(6, 1.0, 0.3), regular(36, 0.46), regular(6, 0.22, math.pi / 6)], (0.4, 1.0, 0.85),
               {"line": 4.4, "glow": 13.0, "fill": 0.3}),
    # A viper's head with two burning eyes and swept-back horns.
    "leviathan": ([[(1.0, 0.0), (0.62, 0.36), (0.0, 0.58), (-0.55, 0.92), (-0.4, 0.42), (-0.95, 0.0), (-0.4, -0.42),
                    (-0.55, -0.92), (0.0, -0.58), (0.62, -0.36)],
                   [(0.36, 0.2), (0.05, 0.34), (0.12, 0.14)], [(0.36, -0.2), (0.05, -0.34), (0.12, -0.14)]],
                  (0.52, 0.46, 1.0), {"line": 4.2, "glow": 12.0, "fill": 0.34}),
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


def heart(steps=36, s=1.0 / 17.0):
    pts = []
    for t in np.linspace(0, 2 * math.pi, steps, endpoint=False):
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((x * s, y * s + 0.08))
    return pts


def drop(steps=30):
    pts = [(0.0, -0.95)]
    for a in np.linspace(-0.25 * math.pi, 1.25 * math.pi, steps):
        pts.append((0.6 * math.cos(a), 0.3 + 0.6 * math.sin(a)))
    return pts


def tri_at(cx, cy, r, rot=-math.pi / 2):
    return [(cx + x, cy + y) for x, y in regular(3, r, rot)]


# Mutators (Daily Run rule twists) and the daily sun.
MOD_ICONS = {
    "volatile": ([star(10, 0.95, 0.55), regular(20, 0.25)], [], (1.0, 0.55, 0.2)),
    "lucky": ([star(5, 0.95, 0.4, -math.pi / 2)], [], (1.0, 0.85, 0.35)),
    "overcharged": ([[(0.15, -0.95), (-0.5, 0.1), (-0.02, 0.1), (-0.2, 0.95), (0.55, -0.15), (0.05, -0.15),
                      (0.35, -0.95)]], [], (0.35, 0.95, 1.0)),
    "gravity": ([regular(24, 0.26)], spiral(3, 0.42, 0.98, -0.35), (0.45, 0.8, 1.0)),
    "gilded": ([[(-0.85, 0.55), (-0.85, -0.35), (-0.42, 0.05), (0.0, -0.7), (0.42, 0.05), (0.85, -0.35),
                 (0.85, 0.55)]], [[(-0.6, 0.78), (0.6, 0.78)]], (1.0, 0.75, 0.3)),
    "glass": ([heart()], [[(0.05, -0.5), (-0.12, -0.1), (0.12, 0.15), (-0.04, 0.55)]], (1.0, 0.35, 0.5)),
    "horde": ([tri_at(0.0, -0.45, 0.42), tri_at(-0.5, 0.4, 0.42), tri_at(0.5, 0.4, 0.42)], [], (1.0, 0.3, 0.65)),
    "frenzy": ([], [[(-0.75, -0.7), (-0.05, 0.0), (-0.75, 0.7)], [(0.0, -0.7), (0.7, 0.0), (0.0, 0.7)]],
               (1.0, 0.3, 0.3)),
    "giants": ([regular(6, 0.95, math.pi / 6), regular(6, 0.36, math.pi / 6)], [], (0.4, 1.0, 0.5)),
    "bloodlight": ([drop()], [[(0.18, 0.05), (0.32, 0.35)]], (0.9, 0.15, 0.3)),
    "dusk": ([crescent(0.95, 0.72, 0.4)], [], (0.75, 0.45, 1.0)),
}


# Round 6: the Ion Scythe, Photon Mines, their evolutions and the relics.
def arc_pts(r, a0, a1, steps=16):
    return [(r * math.cos(a), r * math.sin(a)) for a in np.linspace(a0, a1, steps)]


ARSENAL_ICONS = {
    "scythe": ([[(x * 0.95 + 0.05, y * 0.95) for x, y in crescent(0.95, 0.78, 0.38)]],
               [[(-0.95, 0.75), (-0.25, 0.05)]], (0.5, 1.0, 0.8)),
    "mine": ([regular(6, 0.62, math.pi / 6), regular(16, 0.2)], rays(6, 0.7, 0.98), (1.0, 0.45, 0.55)),
}
ARSENAL_EVO = {
    "scythe_evo": ([crescent(0.95, 0.7, 0.36), [(-x, -y) for x, y in crescent(0.62, 0.44, 0.24)]], [],
                   (0.6, 1.0, 0.9)),
}
STAR_PTS = [(-0.8, -0.55), (-0.15, -0.8), (0.55, -0.35), (0.3, 0.45), (-0.5, 0.7)]
RELIC_ICONS = {
    "halo": ([regular(36, 0.42)], [arc_pts(0.88, -2.7, -0.44, 18), [(0.0, -0.1), (0.0, 0.2)]],
             (1.0, 0.92, 0.55)),
    "wake": ([[(0.95, 0.0), (0.45, 0.32), (0.55, 0.0), (0.45, -0.32)]],
             [[(0.3, 0.0), (-0.15, 0.25), (-0.5, -0.2), (-0.95, 0.15)],
              [(0.25, 0.42), (-0.25, 0.62), (-0.7, 0.45)], [(0.25, -0.42), (-0.25, -0.62), (-0.7, -0.45)]],
             (0.4, 0.95, 1.0)),
    "starbreaker": ([star(4, 0.95, 0.22, -math.pi / 2)], rays(4, 0.35, 0.7, -math.pi / 4), (1.0, 0.5, 0.3)),
    "supercrit": ([star(6, 0.95, 0.5, -math.pi / 2), star(6, 0.42, 0.22, -math.pi / 2)], [], (1.0, 0.85, 0.35)),
    "overcharge": ([regular(36, 0.9)], [[(0.12, -0.62), (-0.3, 0.06), (0.06, 0.06), (-0.1, 0.62)]],
                   (0.35, 0.95, 1.0)),
    "phoenix": ([[(0.0, -0.95), (0.25, -0.3), (0.95, -0.55), (0.45, 0.15), (0.6, 0.85), (0.0, 0.45),
                  (-0.6, 0.85), (-0.45, 0.15), (-0.95, -0.55), (-0.25, -0.3)]], [], (1.0, 0.45, 0.3)),
    "midas": ([regular(32, 0.9), [(x * 0.5, y * 0.5) for x, y in GEM]], [], (1.0, 0.78, 0.3)),
    "wrath": ([crescent(0.95, 0.74, 0.34)], [[(-0.15, -0.35), (0.05, 0.0), (-0.15, 0.35)]], (1.0, 0.3, 0.45)),
}


def arsenal_sprites():
    for name, (shapes, lines, col) in ARSENAL_ICONS.items():
        save(neon(shapes, col, size=96, radius=34, line=3.6, glow=6.5, fill=0.3, lines=lines), "i_" + name)
    for name, (shapes, lines, col) in ARSENAL_EVO.items():
        save(neon(shapes, col, size=96, radius=34, line=3.8, glow=8.0, fill=0.38, lines=lines, core_white=0.7),
             "i_" + name)
    # Constellation: a little star chart (dots on a path).
    dots = [[(cx + x, cy + y) for x, y in regular(10, 0.13)] for cx, cy in STAR_PTS]
    save(neon(dots, (1.0, 0.6, 0.4), size=96, radius=34, line=3.8, glow=8.0, fill=0.6, lines=[STAR_PTS],
              core_white=0.7), "i_mine_evo")
    for name, (shapes, lines, col) in RELIC_ICONS.items():
        save(neon(shapes, col, size=96, radius=34, line=3.8, glow=8.0, fill=0.35, lines=lines, core_white=0.75),
             "i_" + name)
    # World sprite for a mine: white so the view can tint it (armed or not).
    save(neon([regular(6, 0.9, math.pi / 6), regular(16, 0.3)], (1, 1, 1), size=64, radius=24, line=2.6, glow=5,
              fill=0.4, core_white=1.0, lines=rays(6, 0.45, 0.7)), "mine")
    # The first elite's cache: a violet cube holding a relic.
    save(neon([CUBE, star(4, 0.4, 0.16, -math.pi / 2)], (0.75, 0.5, 1.0), size=96, radius=34, line=3.8, glow=9,
              fill=0.5, lines=CUBE_LINES), "p_relicchest")


# Round 7: Radiance (a corona around a sun) and Banish (a card struck through).
CARD = [(-0.55, -0.85), (0.55, -0.85), (0.55, 0.85), (-0.55, 0.85)]


def radiance_icons():
    save(neon([regular(28, 0.34), star(16, 0.62, 0.44)], (1.0, 0.62, 0.28), size=96, radius=34, line=3.8, glow=9.0,
              fill=0.45, lines=rays(8, 0.74, 0.98, math.pi / 8), core_white=0.8), "i_radiance")
    save(neon([CARD], (1.0, 0.3, 0.38), size=96, radius=34, line=3.8, glow=8.0, fill=0.25,
              lines=[[(-0.85, 0.75), (0.85, -0.75)], [(-0.2, -0.45), (0.2, -0.45)]], core_white=0.7), "i_banish")


# Round 8: rifts (beacon, wisp, Umbral Trial) and the Umbral relics.
VIOLET = (0.78, 0.32, 1.0)
CROWN = [(-0.85, 0.35), (-0.85, -0.45), (-0.42, -0.05), (0.0, -0.8), (0.42, -0.05), (0.85, -0.45), (0.85, 0.35)]
UMBRAL_ICONS = {
    "u_sun": ([regular(28, 0.4)], rays(10, 0.56, 0.86) + [[(-0.12, -0.42), (0.08, -0.12), (-0.06, 0.1), (0.12, 0.42)]],
              (1.0, 0.36, 0.5)),
    "u_hunger": ([star(10, 0.84, 0.56), regular(24, 0.24)], [], (0.85, 0.3, 1.0)),
    "u_frenzy": ([star(8, 0.84, 0.66, math.pi / 8)],
                 [[(0.1, -0.5), (-0.22, 0.04), (0.06, 0.04), (-0.1, 0.5)]], (1.0, 0.42, 0.25)),
    "u_gambit": ([[(x * 0.84, y * 0.84) for x, y in DIAMOND], regular(12, 0.1)] +
                 [[(cx + x, cy + y) for x, y in regular(10, 0.08)] for cx, cy in ((-0.42, 0.0), (0.42, 0.0))],
                 [], (1.0, 0.75, 0.3)),
    "u_crown": ([[(x * 0.8, y * 0.8 - 0.1) for x, y in CROWN]],
                [[(math.cos(a) * 0.16 - 0.2, math.sin(a) * 0.12 + 0.62) for a in np.linspace(0, 2 * math.pi, 17)],
                 [(math.cos(a) * 0.16 + 0.2, math.sin(a) * 0.12 + 0.62) for a in np.linspace(0, 2 * math.pi, 17)]],
                (1.0, 0.85, 0.45)),
}
RIFT_ICONS = {
    "rift_beacon": ([regular(32, 0.9), star(4, 0.5, 0.16, -math.pi / 2)], [], (1.0, 0.82, 0.38)),
    "rift_wisp": ([regular(20, 0.3)],
                  [[(-0.3, 0.12), (-0.62, 0.3), (-0.95, 0.24)], [(-0.3, -0.12), (-0.62, -0.3), (-0.95, -0.24)],
                   [(-0.32, 0.0), (-0.8, 0.0)]] + rays(6, 0.42, 0.62, math.pi / 6), (0.55, 1.0, 0.92)),
    "rift_trial": ([regular(24, 0.18)], spiral(3, 0.26, 0.95, 0.55), VIOLET),
}


def over(base, top):
    return Image.alpha_composite(top, base)


def rift_sprites():
    for name, (shapes, lines, col) in UMBRAL_ICONS.items():
        base = neon(shapes, col, size=96, radius=34, line=3.8, glow=8.0, fill=0.35, lines=lines, core_white=0.75)
        # A broken violet ring marks the price every Umbral relic carries.
        ring = neon([], VIOLET, size=96, radius=34, line=2.6, glow=6.0, fill=0.0, core_white=0.4,
                    lines=[arc_pts(0.98, a, a + 1.25, 10) for a in (0.3, 2.4, 4.5)])
        save(over(base, ring), "i_" + name)
    for name, (shapes, lines, col) in RIFT_ICONS.items():
        save(neon(shapes, col, size=96, radius=34, line=3.8, glow=8.0, fill=0.35, lines=lines, core_white=0.75),
             "i_" + name)
    # World sprite for the Umbral Rift: a white vortex the view tints violet.
    save(neon([regular(24, 0.12)], (1, 1, 1), size=256, radius=110, line=5.0, glow=14.0, fill=0.2, core_white=1.0,
              lines=spiral(4, 0.16, 1.0, 0.6, steps=28)), "vortex")


# Round 9: the Ricochet Glaive, Ouroboros, Echo and the Starfall rift.
LIME = (0.72, 1.0, 0.4)


def glaive_shape(blades=3, r1=0.95, r0=0.36, hook=0.55):
    """A spinning disc with hooked blades (curving clockwise)."""
    pts = []
    for k in range(blades):
        a = 2 * math.pi * k / blades
        step = 2 * math.pi / blades
        pts.append((r0 * math.cos(a), r0 * math.sin(a)))
        pts.append((r1 * math.cos(a + hook * step * 0.45), r1 * math.sin(a + hook * step * 0.45)))
        pts.append((r0 * 0.9 * math.cos(a + step * 0.62), r0 * 0.9 * math.sin(a + step * 0.62)))
    return pts


def serpent(r=0.78, steps=40, gap=0.5):
    """Ouroboros: a ring that eats its own tail (an open arc and a head)."""
    body = [(r * math.cos(a), r * math.sin(a)) for a in np.linspace(gap, 2 * math.pi - 0.15, steps)]
    hx, hy = r * math.cos(gap * 0.35), r * math.sin(gap * 0.35)
    head = [(hx + 0.2, hy - 0.02), (hx - 0.02, hy + 0.17), (hx - 0.1, hy - 0.12)]
    return body, head


ECHO_SHIP = [(1.0, 0.0), (-0.35, 0.5), (-0.1, 0.0), (-0.35, -0.5)]
ECHO_LINES = [[(-0.5, 0.66), (-0.26, 0.0), (-0.5, -0.66)], [(-0.92, 0.84), (-0.64, 0.0), (-0.92, -0.84)]]


def ricochet_sprites():
    # Weapon icons.
    save(neon([glaive_shape(3, 0.95, 0.34), regular(12, 0.14)], LIME, size=96, radius=34, line=3.6, glow=6.5,
              fill=0.3, lines=[arc_pts(1.0, 2.2, 3.4, 10), arc_pts(1.0, 4.3, 5.5, 10)]), "i_glaive")
    body, head = serpent()
    save(neon([head, [(x * 0.32, y * 0.32) for x, y in glaive_shape(4, 0.95, 0.4)]], (0.9, 1.0, 0.3), size=96,
              radius=34, line=3.8, glow=8.0, fill=0.38, lines=[body], core_white=0.7), "i_glaive_evo")
    # World sprites: white so the view can tint them.
    save(neon([glaive_shape(), regular(12, 0.18)], (1, 1, 1), size=64, radius=24, line=2.6, glow=5.0, fill=0.45,
              core_white=1.0), "glaive")
    save(neon([glaive_shape(4, 0.98, 0.42, 0.7), regular(12, 0.2)], (1, 1, 1), size=64, radius=25, line=2.8,
              glow=6.0, fill=0.5, core_white=1.0, lines=[arc_pts(0.66, 0.0, 5.6, 20)]), "glaive_evo")
    # Echo: an arrow trailed by its own echoes.
    save(neon([ECHO_SHIP], LIME, radius=40, line=4.0, glow=10, fill=0.35, core_white=0.75, lines=ECHO_LINES),
         "ship_echo")
    save(neon([ECHO_SHIP], LIME, size=320, radius=110, line=8.0, glow=24, fill=0.32, core_white=0.75,
              lines=ECHO_LINES), "ship_big_echo")
    save(neon([ECHO_SHIP], LIME, size=96, radius=34, line=3.6, glow=6.5, fill=0.3, lines=ECHO_LINES), "i_ship_echo")
    # Encore: a note of light ringing out in echoes.
    save(neon([regular(16, 0.2)], LIME, size=96, radius=34, line=3.8, glow=8.0, fill=0.45, core_white=0.75,
              lines=[arc_pts(r, -0.9, 0.9, 12) for r in (0.42, 0.66, 0.9)] +
              [arc_pts(r, math.pi - 0.9, math.pi + 0.9, 12) for r in (0.42, 0.66, 0.9)]), "i_od_echo")
    # Starfall: a falling star over a ring.
    star_pts = [(x * 0.42 + 0.22, y * 0.42 - 0.22) for x, y in star(4, 1.0, 0.32, -math.pi / 2)]
    save(neon([star_pts], (0.55, 0.78, 1.0), size=96, radius=34, line=3.8, glow=8.0, fill=0.4, core_white=0.75,
              lines=[[(-0.05, 0.05), (-0.8, 0.8)], [(-0.12, 0.35), (-0.55, 0.78)], [(0.2, 0.12), (-0.3, 0.9)],
                     arc_pts(0.9, 0.4, 1.9, 12)]), "i_rift_starfall")
    # Comet: a white-hot head (x = 224) with a tapering tail to the left.
    w, h = 256, 64
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    cy = (h - 1) / 2
    t = np.clip(x / 224.0, 0, 1)
    width = 1.0 + 9.0 * t ** 1.5
    d = np.abs(y - cy) / width
    tail = np.exp(-d * d * 1.4) * t ** 1.8 * np.clip((240 - x) / 16.0, 0, 1)
    hr = np.sqrt((x - 224) ** 2 + (y - cy) ** 2)
    head = np.clip(1 - (hr - 7) / 2.0, 0, 1) + np.exp(-np.maximum(hr - 7, 0) / 6.0) * 0.7
    a = np.clip(tail * 0.85 + head, 0, 1) * np.clip((w - 1 - x) / 6.0, 0, 1)
    save(white_img(a), "comet")


# Round 10: the Leviathan.
def leviathan_sprites():
    enemy_sprites()
    # A body segment: a hex scale with a chevron spine, white so the view can tint it.
    save(neon([regular(6, 1.0), regular(6, 0.42)], (1, 1, 1), size=64, radius=24, line=2.8, glow=5.5, fill=0.4,
              core_white=1.0, lines=[[(-0.6, 0.62), (0.3, 0.0), (-0.6, -0.62)]]), "levi_seg")


# Round 11: the Gauntlet (two crossed blades inside a ring of four boss marks).
def gauntlet_icons():
    blade = [(0.0, -0.98), (0.11, -0.2), (0.0, 0.62), (-0.11, -0.2)]
    def rot(pts, a):
        c, s_ = math.cos(a), math.sin(a)
        return [(x * c - y * s_, x * s_ + y * c) for x, y in pts]
    shapes = [rot(blade, math.pi / 4), rot(blade, -math.pi / 4)]
    shapes += [[(math.cos(a) * 0.82 + x, math.sin(a) * 0.82 + y) for x, y in regular(4, 0.12, math.pi / 4)]
               for a in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2)]
    guards = [[(-0.42, 0.3), (-0.2, 0.42)], [(0.42, 0.3), (0.2, 0.42)]]
    save(neon(shapes, (1.0, 0.72, 0.3), size=96, radius=34, line=3.8, glow=8.5, fill=0.4, lines=guards,
              core_white=0.75), "i_gauntlet")


# Round 12: sector icons. The Neon Grid (a square lattice in a ring), the Abyss
# (a black hole with a spiral disk) and Corona (a sun with flame rays and gaps).
def sector_icons():
    ring = [(math.cos(a) * 0.95, math.sin(a) * 0.95) for a in np.linspace(0, 2 * math.pi, 49)]
    lattice = []
    for v in (-0.45, 0.0, 0.45):
        h = math.sqrt(max(0.0, 0.95 ** 2 - v * v)) * 0.92
        lattice.append([(v, -h), (v, h)])
        lattice.append([(-h, v), (h, v)])
    save(neon([], (0.35, 0.95, 1.0), size=96, radius=34, line=3.4, glow=8.0, fill=0.0, lines=[ring] + lattice,
              core_white=0.7), "i_sector_grid")
    save(neon([regular(32, 0.3)], (0.62, 0.45, 1.0), size=96, radius=34, line=3.6, glow=9.0, fill=0.05,
              lines=spiral(3, 0.42, 0.98, 0.45) + [[(math.cos(a) * 0.38, math.sin(a) * 0.38)
                                                   for a in np.linspace(0, 2 * math.pi, 33)]],
              core_white=0.75), "i_sector_abyss")
    flames = []
    for k in range(12):
        if k % 4 == 0:
            continue
        a = 2 * math.pi * k / 12
        flames.append([(math.cos(a) * 0.55, math.sin(a) * 0.55), (math.cos(a + 0.12) * 0.78, math.sin(a + 0.12) * 0.78),
                       (math.cos(a) * 0.98, math.sin(a) * 0.98)])
    save(neon([regular(32, 0.42)], (1.0, 0.55, 0.22), size=96, radius=34, line=3.8, glow=9.0, fill=0.6,
              lines=flames, core_white=0.8), "i_sector_corona")


def mod_icons():
    for name, (shapes, lines, col) in MOD_ICONS.items():
        save(neon(shapes, col, size=96, radius=34, line=3.8, glow=8.0, fill=0.35, lines=lines, core_white=0.75),
             "i_mod_" + name)
    save(neon([regular(28, 0.5)], (1.0, 0.82, 0.35), size=96, radius=34, line=3.8, glow=8.0, fill=0.45,
              lines=rays(12, 0.66, 0.98), core_white=0.75), "i_daily")


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


# Round 13: resonance icons. The two weapons side by side inside a ring of the
# resonance's colour, with a spark where they meet. Built from the weapon icons.
RESONANCES = {
    "conductor": ("pulse", "arc", (0.6, 0.85, 1.0)),
    "salvo": ("pulse", "seeker", (1.0, 0.82, 0.45)),
    "payload": ("seeker", "lance", (1.0, 0.86, 0.5)),
    "refraction": ("lance", "glaive", (0.9, 1.0, 0.55)),
    "homecoming": ("glaive", "nova", (0.85, 0.75, 1.0)),
    "surge": ("nova", "orbit", (0.95, 0.6, 1.0)),
    "bladestorm": ("orbit", "scythe", (0.5, 1.0, 0.95)),
    "sow": ("scythe", "mine", (0.75, 1.0, 0.65)),
    "tesla": ("mine", "arc", (0.85, 0.7, 1.0)),
}


def resonance_icons():
    for name, (a, b, col) in RESONANCES.items():
        ring = [(math.cos(t) * 0.97, math.sin(t) * 0.97) for t in np.linspace(0, 2 * math.pi, 65)]
        base = neon([], col, size=96, radius=44, line=2.6, glow=5.0, fill=0.0, lines=[ring], core_white=0.5,
                    glow_amt=0.7)
        for wid, x in ((a, 0), (b, 38)):
            ic = Image.open(os.path.join(SPR, "i_" + wid + ".png")).convert("RGBA").resize((58, 58), Image.LANCZOS)
            layer = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
            layer.paste(ic, (x, 19), ic)
            base = Image.alpha_composite(base, layer)
        spark = neon([star(4, 0.42, 0.1)], (1.0, 1.0, 1.0), size=96, radius=26, line=2.4, glow=6.0,
                     fill=0.9, core_white=1.0)
        base = Image.alpha_composite(base, spark)
        save(base, "i_res_" + name)


if __name__ == "__main__":
    import sys
    if "--threats" in sys.argv:
        enemy_sprites()
        print("enemy sprites ok")
        sys.exit(0)
    if "--arsenal" in sys.argv:
        arsenal_sprites()
        print("arsenal art ok")
        sys.exit(0)
    if "--radiance" in sys.argv:
        radiance_icons()
        print("radiance art ok")
        sys.exit(0)
    if "--rifts" in sys.argv:
        rift_sprites()
        print("rift art ok")
        sys.exit(0)
    if "--ricochet" in sys.argv:
        ricochet_sprites()
        print("ricochet art ok")
        sys.exit(0)
    if "--leviathan" in sys.argv:
        leviathan_sprites()
        print("leviathan art ok")
        sys.exit(0)
    if "--gauntlet" in sys.argv:
        gauntlet_icons()
        print("gauntlet art ok")
        sys.exit(0)
    if "--sectors" in sys.argv:
        sector_icons()
        print("sector art ok")
        sys.exit(0)
    if "--resonance" in sys.argv:
        resonance_icons()
        print("resonance art ok")
        sys.exit(0)
    if "--mods" in sys.argv:
        mod_icons()
        print("mutator icons ok")
        sys.exit(0)
    enemy_sprites()
    fx_sprites()
    player_sprites()
    icons()
    ship_sprites()
    mod_icons()
    arsenal_sprites()
    radiance_icons()
    rift_sprites()
    ricochet_sprites()
    leviathan_sprites()
    gauntlet_icons()
    sector_icons()
    resonance_icons()
    app_icon()
    print("art ok")
