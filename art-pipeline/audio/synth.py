"""Offline sound toolkit for Zombie Smash: band-limited oscillators, drums, filters, reverb, delay and a small mixer.
Everything renders to 32 kHz 16-bit WAV files that the game decodes once and plays through Web Audio."""
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 32000
RNG = np.random.default_rng(7)

NOTE_BASE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}

def midi(name):
    """'C#4' / 'Bb3' / 60 -> MIDI number."""
    if isinstance(name, (int, float)): return int(name)
    n = NOTE_BASE[name[0]]; i = 1
    while i < len(name) and name[i] in '#b':
        n += 1 if name[i] == '#' else -1; i += 1
    return n + 12 * (int(name[i:]) + 1)

def hz(m): return 440.0 * 2 ** ((np.asarray(m, float) - 69) / 12)

def sec(s): return int(round(s * SR))

# ---------------------------------------------------------------- envelopes
def adsr(n, a=0.005, d=0.1, s=0.6, r=0.1):
    a_, d_, r_ = max(1, sec(a)), max(1, sec(d)), max(1, sec(r))
    body = max(0, n - r_)
    e = np.empty(n)
    na = min(a_, n); e[:na] = np.linspace(0, 1, na, endpoint=False)
    if n > na:
        nd = min(d_, n - na); e[na:na + nd] = np.linspace(1, s, nd, endpoint=False)
        e[na + nd:body] = s if body > na + nd else 0
    if r_ > 0 and n > 0:
        start = min(body, n)
        lvl = e[start - 1] if start > 0 else 0
        e[start:] = np.linspace(lvl, 0, n - start)
    return e

def expdecay(n, t60):
    t = np.arange(n) / SR
    return np.exp(-6.9 * t / max(t60, 1e-3))

def fade(x, a=0.002, b=0.004):
    x = x.copy(); na, nb = min(sec(a), len(x)), min(sec(b), len(x))
    if na: x[:na] *= np.linspace(0, 1, na)
    if nb: x[-nb:] *= np.linspace(1, 0, nb)
    return x

# ---------------------------------------------------------------- oscillators (PolyBLEP, no aliasing fizz)
def _blep(p, dt):
    out = np.zeros_like(p)
    m = p < dt; x = p[m] / dt[m] if np.ndim(dt) else p[m] / dt
    out[m] = x + x - x * x - 1
    m2 = p > 1 - dt
    x2 = (p[m2] - 1) / (dt[m2] if np.ndim(dt) else dt)
    out[m2] = x2 * x2 + x2 + x2 + 1
    return out

def _phase(freq, n):
    f = np.broadcast_to(np.asarray(freq, float), (n,)).copy()
    dt = f / SR
    return (np.cumsum(dt) % 1.0), dt

def saw(freq, n):
    p, dt = _phase(freq, n)
    return 2 * p - 1 - _blep(p, dt)

def pulse(freq, n, duty=0.5):
    p, dt = _phase(freq, n)
    s1 = 2 * p - 1 - _blep(p, dt)
    p2 = (p + duty) % 1.0
    s2 = 2 * p2 - 1 - _blep(p2, dt)
    return (s1 - s2) * 0.5

def tri(freq, n):
    p, _ = _phase(freq, n)
    return 4 * np.abs(p - 0.5) - 1

def sine(freq, n):
    p, _ = _phase(freq, n)
    return np.sin(2 * np.pi * p)

def noise(n): return RNG.uniform(-1, 1, n)

def vib(n, f0, rate=5.5, depth=0.006, delay=0.12):
    t = np.arange(n) / SR
    amt = np.clip((t - delay) / 0.2, 0, 1) * depth
    return f0 * (1 + amt * np.sin(2 * np.pi * rate * t))

def glide(f0, f1, n, curve=1.0):
    x = np.linspace(0, 1, n) ** curve
    return f0 * (f1 / f0) ** x

