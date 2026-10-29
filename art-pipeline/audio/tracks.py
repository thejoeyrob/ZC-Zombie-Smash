"""The Zombie Smash soundtrack: one function per looping track."""
from music_lib import *

P = lambda duty, **k: (lambda m, d: note_pulse(m, d, duty, True, 0.006, 0.1, 0.75, 0.05, **k))
BELL = lambda t60=0.7: (lambda m, d: note_bell(m, max(d, 0.2), 0.8, t60))
ORG = lambda m, d: note_organ(m, d)
PLK = lambda m, d: note_pluck(m, d)

# ====================================================================== HOME (title / menus) -- C minor, heroic and bouncy
def home():
    s = Song('home', 108, ['Cm', 'Cm', 'Ab', 'Bb', 'Cm', 'Eb', 'Ab', 'G7', 'Fm', 'Fm', 'Cm', 'Cm', 'Ab', 'Bb', 'Cm', 'G7'], 'C', 'minor', swing=0.12)
    mel = ['G4:1 C5:1 Eb5:1 G5:1', 'Eb5:1.5 D5:.5 C5:1 D5:1', 'Eb5:1 Ab5:1 G5:.5 F5:.5 Eb5:1', 'D5:1.5 F5:.5 Bb5:2',
           'G5:1 C6:1 Bb5:.5 Ab5:.5 G5:1', 'Bb5:1.5 G5:.5 Eb5:2', 'C6:1 Eb6:1 D6:.5 C6:.5 Ab5:1', 'D6:1.5 B5!:.5 G5:2',
           'C6:2 Ab5:1 F5:1', 'Ab5:1.5 G5:.5 F5:2', 'G5:2 Eb5:1 C5:1', 'Eb5:1 D5:1 G5:2',
           'C6:1.5 Bb5:.5 Ab5:1 Eb5:1', 'D6:1.5 C6:.5 Bb5:2', 'Eb6:1 D6:1 C6:1 G5:1', 'B5!:1 D6:1 G5:2']
    s.melody(mel, P(0.25), 0.55, -0.05, 0.28, 0.3)
    s.melody(mel[4:], BELL(0.5), 0.2, 0.2, 0.35, 0.2, octave=12, start=4)           # a bell doubles the tune from bar 5
    s.pad(BARS(1, 16), 58, 0.15, 1300)
    s.bass('half', BARS(1, 4), 0.5); s.bass('root8', BARS(5, 16), 0.5)
    s.drums('soft', BARS(1, 4), 0.8); s.drums('pop', BARS(5, 16), 0.9, fill_bars={7, 15})
    s.arp(BARS(9, 16), .5, 66, 0.2, 0.125, 0.4, 'updown', 0.3, 0.3)
    s.crash([0, 4, 8, 12], 0.4)
    return s.render(rev_amt=0.3, target=-19.5)

# ====================================================================== STORY (opening comic) -- A minor, curious and mysterious
def story():
    s = Song('story', 84, ['Am', 'Am', 'F', 'E7', 'Am', 'C', 'G', 'E7', 'Dm', 'Dm', 'Am', 'Am', 'F', 'G', 'E7', 'E7'], 'A', 'minor', swing=0.0)
    mel = ['E5:2 A5:1 G5:1', 'E5:1 C5:1 E5:1 D5:1', 'A5:1.5 G5:.5 F5:2', 'G#5!:1 B5!:1 A5:.5 G#5!:.5 E5:1',
           'C6:1.5 B5:.5 A5:1 E5:1', 'G5:1 E5:1 C5:1 E5:1', 'D5:1 G5:1 B5:1 D6:1', 'B5!:1.5 G#5!:.5 E5:2',
           'F5:2 A5:1 D6:1', 'A5:1 C6:1 F5:2', 'E5:1 A5:1 C6:2', 'A5:1 B5:1 E5:2',
           'A5:1 C6:1 F6:2', 'D6:1.5 B5:.5 G5:2', 'G#5!:1 B5!:1 D6:1 B5:1', 'E6:1.5 D6:.5 B5:2']
    soft = lambda m, d: lp(note_pulse(m, d, 0.5, True, 0.04, 0.2, 0.7, 0.15), 2400, 1)
    s.melody(mel, soft, 0.42, 0.0, 0.5, 0.25)
    s.pad(BARS(1, 16), 57, 0.17, 1100)
    s.arp(BARS(1, 16), 0.5, 69, 0.24, 0.125, 0.4, 'up', 0.45, 0.4, 0.45, make=lambda m, d: note_bell(m, 0.5, 0.9, 0.5) * 0.7)
    s.bass('pedal', BARS(1, 16), 0.42, make=lambda m, d: lp(note_tri(m, d, 0.05, 0.3, 0.8, 0.3), 700, 1))
    s.drums('heart', BARS(5, 16), 0.5, kick_g=0.7)
    s.drums('soft', BARS(9, 16), 0.4)
    return s.render(rev_amt=0.4, rev_time=2.2, target=-21.0)

