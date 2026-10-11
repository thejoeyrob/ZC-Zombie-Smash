/* Web Audio engine. Version 7.11 adds a synthesized "new" sound set (effects and music generated live,
   no audio files) next to the original recorded set, and keeps sound on when the iPhone is on silent. */
(() => {
  'use strict';

  const midi = (n) => 440 * Math.pow(2, (n - 69) / 12);
  const rnd = (a, b) => a + Math.random() * (b - a);

  // ---------------------------------------------------------------------------------------------
  // Synth voices
  // ---------------------------------------------------------------------------------------------
  class Synth {
    constructor(ctx) {
      this.ctx = ctx;
      const len = ctx.sampleRate;
      this.noiseBuf = ctx.createBuffer(1, len, ctx.sampleRate);
      const d = this.noiseBuf.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    }
    // One oscillator with a pitch glide, an optional filter and a percussive or sustained envelope.
    tone(dest, t, o) {
      const c = this.ctx,
        {
          type = 'sine',
          f,
          f2 = f,
          dur = 0.2,
          gain = 0.3,
          attack = 0.004,
          hold = 0,
          filter = null,
          detune = 0,
          vib = null,
          glide = 'exp',
        } = o,
        osc = c.createOscillator(),
        g = c.createGain();
      osc.type = type;
      osc.detune.value = detune;
      osc.frequency.setValueAtTime(Math.max(1, f), t);
      if (f2 !== f) {
        const end = t + Math.max(0.01, dur * 0.9);
        if (glide === 'lin') osc.frequency.linearRampToValueAtTime(Math.max(1, f2), end);
        else osc.frequency.exponentialRampToValueAtTime(Math.max(1, f2), end);
      }
      g.gain.setValueAtTime(0.0001, t);
      g.gain.linearRampToValueAtTime(gain, t + attack);
      if (hold > 0) g.gain.setValueAtTime(gain, t + attack + hold);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      let node = osc;
      if (filter) {
        const fl = c.createBiquadFilter();
        fl.type = filter.type || 'lowpass';
        fl.Q.value = filter.q ?? 0.7;
        fl.frequency.setValueAtTime(filter.f, t);
        if (filter.f2) fl.frequency.exponentialRampToValueAtTime(Math.max(20, filter.f2), t + dur);
        node.connect(fl);
        node = fl;
      }
      node.connect(g);
      g.connect(dest);
      if (vib) {
        const lfo = c.createOscillator(),
          lg = c.createGain();
        lfo.frequency.value = vib.rate;
        lg.gain.value = vib.depth;
        lfo.connect(lg);
        lg.connect(osc.frequency);
        lfo.start(t);
        lfo.stop(t + dur + 0.05);
      }
      osc.start(t);
      osc.stop(t + dur + 0.05);
      return g;
    }
    // Filtered noise burst.
    noise(dest, t, o) {
      const c = this.ctx,
        {
          dur = 0.1,
          gain = 0.3,
          attack = 0.002,
          filter = { type: 'highpass', f: 2000 },
          rate = 1,
        } = o,
        src = c.createBufferSource(),
        g = c.createGain(),
        fl = c.createBiquadFilter();
      src.buffer = this.noiseBuf;
      src.loop = true;
      src.playbackRate.value = rate;
      fl.type = filter.type;
      fl.Q.value = filter.q ?? 0.7;
      fl.frequency.setValueAtTime(filter.f, t);
      if (filter.f2) fl.frequency.exponentialRampToValueAtTime(Math.max(20, filter.f2), t + dur);
      g.gain.setValueAtTime(0.0001, t);
      g.gain.linearRampToValueAtTime(gain, t + attack);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      src.connect(fl);
      fl.connect(g);
      g.connect(dest);
      src.start(t, Math.random() * 0.8);
      src.stop(t + dur + 0.05);
      return g;
    }
  }

  // Sound effects. Each returns its length in seconds.
  const SFX = {
    pistol(s, d, t) {
      s.noise(d, t, { dur: 0.09, gain: 0.55, filter: { type: 'highpass', f: 1400, f2: 700 } });
      s.tone(d, t, { type: 'sine', f: 240, f2: 55, dur: 0.12, gain: 0.55 });
      s.tone(d, t, { type: 'square', f: 900, f2: 200, dur: 0.04, gain: 0.12 });
      return 0.2;
    },
    smg(s, d, t) {
      s.noise(d, t, { dur: 0.05, gain: 0.4, filter: { type: 'bandpass', f: 2600, q: 0.9 } });
      s.tone(d, t, { type: 'sine', f: 320, f2: 90, dur: 0.06, gain: 0.4 });
      return 0.1;
    },
    shotgun(s, d, t) {
      s.noise(d, t, { dur: 0.32, gain: 0.8, filter: { type: 'lowpass', f: 3800, f2: 300 } });
      s.noise(d, t, { dur: 0.08, gain: 0.5, filter: { type: 'highpass', f: 2200 } });
      s.tone(d, t, { type: 'sine', f: 120, f2: 36, dur: 0.3, gain: 0.8 });
      s.tone(d, t + 0.17, { type: 'sine', f: 90, f2: 40, dur: 0.18, gain: 0.25 });
      return 0.4;
    },
    dmr(s, d, t) {
      s.noise(d, t, { dur: 0.38, gain: 0.7, filter: { type: 'highpass', f: 1800, f2: 500 } });
      s.noise(d, t, { dur: 0.22, gain: 0.6, filter: { type: 'lowpass', f: 2400, f2: 200 } });
      s.tone(d, t, { type: 'sine', f: 170, f2: 32, dur: 0.3, gain: 0.75 });
      s.tone(d, t, { type: 'triangle', f: 2100, f2: 1500, dur: 0.22, gain: 0.1 });
      s.tone(d, t + 0.12, { type: 'sine', f: 110, f2: 40, dur: 0.25, gain: 0.18 });
      return 0.45;
    },
    burst(s, d, t) {
      for (let i = 0; i < 3; i++) {
        const u = t + i * 0.035;
        s.tone(d, u, {
          type: 'sawtooth',
          f: 1700,
          f2: 380,
          dur: 0.09,
          gain: 0.22,
          filter: { type: 'bandpass', f: 1400, q: 1.4 },
        });
        s.noise(d, u, { dur: 0.03, gain: 0.2, filter: { type: 'highpass', f: 4000 } });
      }
      return 0.2;
    },
    hit(s, d, t) {
      const k = rnd(0.9, 1.15);
      s.tone(d, t, { type: 'sine', f: 190 * k, f2: 60, dur: 0.1, gain: 0.55 });
      s.noise(d, t, { dur: 0.07, gain: 0.35, filter: { type: 'lowpass', f: 1500, f2: 400 } });
      s.tone(d, t, { type: 'square', f: 520 * k, f2: 180, dur: 0.035, gain: 0.07 });
      return 0.15;
    },
    hurt(s, d, t) {
      s.tone(d, t, {
        type: 'sawtooth',
        f: 330,
        f2: 90,
        dur: 0.38,
        gain: 0.38,
        filter: { type: 'lowpass', f: 1400, f2: 250 },
        vib: { rate: 24, depth: 22 },
      });
      s.noise(d, t, { dur: 0.16, gain: 0.35, filter: { type: 'lowpass', f: 1800, f2: 300 } });
      s.tone(d, t + 0.01, { type: 'sine', f: 110, f2: 40, dur: 0.25, gain: 0.5 });
      return 0.45;
    },
    grenade(s, d, t) {
      s.noise(d, t, { dur: 0.9, gain: 0.95, filter: { type: 'lowpass', f: 2600, f2: 90 } });
      s.noise(d, t, { dur: 0.25, gain: 0.5, filter: { type: 'highpass', f: 1500 } });
      s.tone(d, t, { type: 'sine', f: 95, f2: 26, dur: 0.8, gain: 0.95 });
      for (let i = 0; i < 6; i++)
        s.noise(d, t + 0.18 + i * rnd(0.04, 0.09), {
          dur: 0.05,
          gain: 0.18,
          filter: { type: 'bandpass', f: rnd(900, 3200), q: 2 },
        });
      return 1;
    },
    throw(s, d, t) {
      s.noise(d, t, {
        dur: 0.26,
        gain: 0.35,
        attack: 0.1,
        filter: { type: 'bandpass', f: 400, f2: 2000, q: 1.2 },
      });
      s.tone(d, t, { type: 'triangle', f: 300, f2: 760, dur: 0.2, gain: 0.18, glide: 'lin' });
      return 0.3;
    },
    ricochet(s, d, t) {
      const k = rnd(0.9, 1.2);
      s.tone(d, t, { type: 'triangle', f: 2600 * k, f2: 1700 * k, dur: 0.16, gain: 0.3 });
      s.tone(d, t, { type: 'sine', f: 3900 * k, f2: 2500 * k, dur: 0.1, gain: 0.14 });
      s.noise(d, t, { dur: 0.03, gain: 0.25, filter: { type: 'highpass', f: 5000 } });
      return 0.2;
    },
    pickup(s, d, t) {
      [72, 76, 79, 84].forEach((n, i) =>
        s.tone(d, t + i * 0.055, {
          type: 'square',
          f: midi(n),
          dur: 0.16,
          gain: 0.16,
          filter: { type: 'lowpass', f: 4200 },
        }),
      );
      s.tone(d, t + 0.17, { type: 'sine', f: midi(96), dur: 0.3, gain: 0.08 });
      return 0.5;
    },
    boost(s, d, t) {
      s.tone(d, t, {
        type: 'sawtooth',
        f: 180,
        f2: 1500,
        dur: 0.4,
        gain: 0.26,
        glide: 'lin',
        filter: { type: 'lowpass', f: 3000 },
      });
      [60, 67, 72, 79].forEach((n, i) =>
        s.tone(d, t + 0.1 + i * 0.07, { type: 'square', f: midi(n), dur: 0.22, gain: 0.12 }),
      );
      return 0.6;
    },
    alarm(s, d, t) {
      for (let i = 0; i < 4; i++)
        s.tone(d, t + i * 0.24, {
          type: 'square',
          f: i % 2 ? 440 : 620,
          dur: 0.22,
          gain: 0.26,
          attack: 0.01,
          hold: 0.12,
          filter: { type: 'lowpass', f: 1800 },
        });
      s.tone(d, t, { type: 'sine', f: 55, f2: 40, dur: 1, gain: 0.4 });
      return 1.1;
    },
    whoosh(s, d, t) {
      s.noise(d, t, {
        dur: 0.45,
        gain: 0.4,
        attack: 0.18,
        filter: { type: 'bandpass', f: 250, f2: 2800, q: 0.9 },
      });
      s.tone(d, t, { type: 'sine', f: 70, f2: 38, dur: 0.35, gain: 0.35 });
      return 0.5;
    },
    victory(s, d, t) {
      const notes = [60, 64, 67, 72, 67, 72, 76, 79];
      notes.forEach((n, i) => {
        const u = t + i * 0.11,
          long = i === notes.length - 1;
        s.tone(d, u, {
          type: 'square',
          f: midi(n),
          dur: long ? 0.9 : 0.14,
          gain: 0.17,
          hold: long ? 0.5 : 0,
          filter: { type: 'lowpass', f: 3600 },
        });
        s.tone(d, u, { type: 'triangle', f: midi(n - 12), dur: long ? 0.9 : 0.14, gain: 0.2 });
      });
      s.noise(d, t + 0.88, { dur: 0.6, gain: 0.2, filter: { type: 'highpass', f: 6000 } });
      return 1.8;
    },
    loss(s, d, t) {
      [67, 65, 63, 60].forEach((n, i) => {
        const u = t + i * 0.34;
        s.tone(d, u, {
          type: 'sawtooth',
          f: midi(n - 12),
          f2: midi(n - 12) * 0.97,
          dur: 0.5,
          gain: 0.28,
          filter: { type: 'lowpass', f: 900 },
        });
        s.tone(d, u, { type: 'sine', f: midi(n - 24), dur: 0.5, gain: 0.3 });
      });
      s.tone(d, t + 1.1, { type: 'sine', f: 60, f2: 24, dur: 1.1, gain: 0.5 });
      return 2.3;
    },
    'boss-attack'(s, d, t) {
      s.tone(d, t, {
        type: 'sawtooth',
        f: 120,
        f2: 52,
        dur: 0.5,
        gain: 0.4,
        filter: { type: 'lowpass', f: 1200, f2: 200 },
        detune: -8,
      });
      s.tone(d, t, {
        type: 'sawtooth',
        f: 123,
        f2: 55,
        dur: 0.5,
        gain: 0.3,
        filter: { type: 'lowpass', f: 1200, f2: 200 },
        detune: 9,
      });
      s.noise(d, t, { dur: 0.3, gain: 0.4, filter: { type: 'lowpass', f: 2200, f2: 200 } });
      s.tone(d, t + 0.02, { type: 'square', f: 300, f2: 70, dur: 0.14, gain: 0.12 });
      return 0.6;
    },
  };

  // ---------------------------------------------------------------------------------------------
  // Music: a small step sequencer. Every track is one loop that repeats, played live by the synth.
  // ---------------------------------------------------------------------------------------------
  class Drums {
    constructor(s) {
      this.s = s;
    }
    kick(d, t, g = 0.85) {
      this.s.tone(d, t, { type: 'sine', f: 165, f2: 42, dur: 0.17, gain: g, attack: 0.002 });
      // Phone speakers cannot reproduce the deep part, so add an audible punch on top.
      this.s.tone(d, t, {
        type: 'triangle',
        f: 460,
        f2: 120,
        dur: 0.06,
        gain: g * 0.45,
        attack: 0.001,
      });
      this.s.noise(d, t, { dur: 0.02, gain: 0.15, filter: { type: 'lowpass', f: 3000 } });
    }
    snare(d, t, g = 0.5) {
      this.s.noise(d, t, { dur: 0.17, gain: g, filter: { type: 'bandpass', f: 2100, q: 0.6 } });
      this.s.tone(d, t, { type: 'triangle', f: 230, f2: 150, dur: 0.1, gain: g * 0.7 });
    }
    clap(d, t, g = 0.4) {
      for (let i = 0; i < 3; i++)
        this.s.noise(d, t + i * 0.011, {
          dur: 0.07,
          gain: g,
          filter: { type: 'bandpass', f: 1500, q: 0.8 },
        });
      this.s.noise(d, t + 0.033, {
        dur: 0.16,
        gain: g * 0.8,
        filter: { type: 'bandpass', f: 1500, q: 0.8 },
      });
    }
    hat(d, t, g = 0.16, open = false) {
      this.s.noise(d, t, {
        dur: open ? 0.2 : 0.035,
        gain: g,
        filter: { type: 'highpass', f: 7500 },
      });
    }
    crash(d, t, g = 0.3) {
      this.s.noise(d, t, { dur: 1.1, gain: g, filter: { type: 'highpass', f: 4500 } });
    }
    tom(d, t, f = 120, g = 0.6) {
      this.s.tone(d, t, { type: 'sine', f, f2: f * 0.5, dur: 0.28, gain: g });
    }
  }

  // Chords are given as MIDI triads. Roots are the bass notes for each bar.
  const CH = {
    Am: [57, 60, 64],
    F: [53, 57, 60],
    C: [60, 64, 67],
    G: [55, 59, 62],
    E: [52, 56, 59],
    Em: [52, 55, 59],
    D: [50, 54, 57],
    B: [47, 51, 54],
    Dm: [50, 53, 57],
    G7: [55, 59, 62, 65],
    Am7: [57, 60, 64, 67],
    Dm7: [50, 53, 57, 60],
    Cmaj7: [60, 64, 67, 71],
    E7: [52, 56, 59, 62],
  };

  function makeTracks(synth) {
    const dr = new Drums(synth),
      S = synth;
    const bass = (d, t, n, len, o = {}) =>
      S.tone(d, t, {
        type: o.type || 'sawtooth',
        f: midi(n),
        dur: len,
        gain: o.gain ?? 0.34,
        attack: 0.004,
        filter: { type: 'lowpass', f: o.cut || 700, f2: (o.cut || 700) * 0.45, q: 2 },
      });
    const pluck = (d, t, n, len, g = 0.1, type = 'square') =>
      S.tone(d, t, {
        type,
        f: midi(n),
        dur: len,
        gain: g,
        attack: 0.003,
        filter: { type: 'lowpass', f: 3800, f2: 1200 },
        detune: rnd(-4, 4),
      });
    const lead = (d, t, n, len, g = 0.14, type = 'square') =>
      S.tone(d, t, {
        type,
        f: midi(n),
        dur: len,
        gain: g,
        attack: 0.01,
        hold: len * 0.35,
        filter: { type: 'lowpass', f: 4200 },
        vib: { rate: 5.5, depth: 5 },
      });
    const pad = (d, t, chord, len, g = 0.05) =>
      chord.forEach((n, i) =>
        S.tone(d, t, {
          type: 'triangle',
          f: midi(n),
          dur: len,
          gain: g,
          attack: Math.min(0.6, len * 0.3),
          hold: len * 0.4,
          detune: (i - 1) * 6,
          filter: { type: 'lowpass', f: 1800 },
        }),
      );
    const stab = (d, t, chord, len, g = 0.1, cut = 2400) =>
      chord.forEach((n) =>
        S.tone(d, t, {
          type: 'sawtooth',
          f: midi(n + 12),
          dur: len,
          gain: g,
          attack: 0.003,
          filter: { type: 'lowpass', f: cut, f2: cut * 0.3, q: 1.5 },
          detune: rnd(-6, 6),
        }),
      );

    return {
      // Driving A-minor arcade theme. Bars 1-4 build the groove, bars 5-8 add the lead.
      main: {
        bpm: 138,
        bars: 8,
        step(d, t, s, k, bar, sd) {
          const prog = [CH.Am, CH.F, CH.C, CH.G, CH.Am, CH.F, CH.G, CH.E],
            roots = [45, 41, 48, 43, 45, 41, 43, 40],
            ch = prog[bar],
            root = roots[bar];
          if (k % 4 === 0) dr.kick(d, t);
          if (k === 4 || k === 12) dr.snare(d, t);
          if (k % 2 === 0) dr.hat(d, t, 0.13);
          else if (bar > 0) dr.hat(d, t, 0.05);
          if (k === 14) dr.hat(d, t, 0.14, true);
          if (k === 0 && bar % 4 === 0) dr.crash(d, t, 0.22);
          if (k % 2 === 0) bass(d, t, root + (k === 6 || k === 14 ? 12 : 0), sd * 1.8);
          if (k === 11) bass(d, t, root + 12, sd * 0.9, { gain: 0.2 });
          const arp = [0, 2, 1, 3, 2, 1, 3, 1, 0, 2, 1, 3, 2, 3, 1, 2][k],
            chord = [ch[0], ch[1], ch[2], ch[0] + 12][arp];
          pluck(d, t, chord + 12, sd * 0.95, bar < 4 ? 0.085 : 0.06);
          if (k === 0) pad(d, t, ch, sd * 16, 0.05);
          if (bar >= 4) {
            const mel = {
              4: [
                [0, 76, 3],
                [4, 81, 2],
                [6, 79, 2],
                [8, 76, 4],
                [12, 74, 2],
                [14, 76, 2],
              ],
              5: [
                [0, 72, 3],
                [4, 77, 2],
                [6, 76, 2],
                [8, 72, 4],
                [12, 69, 2],
                [14, 72, 2],
              ],
              6: [
                [0, 74, 3],
                [4, 79, 2],
                [6, 77, 2],
                [8, 74, 4],
                [12, 71, 2],
                [14, 74, 2],
              ],
              7: [
                [0, 76, 3],
                [4, 80, 2],
                [6, 83, 2],
                [8, 81, 6],
              ],
            }[bar];
            for (const [at, n, len] of mel) if (at === k) lead(d, t, n, len * sd, 0.12);
          }
        },
      },
      // Heavier, faster boss battle in E minor: double kicks, saw bass, power stabs and a siren on the last bar.
      boss: {
        bpm: 152,
        bars: 8,
        step(d, t, s, k, bar, sd) {
          const prog = [CH.Em, CH.Em, CH.C, CH.D, CH.Em, CH.Em, CH.C, CH.B],
            roots = [40, 40, 36, 38, 40, 40, 36, 35],
            ch = prog[bar],
            root = roots[bar];
          if ([0, 3, 6, 8, 11, 14].includes(k)) dr.kick(d, t, 0.95);
          if (k === 4 || k === 12) dr.snare(d, t, 0.55);
          dr.hat(d, t, k % 2 ? 0.06 : 0.14);
          if (k === 0 && bar % 4 === 0) dr.crash(d, t, 0.3);
          if (bar === 7 && k >= 8 && k % 2 === 0) dr.snare(d, t, 0.3 + k * 0.02);
          bass(d, t, root + (k % 4 === 3 ? 12 : 0), sd * 0.9, {
            gain: 0.36,
            cut: 520 + (k % 8) * 70,
          });
          if ([0, 6, 10].includes(k)) stab(d, t, ch, sd * 1.4, 0.075, 2600);
          if (k % 4 === 2) pluck(d, t, ch[(k >> 2) % 3] + 24, sd * 0.8, 0.05, 'sawtooth');
          if (k === 0) pad(d, t, ch, sd * 16, 0.045);
          if (bar >= 4 && k % 2 === 0) {
            const run = [76, 77, 79, 77, 76, 74, 76, 79][((k >> 1) + bar) % 8];
            lead(d, t, run, sd * 1.6, 0.1, 'sawtooth');
          }
          if (bar === 7)
            S.tone(d, t, {
              type: 'sawtooth',
              f: 400 + k * 90,
              dur: sd * 1.2,
              gain: 0.04,
              filter: { type: 'lowpass', f: 3000 },
            });
        },
      },
      // Disco Man's dance floor: four-on-the-floor, octave bass, off-beat hats and chord stabs.
      disco: {
        bpm: 118,
        bars: 8,
        step(d, t, s, k, bar, sd) {
          const prog = [CH.Am7, CH.Dm7, CH.G7, CH.Cmaj7, CH.Am7, CH.Dm7, CH.E7, CH.Am7],
            roots = [45, 38, 43, 36, 45, 38, 40, 45],
            ch = prog[bar],
            root = roots[bar];
          if (k % 4 === 0) dr.kick(d, t, 0.8);
          if (k === 4 || k === 12) dr.clap(d, t, 0.3);
          if (k % 4 === 2) dr.hat(d, t, 0.2, true);
          else if (k % 2 === 1) dr.hat(d, t, 0.06);
          bass(d, t, root + (k % 4 === 2 || k === 15 ? 12 : 0), sd * 0.85, {
            type: 'sawtooth',
            gain: 0.32,
            cut: 900,
          });
          if ([2, 3, 6, 10, 11, 14].includes(k)) stab(d, t, ch, sd * 0.7, 0.07, 3200);
          if (k === 0) pad(d, t, ch, sd * 16, 0.05);
          if (bar >= 4) {
            const mel = {
              4: [
                [2, 81, 2],
                [6, 84, 2],
                [8, 83, 2],
                [10, 81, 2],
                [12, 79, 4],
              ],
              5: [
                [2, 77, 2],
                [6, 81, 2],
                [8, 79, 2],
                [10, 77, 2],
                [12, 74, 4],
              ],
              6: [
                [2, 76, 2],
                [6, 80, 2],
                [8, 83, 2],
                [10, 80, 2],
                [12, 76, 4],
              ],
              7: [
                [0, 81, 6],
                [8, 76, 2],
                [10, 79, 2],
                [12, 81, 4],
              ],
            }[bar];
            for (const [at, n, len] of mel) if (at === k) lead(d, t, n, len * sd, 0.1, 'triangle');
          }
        },
      },
      // Boss entrance: slow, low and threatening. Replaced by the fight track when the boss arrives.
      entrance: {
        bpm: 86,
        bars: 4,
        step(d, t, s, k, bar, sd) {
          const roots = [38, 38, 39, 37],
            ch = [CH.Dm, CH.Dm, [51, 55, 58], [49, 53, 56]][bar];
          if (k === 0 || k === 3) dr.tom(d, t, k ? 90 : 105, 0.7);
          if (k === 8 && bar % 2) dr.crash(d, t, 0.12);
          if (k === 0) {
            bass(d, t, roots[bar] - 12, sd * 16, { gain: 0.4, cut: 260 });
            pad(
              d,
              t,
              ch.map((n) => n - 12),
              sd * 16,
              0.07,
            );
            pad(d, t, ch, sd * 16, 0.045);
          }
          if (k % 4 === 0 && bar >= 2)
            S.tone(d, t, {
              type: 'sawtooth',
              f: midi(ch[k % 3] + 24),
              dur: sd * 3,
              gain: 0.03,
              filter: { type: 'lowpass', f: 1800 },
              vib: { rate: 7, depth: 18 },
            });
        },
      },
    };
  }

  // ---------------------------------------------------------------------------------------------
  // The audio system the game talks to.
  // ---------------------------------------------------------------------------------------------
  // Loudness trims measured by rendering each effect offline, so the loud ones do not clip the mix.
  const TRIM = {
    pistol: 0.95,
    shotgun: 0.75,
    dmr: 0.55,
    grenade: 0.58,
    hit: 1,
    hurt: 1,
    alarm: 0.9,
  };
  const FILES = [
    'pistol',
    'smg',
    'shotgun',
    'dmr',
    'burst',
    'hit',
    'hurt',
    'grenade',
    'throw',
    'ricochet',
    'pickup',
    'boost',
    'alarm',
    'whoosh',
    'victory',
    'loss',
    'boss-attack',
  ];

  class AudioSystem {
    constructor() {
      this.ctx = null;
      this.buffers = new Map();
      this.loading = new Map();
      this.music = null;
      this.track = null;
      this.wantTrack = null;
      this.paused = true;
      this.last = {};
      this.voices = 0;
      this.seq = null;
      this.keepAlive = null;
      const defaults = { music: 0.45, effects: 0.75, set: 'new' };
      try {
        this.settings = { ...defaults, ...(JSON.parse(localStorage.getItem('zs7-audio')) || {}) };
      } catch {
        this.settings = defaults;
      }
      if (this.settings.set !== 'original') this.settings.set = 'new';
      // iPhone: Web Audio is silenced by the ring/silent switch unless the page asks for "playback" audio.
      this.playbackSession();
    }
    get synthMode() {
      return this.settings.set !== 'original';
    }
    playbackSession() {
      try {
        if (navigator.audioSession) navigator.audioSession.type = 'playback';
      } catch {}
    }
    // Older iPhones have no Audio Session API. Playing a silent <audio> clip switches Safari to playback audio.
    startKeepAlive() {
      if (this.keepAlive || navigator.audioSession) return;
      try {
        const n = 800,
          buf = new ArrayBuffer(44 + n),
          v = new DataView(buf),
          str = (o, s) => [...s].forEach((c, i) => v.setUint8(o + i, c.charCodeAt(0)));
        str(0, 'RIFF');
        v.setUint32(4, 36 + n, true);
        str(8, 'WAVEfmt ');
        v.setUint32(16, 16, true);
        v.setUint16(20, 1, true);
        v.setUint16(22, 1, true);
        v.setUint32(24, 8000, true);
        v.setUint32(28, 8000, true);
        v.setUint16(32, 1, true);
        v.setUint16(34, 8, true);
        str(36, 'data');
        v.setUint32(40, n, true);
        for (let i = 0; i < n; i++) v.setUint8(44 + i, 128);
        const el = new Audio(URL.createObjectURL(new Blob([buf], { type: 'audio/wav' })));
        el.loop = true;
        el.setAttribute('playsinline', '');
        this.keepAlive = el;
        el.play().catch(() => {
          this.keepAlive = null;
        });
      } catch {}
    }
    async unlock() {
      try {
        this.playbackSession();
        this.startKeepAlive();
        if (!this.ctx) {
          this.ctx = new (window.AudioContext || window.webkitAudioContext)();
          this.master = this.ctx.createGain();
          const comp = this.ctx.createDynamicsCompressor();
          comp.threshold.value = -14;
          comp.knee.value = 14;
          comp.ratio.value = 5;
          comp.attack.value = 0.004;
          comp.release.value = 0.18;
          this.master.connect(comp);
          comp.connect(this.ctx.destination);
          this.fx = this.ctx.createGain();
          this.fx.gain.value = this.settings.effects;
          this.fx.connect(this.master);
          this.musicBus = this.ctx.createGain();
          this.musicBus.gain.value = this.settings.music;
          this.musicBus.connect(this.master);
          this.master.gain.value = this.paused ? 0 : 1;
          this.synth = new Synth(this.ctx);
          this.tracks = makeTracks(this.synth);
          if (!this.synthMode) for (const name of FILES) this.buffer('sfx-' + name + '.mp3');
        }
        if (this.ctx.state !== 'running') await this.ctx.resume();
        if (this.wantTrack && !this.paused) this.playMusic(this.wantTrack);
      } catch {}
    }
    async buffer(file) {
      if (this.buffers.has(file)) return this.buffers.get(file);
      if (this.loading.has(file)) return this.loading.get(file);
      const task = fetch('./' + file)
        .then((r) => {
          if (!r.ok) throw Error(file);
          return r.arrayBuffer();
        })
        .then((b) => this.ctx.decodeAudioData(b))
        .then((b) => {
          this.buffers.set(file, b);
          return b;
        })
        .catch(() => null)
        .finally(() => this.loading.delete(file));
      this.loading.set(file, task);
      return task;
    }

    // ---- music -------------------------------------------------------------------------------
    stopMusic(fade = 0.4) {
      const now = this.ctx.currentTime;
      if (this.seq) {
        clearInterval(this.seq.timer);
        const old = this.seq;
        old.gain.gain.cancelScheduledValues(now);
        old.gain.gain.setValueAtTime(old.gain.gain.value, now);
        old.gain.gain.linearRampToValueAtTime(0, now + fade);
        setTimeout(() => old.gain.disconnect(), (fade + 0.3) * 1000);
        this.seq = null;
      }
      if (this.music) {
        const old = this.music;
        old.gain.gain.cancelScheduledValues(now);
        old.gain.gain.setValueAtTime(old.gain.gain.value, now);
        old.gain.gain.linearRampToValueAtTime(0, now + fade);
        try {
          old.source.stop(now + fade + 0.05);
        } catch {}
        this.music = null;
      }
    }
    startSequencer(track) {
      const def = this.tracks[track];
      if (!def) return;
      const gain = this.ctx.createGain(),
        now = this.ctx.currentTime;
      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(0.6, now + 0.25);
      gain.connect(this.musicBus);
      const seq = { def, gain, step: 0, next: now + 0.06, sd: 60 / def.bpm / 4, timer: null };
      this.seq = seq;
      this.runSequencer();
    }
    runSequencer() {
      const seq = this.seq;
      if (!seq) return;
      clearInterval(seq.timer);
      seq.next = Math.max(seq.next, this.ctx.currentTime + 0.04);
      const tick = () => {
        const total = seq.def.bars * 16;
        while (seq.next < this.ctx.currentTime + 0.18) {
          const s = seq.step % total;
          try {
            seq.def.step(seq.gain, seq.next, s, s % 16, Math.floor(s / 16), seq.sd);
          } catch {}
          seq.next += seq.sd;
          seq.step++;
        }
      };
      tick();
      seq.timer = setInterval(tick, 28);
    }
    async playMusic(track) {
      this.wantTrack = track;
      if (!this.ctx || this.paused || this.track === track) return;
      this.track = track;
      if (this.synthMode) {
        this.stopMusic();
        this.startSequencer(track);
        return;
      }
      const buffer = await this.buffer('music-' + track + '.mp3');
      if (!buffer || this.wantTrack !== track || this.paused) {
        if (this.track === track) this.track = null;
        return;
      }
      this.stopMusic();
      const now = this.ctx.currentTime,
        source = this.ctx.createBufferSource(),
        gain = this.ctx.createGain();
      source.buffer = buffer;
      source.loop = track !== 'entrance';
      source.connect(gain);
      gain.connect(this.musicBus);
      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(1, now + 0.4);
      source.start();
      source.onended = () => {
        source.disconnect();
        gain.disconnect();
        if (this.track === track && !source.loop) {
          this.track = null;
          if (this.wantTrack && this.wantTrack !== track) this.playMusic(this.wantTrack);
        }
      };
      this.music = { source, gain };
    }

    // ---- sound effects ------------------------------------------------------------------------
    async sfx(name, volume = 1) {
      if (!this.ctx || this.paused || this.settings.effects === 0 || this.voices > 22) return;
      const time = performance.now(),
        minGap = { hit: 50, ricochet: 80, 'boss-attack': 140 }[name] || 25;
      if (time - (this.last[name] || 0) < minGap) return;
      this.last[name] = time;
      if (this.synthMode) {
        const fn = SFX[name];
        if (!fn) return;
        const bus = this.ctx.createGain();
        bus.gain.value = volume * (TRIM[name] ?? 1);
        bus.connect(this.fx);
        const len = fn(this.synth, bus, this.ctx.currentTime + 0.005);
        this.voices++;
        setTimeout(
          () => {
            this.voices--;
            bus.disconnect();
          },
          (len + 0.2) * 1000,
        );
        return;
      }
      const buffer = await this.buffer('sfx-' + name + '.mp3');
      if (!buffer || this.paused) return;
      const s = this.ctx.createBufferSource(),
        g = this.ctx.createGain();
      s.buffer = buffer;
      s.playbackRate.value = ['hit', 'pistol', 'smg'].includes(name)
        ? 0.96 + Math.random() * 0.08
        : 1;
      g.gain.value = volume;
      s.connect(g);
      g.connect(this.fx);
      this.voices++;
      s.onended = () => {
        this.voices--;
        s.disconnect();
        g.disconnect();
      };
      s.start();
    }
    save() {
      try {
        localStorage.setItem('zs7-audio', JSON.stringify(this.settings));
      } catch {}
    }
    set(kind, value) {
      this.settings[kind] = Math.max(0, Math.min(1, Number(value)));
      this.save();
      if (this.ctx) {
        if (kind === 'effects')
          this.fx.gain.setTargetAtTime(this.settings.effects, this.ctx.currentTime, 0.03);
        else this.musicBus.gain.setTargetAtTime(this.settings.music, this.ctx.currentTime, 0.05);
      }
    }
    // Switch between the new synthesized sounds and the original recorded ones.
    setSoundSet(name) {
      this.settings.set = name === 'original' ? 'original' : 'new';
      this.save();
      if (!this.ctx) return;
      if (this.ctx && this.track) {
        this.stopMusic(0.15);
        this.track = null;
      }
      if (!this.synthMode) for (const n of FILES) this.buffer('sfx-' + n + '.mp3');
      if (this.wantTrack && !this.paused) this.playMusic(this.wantTrack);
    }
    pause() {
      this.paused = true;
      if (this.ctx) {
        this.master.gain.setTargetAtTime(0, this.ctx.currentTime, 0.035);
        if (this.seq) clearInterval(this.seq.timer);
      }
    }
    resume() {
      this.paused = false;
      if (this.ctx) {
        this.master.gain.setTargetAtTime(1, this.ctx.currentTime, 0.025);
        if (this.seq) this.runSequencer();
      }
      this.unlock();
    }
  }
  AudioSystem.internals = { Synth, SFX, makeTracks }; // exposed for offline rendering in tests
  window.ZSAudio = AudioSystem;
})();
