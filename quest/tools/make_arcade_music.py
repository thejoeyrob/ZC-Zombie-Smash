#!/usr/bin/env python3
"""Renders the arcade's own background music for the VR app: a bright, major-key 80s hard-rock instrumental
(power chords, palm-muted chug, an air-guitar lead with vibrato and echo, big snare). It reuses the sound toolkit in
art-pipeline/audio read-only and writes into quest/vr-art, so the phone game's sound library is never touched."""
import os, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'art-pipeline', 'audio'))
from synth import *

BPM = 144
BEAT = 60.0 / BPM
BARS = 24
LOOP = BARS * 4 * BEAT
OUT = os.path.join(os.path.dirname(__file__), '..', 'vr-art')

# 24 bars: A section (8) / B section (8) / A again with a harmony and a fill (8)
A_SEC = ['A', 'E', 'F#m', 'D', 'A', 'E', 'D', 'E']
B_SEC = ['D', 'A', 'E', 'F#m', 'D', 'A', 'B', 'E']
CHORDS = A_SEC + B_SEC + A_SEC
ROOT = {'A': 'A2', 'E': 'E2', 'F#m': 'F#2', 'D': 'D2', 'B': 'B2'}
MINOR = {'F#m'}

def power(root, octave_up=0):
    r = midi(root) + 12 * octave_up
    return [r, r + 7, r + 12]

def guitar(m, dur, drive=5.0, mute=False, cut=3600):
    n = sec(dur + 0.08)
    f = float(hz(m))
    x = saw(np.full(n, f), n) * 0.6 + saw(np.full(n, f * 1.004), n) * 0.4
    x = np.tanh(x * drive)
    x = lp(hp(x, 90, 1), 1800 if mute else cut, 2)
    env = adsr(n, 0.003, 0.05 if mute else 0.4, 0.15 if mute else 0.8, 0.04 if mute else 0.1)
    return x * env * 0.4

def lead_note(m, dur, vibrato=True):
    n = sec(dur + 0.12)
    f = vib(n, float(hz(m)), 5.6, 0.011, 0.18) if vibrato and dur > 0.4 else np.full(n, float(hz(m)))
    x = saw(f, n) * 0.7 + pulse(f * 1.002, n, 0.4) * 0.3
    x = np.tanh(x * 3.2)
    x = lp(x, 3800, 2)
    return x * adsr(n, 0.006, 0.12, 0.8, 0.1) * 0.5

def bass_note(m, dur):
    n = sec(dur + 0.03); f = float(hz(m))
    x = saw(np.full(n, f), n) * 0.6 + sine(np.full(n, f), n) * 0.5
    return lp(np.tanh(x * 1.6), 700, 2) * adsr(n, 0.004, 0.06, 0.8, 0.03) * 0.55

# lead lines: (start beat within 8 bars, note, length in beats)
LINE_A = [(0, 'E5', 1.5), (1.5, 'C#5', .5), (2, 'E5', 1), (3, 'A5', 1), (4, 'B5', 1.5), (5.5, 'A5', .5), (6, 'F#5', 1), (7, 'E5', 1),
          (8, 'F#5', 1), (9, 'A5', 1), (10, 'C#6', 1.5), (11.5, 'B5', .5), (12, 'A5', 2), (14, 'F#5', 1), (15, 'D5', 1),
          (16, 'E5', 1.5), (17.5, 'C#5', .5), (18, 'E5', 1), (19, 'A5', 1), (20, 'B5', 1), (21, 'C#6', 1), (22, 'B5', 1), (23, 'A5', 1),
          (24, 'F#5', 1), (25, 'E5', 1), (26, 'D5', 1), (27, 'E5', 1), (28, 'F#5', 1.5), (29.5, 'E5', .5), (30, 'B4', 2)]
LINE_B = [(0, 'D5', 1), (1, 'F#5', 1), (2, 'A5', 2), (4, 'E5', 1), (5, 'A5', 1), (6, 'C#6', 2),
          (8, 'B5', 1), (9, 'E5', 1), (10, 'G#5', 2), (12, 'A5', 1), (13, 'F#5', 1), (14, 'C#5', 2),
          (16, 'D6', 1.5), (17.5, 'C#6', .5), (18, 'A5', 2), (20, 'E5', 1), (21, 'A5', 1), (22, 'C#6', 1), (23, 'E6', 1),
          (24, 'F#6', 1.5), (25.5, 'E6', .5), (26, 'D6', 1), (27, 'B5', 1), (28, 'B5', 1), (29, 'D#6', 1), (30, 'E6', 2)]