# ====================================================================== WAVE 1 -- G major, friendly and bouncy
def wave1():
    s = Song('wave1', 126, ['G', 'G', 'C', 'D', 'G', 'Em', 'C', 'D', 'Em', 'Bm', 'C', 'D', 'Am7', 'D7', 'G', 'D7'], 'G', 'major', swing=0.18)
    mel = ['B4:.5 D5:.5 G5:1 F#5:.5 G5:.5 A5:1', 'B5:.5 A5:.5 G5:1 D5:1 G5:1', 'E5:.5 G5:.5 C6:1 B5:.5 C6:.5 D6:1', 'D6:1 A5:.5 F#5:.5 D5:1 A5:1',
           'B5:.5 D6:.5 G6:1 F#6:.5 G6:.5 A6:1', 'G5:1 E5:.5 G5:.5 B5:1 G5:1', 'E5:.5 G5:.5 C6:1 E6:1 C6:1', 'D6:.5 C6:.5 B5:.5 A5:.5 F#5:1 A5:1',
           'B5:1 G5:1 E5:1 G5:1', 'D6:1 B5:1 F#5:1 B5:1', 'C6:1.5 B5:.5 G5:1 E5:1', 'F#5:1 A5:1 D6:2',
           'E6:1 C6:1 A5:1 E5:1', 'F#5:1 A5:1 C6:1 A5:1', 'B5:.5 D6:.5 G6:1 D6:1 B5:1', 'A5:1 F#5:1 A5:1 D5:1']
    s.melody(mel, P(0.25), 0.55, -0.05, 0.2, 0.25)
    s.bass('walk', BARS(1, 4), 0.55); s.bass('root8', BARS(5, 16), 0.5)
    s.drums('basic', BARS(1, 4), 0.85); s.drums('pop', BARS(5, 16), 0.9, fill_bars={7, 15})
    s.comp(BARS(5, 16), [(0.5, .2), (1.5, .2), (2.5, .2), (3.5, .2)], 60, 0.16)
    s.arp(BARS(9, 16), .25, 67, 0.12, 0.125, 0.4, 'saw', 0.2, 0.25, 0.2)
    s.crash([0, 4, 8, 12], 0.4)
    return s.render(rev_amt=0.22, target=-19.0)

