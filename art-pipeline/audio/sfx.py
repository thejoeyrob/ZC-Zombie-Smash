"""Zombie Smash sound effects. Bright, clean, short and punchy (console-arcade style); every file is mono 32 kHz."""
import numpy as np
from synth import *

def _env(n, a=0.002, d=0.1, s=0.0, r=0.02): return adsr(n, a, d, s, r)

def blip(f0, f1, dur, duty=0.5, curve=1.0, vol=0.6, r=0.02, a=0.002, d=None):
    n = sec(dur + r); f = glide(f0, f1, n, curve)
    return pulse(f, n, duty) * adsr(n, a, d if d is not None else dur * 0.9, 0.0, r) * vol

def sine_blip(f0, f1, dur, vol=0.7, t60=None):
    n = sec(dur); f = glide(f0, f1, n); x = sine(f, n) * expdecay(n, t60 or dur * 0.6)
    return fade(x * vol, 0.002, 0.01)

def seq_notes(notes, gap, fn, **kw):
    """notes: MIDI names; fn(note) -> mono sound; each one starts `gap` seconds after the last."""
    total = sec(gap * (len(notes) - 1)) + max(len(fn(midi(notes[-1]))), 1)
    out = np.zeros(total + sec(0.05))
    for i, nt in enumerate(notes):
        x = fn(midi(nt)); j = sec(gap * i); out[j:j + len(x)] += x[:len(out) - j]
    return out

def thump(f0=120, f1=40, dur=0.3, vol=1.0, k=14):
    n = sec(dur); t = np.arange(n) / SR; f = f1 + (f0 - f1) * np.exp(-t * 22)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * k) * vol

def whoosh(dur, f0, f1, vol=0.5, q=0.6, shape=2.0):
    n = sec(dur); x = noise(n); out = np.zeros(n); steps = 18
    edges = np.linspace(0, n, steps + 1).astype(int); fc = glide(f0, f1, steps)
    for i in range(steps):
        lo = fc[i] * (1 - q * .5); hi = fc[i] * (1 + q)
        out[edges[i]:edges[i + 1]] = bp(x[edges[i]:edges[i + 1]], max(60, lo), min(hi, 14000), 1)
    t = np.linspace(0, 1, n)
    e = np.sin(np.pi * t ** shape) ** 1.0
    return fade(out * e * vol * 3, 0.005, 0.02)

def mixn(*xs):
    n = max(len(x) for x in xs); out = np.zeros(n)
    for x in xs: out[:len(x)] += x
    return out

S = {}
def sfx(fn): S[fn.__name__] = fn; return fn

# ------------------------------------------------------------------ interface
@sfx
def click():
    return fade(mixn(blip(2400, 3000, 0.012, 0.5, 1, 0.5, 0.004), 0.18 * sine_blip(1200, 900, 0.03, 0.5, 0.02)), 0.0005, 0.004)

@sfx
def chime():  # confirm: two soft bell notes, a fifth apart
    a = note_bell(midi('E5'), 0.5, 0.6, 0.45); b = note_bell(midi('B5'), 0.6, 0.6, 0.6)
    out = np.zeros(sec(0.95)); out[:len(a)] += a * 0.8; j = sec(0.085); out[j:j + len(b)] += b * 0.7
    return lp(out, 6500, 1)

@sfx
def back():
    return _join([blip(660, 640, 0.06, 0.5, 1, 0.35), blip(440, 420, 0.1, 0.5, 1, 0.3)], 0.07)

def _join(parts, gap):
    out = np.zeros(sec(gap * (len(parts) - 1)) + max(len(p) for p in parts))
    for i, p in enumerate(parts): j = sec(gap * i); out[j:j + len(p)] += p
    return out

@sfx
def toggle(): return _join([blip(880, 880, 0.04, 0.25, 1, 0.4), blip(1320, 1320, 0.06, 0.25, 1, 0.35)], 0.045)
@sfx
def key(): return blip(1500, 1500, 0.03, 0.25, 1, 0.4, 0.01)
@sfx
def error(): return _join([blip(196, 196, 0.1, 0.5, 1, 0.45, 0.02, d=0.2), blip(147, 147, 0.18, 0.5, 1, 0.45, 0.04, d=0.3)], 0.11)
@sfx
def page():  # comic panel swap
    return whoosh(0.28, 700, 3200, 0.5, 0.9, 1.4)