# ---------------------------------------------------------------- filters
def lp(x, fc, order=2):
    fc = min(fc, SR * 0.45); return signal.sosfilt(signal.butter(order, fc, 'low', fs=SR, output='sos'), x)
def hp(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, max(20, fc), 'high', fs=SR, output='sos'), x)
def bp(x, lo, hi, order=2):
    hi = min(hi, SR * 0.45); return signal.sosfilt(signal.butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)

def sweep_lp(x, f0, f1, curve=1.0, order=2, steps=24):
    """Low-pass whose cutoff moves from f0 to f1 over the sound (block-wise)."""
    n = len(x); out = np.zeros(n); edges = np.linspace(0, n, steps + 1).astype(int)
    fcs = glide(f0, f1, steps, curve) if f0 > 0 else np.full(steps, f1)
    zi = None
    for i in range(steps):
        sos = signal.butter(order, min(fcs[i], SR * 0.45), 'low', fs=SR, output='sos')
        if zi is None: zi = np.zeros((sos.shape[0], 2))
        out[edges[i]:edges[i + 1]], zi = signal.sosfilt(sos, x[edges[i]:edges[i + 1]], zi=zi)
    return out

# ---------------------------------------------------------------- stereo mixer
class Mix:
    """Stereo buffer with a dry bus and send buses for reverb and delay."""
    def __init__(self, seconds):
        self.n = sec(seconds)
        self.l = np.zeros(self.n); self.r = np.zeros(self.n)
        self.rv = np.zeros(self.n); self.dl = np.zeros(self.n)

    def add(self, x, t, gain=1.0, pan=0.0, rev=0.0, dly=0.0):
        i = sec(t)
        if i >= self.n or len(x) == 0: return
        j = min(self.n, i + len(x)); x = x[:j - i] * gain
        a = (pan + 1) * np.pi / 4
        self.l[i:j] += x * np.cos(a); self.r[i:j] += x * np.sin(a)
        if rev: self.rv[i:j] += x * rev
        if dly: self.dl[i:j] += x * dly

def reverb_ir(seconds=2.0, damp=4200, pre=0.012, seed=3):
    g = np.random.default_rng(seed); n = sec(seconds)
    t = np.arange(n) / SR; irs = []
    for ch in range(2):
        x = g.normal(size=n) * np.exp(-6.9 * t / seconds) ** 1.0
        x = lp(x, damp, 1)
        x = np.concatenate([np.zeros(sec(pre + 0.003 * ch)), x])[:n]
        irs.append(x)
    return irs

def finish(m, rev_amt=0.25, rev_time=1.8, rev_damp=4200, dly_time=None, dly_fb=0.35, dly_amt=0.3, hp_cut=28):
    """Add reverb and ping-pong delay from the send buses; returns (2, n) float array."""
    l, r = m.l.copy(), m.r.copy()
    if m.rv.any():
        irl, irr = reverb_ir(rev_time, rev_damp)
        l += signal.fftconvolve(m.rv, irl)[:m.n] * rev_amt * 0.5
        r += signal.fftconvolve(m.rv, irr)[:m.n] * rev_amt * 0.5
    if dly_time and m.dl.any():
        d = sec(dly_time); tapl = np.zeros(m.n); tapr = np.zeros(m.n)
        src = m.dl.copy(); k = 0; g = 1.0
        while k < 7 and d * (k + 1) < m.n:
            g *= dly_fb; seg = np.zeros(m.n); seg[d * (k + 1):] = src[:m.n - d * (k + 1)] * g
            (tapl if k % 2 == 0 else tapr)[:] += seg; k += 1
        l += lp(tapl, 3800, 1) * dly_amt; r += lp(tapr, 3800, 1) * dly_amt
    out = np.stack([l, r])
    return signal.sosfilt(signal.butter(2, hp_cut, 'high', fs=SR, output='sos'), out, axis=1)