# ====================================================================== WAVE 2 -- D minor, driving
def wave2():
    s = Song('wave2', 138, ['Dm', 'Dm', 'Bb', 'C', 'Dm', 'Dm', 'Bb', 'A', 'Gm', 'Gm', 'Dm', 'Dm', 'Bb', 'C', 'A', 'A'], 'D', 'minor', swing=0.0)
    mel = ['D5:.5 F5:.5 A5:1 D6:1 C6:.5 A5:.5', 'A5:1 F5:1 D5:2', 'Bb5:.5 D6:.5 F6:1 D6:1 Bb5:1', 'C6:.5 E6:.5 G6:1 E6:1 C6:1',
           'D5:.5 F5:.5 A5:1 D6:1 E6:.5 F6:.5', 'A5:1 D6:1 F6:2', 'D6:1 F6:1 Bb5:1 D6:1', 'C#6!:1 E6:1 A5:1 C#6!:1',
           'D6:1 Bb5:1 G5:1 Bb5:1', 'D6:.5 C6:.5 Bb5:1 G5:2', 'F5:1 A5:1 D6:1 F6:1', 'D6:1 E6:1 A5:2',
           'Bb5:1 D6:1 F6:1 Bb6:1', 'C6:.5 E6:.5 G6:1 E6:1 C6:1', 'A5:.5 C#6!:.5 E6:1 A6:1 G6:1', 'E6:1 C#6!:1 A5:1 E5:1']
    lead = lambda m, d: note_pulse(m, d, 0.5, True, 0.004, 0.08, 0.7, 0.04)
    s.melody(mel, lead, 0.5, -0.05, 0.2, 0.25)
    s.melody(mel, P(0.125), 0.16, 0.25, 0.15, 0.2, octave=12)
    s.bass('drive16', BARS(1, 16), 0.5)
    s.drums('drive', BARS(1, 4), 0.9); s.drums('driveh', BARS(5, 16), 0.9, fill_bars={7, 15})
    s.comp(BARS(5, 16), [(0, .5), (1.5, .3), (3, .4)], 58, 0.16, make=lambda m, d: note_pluck(m, d, 2800))
    s.arp(BARS(9, 16), .25, 62, 0.11, 0.25, -0.4, 'updown', 0.15, 0.2, 0.2)
    s.crash([0, 4, 8, 12], 0.5)
    return s.render(rev_amt=0.2, target=-18.6)

# ====================================================================== WAVE 3 -- E minor, intense
def wave3():
    s = Song('wave3', 150, ['Em', 'C', 'D', 'Em', 'Em', 'C', 'D', 'B', 'Am', 'Am', 'Em', 'Em', 'C', 'D', 'B', 'B'], 'E', 'minor', swing=0.0)
    mel = ['E5:.5 G5:.5 B5:.5 E6:.5 D6:.5 B5:.5 G5:.5 B5:.5', 'E5:.5 G5:.5 C6:.5 E6:.5 D6:.5 C6:.5 G5:.5 E5:.5',
           'F#5:.5 A5:.5 D6:.5 F#6:.5 E6:.5 D6:.5 A5:.5 F#5:.5', 'E6:1 B5:1 G5:1 B5:1',
           'E5:.5 G5:.5 B5:.5 E6:.5 D6:.5 B5:.5 G5:.5 B5:.5', 'G5:.5 C6:.5 E6:.5 G6:.5 E6:1 C6:1',
           'A5:.5 D6:.5 F#6:.5 A6:.5 F#6:1 D6:1', 'D#6!:.5 F#6:.5 B6:1 F#6:1 D#6!:1',
           'C6:1 E6:1 A6:1 E6:1', 'C6:.5 E6:.5 D6:.5 C6:.5 A5:1 B5:1', 'G5:1 B5:1 E6:2', 'B5:1 D6:1 G5:2',
           'G5:.5 C6:.5 E6:.5 G6:.5 E6:2', 'A5:.5 D6:.5 F#6:.5 A6:.5 F#6:2', 'D#6!:.5 F#6:.5 B6:.5 F#6:.5 D#6!:2', 'D#6!:1 F#6:1 B5:2']
    s.melody(mel, P(0.125), 0.5, -0.05, 0.18, 0.25)
    s.melody(mel[4:], lambda m, d: note_pulse(m, d, 0.5, False, 0.004, 0.06, 0.6, 0.03), 0.14, 0.3, 0.12, 0.15, octave=-12, start=4)
    s.bass('gallop', BARS(1, 16), 0.5)
    s.drums('driveh', BARS(1, 16), 1.0, fill_bars={3, 7, 11, 15}, snare_g=0.8)
    s.comp(BARS(1, 16), [(0, .25), (1.5, .25), (2.75, .25)], 55, 0.16, make=lambda m, d: note_pluck(m, d, 3400))
    s.arp(BARS(5, 16), .25, 64, 0.1, 0.25, -0.4, 'up', 0.12, 0.2, 0.2)
    s.crash([0, 4, 8, 12], 0.5)
    return s.render(rev_amt=0.18, target=-18.2)