# ------------------------------------------------------------------ guns
def gun(dur, body_f, crack_hi, crack_gain, boom=0.8, tail=0.0, tone=0.5):
    n = sec(dur); t = np.arange(n) / SR
    crack = hp(noise(n), crack_hi, 1) * np.exp(-t * 90) * crack_gain
    punch = thump(body_f, body_f * 0.35, dur, boom, 26)
    zing = pulse(glide(body_f * 5, body_f * 1.2, n, 0.5), n, 0.25) * np.exp(-t * 45) * tone
    x = crack + punch + zing
    if tail: x += lp(noise(n), 1800, 1) * np.exp(-t * tail) * 0.18
    return fade(x, 0.0004, 0.01)

@sfx
def pistol(): return gun(0.16, 210, 2200, 0.55, 0.7, 20, 0.35)
@sfx
def smg(): return gun(0.075, 300, 3000, 0.45, 0.5, 0, 0.3)
@sfx
def shotgun():
    n = sec(0.42); t = np.arange(n) / SR
    x = lp(noise(n), 3600, 1) * np.exp(-t * 11) * 0.9 + thump(105, 38, 0.42, 1.0, 9) + hp(noise(n), 2000, 1) * np.exp(-t * 60) * 0.4
    return fade(x * 0.85, 0.0005, 0.02)
@sfx
def dmr():
    n = sec(0.55); t = np.arange(n) / SR
    x = hp(noise(n), 2600, 1) * np.exp(-t * 75) * 0.8 + thump(140, 36, 0.55, 1.0, 7) + pulse(glide(1800, 220, n, 0.4), n, 0.125) * np.exp(-t * 30) * 0.4
    x += lp(noise(n), 900, 1) * np.exp(-t * 6) * 0.2
    return fade(x * 0.9, 0.0004, 0.03)
@sfx
def burst():
    return _join([gun(0.07, 330, 3200, 0.45, 0.5, 0, 0.3) for _ in range(3)], 0.055)

# special weapons ---------------------------------------------------------
@sfx
def hose():  # water pulse: bubbly sine blips over a soft spray
    n = sec(0.16); t = np.arange(n) / SR
    spray = bp(noise(n), 1800, 6000, 1) * np.exp(-t * 18) * 0.5
    return fade(mixn(spray, sine_blip(500, 1500, 0.12, 0.45, 0.07), sine_blip(800, 1900, 0.09, 0.3, 0.05)), 0.001, 0.01)
@sfx
def rainbow():
    return _join([blip(midi_hz('C6'), midi_hz('C6'), .04, .25, 1, .32, .01) if False else blip(f, f, 0.045, 0.25, 1, 0.3, 0.015) for f in (1046, 1318, 1568, 2093)], 0.032)
def midi_hz(n): return float(hz(midi(n)))
@sfx
def bass():
    n = sec(0.6); t = np.arange(n) / SR
    x = thump(95, 28, 0.6, 1.1, 6) + lp(noise(n), 500, 1) * np.exp(-t * 14) * 0.5 + sine(glide(60, 30, n), n) * np.exp(-t * 5) * 0.5
    return fade(x * 0.9, 0.002, 0.05)
@sfx
def beans():
    n = sec(0.05); t = np.arange(n) / SR
    return fade(sine(glide(900, 380, n), n) * np.exp(-t * 60) * 0.6 + hp(noise(n), 3500, 1) * np.exp(-t * 130) * 0.3, 0.0005, 0.005)
@sfx
def laser():
    n = sec(0.2); f = glide(2600, 240, n, 0.55)
    x = pulse(f, n, 0.25) * np.exp(-np.arange(n) / SR * 13) * 0.55 + sine(f * 0.5, n) * 0.25 * np.exp(-np.arange(n) / SR * 18)
    return fade(x, 0.0005, 0.01)
@sfx
def remover():
    n = sec(0.14); t = np.arange(n) / SR
    return fade(mixn(hp(noise(n), 3500, 1) * np.exp(-t * 14) * 0.55, sine_blip(2200, 1800, 0.05, 0.3, 0.04)), 0.002, 0.02)
