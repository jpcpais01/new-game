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


if __name__ == "__main__":
    sfx()
    music()
    print("audio ok")