# ====================================================================== WARNING (boss arrives) -- dread builds, D minor with tritones
def warning():
    s = Song('warning', 100, ['Dm', 'Dm', 'Bb', 'Bb', 'Gm', 'Ab', 'Dm', 'A'], 'D', 'minor')
    mel = ['D5:1 D5:1 Ab5!:2', 'D5:1 D5:1 A5:2', 'F5:1 F5:1 B5!:2', 'F5:1 F5:1 Bb5:2', 'G5:1 G5:1 Db6!:2', 'Eb5:1 Eb5:1 Ab5:2', 'F5:.5 A5:.5 D6:1 A5:1 F5:1', 'E5:.5 G5:.5 C#6!:1 E6:2']
    s.melody(mel, lambda m, d: lp(note_pulse(m, d, 0.25, True, 0.01, 0.1, 0.8, 0.1), 3200, 1), 0.45, 0.0, 0.4, 0.3, check=False)
    s.pad(BARS(1, 8), 50, 0.22, 900)
    s.bass('pedal', BARS(1, 8), 0.6)
    s.drums('heart', BARS(1, 8), 0.9, kick_g=1.0)
    s.drums('drive', BARS(5, 8), 0.7, fill_bars={7})
    s.arp(BARS(3, 8), .25, 69, 0.14, 0.125, 0.5, 'saw', 0.35, 0.3, 0.2)
    return s.render(rev_amt=0.35, rev_time=2.0, target=-18.8)

# ====================================================================== BOSS BATTLE -- E minor, relentless
def boss():
    s = Song('boss', 168, ['Em', 'Em', 'C', 'D', 'Em', 'Em', 'Bb', 'B', 'C', 'D', 'Em', 'Em', 'C', 'D', 'Bb', 'B'], 'E', 'minor')
    mel = ['B5:.5 B5:.5 E6:1 D6:.5 B5:.5 G5:1', 'E6:.5 E6:.5 G6:1 F#6:.5 E6:.5 D6:1', 'C6:.5 C6:.5 G6:1 E6:.5 C6:.5 G5:1', 'D6:.5 D6:.5 A6:1 F#6:.5 D6:.5 A5:1',
           'B5:.5 E6:.5 G6:.5 B6:.5 A6:.5 G6:.5 E6:.5 B5:.5', 'E6:.5 G6:.5 B6:1 A6:.5 G6:.5 F#6:1', 'F6!:.5 F6!:.5 Bb6!:1 Ab6!:.5 F6!:.5 D6!:1', 'D#6!:.5 F#6:.5 B6:1 A6:.5 F#6:.5 D#6!:1',
           'G6:1 E6:1 C6:1 E6:1', 'A6:1 F#6:1 D6:1 F#6:1', 'G6:.5 B6:.5 E7!:1 D7!:1 B6:1', 'B6:.5 A6:.5 G6:.5 F#6:.5 E6:2',
           'E6:.5 G6:.5 C7!:1 G6:1 E6:1', 'F#6:.5 A6:.5 D7!:1 A6:1 F#6:1', 'D6!:.5 F6!:.5 Bb6!:.5 D7!:.5 Bb6!:2', 'D#6!:.5 F#6:.5 B6:.5 F#6:.5 D#6!:1 B5:1']
    s.melody(mel, P(0.125), 0.5, -0.05, 0.14, 0.2, check=False)
    s.melody(mel, lambda m, d: note_pulse(m, d, 0.5, False, 0.004, 0.06, 0.6, 0.03), 0.13, 0.3, 0.1, 0.1, octave=-12, check=False)
    s.bass('gallop', BARS(1, 16), 0.55)
    s.drums('double', BARS(1, 16), 1.0, fill_bars={3, 7, 11, 15}, snare_g=0.85, kick_g=1.0)
    s.comp(BARS(1, 16), [(0, .3), (1.5, .25), (2.5, .25)], 55, 0.17, make=lambda m, d: note_pluck(m, d, 3800))
    s.arp(BARS(1, 16), .25, 60, 0.1, 0.25, -0.4, 'updown', 0.1, 0.15, 0.2)
    s.crash([0, 4, 8, 12], 0.55)
    return s.render(rev_amt=0.16, target=-17.8)