@sfx
def purge():  # electric arc
    n = sec(0.22); t = np.arange(n) / SR
    buzz = pulse(glide(180, 110, n), n, 0.5) * np.sin(2 * np.pi * 90 * t) * 0.6
    crackle = hp(noise(n), 2500, 1) * (np.random.default_rng(2).uniform(size=n) > 0.7) * np.exp(-t * 12)
    return fade((buzz * np.exp(-t * 11) + crackle * 0.5) * 0.9, 0.001, 0.02)

# ------------------------------------------------------------------ combat feedback
@sfx
def hit():
    n = sec(0.07); t = np.arange(n) / SR
    return fade(lp(noise(n), 1500, 1) * np.exp(-t * 55) * 0.8 + sine(glide(260, 110, n), n) * np.exp(-t * 45) * 0.6, 0.0004, 0.008)
@sfx
def kill():  # cartoon pop with a squeak
    n = sec(0.2); t = np.arange(n) / SR
    pop = sine(glide(700, 170, n, 0.6), n) * np.exp(-t * 20) * 0.7
    splat = lp(noise(n), 2200, 1) * np.exp(-t * 28) * 0.55
    sq = blip(1100, 1700, 0.05, 0.25, 1, 0.12, 0.01)
    out = mixn(pop + splat, sq)
    return fade(out, 0.0005, 0.02)
@sfx
def ricochet():
    n = sec(0.32); t = np.arange(n) / SR
    x = sine(glide(3000, 2200, n), n) * np.exp(-t * 14) * 0.5 + sine(glide(4500, 3200, n), n) * np.exp(-t * 22) * 0.2
    return fade(x, 0.0005, 0.03)
@sfx
def bosshit():
    n = sec(0.16); t = np.arange(n) / SR
    return fade(thump(200, 70, 0.16, 0.9, 20) + hp(noise(n), 1500, 1) * np.exp(-t * 60) * 0.4 + sine(glide(900, 400, n), n) * np.exp(-t * 35) * 0.3, 0.0004, 0.01)
@sfx
def throw(): return whoosh(0.32, 500, 2600, 0.45, 0.8, 1.1)
@sfx
def explosion():
    n = sec(1.15); t = np.arange(n) / SR
    rumble = sweep_lp(noise(n), 5200, 140, 0.55, 2, 28) * np.exp(-t * 3.2) * 1.2
    boom = thump(110, 26, 1.15, 1.2, 4.2)
    crack = hp(noise(n), 1800, 1) * np.exp(-t * 28) * 0.7
    return fade((rumble + boom + crack) * 0.8, 0.0006, 0.08)
@sfx
def hurt():  # Joey takes a hit
    n = sec(0.34); f = glide(520, 150, n, 0.7); t = np.arange(n) / SR
    x = pulse(f, n, 0.5) * np.exp(-t * 8) * 0.55 + hp(noise(n), 900, 1) * np.exp(-t * 40) * 0.25
    return fade(x, 0.0005, 0.04)
@sfx
def breach():  # a zombie got past the line
    return _join([blip(300, 300, 0.12, 0.5, 1, 0.5, 0.03, d=0.3), blip(225, 225, 0.2, 0.5, 1, 0.5, 0.05, d=0.4)], 0.13)

# ------------------------------------------------------------------ rewards
@sfx
def pickup():  # coin
    return _join([blip(1976, 1976, 0.07, 0.5, 1, 0.38, 0.01, d=0.3), blip(2637, 2637, 0.32, 0.5, 1, 0.34, 0.1, d=0.45)], 0.07)
@sfx
def heart():
    return seq_notes(['C5', 'E5', 'G5', 'C6'], 0.075, lambda m: note_bell(m, 0.35, 0.5, 0.35) * 0.9)
@sfx
def goldheart():
    out = seq_notes(['C5', 'E5', 'G5', 'C6', 'E6', 'G6'], 0.065, lambda m: note_bell(m, 0.5, 0.7, 0.5))
    sp = np.zeros(len(out)); sp += hp(noise(len(out)), 7000, 1) * np.exp(-np.arange(len(out)) / SR * 6) * 0.05
    return out + sp