def render():
    m = Mix(LOOP + 2.5)
    for bar in range(BARS):
        t0 = bar * 4 * BEAT
        ch = CHORDS[bar]
        root = ROOT[ch.replace('m', '') if ch not in ROOT else ch]
        r = midi(root)
        third = 3 if ch in MINOR else 4
        sec_idx = bar // 8
        # drums
        for b in range(4):
            tb = t0 + b * BEAT
            if b in (0, 2): m.add(kick(1.0), tb, 0.9)
            if b in (1, 3): m.add(snare(1.0, 200, 0.18), tb, 0.85, rev=0.2)
            m.add(hat(0.9), tb, 0.35, pan=0.2); m.add(hat(0.7), tb + BEAT / 2, 0.3, pan=0.2)
        m.add(kick(0.9), t0 + 2.5 * BEAT, 0.8)
        if bar % 8 == 0:
            m.add(crash(1.0, 1.6), t0, 0.5, rev=0.3)
        if bar % 8 == 7:       # a tom fill into the next section
            for k, (f, tq) in enumerate([(190, 2.5), (160, 3.0), (130, 3.25), (100, 3.5), (100, 3.75)]):
                m.add(tom(f, 1.0, 0.25), t0 + tq * BEAT, 0.6, pan=-0.3 + 0.15 * k, rev=0.15)
        # bass: driving 8ths
        for e in range(8):
            m.add(bass_note(r + 0 + (12 if e % 4 == 3 else 0), BEAT / 2 * 0.9), t0 + e * BEAT / 2, 0.8)
        # rhythm guitar: palm-muted chug, then an open chord ring on the one
        for e in range(8):
            te = t0 + e * BEAT / 2
            if e == 0:
                for nn in power(root, 2) + [r + 24 + third]:
                    m.add(guitar(nn, BEAT * 1.6, 6.0, False), te, 0.28, pan=-0.45, rev=0.12)
                    m.add(guitar(nn, BEAT * 1.6, 6.0, False), te, 0.24, pan=0.45, rev=0.12)
            elif e >= 3 or e == 2:
                for nn in power(root, 2):
                    m.add(guitar(nn, BEAT / 2 * 0.8, 6.0, True), te, 0.25, pan=-0.5)
                    m.add(guitar(nn, BEAT / 2 * 0.8, 6.0, True), te, 0.22, pan=0.5)
        # a bright synth stab on the 'and' of two, for that 80s shine
        if bar % 2 == 1:
            for nn in (r + 24, r + 24 + third, r + 24 + 7):
                m.add(note_pluck(nn, 0.25) * 0.5, t0 + 2.5 * BEAT, 0.4, pan=0.0, rev=0.3, dly=0.2)
    # the lead guitar: A section, B section, then the A line again an octave of harmony higher
    def play(line, start_bar, harmony=False):
        for (b, nname, ln) in line:
            tt = start_bar * 4 * BEAT + b * BEAT
            mm = midi(nname)
            m.add(lead_note(mm, ln * BEAT * 0.97), tt, 0.62, pan=0.1, rev=0.28, dly=0.35)
            if harmony:
                m.add(lead_note(mm + 4 if nname[0] in 'ADE' else mm + 3, ln * BEAT * 0.97, False), tt, 0.3, pan=-0.2, rev=0.25, dly=0.3)
    play(LINE_A[:], 0)
    play(LINE_B[:], 8)
    play(LINE_A[:], 16, harmony=True)
    out = finish(m, rev_amt=0.3, rev_time=1.6, rev_damp=5200, dly_time=BEAT * 0.75, dly_fb=0.38, dly_amt=0.32)
    out = loopfold(out, LOOP)
    out = normalise(out, -19.0)
    # loop seamlessly: fade nothing, the fold already carried the tails over
    return out

if __name__ == '__main__':
    x = render()
    save(os.path.join(OUT, 'mus-arcade.wav'), x)
    print('arcade music', round(x.shape[1] / SR, 1), 's, peak', round(float(np.abs(x).max()), 2))
