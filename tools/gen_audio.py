#!/usr/bin/env python3
"""Synthesises every sound and music loop in assets/audio (numpy + ffmpeg).

Rerun after editing: python3 tools/gen_audio.py
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, hold=0.0):
    """ADSR over n samples (seconds for a/d/r/hold)."""
    out = np.zeros(n)
    ai, di, hi, ri = int(a * SR), int(d * SR), int(hold * SR), int(r * SR)
    i = 0
    seg = min(ai, n - i)
    out[i:i + seg] = np.linspace(0, 1, max(ai, 1))[:seg]
    i += seg
    seg = min(di, n - i)
    out[i:i + seg] = np.linspace(1, s, max(di, 1))[:seg]
    i += seg
    seg = min(hi, n - i)
    out[i:i + seg] = s
    i += seg
    seg = min(ri, n - i)
    out[i:i + seg] = np.linspace(s, 0, max(ri, 1))[:seg]
    return out


def expdecay(n, k):
    return np.exp(-np.arange(n) / SR * k)


def sweep_phase(f0, f1, n, curve=1.0):
    f = f0 + (f1 - f0) * (np.linspace(0, 1, n) ** curve)
    return 2 * np.pi * np.cumsum(f) / SR


def saw_from_phase(ph, harmonics=12):
    out = np.zeros_like(ph)
    for h in range(1, harmonics + 1):
        out += np.sin(ph * h) / h * (-1) ** (h + 1)
    return out * 0.6


def square_from_phase(ph, harmonics=9):
    out = np.zeros_like(ph)
    for h in range(1, harmonics * 2, 2):
        out += np.sin(ph * h) / h
    return out * 0.8


def lowpass(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / np.sqrt(1.0 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def highpass(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / np.sqrt(1.0 + (cutoff / np.maximum(f, 1.0)) ** 4)
    return np.fft.irfft(X, len(x))


def noise(n):
    return rng.uniform(-1, 1, n)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def write_wav(name, x, peak=0.9):
    os.makedirs(OUT, exist_ok=True)
    x = norm(x, peak)
    fade = min(len(x), 200)
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(name, stereo):
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, name + "_tmp.wav")
    data = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.T.copy().tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4",
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# --- sound effects ---------------------------------------------------------------

def sfx():
    n = int(0.06 * SR)
    ph = sweep_phase(2200, 1400, n)
    write_wav("click", np.sin(ph) * expdecay(n, 70) + noise(n) * expdecay(n, 300) * 0.2, 0.6)

    n = int(0.22 * SR)
    x = highpass(noise(n), 1500) * env(n, 0.01, 0.2) * 0.5
    ph = sweep_phase(500, 1500, n, 0.6)
    x += np.sin(ph) * env(n, 0.005, 0.2) * 0.3
    write_wav("card", x, 0.6)

    n = int(0.35 * SR)
    x = np.zeros(n)
    for k, m in enumerate([76, 83, 88]):
        st = int(k * 0.045 * SR)
        seg = n - st
        tt = np.arange(seg) / SR
        x[st:] += (np.sin(2 * np.pi * mtof(m) * tt) + 0.3 * np.sin(4 * np.pi * mtof(m) * tt)) * expdecay(seg, 9)
    write_wav("select", x, 0.75)

    n = int(1.0 * SR)
    x = np.zeros(n)
    for k, m in enumerate([69, 73, 76, 81, 85, 88]):
        st = int(k * 0.06 * SR)
        seg = n - st
        tt = np.arange(seg) / SR
        tone = np.sin(2 * np.pi * mtof(m) * tt) + 0.4 * np.sin(2 * np.pi * mtof(m + 12) * tt + 0.3)
        x[st:] += tone * expdecay(seg, 4.0) * (0.8 + 0.04 * k)
    x += lowpass(noise(n), 6000) * env(n, 0.3, 0.6) * 0.08
    write_wav("levelup", x, 0.8)

    n = int(0.09 * SR)
    ph = sweep_phase(1300, 380, n, 0.5)
    x = square_from_phase(ph, 4) * expdecay(n, 45) * 0.5 + np.sin(ph * 0.5) * expdecay(n, 40) * 0.5
    write_wav("shoot", lowpass(x, 5000), 0.5)

    n = int(0.05 * SR)
    x = highpass(noise(n), 2500) * expdecay(n, 120) + np.sin(sweep_phase(900, 500, n)) * expdecay(n, 90) * 0.5
    write_wav("hit", x, 0.5)

    n = int(0.22 * SR)
    ph = sweep_phase(700, 120, n, 0.4)
    x = np.sin(ph) * expdecay(n, 22) * 0.8
    x += lowpass(noise(n), 4000) * expdecay(n, 30) * 0.7
    x += np.sin(sweep_phase(2400, 1800, n)) * expdecay(n, 60) * 0.2
    write_wav("kill", x, 0.7)

    n = int(0.6 * SR)
    ph = sweep_phase(160, 38, n, 0.5)
    x = np.sin(ph) * expdecay(n, 7) * 1.0
    x += lowpass(noise(n), 1800) * expdecay(n, 9) * 0.8
    x += highpass(noise(n), 3000) * expdecay(n, 25) * 0.3
    write_wav("kill_big", x, 0.85)

    n = int(0.12 * SR)
    tt = np.arange(n) / SR
    x = (np.sin(2 * np.pi * 1568 * tt) + 0.5 * np.sin(2 * np.pi * 2352 * tt)) * expdecay(n, 28)
    write_wav("gem", x, 0.5)

    n = int(0.4 * SR)
    ph = sweep_phase(300, 60, n, 0.6)
    x = saw_from_phase(ph, 10) * expdecay(n, 9)
    x += lowpass(noise(n), 2500) * expdecay(n, 14) * 0.9
    write_wav("hurt", lowpass(x, 3000), 0.85)

    n = int(0.8 * SR)
    x = lowpass(noise(n), 1200) * env(n, 0.02, 0.75) * 1.0
    x += np.sin(sweep_phase(80, 40, n)) * expdecay(n, 5) * 0.9
    x += highpass(noise(n), 5000) * env(n, 0.005, 0.3) * 0.25
    write_wav("nova", x, 0.85)

    n = int(0.28 * SR)
    sq = np.sign(np.sin(sweep_phase(90, 140, n))) * 0.5
    crackle = noise(n) * (rng.uniform(0, 1, n) > 0.7)
    x = (sq * 0.4 + highpass(crackle, 1500) * 0.8) * expdecay(n, 12)
    write_wav("zap", x, 0.6)

    n = int(0.55 * SR)
    ph = sweep_phase(1800, 220, n, 0.3)
    x = saw_from_phase(ph, 8) * expdecay(n, 6) * 0.6
    x += np.sin(sweep_phase(110, 55, n)) * expdecay(n, 5) * 0.8
    write_wav("lance", lowpass(x, 6000), 0.8)

    n = int(0.25 * SR)
    x = highpass(noise(n), 1200) * env(n, 0.03, 0.22) * 0.6
    x += np.sin(sweep_phase(300, 700, n)) * env(n, 0.01, 0.22) * 0.3
    write_wav("missile", x, 0.5)

    n = int(0.7 * SR)
    x = np.sin(sweep_phase(120, 35, n, 0.4)) * expdecay(n, 6)
    x += lowpass(noise(n), 1500) * expdecay(n, 7) * 1.1
    write_wav("boom", x, 0.85)

    n = int(1.6 * SR)
    tt = np.arange(n) / SR
    f = np.where((tt * 2.5) % 1.0 < 0.5, 660.0, 520.0)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = square_from_phase(ph, 5) * env(n, 0.02, 0.1, 0.8, 0.3, 1.1) * 0.5
    x += np.sin(sweep_phase(55, 50, n)) * env(n, 0.1, 0.1, 0.9, 0.4, 1.0) * 0.6
    write_wav("alarm", lowpass(x, 4000), 0.75)

    n = int(2.4 * SR)
    x = np.sin(sweep_phase(90, 25, n, 0.5)) * expdecay(n, 1.8) * 1.0
    x += lowpass(noise(n), 900) * expdecay(n, 2.2) * 1.2
    x += highpass(noise(n), 2500) * expdecay(n, 6) * 0.3
    for m in [57, 64, 69, 76]:
        tt = np.arange(n) / SR
        x += np.sin(2 * np.pi * mtof(m) * tt) * env(n, 0.4, 0.2, 0.6, 1.5, 0.2) * 0.12
    write_wav("boss_down", x, 0.9)

    n = int(0.45 * SR)
    x = np.zeros(n)
    for k, m in enumerate([84, 88, 91, 96]):
        st = int(k * 0.035 * SR)
        tt = np.arange(n - st) / SR
        x[st:] += np.sin(2 * np.pi * mtof(m) * tt) * expdecay(n - st, 10)
    write_wav("pickup", x, 0.6)

    n = int(1.8 * SR)
    x = np.zeros(n)
    tt = np.arange(n) / SR
    for m in [57, 64, 69, 73, 76]:
        x += np.sin(2 * np.pi * mtof(m) * tt) * env(n, 0.3, 0.2, 0.7, 1.0, 0.3)
    x += highpass(noise(n), 4000) * env(n, 0.6, 0.6) * 0.3
    x += np.sin(sweep_phase(60, 120, n)) * env(n, 0.5, 1.2) * 0.4
    write_wav("revive", x, 0.85)

    n = int(3.0 * SR)
    x = np.zeros(n)
    for k, chord in enumerate([[57, 64, 69, 72], [53, 60, 65, 69], [55, 62, 67, 71], [57, 64, 69, 73, 76]]):
        st = int(k * 0.5 * SR)
        seg = n - st
        tt = np.arange(seg) / SR
        dur = 0.6 if k < 3 else 2.4
        e = env(seg, 0.02, 0.1, 0.7, 0.6 if k == 3 else 0.15, dur - 0.2)
        for m in chord:
            x[st:] += saw_from_phase(2 * np.pi * mtof(m) * tt, 6) * e * 0.25
    write_wav("win", lowpass(x, 3500), 0.85)

    n = int(2.2 * SR)
    x = np.zeros(n)
    for k, m in enumerate([69, 65, 62, 57]):
        st = int(k * 0.32 * SR)
        seg = n - st
        tt = np.arange(seg) / SR
        x[st:] += saw_from_phase(2 * np.pi * mtof(m) * tt, 6) * expdecay(seg, 2.5) * 0.4
    x += np.sin(sweep_phase(110, 30, n)) * expdecay(n, 1.5) * 0.6
    write_wav("lose", lowpass(x, 2200), 0.85)

    n = int(0.9 * SR)
    x = highpass(noise(n), 600) * env(n, 0.5, 0.35) * 0.5
    x += np.sin(sweep_phase(200, 900, n, 1.5)) * env(n, 0.4, 0.45) * 0.4
    write_wav("wave", x, 0.7)

    n = int(0.4 * SR)
    x = highpass(noise(n), 2000) * env(n, 0.25, 0.12) * 0.6
    x += np.sin(sweep_phase(400, 1200, n, 2.0)) * env(n, 0.3, 0.1) * 0.3
    write_wav("dash", x, 0.55)

    n = int(0.5 * SR)
    x = np.zeros(n)
    for k, m in enumerate([72, 79, 84, 91]):
        st = int(k * 0.05 * SR)
        tt = np.arange(n - st) / SR
        x[st:] += (np.sin(2 * np.pi * mtof(m) * tt) + 0.3 * np.sin(2 * np.pi * mtof(m) * 3 * tt)) * expdecay(n - st, 8)
    write_wav("buy", x, 0.7)


# --- music -----------------------------------------------------------------------

def place(buf, x, start):
    start = int(start)
    end = start + x.shape[-1]
    if end <= buf.shape[-1]:
        buf[..., start:end] += x
    else:
        cut = buf.shape[-1] - start
        buf[..., start:] += x[..., :cut]
        buf[..., :end - buf.shape[-1]] += x[..., cut:]  # wrap the tail for a seamless loop


def pan(x, p):
    return np.stack([x * (1 - p) ** 0.5, x * (1 + p) ** 0.5]) * 0.7071


def kick():
    n = int(0.35 * SR)
    return np.sin(sweep_phase(150, 42, n, 0.25)) * expdecay(n, 9) + noise(n) * expdecay(n, 200) * 0.15


def snare():
    n = int(0.25 * SR)
    return highpass(noise(n), 1200) * expdecay(n, 16) * 0.8 + np.sin(sweep_phase(260, 180, n)) * expdecay(n, 25) * 0.4


def hat(open_=False):
    n = int((0.22 if open_ else 0.05) * SR)
    return highpass(noise(n), 7000) * expdecay(n, 14 if open_ else 80)


def pluck(m, dur, bright=3500.0):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    ph = 2 * np.pi * mtof(m) * tt
    x = saw_from_phase(ph, 14) + 0.5 * saw_from_phase(ph * 1.005, 14)
    return lowpass(x * expdecay(n, 7), bright)


def pad(chord, dur):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for m in chord:
        for det in (-0.12, 0.0, 0.12):
            f = mtof(m + det)
            x += saw_from_phase(2 * np.pi * f * tt + rng.uniform(0, 6), 8)
    x = lowpass(x, 1400) * env(n, dur * 0.25, 0.1, 1.0, dur * 0.35, dur * 0.3)
    return x / len(chord)


def bass(m, dur):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    x = np.sin(2 * np.pi * mtof(m) * tt) + 0.35 * saw_from_phase(2 * np.pi * mtof(m) * tt, 5)
    return lowpass(x, 700) * env(n, 0.005, 0.08, 0.7, 0.05, dur - 0.15)


def music():
    bpm = 128.0
    beat = 60.0 / bpm
    bars = 16
    n = int(bars * 4 * beat * SR)
    base = np.zeros((2, n))
    drive = np.zeros((2, n))
    prog = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]  # Am F C G
    roots = [45, 41, 48, 43]
    arps = [[69, 72, 76, 81], [65, 69, 72, 77], [67, 72, 76, 79], [67, 71, 74, 79]]
    for bar in range(bars):
        c = (bar // 2) % 4
        t0 = bar * 4 * beat
        if bar % 2 == 0:
            place(base, pan(pad(prog[c], 8 * beat), 0.0) * 0.32, t0 * SR)
        for e in range(8):
            place(base, pan(bass(roots[c] if e % 2 == 0 else roots[c] + 12, beat * 0.5), 0.0) * 0.38,
                  (t0 + e * beat * 0.5) * SR)
        for e in range(8):
            place(base, pan(hat(), 0.3) * 0.08, (t0 + e * beat * 0.5 + beat * 0.25) * SR)
        for b in range(4):
            place(drive, pan(kick(), 0.0) * 0.7, (t0 + b * beat) * SR)
            if b % 2 == 1:
                place(drive, pan(snare(), -0.1) * 0.42, (t0 + b * beat) * SR)
            place(drive, pan(hat(True), 0.25) * 0.12, (t0 + b * beat + beat * 0.5) * SR)
        for s in range(16):
            m = arps[c][(s * 3 + bar) % 4] + (12 if s % 8 == 7 else 0)
            place(drive, pan(pluck(m, beat * 0.5, 2500 + 1500 * (s % 4 == 0)), 0.35 if s % 2 else -0.35) * 0.14,
                  (t0 + s * beat * 0.25) * SR)
    write_ogg("music_run", norm(base, 0.7))
    write_ogg("music_drive", norm(drive, 0.75))

    # Menu: slow, wide, shimmering.
    bar_d = 4.0
    bars = 8
    n = int(bars * bar_d * SR)
    menu = np.zeros((2, n))
    prog = [[57, 64, 69, 72], [53, 60, 65, 69], [48, 55, 60, 64], [52, 59, 64, 67]]
    for bar in range(bars):
        c = bar % 4
        t0 = bar * bar_d
        place(menu, pan(pad(prog[c], bar_d * 1.6), 0.0) * 0.4, t0 * SR)
        place(menu, pan(bass(prog[c][0] - 12, bar_d), 0.0) * 0.25, t0 * SR)
        for s in range(8):
            m = prog[c][(s * 5 + bar) % 4] + 12
            place(menu, pan(pluck(m, 1.2, 2000), 0.6 if s % 2 else -0.6) * 0.07, (t0 + s * bar_d / 8) * SR)
    write_ogg("music_menu", norm(menu, 0.65))


def sfx_evolution():
    """Prism Cache and evolution sounds (own RNG so older sounds stay identical)."""
    global rng
    rng = np.random.default_rng(31)
    # Cache opening: a shimmering riser into a bright burst.
    n = int(1.5 * SR)
    tt = np.arange(n) / SR
    rise = np.zeros(n)
    for k, m in enumerate([72, 76, 79, 83, 86, 88, 91, 95]):
        st = int(k * 0.11 * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        rise[st:] += np.sin(2 * np.pi * mtof(m) * t2) * expdecay(seg, 5) * (0.5 + 0.07 * k)
    rise += highpass(noise(n), 3000) * env(n, 0.9, 0.5) * 0.35
    rise += np.sin(sweep_phase(80, 40, n)) * env(n, 0.95, 0.5) * 0.5
    write_wav("chest", rise, 0.8)
    # Evolution: a huge major chord with a downward whoosh and sub drop.
    n = int(2.6 * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for m in [45, 57, 64, 69, 73, 76, 81]:
        x += saw_from_phase(2 * np.pi * mtof(m) * tt, 7) * env(n, 0.01, 0.3, 0.55, 1.6, 0.5) * 0.18
    x = lowpass(x, 4200)
    x += np.sin(sweep_phase(140, 30, n, 0.5)) * expdecay(n, 2.0) * 0.9
    x += highpass(noise(n), 1800) * expdecay(n, 3.5) * 0.4
    write_wav("evolve", x, 0.9)
    # Singularity opening: reversed suction.
    n = int(1.1 * SR)
    x = lowpass(noise(n), 900) * env(n, 0.9, 0.15) * 0.9
    x += np.sin(sweep_phase(50, 160, n, 2.0)) * env(n, 0.9, 0.15) * 0.6
    write_wav("well", x, 0.7)
    # Singularity detonation: a deep crunch.
    n = int(1.0 * SR)
    x = np.sin(sweep_phase(200, 28, n, 0.35)) * expdecay(n, 4.5) * 1.1
    x += lowpass(noise(n), 2200) * expdecay(n, 6) * 1.0
    x += highpass(noise(n), 4000) * expdecay(n, 18) * 0.3
    write_wav("implode", x, 0.9)


def sfx_overdrive():
    """Overdrive and mission sounds (own RNG so older sounds stay identical)."""
    global rng
    rng = np.random.default_rng(53)
    # Overdrive: a sub thump, a rising saw stack and a bright crash.
    n = int(1.8 * SR)
    tt = np.arange(n) / SR
    x = np.sin(sweep_phase(160, 34, n, 0.3)) * expdecay(n, 3.0) * 1.1
    for m in [38, 45, 50, 57, 62]:
        x += saw_from_phase(sweep_phase(mtof(m) * 0.5, mtof(m), n, 0.15), 8) * env(n, 0.02, 0.4, 0.4, 1.0, 0.3) * 0.16
    x = lowpass(x, 5200)
    x += highpass(noise(n), 2500) * expdecay(n, 4.5) * 0.55
    x += highpass(noise(n), 6000) * env(n, 0.002, 0.05, 0.0, 0.0) * 0.6
    write_wav("overdrive", x, 0.95)
    # Overdrive ready: a two-note glassy chime.
    n = int(0.7 * SR)
    x = np.zeros(n)
    for k, m in enumerate([81, 88]):
        st = int(k * 0.09 * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        tone = np.sin(2 * np.pi * mtof(m) * t2) + 0.35 * np.sin(2 * np.pi * mtof(m) * 2.01 * t2)
        x[st:] += tone * expdecay(seg, 7) * 0.6
    write_wav("od_ready", x, 0.7)
    # Mission complete: a short triumphant arpeggio.
    n = int(1.3 * SR)
    x = np.zeros(n)
    for k, m in enumerate([72, 76, 79, 84]):
        st = int(k * 0.08 * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        x[st:] += square_from_phase(2 * np.pi * mtof(m) * t2, 5) * expdecay(seg, 4.0 - 0.6 * k) * 0.25
    x = lowpass(x, 6000)
    write_wav("mission", x, 0.8)


def sfx_threats():
    """Lasers, blinks and the Chain (own RNG so older sounds stay identical)."""
    global rng
    rng = np.random.default_rng(97)
    # Laser charge: a rising whine with a fizzing edge.
    n = int(1.2 * SR)
    x = saw_from_phase(sweep_phase(220, 1400, n, 1.6), 6) * env(n, 0.05, 0.0, 1.0, 0.08, 1.05) * 0.4
    x = lowpass(x, 5000)
    x += highpass(noise(n), 5000) * np.linspace(0.05, 0.4, n) * env(n, 0.05, 0.0, 1.0, 0.08, 1.05)
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * np.linspace(6, 26, n).cumsum() / SR)
    write_wav("charge", x, 0.7)
    # Laser fire: a searing zap over a sub thump.
    n = int(0.7 * SR)
    x = square_from_phase(sweep_phase(1800, 140, n, 0.4), 7) * expdecay(n, 6.0) * 0.45
    x = lowpass(x, 7000)
    x += np.sin(sweep_phase(120, 40, n, 0.5)) * expdecay(n, 7.0) * 0.9
    x += highpass(noise(n), 3500) * expdecay(n, 9.0) * 0.5
    write_wav("laser", x, 0.9)
    # Blink: a reversed shimmer that snaps.
    n = int(0.45 * SR)
    tt = np.arange(n) / SR
    x = np.sin(2 * np.pi * (900 + 1600 * tt / tt[-1]) * tt) * env(n, 0.38, 0.06) * 0.5
    x += highpass(noise(n), 4500) * env(n, 0.4, 0.05) * 0.4
    write_wav("blink", x, 0.65)
    # Chain milestone: a bright rising triad stab.
    n = int(0.9 * SR)
    x = np.zeros(n)
    for k, m in enumerate([76, 83, 88, 95]):
        st = int(k * 0.045 * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        x[st:] += saw_from_phase(2 * np.pi * mtof(m) * t2, 6) * expdecay(seg, 5.0) * 0.22
    x = lowpass(x, 7000)
    x += highpass(noise(n), 6000) * expdecay(n, 14) * 0.3
    write_wav("chain", x, 0.8)
    # Chain broken: glass shattering downwards.
    n = int(0.8 * SR)
    x = np.zeros(n)
    for k in range(14):
        st = int(rng.uniform(0, 0.25) * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        f = rng.uniform(2500, 6500)
        x[st:] += np.sin(2 * np.pi * f * t2 * (1 - 0.3 * t2)) * expdecay(seg, rng.uniform(12, 30)) * 0.2
    x += np.sin(sweep_phase(700, 120, n, 0.6)) * expdecay(n, 6) * 0.4
    write_wav("chain_lost", x, 0.7)


def sfx_arsenal():
    """Ion Scythe, Photon Mines, relics and the Guardian Halo (own RNG)."""
    global rng
    rng = np.random.default_rng(131)
    # Scythe: an airy whoosh with a bright edge that rings out.
    n = int(0.32 * SR)
    sw = highpass(noise(n), 900)
    sw = lowpass(sw, 6500) * env(n, 0.04, 0.0, 1.0, 0.24, 0.02) * 0.9
    sw += np.sin(sweep_phase(1400, 2600, n, 0.6)) * env(n, 0.03, 0.2) * 0.25
    write_wav("slash", sw, 0.7)
    # Mine drop: a soft beep pair and a click.
    n = int(0.22 * SR)
    tt = np.arange(n) / SR
    x = np.sin(2 * np.pi * 1320 * tt) * env(n, 0.002, 0.06) * 0.5
    st = int(0.07 * SR)
    x[st:] += np.sin(2 * np.pi * 1760 * tt[:n - st]) * env(n - st, 0.002, 0.08) * 0.45
    x += highpass(noise(n), 4000) * expdecay(n, 60) * 0.3
    write_wav("mine", x, 0.6)
    # Relic: a shimmering major chord that blooms.
    n = int(1.6 * SR)
    x = np.zeros(n)
    tt = np.arange(n) / SR
    for k, m in enumerate([67, 71, 74, 79, 83, 86]):
        st = int(k * 0.06 * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t2)
        x[st:] += (np.sin(2 * np.pi * mtof(m) * t2 * vib) + 0.35 * np.sin(4 * np.pi * mtof(m) * t2)) * \
            env(seg, 0.08, 0.5, 0.4, 0.6, 0.3) * 0.18
    x += highpass(noise(n), 7000) * env(n, 0.3, 0.6) * 0.12
    write_wav("relic", x, 0.85)
    # Halo block: a struck glass bell over a soft thump.
    n = int(0.9 * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for f, a, k in [(1568, 0.5, 5.0), (2352, 0.3, 7.0), (3920, 0.2, 10.0), (4700, 0.12, 14.0)]:
        x += np.sin(2 * np.pi * f * tt) * expdecay(n, k) * a
    x += np.sin(sweep_phase(160, 60, n, 0.5)) * expdecay(n, 12) * 0.6
    write_wav("halo", x, 0.8)


def sfx_radiance():
    """Banish and the Radiance unlock (own RNG)."""
    global rng
    rng = np.random.default_rng(171)
    # Banish: a card torn away: a downward glitch sweep, crackle and a low thud.
    n = int(0.42 * SR)
    ph = sweep_phase(900, 140, n, 0.5)
    x = square_from_phase(ph, 7) * env(n, 0.004, 0.32) * 0.35
    crush = np.repeat(noise(n // 64 + 1), 64)[:n]
    x += lowpass(crush, 3200) * env(n, 0.002, 0.18) * 0.45
    x += np.sin(sweep_phase(120, 45, n, 0.6)) * expdecay(n, 9) * 0.7
    write_wav("banish", lowpass(x, 7000), 0.8)
    # Ascend: a rising shimmer that opens into a bright fifth.
    n = int(2.0 * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    x += np.sin(sweep_phase(220, 880, n, 1.6)) * env(n, 0.3, 0.6, 0.3, 0.6, 0.5) * 0.22
    for k, m in enumerate([69, 76, 81, 88]):
        st = int((0.5 + 0.09 * k) * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        x[st:] += (np.sin(2 * np.pi * mtof(m) * t2) + 0.3 * np.sin(6 * np.pi * mtof(m) * t2)) * \
            env(seg, 0.02, 0.6, 0.35, 0.7, 0.2) * 0.16
    x += highpass(noise(n), 6000) * env(n, 0.8, 0.9) * 0.1
    write_wav("ascend", x, 0.85)


def sfx_rifts():
    """Rifts: opening, the wisp, the Umbral Trial and a completed rift (own RNG)."""
    global rng
    rng = np.random.default_rng(211)
    # Rift opens: a far-off shimmer that swells and hangs.
    n = int(1.3 * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for k, m in enumerate([74, 81, 86]):
        vib = 1 + 0.006 * np.sin(2 * np.pi * (4.0 + k) * tt)
        x += np.sin(2 * np.pi * mtof(m) * tt * vib) * env(n, 0.35, 0.5, 0.3, 0.5, 0.1) * 0.16
    x += lowpass(highpass(noise(n), 3000), 9000) * env(n, 0.5, 0.6) * 0.14
    x += np.sin(sweep_phase(300, 600, n, 1.4)) * env(n, 0.4, 0.6) * 0.12
    write_wav("rift", x, 0.75)
    # Wisp: a quick run of bell-like sparkles.
    n = int(0.7 * SR)
    x = np.zeros(n)
    for k, m in enumerate([88, 91, 95, 100]):
        st = int(k * 0.055 * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        x[st:] += (np.sin(2 * np.pi * mtof(m) * t2) + 0.4 * np.sin(2 * np.pi * mtof(m) * 2.76 * t2)) * \
            expdecay(seg, 9.0) * 0.22
    write_wav("wisp", x, 0.7)
    # Umbral Trial: a dark sub drop under a detuned minor cluster.
    n = int(1.4 * SR)
    tt = np.arange(n) / SR
    x = np.sin(sweep_phase(110, 38, n, 0.5)) * expdecay(n, 3.0) * 0.8
    for m, dt in [(50, 0.0), (53, 0.3), (57, -0.25)]:
        f = mtof(m) * (1 + dt / 100.0)
        x += lowpass(saw_from_phase(2 * np.pi * f * tt, 10), 1800) * env(n, 0.05, 0.5, 0.4, 0.7, 0.2) * 0.14
    x += lowpass(noise(n), 900) * expdecay(n, 6) * 0.3
    write_wav("trial", x, 0.85)
    # Rift complete: a bright rising arpeggio landing on a ringing chord.
    n = int(1.5 * SR)
    x = np.zeros(n)
    for k, m in enumerate([72, 76, 79, 84, 88]):
        st = int(k * 0.07 * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        x[st:] += (np.sin(2 * np.pi * mtof(m) * t2) + 0.3 * np.sin(4 * np.pi * mtof(m) * t2)) * \
            env(seg, 0.01, 0.4, 0.3, 0.6, 0.15) * 0.18
    x += highpass(noise(n), 6500) * env(n, 0.02, 0.5) * 0.1
    write_wav("rift_done", x, 0.85)


def sfx_ricochet():
    """Ricochet Glaive and the Starfall rift (own RNG)."""
    global rng
    rng = np.random.default_rng(257)
    # Glaive throw: a spinning whirr that rises and fades.
    n = int(0.3 * SR)
    tt = np.arange(n) / SR
    am = 0.55 + 0.45 * np.sin(2 * np.pi * 38 * tt)
    x = lowpass(highpass(noise(n), 700), 5200) * am * env(n, 0.02, 0.0, 1.0, 0.24, 0.04) * 0.7
    x += np.sin(sweep_phase(520, 980, n, 0.7)) * am * env(n, 0.02, 0.22) * 0.22
    write_wav("glaive", x, 0.65)
    # Ricochet: a short metallic tink.
    n = int(0.16 * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for f, a, k in [(2900, 0.5, 30.0), (4350, 0.32, 40.0), (6100, 0.2, 55.0)]:
        x += np.sin(2 * np.pi * f * tt) * expdecay(n, k) * a
    x += highpass(noise(n), 5000) * expdecay(n, 160) * 0.5
    write_wav("ricochet", x, 0.6)
    # Meteor fall: a thin whistle sliding down.
    n = int(0.7 * SR)
    x = np.sin(sweep_phase(2600, 900, n, 0.8)) * env(n, 0.15, 0.0, 1.0, 0.35, 0.2) * 0.35
    x += lowpass(highpass(noise(n), 2500), 6000) * env(n, 0.2, 0.5) * 0.12
    write_wav("meteor_fall", x, 0.5)
    # Meteor impact: a heavy thump, a crack of debris and a rumble.
    n = int(0.9 * SR)
    x = np.sin(sweep_phase(140, 32, n, 0.4)) * expdecay(n, 6.5) * 0.95
    x += lowpass(noise(n), 2400) * expdecay(n, 14) * 0.6
    x += highpass(noise(n), 3500) * expdecay(n, 45) * 0.35
    write_wav("meteor", x, 0.9)
    # Starfall begins: a falling glassy chime over a deep swell.
    n = int(1.5 * SR)
    tt = np.arange(n) / SR
    x = np.sin(sweep_phase(70, 45, n, 0.6)) * env(n, 0.3, 0.6, 0.4, 0.6, 0.2) * 0.5
    for k, m in enumerate([96, 91, 88, 84, 79]):
        st = int(k * 0.08 * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        x[st:] += (np.sin(2 * np.pi * mtof(m) * t2) + 0.35 * np.sin(2 * np.pi * mtof(m) * 2.76 * t2)) * \
            expdecay(seg, 4.0) * 0.16
    write_wav("starfall", x, 0.8)


def sfx_leviathan():
    """The Leviathan: its roar, the lunge, a shed scale, a hiss as it coils (own RNG)."""
    global rng
    rng = np.random.default_rng(293)
    # Roar: a growling, detuned saw cluster sliding down over a sub swell, with breath noise.
    n = int(2.0 * SR)
    tt = np.arange(n) / SR
    growl = 1 + 0.25 * np.sin(2 * np.pi * 31 * tt) * env(n, 0.3, 1.2)
    x = np.zeros(n)
    for f0, f1, a in [(196, 92, 0.22), (147, 69, 0.22), (233, 104, 0.14)]:
        ph = sweep_phase(f0, f1, n, 0.7) * growl
        x += lowpass(saw_from_phase(ph, 14), 2600) * env(n, 0.12, 0.9, 0.35, 0.8, 0.15) * a
    x += np.sin(sweep_phase(70, 34, n, 0.5)) * env(n, 0.3, 0.9, 0.3, 0.7) * 0.6
    x += lowpass(highpass(noise(n), 500), 3200) * env(n, 0.2, 1.0, 0.2, 0.6) * 0.3
    write_wav("levi_roar", x, 0.9)
    # Lunge: a heavy rushing whoosh with a low thump at the start.
    n = int(0.6 * SR)
    x = lowpass(highpass(noise(n), 220), 1800) * env(n, 0.04, 0.0, 1.0, 0.5, 0.06) * 0.9
    x += np.sin(sweep_phase(90, 40, n, 0.5)) * expdecay(n, 8) * 0.7
    x += np.sin(sweep_phase(420, 160, n, 0.6)) * env(n, 0.03, 0.4) * 0.2
    write_wav("lunge", x, 0.85)
    # Shed: a glassy crack and a scatter of shards.
    n = int(0.55 * SR)
    tt = np.arange(n) / SR
    x = highpass(noise(n), 2200) * expdecay(n, 28) * 0.8
    for f, a in [(1760, 0.3), (2490, 0.22), (3320, 0.16)]:
        x += np.sin(2 * np.pi * f * tt) * expdecay(n, 14) * a
    x += np.sin(sweep_phase(160, 60, n, 0.5)) * expdecay(n, 10) * 0.5
    write_wav("shed", x, 0.8)
    # Coil: a long rising hiss with a rattle.
    n = int(1.1 * SR)
    tt = np.arange(n) / SR
    rattle = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 22 * tt))
    x = highpass(noise(n), 3800) * env(n, 0.25, 0.0, 1.0, 0.45, 0.4) * (0.55 + 0.45 * rattle) * 0.7
    x += np.sin(sweep_phase(300, 520, n, 1.2)) * env(n, 0.3, 0.7) * 0.1
    write_wav("coil", x, 0.6)


def sfx_gauntlet():
    """The Gauntlet: a split chime, a record split, the gong as a boss steps in, the clear fanfare (own RNG)."""
    global rng
    rng = np.random.default_rng(337)
    # Split: two quick bright bell tones, a stopwatch click on top.
    n = int(0.7 * SR)
    x = np.zeros(n)
    for k, m in enumerate([84, 91]):
        st = int(0.07 * k * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        x[st:] += (np.sin(2 * np.pi * mtof(m) * t2) + 0.35 * np.sin(2 * np.pi * mtof(m) * 2.76 * t2)) * \
            expdecay(seg, 6) * 0.3
    x[:int(0.01 * SR)] += highpass(noise(int(0.01 * SR)), 4000) * 0.5
    write_wav("split", x, 0.8)
    # Record: the split chime climbing a major arpeggio with a shimmer.
    n = int(1.3 * SR)
    x = np.zeros(n)
    for k, m in enumerate([79, 83, 86, 91, 95]):
        st = int(0.075 * k * SR)
        seg = n - st
        t2 = np.arange(seg) / SR
        x[st:] += (np.sin(2 * np.pi * mtof(m) * t2) + 0.3 * np.sin(2 * np.pi * mtof(m) * 3.0 * t2)) * \
            expdecay(seg, 4.5) * 0.22
    x += highpass(noise(n), 7000) * env(n, 0.2, 0.9) * 0.08
    write_wav("split_best", x, 0.85)
    # Gong: a low metallic strike with inharmonic partials, struck as the next boss steps in.
    n = int(2.2 * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for f, a, k in [(55, 0.5, 1.6), (110.6, 0.3, 2.2), (152.3, 0.22, 2.8), (207.9, 0.16, 3.4), (296.1, 0.1, 4.5)]:
        x += np.sin(2 * np.pi * f * tt * (1 + 0.002 * np.sin(2 * np.pi * 3 * tt))) * expdecay(n, k) * a
    x += lowpass(noise(n), 900) * expdecay(n, 30) * 0.5
    write_wav("gong", x, 0.9)
    # Clear: a brass-like fanfare (stacked saws through a closing filter) over a timpani roll.
    n = int(2.6 * SR)
    x = np.zeros(n)
    notes = [(67, 0.0, 0.18), (72, 0.18, 0.18), (76, 0.36, 0.18), (79, 0.54, 1.8)]
    for m, st_s, dur in notes:
        st = int(st_s * SR)
        seg = int(dur * SR)
        t2 = np.arange(seg) / SR
        tone = np.zeros(seg)
        for det in (-0.12, 0.0, 0.12):
            tone += saw_from_phase(2 * np.pi * mtof(m + det) * t2, 10)
        tone = lowpass(tone, 3200) * env(seg, 0.02, 0.25, 0.6, 0.3 if dur > 1 else 0.05) * 0.12
        x[st:st + seg] += tone[:max(0, min(seg, n - st))]
    roll = np.zeros(n)
    for k in range(18):
        st = int((0.02 * k) * SR)
        seg = int(0.25 * SR)
        roll[st:st + seg] += np.sin(sweep_phase(110, 70, seg, 0.5)) * expdecay(seg, 14) * (0.15 + 0.02 * k)
    x += roll
    hit = int(0.54 * SR)
    seg = n - hit
    x[hit:] += np.sin(sweep_phase(90, 45, seg, 0.5)) * expdecay(seg, 3) * 0.6
    x[hit:] += highpass(noise(seg), 5000) * expdecay(seg, 2) * 0.1
    write_wav("gauntlet_clear", x, 0.9)


def sfx_sectors():
    """Sectors: a black hole opening, eating and collapsing; the sun swelling, a flare, a clean pass (own RNG)."""
    global rng
    rng = np.random.default_rng(389)
    # Maw opens: a sub drop with a reversed whoosh sucking inwards.
    n = int(1.6 * SR)
    tt = np.arange(n) / SR
    x = np.sin(sweep_phase(120, 32, n, 0.6)) * env(n, 0.05, 1.2, 0.2, 0.3) * 0.8
    suck = lowpass(highpass(noise(n), 300), 2400) * np.linspace(0, 1, n) ** 2.5 * 0.45
    x += suck[::-1]
    x += np.sin(2 * np.pi * 55 * tt * (1 + 0.01 * np.sin(2 * np.pi * 0.7 * tt))) * env(n, 0.3, 1.0) * 0.25
    write_wav("maw_open", x, 0.85)
    # Maw eats: a short, soft, falling blip.
    n = int(0.18 * SR)
    x = np.sin(sweep_phase(900, 260, n, 0.5)) * expdecay(n, 22) * 0.5
    write_wav("maw_eat", x, 0.6)
    # Collapse: an inward rush, a deep boom, then a glitter of chimes as the light pours out.
    n = int(2.2 * SR)
    x = np.zeros(n)
    pre = int(0.45 * SR)
    x[:pre] += lowpass(highpass(noise(pre), 400), 3000) * np.linspace(0, 1, pre) ** 3 * 0.6
    x[:pre] += np.sin(sweep_phase(60, 240, pre, 2.0)) * np.linspace(0, 1, pre) ** 2 * 0.4
    seg = n - pre
    x[pre:] += np.sin(sweep_phase(80, 28, seg, 0.4)) * expdecay(seg, 2.6) * 0.95
    x[pre:] += lowpass(noise(seg), 700) * expdecay(seg, 6) * 0.6
    for k, m in enumerate([84, 88, 91, 96, 100, 103]):
        st = pre + int((0.05 + 0.06 * k) * SR)
        sg = n - st
        t2 = np.arange(sg) / SR
        x[st:] += np.sin(2 * np.pi * mtof(m) * t2) * expdecay(sg, 7) * 0.08
    write_wav("maw_collapse", x, 0.9)
    # The sun swells: a rumbling, rising roar.
    n = int(1.7 * SR)
    tt = np.arange(n) / SR
    rise = np.linspace(0, 1, n) ** 1.6
    x = lowpass(noise(n), 500) * rise * 0.7
    x += np.sin(sweep_phase(45, 110, n, 1.5)) * rise * 0.5
    x += lowpass(highpass(noise(n), 900), 4000) * rise ** 3 * 0.25
    write_wav("flare_warn", x, 0.8)
    # The flare: a roaring burst of fire with a crackle.
    n = int(1.5 * SR)
    x = lowpass(highpass(noise(n), 150), 3500) * env(n, 0.01, 0.0, 1.0, 1.2, 0.15) * 0.8
    x += np.sin(sweep_phase(110, 40, n, 0.5)) * expdecay(n, 3) * 0.7
    crackle = (rng.random(n) < 0.004).astype(float) * rng.uniform(-1, 1, n)
    x += highpass(crackle, 2000) * env(n, 0.05, 1.0) * 0.6
    write_wav("flare", x, 0.9)
    # Slipped through: a quick, cool rising chime.
    n = int(0.5 * SR)
    x = np.zeros(n)
    for k, m in enumerate([86, 93]):
        st = int(0.05 * k * SR)
        sg = n - st
        t2 = np.arange(sg) / SR
        x[st:] += (np.sin(2 * np.pi * mtof(m) * t2) + 0.25 * np.sin(2 * np.pi * mtof(m) * 2.0 * t2)) * \
            expdecay(sg, 9) * 0.3
    write_wav("flare_pass", x, 0.7)


if __name__ == "__main__":
    import sys
    if "--threats" in sys.argv:
        sfx_threats()
        print("threat audio ok")
        sys.exit(0)
    if "--evo" in sys.argv:
        sfx_evolution()
        print("evolution audio ok")
        sys.exit(0)
    if "--arsenal" in sys.argv:
        sfx_arsenal()
        print("arsenal audio ok")
        sys.exit(0)
    if "--radiance" in sys.argv:
        sfx_radiance()
        print("radiance audio ok")
        sys.exit(0)
    if "--rifts" in sys.argv:
        sfx_rifts()
        print("rift audio ok")
        sys.exit(0)
    if "--ricochet" in sys.argv:
        sfx_ricochet()
        print("ricochet audio ok")
        sys.exit(0)
    if "--leviathan" in sys.argv:
        sfx_leviathan()
        print("leviathan audio ok")
        sys.exit(0)
    if "--gauntlet" in sys.argv:
        sfx_gauntlet()
        print("gauntlet audio ok")
        sys.exit(0)
    if "--sectors" in sys.argv:
        sfx_sectors()
        print("sector audio ok")
        sys.exit(0)
    if "--od" in sys.argv:
        sfx_overdrive()
        print("overdrive audio ok")
        sys.exit(0)
    sfx()
    music()
    sfx_evolution()
    sfx_overdrive()
    sfx_threats()
    sfx_arsenal()
    sfx_radiance()
    sfx_rifts()
    sfx_ricochet()
    sfx_leviathan()
    sfx_gauntlet()
    sfx_sectors()
    print("audio ok")