@sfx
def boost1(): return _join([blip(784, 784, 0.07, 0.25, 1, 0.38, 0.02, d=0.2), blip(1175, 1175, 0.16, 0.25, 1, 0.38, 0.06, d=0.3)], 0.07)
@sfx
def boost2(): return _join([blip(f, f, 0.06, 0.25, 1, 0.38, 0.02, d=0.2) for f in (784, 988, 1175)] + [blip(1568, 1568, 0.2, 0.25, 1, 0.38, 0.08, d=0.35)], 0.06)
@sfx
def boost3():
    parts = [blip(f, f, 0.055, 0.25, 1, 0.38, 0.02, d=0.2) for f in (784, 988, 1175, 1568)] + [blip(2093, 2093, 0.35, 0.25, 1, 0.38, 0.12, d=0.5)]
    out = _join(parts, 0.055); sp = hp(noise(len(out)), 6000, 1) * np.exp(-np.arange(len(out)) / SR * 5) * 0.06
    return out + sp
@sfx
def power():  # special weapon grabbed
    n = sec(0.55); f = glide(260, 1400, n, 1.7)
    x = pulse(f, n, 0.25) * adsr(n, 0.01, 0.4, 0.5, 0.12) * 0.45 + sine(f * 2, n) * 0.12 * adsr(n, 0.01, 0.4, 0.5, 0.12)
    return fade(x, 0.002, 0.03)
@sfx
def switch(): return _join([blip(900, 700, 0.02, 0.5, 1, 0.4, 0.005), blip(500, 650, 0.03, 0.5, 1, 0.35, 0.008)], 0.03)
@sfx
def target():
    return note_bell(midi('A5'), 0.45, 0.7, 0.4)
@sfx
def clear():  # wave cleared
    return seq_notes(['G5', 'C6', 'E6', 'G6'], 0.07, lambda m: note_bell(m, 0.5, 0.8, 0.45) * 0.9)

# ------------------------------------------------------------------ bosses & scenes
@sfx
def alarm():  # boss warning siren
    n = sec(1.6); t = np.arange(n) / SR
    f = np.where((t * 2.5) % 1 < 0.5, 880.0, 660.0)
    x = pulse(f, n, 0.5) * 0.4 + saw(f * 0.5, n) * 0.15
    x = lp(x, 2600, 1) * adsr(n, 0.01, 0.1, 0.9, 0.2)
    return fade(x * 0.75, 0.005, 0.1)
@sfx
def warn():  # boss attack incoming
    return fade(mixn(whoosh(0.35, 250, 1500, 0.4, 0.8, 0.9), np.pad(thump(90, 38, 0.3, 0.85, 9), (sec(0.1), 0))), 0.003, 0.03)
@sfx
def doom():  # the fight begins
    n = sec(1.3); t = np.arange(n) / SR
    f = glide(90, 48, n, 0.8)
    growl = saw(f, n) * (1 + 0.5 * np.sin(2 * np.pi * 22 * t)) * 0.5
    growl = sweep_lp(growl, 1800, 300, 0.8, 2, 14) * adsr(n, 0.01, 0.3, 0.7, 0.4)
    hit_ = thump(120, 28, 1.3, 1.1, 5) + hp(noise(n), 1200, 1) * np.exp(-t * 18) * 0.5
    return fade((growl + hit_) * 0.75, 0.001, 0.12)
@sfx
def mutation():  # boss changes form
    n = sec(1.4); t = np.arange(n) / SR
    rise = pulse(glide(80, 700, n, 1.6), n, 0.5) * adsr(n, 0.02, 0.6, 0.6, 0.3) * 0.4
    shim = hp(noise(n), 4000, 1) * np.sin(np.pi * t / 1.4) * 0.12
    boom = thump(100, 30, 1.4, 1.0, 3.5) * np.pad(np.ones(sec(1.0)), (sec(0.4), 0))[:n]
    return fade(lp(rise, 3500, 1) + shim + boom * 0.6, 0.004, 0.2)

if __name__ == '__main__':
    import sys, os
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    for name, fn in S.items():
        x = fn(); x = x / max(1e-6, np.abs(x).max()) * 0.8 if np.abs(x).max() > 0 else x
        save(f'{out}/snd-{name}.wav', x)
    print(len(S), 'effects')
