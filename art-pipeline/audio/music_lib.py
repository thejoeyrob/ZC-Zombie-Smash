"""Tiny arranger: chord progressions + hand-written melodies + generated bass, arps, pads and drums -> a looping stereo mix."""
import re
import numpy as np
from synth import *

PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
QUAL = {'': (0, 4, 7), 'm': (0, 3, 7), '7': (0, 4, 7, 10), 'm7': (0, 3, 7, 10), 'maj7': (0, 4, 7, 11), 'dim': (0, 3, 6),
        'm7b5': (0, 3, 6, 10), 'sus4': (0, 5, 7), '9': (0, 4, 7, 10, 14), 'm9': (0, 3, 7, 10, 14), '5': (0, 7), 'maj9': (0, 4, 7, 11, 14)}
SCALES = {'minor': (0, 2, 3, 5, 7, 8, 10), 'major': (0, 2, 4, 5, 7, 9, 11)}
WARN = []

def chord(name):
    m = re.match(r'^([A-G])([#b]?)(.*)$', name)
    pc = (PC[m.group(1)] + (1 if m.group(2) == '#' else -1 if m.group(2) == 'b' else 0)) % 12
    return pc, QUAL[m.group(3)]

def parse_bar(s, where=''):
    """'G4:1 R:.5 A4:.5 ...' -> [(beat, midi|None, dur)]. A trailing '!' marks a deliberate out-of-key note."""
    out, pos = [], 0.0
    for tok in s.split():
        nm, d = tok.split(':'); d = float(d); ooo = nm.endswith('!'); nm = nm.rstrip('!')
        out.append((pos, None if nm == 'R' else (midi(nm), ooo), d)); pos += d
    if s.strip() and abs(pos - 4.0) > 1e-6: WARN.append(f'{where}: bar adds up to {pos} beats: {s}')
    return out

def voicing(name, centre, span=1):
    pc, iv = chord(name); notes = []
    for i in iv:
        base = (pc + i) % 12; m = base + 12 * round((centre - base) / 12)
        notes.append(int(m))
    return sorted(notes)