def loopfold(out, loop_seconds):
    """Fold anything past the loop length (reverb/delay tails) back onto the start so the loop is seamless."""
    n = sec(loop_seconds); body = out[:, :n].copy(); tail = out[:, n:]
    k = tail.shape[1]
    while k > 0:
        seg = tail[:, :min(k, n)]
        body[:, :seg.shape[1]] += seg
        tail = tail[:, seg.shape[1]:]; k = tail.shape[1]
    return body

def loudness(x):
    """Approximate integrated loudness (K-weighted RMS) in dB, enough to keep tracks level with each other."""
    xs = x if x.ndim == 1 else x.mean(axis=0)
    sos = signal.butter(2, 150, 'high', fs=SR, output='sos')
    y = signal.sosfilt(sos, xs)
    return 10 * np.log10(np.mean(y ** 2) + 1e-12)

def normalise(x, target_db=-18.0, peak=0.89):
    """Bring a mix to the target loudness; tall peaks are rounded off by a soft clipper that never exceeds `peak`."""
    y = x
    for _ in range(3):
        y = peak * np.tanh(x * 10 ** ((target_db - loudness(x)) / 20) / peak) if False else x
        g = 10 ** ((target_db - loudness(y)) / 20); x = x * g
        y = peak * np.tanh(x / peak)
        x = y if False else x
        err = target_db - loudness(y)
        if abs(err) < 0.2: break
        x = x * 10 ** (err / 20)
    return peak * np.tanh(x / peak)

def save(path, x, bits=16):
    x = np.clip(x, -1, 1)
    data = (x.T if x.ndim == 2 else x) * 32767
    wavfile.write(path, SR, data.astype(np.int16))

# ---------------------------------------------------------------- instruments (each returns a mono note)
def note_pulse(m, dur, duty=0.25, vibrato=True, a=0.004, d=0.08, s=0.7, r=0.06, bright=1.0):
    n = sec(dur + r)
    f = vib(n, hz(m)) if vibrato and dur > 0.25 else np.full(n, float(hz(m)))
    x = pulse(f, n, duty) * adsr(n, a, d, s, r)
    return x * 0.5 * bright

