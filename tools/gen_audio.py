#!/usr/bin/env python3
"""Synthesises every sound in Prisma: crystal SFX and the ambient music loop.
Run from the repo root: python3 tools/gen_audio.py  (needs numpy + scipy,
and ffmpeg for the .ogg music). Output goes to assets/audio/.

Everything is generated from a fixed random seed, so the output is
reproducible.
"""
import os
import subprocess
import wave

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
RNG = np.random.default_rng(1234)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def note(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7,
             "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def env(n, attack, decay, sustain_curve=None):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / decay)
    return a * d


def lowpass(x, cutoff, order=2):
    b, a = butter(order, min(cutoff / (SR / 2), 0.99), btype="low")
    return lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = butter(order, min(cutoff / (SR / 2), 0.99), btype="high")
    return lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], btype="band")
    return lfilter(b, a, x)


def sine(freq, dur, phase=0.0):
    t = t_axis(dur)
    if np.ndim(freq) == 0:
        return np.sin(2 * np.pi * freq * t + phase)
    ph = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(ph + phase)


def bell(freq, dur, decay=0.9, bright=1.0):
    """Glassy bell: inharmonic partials, higher ones die faster."""
    t = t_axis(dur)
    partials = [(1.0, 1.0), (2.0, 0.42 * bright), (2.76, 0.32 * bright), (4.07, 0.16 * bright),
                (5.43, 0.09 * bright), (6.8, 0.05 * bright)]
    out = np.zeros_like(t)
    for ratio, amp in partials:
        f = freq * ratio
        if f > SR / 2.2:
            continue
        out += amp * np.sin(2 * np.pi * f * t + RNG.random() * 6.28) * np.exp(-t * ratio ** 0.7 / decay)
    attack = np.clip(t / 0.002, 0, 1)
    return out * attack


def pluck(freq, dur, decay=0.35):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t) + 0.12 * np.sin(6 * np.pi * freq * t)
    return x * np.exp(-t / decay) * np.clip(t / 0.004, 0, 1)


def noise(dur):
    return RNG.standard_normal(int(dur * SR))


def reverb(x, wet=0.3, room=0.84, damp=3500):
    """Small Schroeder reverb (4 combs + 2 allpasses)."""
    n = len(x)
    tail = int(SR * 1.8)
    x = np.concatenate([x, np.zeros(tail)])
    out = np.zeros_like(x)
    for delay_ms, g in ((29.7, room), (37.1, room - 0.02), (41.1, room - 0.03), (43.7, room - 0.05)):
        d = int(SR * delay_ms / 1000)
        b = np.zeros(d + 1)
        b[0] = 1.0
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -g
        out += lfilter(b, a, lowpass(x, damp, 1))
    out /= 4
    for delay_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(SR * delay_ms / 1000)
        b = np.zeros(d + 1)
        b[0] = -g
        b[d] = 1.0
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -g
        out = lfilter(b, a, out)
    return x * (1 - wet) + out * wet


def mix(*parts):
    n = max(len(p) for _, p in parts)
    out = np.zeros(n)
    for offset, p in parts:
        o = int(offset * SR)
        end = min(n, o + len(p))
        if o < n:
            out[o:end] += p[:end - o]
    return out


def place_at(total, offset, sig):
    o = int(offset * SR)
    if o >= len(total):
        return
    end = min(len(total), o + len(sig))
    total[o:end] += sig[:end - o]