class Song:
    def __init__(self, name, bpm, prog, key, mode, swing=0.0, tail=2.5):
        self.name, self.bpm, self.prog = name, bpm, prog; self.bars = len(prog)
        self.key, self.mode, self.swing = PC[key[0]] + (1 if '#' in key else -1 if 'b' in key else 0), mode, swing
        self.beat = 60.0 / bpm; self.len = self.bars * 4 * self.beat
        self.mix = Mix(self.len + tail); self.tail = tail
        self.scale = {(self.key + s) % 12 for s in SCALES[mode]}

    def t(self, bar, beat=0.0):
        sw = 0.0
        if self.swing and abs((beat * 2) % 2 - 1) < 1e-6: sw = self.swing * self.beat * 0.5   # off-beat eighths late
        return (bar * 4 + beat) * self.beat + sw

    # ------------------------------------------------------------------ melody
    def melody(self, bars, make, gain=0.5, pan=0.0, rev=0.2, dly=0.0, octave=0, staccato=1.0, start=0, check=True):
        for bi, s in enumerate(bars):
            bar = start + bi
            if bar >= self.bars or not s: continue
            for beat, nt, d in parse_bar(s, f'{self.name} bar {bar + 1}'):
                if nt is None: continue
                m, ooo = nt; m += octave
                pcm = m % 12
                if check and not ooo and pcm not in self.scale:
                    WARN.append(f'{self.name} bar {bar + 1}: {s.split()[0]}.. note {m} out of key')
                if check and not ooo and d >= 1 and beat in (0.0, 2.0):
                    pc, iv = chord(self.prog[bar]); tones = {(pc + i) % 12 for i in iv}
                    if pcm not in tones: WARN.append(f'{self.name} bar {bar + 1} beat {beat + 1}: {m} is not in {self.prog[bar]}')
                x = make(m, d * self.beat * staccato)
                self.mix.add(x, self.t(bar, beat), gain, pan, rev, dly)

    # ------------------------------------------------------------------ bass
    BASS = {
        'root8': [(i * .5, o, .45) for i, o in enumerate([0, 0, 12, 0, 0, 12, 0, 7])],
        'drive16': [(i * .25, 0, .2) for i in range(16)],
        'half': [(0, 0, .9), (1, 7, .9), (2, 0, .9), (3, 7, .9)],
        'walk': [(0, 0, .9), (1, 'third', .9), (2, 7, .9), (3, 'third', .9)],
        'sync': [(0, 0, .45), (.75, 0, .2), (1.5, 0, .45), (2, 0, .45), (2.75, 12, .2), (3.5, 7, .4)],
        'funk': [(0, 0, .4), (.75, 12, .2), (1.5, 0, .2), (2, 0, .4), (2.5, 7, .2), (3, 5, .2), (3.5, 7, .2)],
        'pedal': [(0, 0, 3.8)],
        'pulse': [(i * .5, 0, .4) for i in range(8)],
        'gallop': [(0, 0, .2), (.5, 0, .2), (.75, 0, .2), (1, 0, .2), (1.5, 0, .2), (1.75, 0, .2), (2, 0, .2), (2.5, 0, .2), (2.75, 0, .2), (3, 0, .2), (3.5, 0, .2), (3.75, 12, .2)],
    }
    def bass(self, pattern, bars, gain=0.55, make=None, pluck=0.16):
        make = make or (lambda m, d: note_bass(m, d, pluck))
        for bar in range(self.bars):
            if bar not in bars: continue
            pc, iv = chord(self.prog[bar]); rm = 36 + pc
            if rm > 43: rm -= 12
            third = 3 if 3 in iv else 4
            pat = self.BASS[pattern if isinstance(pattern, str) else pattern[bar % len(pattern)]]
            for beat, off, d in pat:
                o = third if off == 'third' else off
                self.mix.add(make(rm + o, d * self.beat), self.t(bar, beat), gain, -0.05, 0.03)

    # ------------------------------------------------------------------ arps and pads
    def arp(self, bars, rate=.5, centre=66, gain=0.22, duty=0.125, pan=0.45, pattern='up', rev=0.3, dly=0.35, dur=None, make=None):
        for bar in range(self.bars):
            if bar not in bars: continue
            tones = voicing(self.prog[bar], centre); tones = tones + [t + 12 for t in tones]
            order = {'up': [0, 1, 2, 3, 2, 1], 'updown': [0, 1, 2, 3, 4, 5, 4, 3, 2, 1], 'saw': [0, 1, 2, 3, 4, 5], 'broken': [0, 2, 1, 3, 2, 4]}[pattern]
            steps = int(4 / rate)
            for i in range(steps):
                m = tones[order[i % len(order)] % len(tones)]
                x = (make or (lambda m, d: note_pulse(m, d, duty, False, 0.002, 0.05, 0.5, 0.02)))(m, (dur or rate * 0.8) * self.beat)
                self.mix.add(x, self.t(bar, i * rate), gain, pan * (1 if i % 2 == 0 else -1), rev, dly)

    def pad(self, bars, centre=58, gain=0.16, cutoff=1500, make=None):
        for bar in range(self.bars):
            if bar not in bars: continue
            for k, m in enumerate(voicing(self.prog[bar], centre)):
                x = (make or (lambda m, d: note_pad(m, d, 0.12, cutoff, 0.18, 0.5)))(m, 4 * self.beat)
                self.mix.add(x, self.t(bar), gain, -0.5 + 0.5 * (k % 3), 0.4)

    def comp(self, bars, hits, centre=62, gain=0.22, make=None, dly=0.15):
        """Chord stabs on given beats."""
        for bar in range(self.bars):
            if bar not in bars: continue
            for beat, d in hits:
                for k, m in enumerate(voicing(self.prog[bar], centre)):
                    x = (make or (lambda m, d: note_pluck(m, d)))(m, d * self.beat)
                    self.mix.add(x, self.t(bar, beat), gain, -0.3 + 0.3 * k, 0.2, dly)

    # ------------------------------------------------------------------ drums
    PAT = {
        'basic': dict(k=[0, 2], s=[1, 3], h=[i * .5 for i in range(8)]),
        'pop': dict(k=[0, 1.5, 2], s=[1, 3], h=[i * .5 for i in range(8)]),
        'drive': dict(k=[0, 1, 2, 3], s=[1, 3], h=[i * .5 for i in range(8)]),
        'rock': dict(k=[0, .5, 2, 2.5], s=[1, 3], h=[i * .5 for i in range(8)]),
        'driveh': dict(k=[0, 1, 2, 2.5, 3], s=[1, 3], h=[i * .25 for i in range(16)]),
        'double': dict(k=[0, .5, 1, 1.5, 2, 2.5, 3, 3.5], s=[1, 3], h=[i * .25 for i in range(16)]),
        'disco': dict(k=[0, 1, 2, 3], s=[], c=[1, 3], h=[], oh=[.5, 1.5, 2.5, 3.5], h16=[i * .25 for i in range(16) if i % 2 == 0 or True]),
        'half': dict(k=[0], s=[2], h=[i * .5 for i in range(8)]),
        'heart': dict(k=[0, .5], s=[], h=[]),
        'soft': dict(k=[0, 2], s=[], h=[1, 3], r=[1, 3]),
    }
    def drums(self, pattern, bars, gain=1.0, fill_bars=(), kick_g=0.9, snare_g=0.7, hat_g=0.55, toms=True):
        p = self.PAT[pattern]
        for bar in range(self.bars):
            if bar not in bars: continue
            last_fill = bar in fill_bars
            for b in p.get('k', []): self.mix.add(kick(kick_g), self.t(bar, b), gain * 0.9, 0.0, 0.0)
            for b in p.get('s', []):
                if last_fill and b == 3: continue
                self.mix.add(snare(snare_g), self.t(bar, b), gain * 0.7, 0.05, 0.12)
            for b in p.get('c', []): self.mix.add(clap(snare_g), self.t(bar, b), gain * 0.7, 0.0, 0.18)
            for b in p.get('h', []):
                if b in p.get('oh', []): continue
                self.mix.add(hat(hat_g * (1.0 if b % 1 == 0 else 0.65)), self.t(bar, b), gain * 0.45, 0.35, 0.03)
            for b in p.get('oh', []): self.mix.add(hat(hat_g, True), self.t(bar, b), gain * 0.5, 0.3, 0.06)
            for b in p.get('h16', []): self.mix.add(hat(hat_g * 0.6), self.t(bar, b), gain * 0.3, 0.35, 0.02)
            for b in p.get('r', []): self.mix.add(rim(0.7), self.t(bar, b), gain * 0.5, -0.2, 0.2)
            if last_fill:   # snare roll + toms into the next section
                for i in range(6):
                    self.mix.add(snare(snare_g * (0.5 + 0.1 * i)), self.t(bar, 3 + i * 0.1667), gain * 0.55, 0.0, 0.1)
                if toms:
                    for i, f in enumerate((190, 150, 120)): self.mix.add(tom(f, 0.7), self.t(bar, 2.5 + i * .5), gain * 0.5, -0.4 + 0.4 * i, 0.1)

    def crash(self, bars, gain=0.5):
        for bar in bars: self.mix.add(crash(0.9), self.t(bar), gain, 0.2, 0.2)

    # ------------------------------------------------------------------ render
    def render(self, rev_amt=0.3, rev_time=1.6, dly=None, dly_amt=0.28, target=-19.0):
        out = finish(self.mix, rev_amt, rev_time, 4800, dly if dly is not None else self.beat * 0.75, 0.38, dly_amt)
        out = loopfold(out, self.len)
        return normalise(out, target)

BARS = lambda a, b: set(range(a - 1, b))     # 1-based inclusive bar range
