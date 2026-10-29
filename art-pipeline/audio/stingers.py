"""One-shot music: boot sequence (timed to the CSS power-on animation), stingers and fanfares."""
from music_lib import *
from sfx import S as SFX, mixn, blip, whoosh, thump

def _once(s, rev_amt=0.3, rev_time=1.6, target=-19.0, tail_fade=0.15, length=None, dly=None, dly_amt=0.2):
    out = finish(s.mix, rev_amt, rev_time, 4800, dly if dly is not None else s.beat * 0.75, 0.35, dly_amt)
    n = sec(length or (s.len + s.tail)); out = out[:, :n]
    out = normalise(out, target)
    f = sec(tail_fade); out[:, -f:] *= np.linspace(1, 0, f)
    return out

BR = lambda m, d: note_pulse(m, d, 0.25, True, 0.01, 0.1, 0.8, 0.08)
HORN = lambda m, d: lp(note_pulse(m, d, 0.5, True, 0.012, 0.12, 0.85, 0.1) + 0.5 * note_pulse(m, d, 0.25, False, 0.012, 0.12, 0.85, 0.1), 3000, 1)

def victory():   # boss down: C major fanfare
    s = Song('victory', 150, ['C', 'G', 'C'], 'C', 'major', tail=2.2)
    mel = ['C5:.5 E5:.5 G5:.5 C6:1 G5:.5 E5:.5 G5:.5', 'D6:.5 D6:.5 D6:.5 G6:1.5 F6:.5 E6:.5', 'C6:.5 E6:.5 G6:.5 C7:2.5']
    s.melody(mel, HORN, 0.55, -0.05, 0.3, 0.25, check=False)
    s.melody(mel, BELL_ := (lambda m, d: note_bell(m, max(d, .2), .8, .5)), 0.16, 0.25, 0.4, 0.25, octave=12, check=False)
    s.bass([ 'half', 'half', 'pedal'], BARS(1, 3), 0.55)
    s.pad(BARS(1, 3), 55, 0.16, 1800)
    s.mix.add(kick(1.0), 0, 0.9); s.mix.add(crash(1.0, 1.6), 0, 0.5, 0.2, 0.3)
    s.mix.add(crash(1.0, 2.2), s.t(2), 0.6, 0.1, 0.4); s.mix.add(kick(1.0), s.t(2), 0.9)
    s.arp({2}, .25, 72, 0.12, 0.25, 0.4, 'saw', 0.4, 0.2, make=lambda m, d: note_bell(m, 0.5, .9, .5) * .6)
    return _once(s, 0.35, 2.0, -18.0, length=6.0)

def defeat():    # Joey is down: slow minor descent
    s = Song('defeat', 116, ['Cm', 'Cm', 'Cm'], 'C', 'minor', tail=2.4)
    mel = ['G5:1 Eb5:1 C5:1 G4:1', 'Gb4!:1 F4:1 E4!:1 Eb4:1', 'C4:4']
    s.melody(mel, lambda m, d: lp(note_pulse(m, d, 0.5, True, 0.02, 0.2, 0.8, 0.2), 2200, 1), 0.5, 0.0, 0.4, 0.2, check=False)
    s.pad(BARS(1, 3), 51, 0.22, 800)
    s.bass('pedal', BARS(1, 3), 0.5, make=lambda m, d: lp(note_tri(m, d, 0.03, 0.3, 0.8, 0.4), 500, 1))
    s.mix.add(thump(80, 32, 0.6, 1.0, 5), s.t(2), 0.8)
    return _once(s, 0.4, 2.4, -20.0, 0.4, length=6.6)

def wavestart(): # a new wave begins: quick "ready" flourish
    s = Song('wavestart', 160, ['G'], 'G', 'major', tail=1.4)
    s.melody(['G4:.5 B4:.5 D5:.5 G5:2.5'], BR, 0.55, 0.0, 0.3, 0.2, check=False)
    s.mix.add(kick(0.9), 0, 0.8); s.mix.add(crash(0.7, 1.0), s.t(0, 1.5), 0.4)
    return _once(s, 0.3, 1.2, -19.0, 0.2, length=1.9)

def highscore(): # new high score
    s = Song('highscore', 156, ['C', 'F', 'G', 'C'], 'C', 'major', tail=2.4)
    mel = ['C5:.5 E5:.5 G5:.5 C6:.5 E6:.5 C6:.5 G5:.5 C6:.5', 'A5:.5 C6:.5 F6:1 E6:.5 D6:.5 C6:1', 'B5:.5 D6:.5 G6:1 F6:.5 E6:.5 D6:1', 'C6:.5 E6:.5 G6:.5 C7:2.5']
    s.melody(mel, HORN, 0.5, -0.05, 0.3, 0.3, check=False)
    s.melody(mel, lambda m, d: note_bell(m, max(d, .2), .9, .5), 0.18, 0.25, 0.4, 0.3, octave=12, check=False)
    s.bass('walk', BARS(1, 4), 0.5)
    s.drums('pop', BARS(1, 3), 0.8)
    s.mix.add(crash(1.0, 2.0), s.t(3), 0.6, 0.1, 0.4)
    return _once(s, 0.35, 2.0, -18.5, length=7.0)