# ====================================================================== FINALE (Dr Mantis) -- F# minor, epic
def finale():
    s = Song('finale', 174, ['F#m', 'D', 'E', 'C#7', 'F#m', 'D', 'E', 'C#7', 'Bm', 'Bm', 'F#m', 'F#m', 'D', 'E', 'C#7', 'C#7'], 'F#', 'minor')
    mel = ['A5:.5 A5:.5 C#6:1 F#6:1 E6:1', 'F#6:.5 F#6:.5 A6:1 F#6:.5 D6:.5 A5:1', 'G#5!:.5 G#5!:.5 B5:1 E6:1 G#6:1', 'E#6!:.5 E#6!:.5 G#6!:1 E#6!:1 C#6:1',
           'A5:.5 C#6:.5 F#6:.5 A6:.5 G#6:.5 F#6:.5 C#6:.5 A5:.5', 'D6:.5 F#6:.5 A6:1 F#6:.5 D6:.5 A5:1', 'E6:.5 G#6:.5 B6:1 G#6:.5 E6:.5 B5:1', 'E#6!:.5 G#6!:.5 C#7:1 B6:.5 G#6:.5 E#6!:1',
           'B5:1 D6:1 F#6:2', 'B5:.5 D6:.5 F#6:.5 B6:.5 A6:2', 'C#6:1 F#6:1 A6:2', 'A6:1 G#6:1 F#6:2',
           'F#6:.5 A6:.5 D7:1 A6:1 F#6:1', 'G#6:.5 B6:.5 E7:1 B6:1 G#6:1', 'E#6!:.5 G#6!:.5 C#7:1 G#6:1 E#6!:1', 'E#6!:1 G#6!:1 C#7:2']
    s.melody(mel, P(0.25), 0.5, -0.05, 0.2, 0.25, check=False)
    s.melody(mel, lambda m, d: note_organ(m, d), 0.2, 0.0, 0.3, 0.1, octave=-12, check=False)
    s.pad(BARS(1, 16), 54, 0.2, 2000, make=lambda m, d: note_pad(m, d, 0.14, 2400, 0.1, 0.5))
    s.bass('gallop', BARS(1, 16), 0.55)
    s.drums('double', BARS(1, 16), 1.0, fill_bars={3, 7, 11, 15}, snare_g=0.9, kick_g=1.0)
    s.comp(BARS(1, 16), [(0, .3), (1.5, .25), (2.5, .25)], 54, 0.15, make=lambda m, d: note_pluck(m, d, 3600))
    s.arp(BARS(1, 16), .25, 66, 0.09, 0.25, -0.45, 'updown', 0.1, 0.15, 0.2)
    s.crash([0, 2, 4, 6, 8, 12], 0.6)
    return s.render(rev_amt=0.22, target=-17.8)