def trim(x, thresh=1e-4):
    idx = np.where(np.abs(x) > thresh)[0]
    if len(idx) == 0:
        return x
    x = x[:idx[-1] + 1]
    fade = min(len(x), int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def write_wav(name, x, peak=0.89):
    x = normalize(trim(x), peak)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ------------------------------------------------------------------ SFX ----

def sfx_pick():
    dur = 0.11
    f = np.linspace(560, 980, int(dur * SR))
    x = sine(f, dur) * env(int(dur * SR), 0.004, 0.035)
    x += 0.25 * bell(1960, dur, 0.05)
    return x


def sfx_place():
    dur = 0.35
    n = int(dur * SR)
    f = np.linspace(170, 85, n)
    thump = sine(f, dur) * env(n, 0.002, 0.05)
    click = lowpass(noise(dur), 1800) * env(n, 0.001, 0.008) * 0.8
    tink = (bell(2490, dur, 0.06) * 0.22 + bell(3720, dur, 0.04) * 0.1)
    return reverb(thump + click + tink, 0.12)


def sfx_drop_bad():
    a = lowpass(pluck(330, 0.18, 0.06) + 0.4 * sine(165, 0.18) * env(int(0.18 * SR), 0.003, 0.05), 1400)
    b = lowpass(pluck(247, 0.22, 0.07) + 0.4 * sine(123, 0.22) * env(int(0.22 * SR), 0.003, 0.06), 1200)
    return mix((0, a), (0.09, b)) * 0.8


def sfx_clear():
    base = note("E5")
    x = mix((0, bell(base, 1.6, 0.55)), (0, 0.55 * bell(base * 1.5, 1.6, 0.4)), (0, 0.3 * bell(base * 2, 1.6, 0.3)))
    sh = highpass(noise(0.6), 6000) * env(int(0.6 * SR), 0.01, 0.12) * 0.12
    whoosh = bandpass(noise(0.3), 1200, 5000) * env(int(0.3 * SR), 0.02, 0.06) * 0.25
    return reverb(mix((0, x * 0.6), (0, sh), (0, whoosh)), 0.3)


def sfx_prism():
    notes = ["C6", "D6", "E6", "G6", "A6", "C7", "E7"]
    total = np.zeros(int(2.4 * SR))
    for i, nn in enumerate(notes):
        place_at(total, i * 0.055, bell(note(nn), 1.5, 0.45) * (0.7 - i * 0.04))
    place_at(total, 0, highpass(noise(1.2), 7000) * env(int(1.2 * SR), 0.15, 0.35) * 0.18)
    pad = sum(sine(note(n), 1.6) for n in ("C5", "E5", "G5", "B5")) * env(int(1.6 * SR), 0.15, 0.6) * 0.12
    place_at(total, 0.05, pad)
    return reverb(total, 0.38)


def sfx_perfect():
    total = np.zeros(int(3.4 * SR))
    chord = ["C4", "G4", "D5", "E5", "B5"]
    for n in chord:
        f = note(n)
        v = (sine(f, 2.8) + 0.3 * sine(f * 2.003, 2.8)) * env(int(2.8 * SR), 0.25, 1.0)
        place_at(total, 0.0, v * 0.14)
    for i, n in enumerate(["C6", "E6", "G6", "B6", "D7", "G7"]):
        place_at(total, 0.12 + i * 0.07, bell(note(n), 1.8, 0.6) * 0.45)
    swell = bandpass(noise(1.0), 800, 7000) * np.linspace(0, 1, int(1.0 * SR)) ** 2 * 0.15
    place_at(total, 0.0, swell * env(len(swell), 0.8, 0.15))
    return reverb(total, 0.42)


def sfx_deal():
    total = np.zeros(int(0.5 * SR))
    for i in range(3):
        d = 0.09
        fw = bandpass(noise(d), 900 + i * 400, 4500 + i * 600) * env(int(d * SR), 0.01, 0.025) * 0.35
        pop = sine(np.linspace(380 + i * 90, 640 + i * 120, int(d * SR)), d) * env(int(d * SR), 0.003, 0.03) * 0.5
        place_at(total, i * 0.065, fw + pop)
    return total


def sfx_gameover():
    total = np.zeros(int(3.0 * SR))
    for i, n in enumerate(["A5", "F5", "D5", "A4"]):
        place_at(total, i * 0.18, bell(note(n), 1.6, 0.6) * 0.5)
    pad = sum(sine(note(n), 2.4) for n in ("D3", "A3", "F4")) * env(int(2.4 * SR), 0.3, 0.9) * 0.15
    place_at(total, 0.1, lowpass(pad, 1200))
    return reverb(total, 0.4)


def sfx_newbest():
    total = np.zeros(int(2.8 * SR))
    for i, n in enumerate(["C5", "E5", "G5", "C6", "E6", "G6"]):
        place_at(total, i * 0.075, bell(note(n), 1.4, 0.5) * 0.5)
    for n in ("C4", "G4", "C5", "E5"):
        f = note(n)
        v = (sine(f, 1.8) + 0.25 * sine(f * 3, 1.8)) * env(int(1.8 * SR), 0.05, 0.7) * 0.12
        place_at(total, 0.42, v)
    return reverb(total, 0.35)


def sfx_click():
    d = 0.06
    n = int(d * SR)
    x = sine(np.linspace(1800, 1200, n), d) * env(n, 0.001, 0.012) * 0.6
    x += sine(np.linspace(260, 160, n), d) * env(n, 0.001, 0.02) * 0.5
    return x


def sfx_land():
    d = 0.12
    n = int(d * SR)
    x = bell(1320, d, 0.03) * 0.5 + sine(np.linspace(300, 200, n), d) * env(n, 0.001, 0.02) * 0.4
    return x


def sfx_combo():
    d = 0.5
    n = int(d * SR)
    f = np.geomspace(220, 880, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    x = lowpass(saw, 2600) * env(n, 0.02, 0.18) * 0.4
    x += bell(1318, d, 0.25) * 0.3
    return reverb(x, 0.25)


def sfx_whoosh():
    d = 0.5
    n = int(d * SR)
    x = noise(d)
    # sweep a band upwards
    out = np.zeros(n)
    seg = n // 10
    for i in range(10):
        lo = 300 * 1.35 ** i
        part = bandpass(x[i * seg:(i + 1) * seg + 2000], lo, lo * 3)[: seg]
        out[i * seg:i * seg + len(part)] += part
    return out * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.6


# ---------------------------------------------------------------- music ----

def music():
    bpm = 84
    beat = 60 / bpm
    bar = beat * 4
    chords = [
        ["D3", "A3", "E4", "F#4", "C#5"],     # Dmaj9
        ["B2", "F#3", "D4", "A4", "C#5"],     # Bm9
        ["G2", "D3", "B3", "F#4", "A4"],      # Gmaj9
        ["A2", "E3", "C#4", "G4", "B4"],      # A9-ish
    ]
    bars_per_chord = 2
    loop = bar * bars_per_chord * len(chords)
    loops = 3
    total = np.zeros(int(loop * loops * SR) + SR * 4)
    rng = np.random.default_rng(7)
    arp_pattern = [0, 2, 3, 4, 3, 2, 4, 1]
    for L in range(loops):
        for ci, chord in enumerate(chords):
            start = L * loop + ci * bar * bars_per_chord
            dur = bar * bars_per_chord + 1.2
            n = int(dur * SR)
            t = np.arange(n) / SR
            amp = np.clip(t / 1.4, 0, 1) * np.clip((dur - t) / 1.4, 0, 1)
            pad = np.zeros(n)
            for nn in chord:
                f = note(nn)
                for det in (-0.004, 0.0, 0.0045):
                    pad += np.sin(2 * np.pi * f * (1 + det) * t + rng.random() * 6.28)
                pad += 0.18 * np.sin(2 * np.pi * f * 2 * t)
            lfo = 0.75 + 0.25 * np.sin(2 * np.pi * 0.11 * t + ci)
            place_at(total, start, lowpass(pad * amp * lfo, 1800) * 0.05)
            # Sub bass
            root = note(chord[0]) / 2
            sub = np.sin(2 * np.pi * root * t) * amp * 0.09
            place_at(total, start, sub)
            # Arpeggio: eighth notes, a little sparse and humanised.
            steps = bars_per_chord * 8
            for s in range(steps):
                if rng.random() < 0.22 and s % 4 != 0:
                    continue
                idx = arp_pattern[s % len(arp_pattern)]
                f = note(chord[idx]) * (2 if s % 8 >= 4 else 1)
                vel = 0.10 + 0.05 * (s % 4 == 0) + rng.random() * 0.03
                place_at(total, start + s * beat / 2 + rng.random() * 0.008, pluck(f, 1.2, 0.42) * vel)
            # Sparkle bells now and then
            for k in range(2):
                if rng.random() < 0.6:
                    f = note(chord[rng.integers(2, 5)]) * 4
                    place_at(total, start + rng.random() * bar * bars_per_chord, bell(f, 2.0, 0.7) * 0.035)
    wet = reverb(total, 0.42, room=0.88, damp=4200)
    a = int(loop * SR)
    seg = wet[a:2 * a]  # the middle loop already contains the previous loop's tail
    seg = normalize(seg, 0.8)
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "_music.wav")
    data = (np.clip(seg, -1, 1) * 32767).astype(np.int16)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(OUT, "music.ogg")], check=True)
    os.remove(tmp)


def main():
    write_wav("pick", sfx_pick(), 0.5)
    write_wav("place", sfx_place(), 0.8)
    write_wav("drop_bad", sfx_drop_bad(), 0.55)
    write_wav("clear", sfx_clear(), 0.75)
    write_wav("prism", sfx_prism(), 0.8)
    write_wav("perfect", sfx_perfect(), 0.85)
    write_wav("deal", sfx_deal(), 0.45)
    write_wav("gameover", sfx_gameover(), 0.7)
    write_wav("newbest", sfx_newbest(), 0.8)
    write_wav("click", sfx_click(), 0.5)
    write_wav("land", sfx_land(), 0.35)
    write_wav("combo", sfx_combo(), 0.6)
    write_wav("whoosh", sfx_whoosh(), 0.4)
    music()
    print("audio generated")


if __name__ == "__main__":
    main()