def boot():
    """Power-on sequence synced to the CSS timeline in game.css:
       0.9-2.1 s lamp blinks (soft relay ticks) · 1.9 s CRT flash · 2.5 s JW logo · 2.9/3.2/3.5/3.8 s the four colour blocks."""
    L = 6.6; m = Mix(L); rng = np.random.default_rng(11)
    # mains hum fades in with the console
    n = sec(2.6); t = np.arange(n) / SR
    hum = (sine(np.full(n, 55.0), n) * .5 + sine(np.full(n, 110.0), n) * .25 + sine(np.full(n, 165.0), n) * .08) * np.clip(t / 0.9, 0, 1) * np.clip((2.6 - t) / 0.5, 0, 1)
    m.add(hum * 0.12, 0.0, 1.0, 0.0)
    # lamp: relay ticks on each blink step
    for i, tt in enumerate((0.9, 1.14, 1.36, 1.6, 1.82, 2.06)):
        k = SFX['click'](); m.add(lp(k, 3000, 1) * (0.5 if i < 5 else 0.8), tt, 1.0, 0.15, 0.1)
        m.add(sine_b(1100 if i % 2 == 0 else 800, 0.05), tt, 0.1, 0.0, 0.1)
    # CRT flash at 1.9: electric zip up, thump, degauss wobble
    n = sec(0.32); t = np.arange(n) / SR; zip_ = sine(glide(500, 7500, n, 2.2), n) * np.exp(-t * 7) * 0.3 + hp(noise(n), 5000, 1) * np.exp(-t * 14) * 0.18
    m.add(fade(zip_, 0.003, 0.05), 1.9, 1.0, 0.0, 0.1)
    m.add(thump(95, 34, 0.7, 1.0, 5.5), 2.02, 0.95, 0.0, 0.05)
    n = sec(0.9); t = np.arange(n) / SR
    deg = sine(np.full(n, 60.0), n) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t)) * np.exp(-t * 4.2) + lp(noise(n), 700, 1) * np.exp(-t * 7) * 0.25
    m.add(fade(deg, 0.01, 0.1), 2.05, 0.5, 0.0, 0.2)
    # JW logo (2.5 s): a soft rising swell and a little harp flick
    for i, nt in enumerate(('C4', 'G4', 'D5', 'G5', 'C6')):
        m.add(note_pad(midi(nt), 2.6, 0.1, 1800, 0.55, 0.9), 2.45 + i * 0.03, 0.12, -0.4 + 0.2 * i, 0.5)
    for i, nt in enumerate(('C5', 'G5', 'D6')):
        m.add(note_bell(midi(nt), 0.6, 0.5, 0.4) * 0.5, 2.5 + i * 0.07, 0.5, -0.3 + 0.3 * i, 0.5, 0.2)
    # the four colour blocks: soft airport-style chimes, low-passed, staccato
    for tt, nt in zip((2.9, 3.2, 3.5, 3.8), ('C5', 'G5', 'D6', 'G6')):
        c = lp(note_bell(midi(nt), 0.34, 0.4, 0.26), 2300, 3)
        m.add(c, tt, 0.9, {2.9: -0.3, 3.2: -0.1, 3.5: 0.1, 3.8: 0.3}[tt], 0.35, 0.18)
    # settle: a soft open chord blooms under the last chime and rings out under the Home Screen
    for nt in ('C4', 'G4', 'D5', 'G5'):
        m.add(note_pad(midi(nt), 2.2, 0.08, 1600, 0.4, 1.2), 3.8, 0.1, 0.0, 0.5)
    out = finish(m, 0.4, 2.2, 4800, 0.30, 0.3, 0.22)[:, :sec(L)]
    out = normalise(out, -20.0, 0.85)
    f = sec(0.5); out[:, -f:] *= np.linspace(1, 0, f)
    return out

def sine_b(f, d): n = sec(d); return sine(np.full(n, float(f)), n) * np.exp(-np.arange(n) / SR * 60)

STING = dict(victory=victory, defeat=defeat, wavestart=wavestart, highscore=highscore, boot=boot)

if __name__ == '__main__':
    import sys, os
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    for n, fn in STING.items():
        x = fn(); save(f'{out}/mus-{n}.wav', x); print(f'{n}: {x.shape[1] / SR:.1f}s peak {np.abs(x).max():.2f} loud {loudness(x):.1f}')
    print('\n'.join(WARN) or 'no warnings')