# ====================================================================== DISCO (Disco Man) -- A minor funk
def disco():
    s = Song('disco', 116, ['Am7', 'D9', 'Gmaj7', 'Cmaj7', 'Fmaj7', 'Bm7b5', 'E7', 'E7', 'Am7', 'D9', 'Gmaj7', 'Cmaj7', 'Fmaj7', 'Bm7b5', 'E7', 'E7'], 'A', 'minor', swing=0.12)
    mel = ['A5:.5 R:.5 C6:.5 R:.25 E6:.25 D6:.5 C6:.5 A5:1', 'F#5!:.5 R:.5 A5:.5 R:.25 C6:.5 R:.25 A5:.5 F#5!:.5 R:.5', 'G5:.5 R:.5 B5:.5 R:.25 D6:.5 B5:.25 G5:1.5', 'E5:.5 G5:.5 C6:1 E6:1 G6:1',
           'F5:.5 A5:.5 C6:.5 A5:.5 F5:2', 'F5:.5 R:.5 B5!:.5 R:.25 D6:.5 R:.25 F6:.5 D6:.5 B5:.5', 'G#5!:.5 B5!:.5 E6:1 G#6!:1 R:1', 'E6:.5 D6:.5 B5:.5 G#5!:.5 E5:2']
    s.melody(mel, lambda m, d: sweep_lp(note_pluck(m, d, 4200), 4200, 900, 1.0, 2, 8), 0.55, 0.0, 0.2, 0.3, check=False)
    s.melody(mel, lambda m, d: sweep_lp(note_pluck(m, d, 4200), 4200, 900, 1.0, 2, 8), 0.55, 0.0, 0.2, 0.3, check=False, start=8)
    s.melody(['A6:.25 R:.25 E6:.25 R:.25 A6:.5 R:.5 E6:.5 R:1.5'] * 4, BELL(0.25), 0.16, 0.25, 0.3, 0.25, check=False, start=12)
    s.bass('funk', BARS(1, 16), 0.58, pluck=0.12)
    s.drums('disco', BARS(1, 16), 0.95, fill_bars={7, 15})
    s.comp(BARS(1, 16), [(0.5, .2), (1.5, .2), (2.5, .2), (3.25, .2)], 62, 0.17, make=lambda m, d: note_pulse(m, d, 0.25, False, 0.002, 0.06, 0.3, 0.02))
    s.pad(BARS(1, 16), 64, 0.13, 3200, make=lambda m, d: note_pad(m, d, 0.2, 3400, 0.05, 0.3))
    s.crash([0, 8], 0.5)
    return s.render(rev_amt=0.24, target=-18.6)

# ====================================================================== RESULTS (game over screen) -- F major, wistful music box
def over():
    s = Song('over', 72, ['Dm', 'Bb', 'F', 'C', 'Dm', 'Bb', 'C', 'F'], 'F', 'major')
    mel = ['A5:1 D6:1 F6:2', 'D6:1 F6:1 Bb5:2', 'C6:1 F6:1 A6:2', 'G6:1 E6:1 C6:2', 'F6:1 D6:1 A5:2', 'F6:1 D6:1 Bb5:2', 'G5:1 C6:1 E6:2', 'F6:4']
    s.melody(mel, BELL(0.9), 0.45, 0.0, 0.5, 0.35)
    s.pad(BARS(1, 8), 57, 0.2, 1000)
    s.arp(BARS(1, 8), 1.0, 60, 0.22, 0.5, 0.3, 'up', 0.5, 0.3, 0.9, make=lambda m, d: note_bell(m, 0.6, 0.6, 0.6) * 0.8)
    s.bass('pedal', BARS(1, 8), 0.4, make=lambda m, d: lp(note_tri(m, d, 0.05, 0.3, 0.8, 0.3), 600, 1))
    return s.render(rev_amt=0.45, rev_time=2.4, target=-22.0)

TRACKS = dict(home=home, story=story, wave1=wave1, wave2=wave2, wave3=wave3, warning=warning, boss=boss, finale=finale, disco=disco, over=over)

if __name__ == '__main__':
    import sys, os, time
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    names = sys.argv[2:] or list(TRACKS)
    for n in names:
        t0 = time.time(); x = TRACKS[n](); save(f'{out}/mus-{n}.wav', x)
        print(f'{n}: {x.shape[1] / SR:.1f}s peak {np.abs(x).max():.2f} loud {loudness(x):.1f} ({time.time() - t0:.0f}s render)')
    print('\n'.join(WARN) or 'no warnings')