def note_lead(m, dur, duty=0.25, a=0.008, d=0.15, s=0.75, r=0.08, cutoff=2000):
    """Mega-Drive style FM lead (a Sonic-like brassy-bell tone): two-operator FM whose brightness settles after the attack,
    a faint detuned twin for width, a slow-in vibrato, and a low-pass so it never turns shrill."""
    n = sec(dur + r); t = np.arange(n) / SR
    f = vib(n, hz(m), 5.4, 0.004, 0.22) if dur > 0.3 else np.full(n, float(hz(m)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    idx = 0.7 + 1.1 * np.exp(-t * 6.0)                     # bright pluck at the start, mellower sustain
    x = np.sin(ph + idx * np.sin(ph))                       # modulator at 1:1 = brassy
    x += 0.35 * np.sin(2.003 * ph + 0.5 * idx * np.sin(2 * ph))   # a little upper body
    x += 0.4 * np.sin(1.004 * ph + 0.6 * np.sin(1.004 * ph))      # detuned twin
    return lp(x, cutoff, 2) * adsr(n, a, d, s, r) * 0.38

def note_tri(m, dur, a=0.004, d=0.12, s=0.8, r=0.05):
    n = sec(dur + r); return tri(np.full(n, float(hz(m))), n) * adsr(n, a, d, s, r) * 0.9

def note_bass(m, dur, pluck=0.18, sub=True):
    n = sec(dur + 0.04); f = float(hz(m))
    x = tri(np.full(n, f), n) * 0.7 + pulse(np.full(n, f), n, 0.5) * 0.25
    if sub: x += sine(np.full(n, f / 2), n) * 0.18
    return lp(x, 900, 1) * adsr(n, 0.003, pluck, 0.55, 0.03)

def note_bell(m, dur, bright=1.0, t60=None):
    """Soft FM bell / marimba-ish tone."""
    n = sec(dur if t60 is None else max(dur, t60)); f = float(hz(m)); t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * f * 3.5 * t) * np.exp(-t * 14) * 1.4 * bright
    x = np.sin(2 * np.pi * f * t + mod) * expdecay(n, t60 or dur)
    x += 0.25 * np.sin(2 * np.pi * f * 2.0 * t) * expdecay(n, (t60 or dur) * 0.4)
    return fade(x * 0.6, 0.002, 0.01)

def note_pad(m, dur, detune=0.12, cutoff=1800, a=0.25, r=0.4):
    n = sec(dur + r); f = float(hz(m)); x = np.zeros(n)
    for dt in (-detune, 0, detune):
        x += saw(np.full(n, f * 2 ** (dt / 12)), n)
    x = lp(x / 3, cutoff, 2)
    return x * adsr(n, a, 0.3, 0.8, r) * 0.55

def note_pluck(m, dur, cutoff=3200):
    n = sec(dur + 0.05); f = float(hz(m))
    x = (saw(np.full(n, f), n) + pulse(np.full(n, f * 1.003), n, 0.3)) * 0.5
    return sweep_lp(x, cutoff, 600, 1.0, 2, 10) * adsr(n, 0.002, 0.12, 0.35, 0.04)

def note_organ(m, dur, a=0.01, r=0.05):
    n = sec(dur + r); f = float(hz(m)); x = np.zeros(n)
    for k, g in ((1, 1), (2, .6), (3, .45), (4, .3), (6, .15)):
        x += g * sine(np.full(n, f * k), n)
    return x / 2.5 * adsr(n, a, 0.05, 0.9, r)

# drums ----------------------------------------------------------------
def kick(power=1.0, f0=170, f1=48, dec=0.22):
    n = sec(dec + 0.05); t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * np.exp(-t * 11) + 0.25 * noise(n) * np.exp(-t * 160)
    return fade(x * power * 0.95, 0.0005, 0.01)

def snare(power=1.0, tone=190, dec=0.16):
    n = sec(dec + 0.04); t = np.arange(n) / SR
    nz = hp(noise(n), 1400, 1) * np.exp(-t * 20)
    body = np.sin(2 * np.pi * tone * t) * np.exp(-t * 30) * 0.6
    return fade((nz * 0.85 + body) * power * 0.7, 0.0005, 0.01)

def clap(power=1.0):
    n = sec(0.2); x = np.zeros(n)
    for i, d in enumerate((0, 0.011, 0.021, 0.032)):
        j = sec(d); seg = bp(noise(n - j), 900, 3200, 1) * np.exp(-np.arange(n - j) / SR * (60 if i < 3 else 22))
        x[j:] += seg
    return fade(x * power * 0.55)

def hat(power=1.0, open_=False):
    dec = 0.32 if open_ else 0.045; n = sec(dec + 0.01); t = np.arange(n) / SR
    return fade(hp(noise(n), 6500, 2) * np.exp(-t / dec * 6.0) * power * 0.35, 0.0003, 0.004)

def tom(f=130, power=1.0, dec=0.28):
    n = sec(dec + 0.03); t = np.arange(n) / SR
    fr = f * (1 + 0.6 * np.exp(-t * 18)); ph = 2 * np.pi * np.cumsum(fr) / SR
    return fade(np.sin(ph) * np.exp(-t * 11) * power * 0.8, 0.0005, 0.01)

def crash(power=1.0, dec=1.2):
    n = sec(dec); t = np.arange(n) / SR
    return fade(hp(noise(n), 3500, 2) * np.exp(-t / dec * 5.5) * power * 0.4, 0.001, 0.02)

def rim(power=1.0):
    n = sec(0.06); t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 1700 * t) * np.exp(-t * 90) + hp(noise(n), 2500, 1) * np.exp(-t * 90) * 0.4
    return fade(x * power * 0.45)
