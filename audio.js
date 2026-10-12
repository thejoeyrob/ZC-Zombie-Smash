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
    // The boss lands: a deep, heavy impact with a rising scrape that drops away.
    doom(s, d, t) {
      s.tone(d, t, { type: 'sine', f: 90, f2: 24, dur: 1.1, gain: 0.95 });
      s.tone(d, t, {
        type: 'sawtooth',
        f: 160,
        f2: 40,
        dur: 0.9,
        gain: 0.3,
        filter: { type: 'lowpass', f: 900, f2: 120 },
      });
      s.noise(d, t, { dur: 1.1, gain: 0.7, filter: { type: 'lowpass', f: 3000, f2: 120 } });
      s.noise(d, t, { dur: 0.2, gain: 0.45, filter: { type: 'highpass', f: 2500 } });
      return 1.3;
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

  // Orchestral percussion for the "real" music style: bass drum, orchestral snare, shaker, cymbal, timpani toms.
  class RealDrums extends Drums {
    kick(d, t, g = 0.85) {
      this.s.tone(d, t, { type: 'sine', f: 120, f2: 48, dur: 0.38, gain: g, attack: 0.003 });
      this.s.tone(d, t, { type: 'sine', f: 300, f2: 90, dur: 0.07, gain: g * 0.4, attack: 0.001 });
      this.s.noise(d, t, { dur: 0.05, gain: 0.16, filter: { type: 'lowpass', f: 1400 } });
    }
    snare(d, t, g = 0.5) {
      this.s.noise(d, t, {
        dur: 0.22,
        gain: g * 0.8,
        filter: { type: 'bandpass', f: 1700, q: 0.5 },
      });
      this.s.noise(d, t, { dur: 0.08, gain: g * 0.4, filter: { type: 'highpass', f: 4000 } });
      this.s.tone(d, t, { type: 'sine', f: 190, f2: 140, dur: 0.12, gain: g * 0.6 });
    }
    clap(d, t, g = 0.4) {
      this.tom(d, t, 95, g * 1.4);
    }
    hat(d, t, g = 0.16, open = false) {
      this.s.noise(d, t, {
        dur: open ? 0.3 : 0.07,
        gain: g * 0.55,
        attack: 0.012,
        filter: { type: 'bandpass', f: 6200, q: 0.9 },
      });
    }
    crash(d, t, g = 0.3) {
      this.s.noise(d, t, {
        dur: 2.6,
        gain: g * 0.9,
        attack: 0.05,
        filter: { type: 'highpass', f: 3200 },
      });
      this.s.noise(d, t, {
        dur: 1.6,
        gain: g * 0.4,
        attack: 0.03,
        filter: { type: 'bandpass', f: 5600, q: 0.6 },
      });
    }
    tom(d, t, f = 120, g = 0.6) {
      this.s.tone(d, t, { type: 'sine', f: f * 1.3, f2: f * 0.75, dur: 0.5, gain: g });
      this.s.noise(d, t, { dur: 0.05, gain: g * 0.2, filter: { type: 'lowpass', f: 1000 } });
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

  function makeTracks(synth, real = false) {
    const dr = real ? new RealDrums(synth) : new Drums(synth),
      S = synth;
    let bass = (d, t, n, len, o = {}) =>
      S.tone(d, t, {
        type: o.type || 'sawtooth',
        f: midi(n),
        dur: len,
        gain: o.gain ?? 0.34,
        attack: o.attack ?? 0.004,
        filter: { type: 'lowpass', f: o.cut || 700, f2: (o.cut || 700) * 0.45, q: 2 },
      });
    let pluck = (d, t, n, len, g = 0.1, type = 'square') =>
      S.tone(d, t, {
        type,
        f: midi(n),
        dur: len,
        gain: g,
        attack: 0.003,
        filter: { type: 'lowpass', f: 3800, f2: 1200 },
        detune: rnd(-4, 4),
      });
    let lead = (d, t, n, len, g = 0.14, type = 'square') =>
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
    let pad = (d, t, chord, len, g = 0.05) =>
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
    let stab = (d, t, chord, len, g = 0.1, cut = 2400) =>
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
    // Dark, slow voices for the horror score.
    let drone = (d, t, n, len, g = 0.1, cut = 380) =>
      [-9, 7].forEach((det) =>
        S.tone(d, t, {
          type: 'sawtooth',
          f: midi(n),
          dur: len,
          gain: g * 0.6,
          attack: Math.min(1.2, len * 0.35),
          hold: len * 0.45,
          detune: det,
          filter: { type: 'lowpass', f: cut, f2: cut * 0.6, q: 1 },
          vib: { rate: 0.4, depth: 1.2 },
        }),
      );
    let heartbeat = (d, t, g = 0.45) => {
      S.tone(d, t, { type: 'sine', f: 100, f2: 46, dur: 0.24, gain: g, attack: 0.004 });
      S.tone(d, t + 0.19, { type: 'sine', f: 84, f2: 42, dur: 0.22, gain: g * 0.7, attack: 0.004 });
      // A little click so phone speakers can reproduce it.
      S.noise(d, t, { dur: 0.03, gain: g * 0.25, filter: { type: 'lowpass', f: 900 } });
    };
    let bell = (d, t, n, len = 3.2, g = 0.07) =>
      [
        [1, 1],
        [2.76, 0.45],
        [5.4, 0.2],
        [8.9, 0.1],
      ].forEach(([ratio, amp]) =>
        S.tone(d, t, {
          type: 'sine',
          f: midi(n) * ratio,
          dur: len / (1 + (ratio - 1) * 0.25),
          gain: g * amp,
          attack: 0.002,
        }),
      );
    let timp = (d, t, n = 38, g = 0.7) => {
      S.tone(d, t, {
        type: 'sine',
        f: midi(n) * 1.7,
        f2: midi(n),
        dur: 0.55,
        gain: g,
        attack: 0.002,
      });
      S.tone(d, t, { type: 'triangle', f: midi(n + 12), f2: midi(n), dur: 0.12, gain: g * 0.4 });
      S.noise(d, t, { dur: 0.14, gain: g * 0.35, filter: { type: 'lowpass', f: 800 } });
    };
    let brass = (d, t, n, len, g = 0.1, o = {}) =>
      S.tone(d, t, {
        type: 'sawtooth',
        f: midi(n),
        dur: len,
        gain: g,
        attack: o.attack ?? Math.min(0.2, len * 0.3),
        hold: len * 0.45,
        detune: rnd(-8, 8),
        filter: { type: 'lowpass', f: o.from || 500, f2: o.to || 1700, q: 1.2 },
      });
    let swell = (d, t, len, g = 0.05, from = 300, to = 1500) =>
      S.noise(d, t, {
        dur: len,
        gain: g,
        attack: len * 0.85,
        filter: { type: 'bandpass', f: from, f2: to, q: 0.8 },
      });

    // "Real" style: strings, cello, harp and brass built from layered detuned voices instead of single chip-like waves.
    if (real) {
      const strings = (d, t, n, len, g, cut, att, o = {}) =>
        [-9, 0, 9].forEach((det) =>
          S.tone(d, t, {
            type: 'sawtooth',
            f: midi(n),
            dur: len,
            gain: g / 2.4,
            attack: att,
            hold: len * (o.hold ?? 0.45),
            detune: det + rnd(-2, 2),
            filter: { type: 'lowpass', f: cut, f2: cut * (o.fall ?? 0.7), q: 0.5 },
            vib: { rate: rnd(4.6, 5.4), depth: o.vib ?? 4 },
          }),
        );
      bass = (d, t, n, len, o = {}) => {
        S.tone(d, t, {
          type: 'sawtooth',
          f: midi(n),
          dur: len * 1.05,
          gain: (o.gain ?? 0.34) * 0.85,
          attack: Math.max(0.03, o.attack ?? 0.03),
          filter: { type: 'lowpass', f: (o.cut || 700) * 0.7, f2: (o.cut || 700) * 0.3, q: 0.8 },
          vib: { rate: 4.8, depth: 2 },
        });
        S.tone(d, t, {
          type: 'sine',
          f: midi(n),
          dur: len,
          gain: (o.gain ?? 0.34) * 0.6,
          attack: 0.02,
        });
      };
      pluck = (d, t, n, len, g = 0.1) =>
        [
          [1, 1],
          [2, 0.42],
          [3, 0.2],
          [4.01, 0.1],
        ].forEach(([r, a]) =>
          S.tone(d, t, {
            type: 'sine',
            f: midi(n) * r,
            dur: Math.max(0.5, len * 2.2) / r ** 0.5,
            gain: g * 1.3 * a,
            attack: 0.003,
          }),
        );
      lead = (d, t, n, len, g = 0.14) =>
        strings(d, t, n, len * 1.1, g * 1.5, 3000, 0.07, { hold: 0.7, vib: 7 });
      pad = (d, t, chord, len, g = 0.05) =>
        chord.forEach((n) =>
          strings(d, t, n, len, g * 2.2, 1500, Math.min(0.9, len * 0.35), { hold: 0.5, vib: 3 }),
        );
      stab = (d, t, chord, len, g = 0.1, cut = 2400) =>
        chord.forEach((n) =>
          strings(d, t, n + 12, Math.max(0.2, len), g * 1.2, cut * 0.75, 0.025, {
            hold: 0.1,
            fall: 0.35,
            vib: 2,
          }),
        );
      drone = (d, t, n, len, g = 0.1, cut = 380) => {
        strings(d, t, n, len, g * 1.4, cut * 1.5, Math.min(1.4, len * 0.4), {
          hold: 0.5,
          fall: 0.6,
          vib: 2,
        });
        S.tone(d, t, {
          type: 'sine',
          f: midi(n),
          dur: len,
          gain: g * 0.9,
          attack: Math.min(1.2, len * 0.3),
          hold: len * 0.5,
        });
      };
      brass = (d, t, n, len, g = 0.1, o = {}) =>
        [-7, 7].forEach((det) =>
          S.tone(d, t, {
            type: 'sawtooth',
            f: midi(n),
            dur: len,
            gain: g * 0.65,
            attack: Math.max(0.07, o.attack ?? Math.min(0.2, len * 0.3)),
            hold: len * 0.45,
            detune: det,
            filter: { type: 'lowpass', f: o.from || 500, f2: o.to || 1700, q: 0.9 },
          }),
        );
      timp = (d, t, n = 38, g = 0.7) => {
        S.tone(d, t, {
          type: 'sine',
          f: midi(n) * 1.5,
          f2: midi(n),
          dur: 0.9,
          gain: g,
          attack: 0.003,
        });
        S.tone(d, t, { type: 'sine', f: midi(n) * 2, f2: midi(n) * 1.5, dur: 0.35, gain: g * 0.3 });
        S.noise(d, t, { dur: 0.1, gain: g * 0.3, filter: { type: 'lowpass', f: 700 } });
      };
    }

    // Keys: everything is built on D minor so the transitions between tracks stay in key.
    const DM = [50, 53, 57],
      GM = [43, 46, 50],
      BB = [46, 50, 53],
      AM = [45, 49, 52];

    return {
      // Wave music: slow, dark and sparse. A low drone, a heartbeat, distant bells and a creeping pulse.
      main: {
        bpm: 84,
        bars: 8,
        step(d, t, s, k, bar, sd) {
          const roots = [38, 38, 46, 45, 38, 43, 46, 45],
            chords = [DM, DM, BB, AM, DM, GM, BB, AM],
            root = roots[bar],
            ch = chords[bar];
          if (k === 0) {
            drone(d, t, root, sd * 16, 0.13);
            pad(
              d,
              t,
              ch.map((n) => n + 12),
              sd * 16,
              0.028,
            );
            heartbeat(d, t, 0.4);
          }
          if (k === 8 && bar >= 2) heartbeat(d, t, 0.22);
          if (k === 0) bass(d, t, root, sd * 9, { gain: 0.1, cut: 240, attack: 0.05 });
          if (k === 0 && bar % 4 === 0) swell(d, t, sd * 64, 0.03, 260, 1100);
          if (k === 8 && bar % 4 === 3) timp(d, t, 38, 0.3);
          // Muted pulse that creeps in for the second half of the loop.
          if (bar >= 4 && k % 2 === 0)
            S.tone(d, t, {
              type: 'square',
              f: midi(root + 12),
              dur: sd * 0.7,
              gain: 0.035,
              attack: 0.002,
              filter: { type: 'lowpass', f: 480 },
            });
          if (bar >= 4 && k % 4 === 2) dr.hat(d, t, 0.025);
          // A few lonely bell notes.
          const bells = {
            0: [[2, 69]],
            1: [[10, 65]],
            2: [
              [6, 64],
              [14, 62],
            ],
            3: [[8, 73]],
            4: [
              [4, 69],
              [12, 72],
            ],
            5: [[2, 70]],
            6: [
              [8, 65],
              [13, 67],
            ],
            7: [[6, 73]],
          }[bar];
          for (const [at, n] of bells) if (at === k) bell(d, t, n, 3.4, 0.055);
        },
      },
      // Boss warning: the same key and tempo, but the heartbeat speeds up and the dread stacks until the boss lands.
      entrance: {
        bpm: 84,
        bars: 4,
        step(d, t, s, k, bar, sd) {
          if (k === 0) {
            drone(d, t, 38, sd * 16, 0.15, 420);
            drone(d, t, 26 + 12 + bar, sd * 16, 0.07, 420);
            if (bar >= 1) pad(d, t, [51, 57], sd * 16, 0.05);
            if (bar >= 2) pad(d, t, [56, 62], sd * 16, 0.05);
            swell(d, t, sd * 16, 0.03 + bar * 0.012, 260 + bar * 160, 900 + bar * 700);
            S.tone(d, t, {
              type: 'sawtooth',
              f: midi(57 + bar * 3),
              f2: midi(64 + bar * 3),
              dur: sd * 16,
              gain: 0.022,
              attack: sd * 8,
              filter: { type: 'bandpass', f: 900, q: 2 },
              glide: 'lin',
            });
          }
          // Heartbeat accelerating: once a bar, twice, four times, then every other step.
          const every = [16, 8, 4, 2][bar];
          if (k % every === 0) heartbeat(d, t, 0.4 + bar * 0.1);
          if (bar >= 1 && k === 0)
            S.tone(d, t, {
              type: 'sawtooth',
              f: midi(81),
              dur: sd * 16,
              gain: 0.014,
              attack: sd * 6,
              vib: { rate: 6.5, depth: 9 },
              filter: { type: 'lowpass', f: 3000 },
            });
          if (bar >= 2 && k === 0) {
            [38, 45, 53].forEach((n) => brass(d, t, n, sd * 8, 0.1));
            timp(d, t, 38, 0.6);
          }
          if (bar === 3 && k >= 8) timp(d, t, 38 + (k % 2) * 7, 0.2 + (k - 8) * 0.06);
          if (bar === 3 && k === 8) swell(d, t, sd * 8, 0.12, 2500, 9000);
        },
      },
      // Story intro: eerie and slow. A low drone, beating high notes, whispering air, distant bells and a faint heartbeat.
      story: {
        bpm: 60,
        bars: 4,
        level: 0.55,
        step(d, t, s, k, bar, sd) {
          if (k === 0 && bar % 2 === 0) {
            drone(d, t, 38, sd * 32, 0.17, 300);
            drone(d, t, 45, sd * 32, 0.08, 360);
          }
          if (k === 0) {
            // Two notes a semitone apart make a slow, uneasy beating.
            [74, 75].forEach((n, i) =>
              S.tone(d, t, {
                type: 'sine',
                f: midi(n),
                dur: sd * 16,
                gain: 0.022,
                attack: sd * 6,
                hold: sd * 4,
                detune: i * 5,
                vib: { rate: 0.5, depth: 2 },
              }),
            );
            pad(
              d,
              t,
              [
                [57, 62],
                [58, 62],
                [57, 60],
                [55, 61],
              ][bar].map((n) => n + 0),
              sd * 16,
              0.04,
            );
          }
          if (k === 0 && bar % 2 === 1) swell(d, t, sd * 16, 0.045, 700, 2400);
          if (k === 0 && bar % 2 === 0) heartbeat(d, t, 0.22);
          const bells = [
            [0, 74],
            [8, 70],
            [4, 69],
            [12, 73],
          ][bar];
          if (k === bells[0]) bell(d, t, bells[1], 5, 0.05);
          if (bar === 3 && k === 8) timp(d, t, 38, 0.25);
        },
      },
      // Boss fight: fast, heavy and driving, in the same key. Bars 5-8 add a heroic, desperate horn line.
      boss: {
        bpm: 160,
        bars: 8,
        step(d, t, s, k, bar, sd) {
          const roots = [38, 38, 46, 45, 38, 43, 46, 45],
            chords = [DM, DM, BB, AM, DM, GM, BB, AM],
            root = roots[bar],
            ch = chords[bar],
            fill = bar % 4 === 3 && k >= 12;
          if ([0, 3, 6, 8, 11, 14].includes(k)) dr.kick(d, t, 0.95);
          if ((k === 4 || k === 12) && !fill) dr.snare(d, t, 0.58);
          if (fill) dr.snare(d, t, 0.3 + (k - 12) * 0.12);
          dr.hat(d, t, k % 2 ? 0.07 : 0.15);
          if (k === 0 && bar % 4 === 0) dr.crash(d, t, 0.3);
          if (bar === 7 && k >= 8 && k % 2 === 0) dr.tom(d, t, 150 - (k - 8) * 6, 0.45);
          // Phrygian-flavoured bass riff: root, octave, flat seventh and the flat second for menace.
          const riff = [0, null, 0, 12, 0, null, 10, 0, 0, null, 0, 12, 5, null, 3, 1][k];
          if (riff !== null)
            bass(d, t, root + (riff > 12 ? 0 : riff), sd * 0.85, {
              gain: 0.34,
              cut: 520 + (k % 4) * 140,
            });
          if ([0, 6, 10].includes(k)) {
            brass(d, t, root + 12, sd * 2.4, 0.075, { from: 700, to: 2600, attack: 0.01 });
            brass(d, t, root + 19, sd * 2.4, 0.06, { from: 700, to: 2600, attack: 0.01 });
          }
          if (k % 2 === 1) pluck(d, t, ch[(k >> 1) % 3] + 24, sd * 0.8, 0.032, 'sawtooth');
          if (k === 0)
            pad(
              d,
              t,
              ch.map((n) => n + 12),
              sd * 16,
              0.04,
            );
          if (bar >= 4) {
            const horn = {
              4: [
                [0, 74, 4],
                [4, 69, 2],
                [6, 72, 2],
                [8, 74, 4],
                [12, 77, 4],
              ],
              5: [
                [0, 74, 3],
                [4, 70, 2],
                [6, 72, 2],
                [8, 75, 4],
                [12, 74, 4],
              ],
              6: [
                [0, 77, 4],
                [4, 74, 2],
                [6, 70, 2],
                [8, 74, 4],
                [12, 72, 4],
              ],
              7: [
                [0, 73, 6],
                [8, 76, 4],
                [12, 81, 4],
              ],
            }[bar];
            for (const [at, n, len] of horn)
              if (at === k) brass(d, t, n, len * sd, 0.1, { from: 900, to: 3200, attack: 0.02 });
          }
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
      // Victory fanfare after a boss falls: the game's own brass and timpani, turned to the major key.
      // One-shot. `off` shifts it into the key of the music it replaces.
      victory: {
        bpm: 132,
        bars: 4,
        tail: 2.6,
        level: 0.5,
        oneShot: true,
        step(d, t, s, k, bar, sd, off = 0) {
          const m = (n) => n + off,
            roots = [38, 43, 45, 38],
            chords = [
              [50, 54, 57, 62],
              [47, 50, 55, 59],
              [49, 52, 57, 61],
              [50, 54, 57, 62],
            ],
            root = roots[bar];
          if (s === 0) {
            dr.crash(d, t, 0.34);
            timp(d, t, m(38), 0.8);
          }
          if (k % 4 === 0) dr.kick(d, t, 0.7);
          if (bar >= 1 && (k === 4 || k === 12)) dr.clap(d, t, 0.25);
          if (bar >= 1) dr.hat(d, t, k % 2 ? 0.05 : 0.11);
          if (k === 0) {
            chords[bar].forEach((n) =>
              brass(d, t, m(n), sd * (bar === 3 ? 14 : 7), 0.08, { from: 700, to: 2600 }),
            );
            pad(
              d,
              t,
              chords[bar].map((n) => m(n) + 12),
              sd * (bar === 3 ? 15 : 8),
              0.04,
            );
          }
          if (bar < 3 && k % 2 === 0)
            bass(d, t, m(root) + (k % 4 === 2 ? 12 : 0), sd * 1.5, { gain: 0.3, cut: 800 });
          if (bar === 0 && k < 8)
            pluck(d, t, m([62, 66, 69, 74, 78, 81, 86, 81][k]), sd * 1.4, 0.07);
          if (bar === 0 && k >= 8)
            pluck(d, t, m([74, 69, 66, 69, 74, 78, 81, 86][k - 8]), sd * 1.2, 0.05);
          const tune = {
            1: [
              [0, 81, 4],
              [4, 78, 2],
              [6, 79, 2],
              [8, 81, 4],
              [12, 83, 4],
            ],
            2: [
              [0, 85, 4],
              [4, 83, 2],
              [6, 81, 2],
              [8, 78, 4],
              [12, 76, 2],
              [14, 78, 2],
            ],
            3: [[0, 86, 14]],
          }[bar];
          if (tune)
            for (const [at, n, len] of tune)
              if (at === k)
                brass(d, t, m(n - 12), len * sd, 0.1, { from: 900, to: 3200, attack: 0.02 });
          if (bar === 3 && k === 0) {
            dr.crash(d, t, 0.34);
            timp(d, t, m(38), 0.9);
            bass(d, t, m(38), sd * 14, { gain: 0.34, cut: 700 });
            bell(d, t, m(74), 2.6, 0.06);
          }
          if (bar === 3 && k >= 10 && k % 2 === 0) timp(d, t, m(38) + (k % 4 ? 7 : 0), 0.35);
        },
      },
      // Defeat: the music closes on a slow, fateful cadence (iv, V, i) with tolling bells and timpani.
      defeat: {
        bpm: 54,
        bars: 2,
        tail: 3.2,
        oneShot: true,
        step(d, t, s, k, bar, sd, off = 0) {
          const m = (n) => n + off;
          if (bar === 0 && k === 0) {
            drone(d, t, m(43), sd * 8, 0.16, 520);
            [55, 58, 62].forEach((n) =>
              brass(d, t, m(n), sd * 8, 0.09, { from: 400, to: 1100, attack: 0.15 }),
            );
            timp(d, t, m(43), 0.85);
            bell(d, t, m(67), 3.4, 0.07);
          }
          if (bar === 0 && k === 8) {
            drone(d, t, m(45), sd * 8, 0.18, 560);
            [57, 61, 64].forEach((n) =>
              brass(d, t, m(n), sd * 8, 0.1, { from: 400, to: 1300, attack: 0.15 }),
            );
            timp(d, t, m(45), 1);
            bell(d, t, m(69), 3.4, 0.07);
          }
          if (bar === 0 && k === 12) swell(d, t, sd * 5, 0.2, 2200, 9000);
          if (bar === 1 && k === 0) {
            drone(d, t, m(38), sd * 16, 0.22, 600);
            [50, 53, 57, 62].forEach((n) =>
              brass(d, t, m(n), sd * 15, 0.1, { from: 350, to: 900, attack: 0.25 }),
            );
            timp(d, t, m(38), 1.1);
            bell(d, t, m(62), 4.2, 0.08);
            bell(d, t, m(50), 5, 0.07);
            dr.crash(d, t, 0.18);
          }
          if (bar === 1 && k === 8) bell(d, t, m(50), 5, 0.05);
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
    doom: 0.7,
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
      this.keyOffset = 0; // semitones from D, so stingers land in the key of the music they replace
      this.holdTrack = null; // a one-shot stinger (victory or defeat) that must finish before music resumes
      this.holdUntil = 0;
      const defaults = { music: 0.45, effects: 0.75, set: 'new', style: 'real' };
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
    get tracks() {
      return this.settings.style === 'synth' ? this.tracksSynth : this.tracksReal;
    }
    // The layered orchestral voices are denser than the single chip waves, so they sit a little lower.
    get levelScale() {
      return this.settings.style === 'synth' ? 1 : 0.6;
    }
    // A hall reverb that only the "real" music style feeds.
    buildReverb() {
      const c = this.ctx,
        len = Math.floor(c.sampleRate * 2.6),
        ir = c.createBuffer(2, len, c.sampleRate);
      for (let ch = 0; ch < 2; ch++) {
        const d = ir.getChannelData(ch);
        for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.6);
      }
      this.reverb = c.createConvolver();
      this.reverb.buffer = ir;
      this.wet = c.createGain();
      this.wet.gain.value = this.settings.style === 'synth' ? 0 : 0.32;
      this.musicBus.connect(this.reverb);
      this.reverb.connect(this.wet);
      this.wet.connect(this.master);
    }
    setMusicStyle(name) {
      this.settings.style = name === 'synth' ? 'synth' : 'real';
      this.save();
      if (!this.ctx) return;
      this.wet.gain.setTargetAtTime(
        this.settings.style === 'synth' ? 0 : 0.32,
        this.ctx.currentTime,
        0.05,
      );
      if (this.track && !this.holdTrack) {
        this.stopMusic(0.15);
        this.track = null;
      }
      if (this.wantTrack && !this.paused) this.playMusic(this.wantTrack);
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
          this.tracksSynth = makeTracks(this.synth);
          this.tracksReal = makeTracks(this.synth, true);
          this.buildReverb();
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
      gain.gain.linearRampToValueAtTime((def.level ?? 0.6) * this.levelScale, now + 0.25);
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
      // A victory or defeat stinger finishes first; the hold timer then plays whatever is wanted.
      if (this.holdTrack && this.holdUntil > performance.now()) return;
      this.track = track;
      if (this.synthMode) {
        this.keyOffset = track === 'disco' ? -5 : 0;
        this.stopMusic();
        this.startSequencer(track);
        return;
      }
      const buffer = await this.buffer(
        'music-' + (track === 'story' ? 'entrance' : track) + '.mp3',
      );
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

    // ---- stingers: victory after a boss, defeat when Joey falls ---------------------------------
    // The running music fades out and the stinger plays, in the same key, all the way through.
    stinger(name) {
      if (!this.ctx || this.paused || !this.synthMode) return;
      const def = this.tracks[name];
      if (!def) return;
      this.cancelStinger(0.05);
      this.stopMusic(name === 'defeat' ? 0.3 : 0.45);
      const ctx = this.ctx,
        sd = 60 / def.bpm / 4,
        total = def.bars * 16,
        off = this.keyOffset || 0,
        t0 = ctx.currentTime + (name === 'defeat' ? 0.28 : 0.1),
        gain = ctx.createGain();
      gain.gain.value = (def.level ?? 0.6) * this.levelScale;
      gain.connect(this.musicBus);
      for (let s = 0; s < total; s++) {
        try {
          def.step(gain, t0 + s * sd, s, s % 16, Math.floor(s / 16), sd, off);
        } catch {}
      }
      const length = t0 - ctx.currentTime + total * sd + (def.tail || 2);
      this.stingerGain = gain;
      this.track = name;
      this.holdTrack = name;
      this.holdUntil = performance.now() + length * 1000;
      // After a victory the game carries on with the wave music; after a defeat nothing resumes by itself.
      this.wantTrack = name === 'victory' ? 'main' : null;
      clearTimeout(this.holdTimer);
      this.holdTimer = setTimeout(() => {
        this.holdTrack = null;
        this.holdUntil = 0;
        this.track = null;
        setTimeout(() => gain.disconnect(), 500);
        if (!this.paused && this.wantTrack) this.playMusic(this.wantTrack);
      }, length * 1000);
    }
    cancelStinger(fade = 0.2) {
      clearTimeout(this.holdTimer);
      if (this.stingerGain && this.ctx) {
        const g = this.stingerGain,
          now = this.ctx.currentTime;
        g.gain.cancelScheduledValues(now);
        g.gain.setValueAtTime(g.gain.value, now);
        g.gain.linearRampToValueAtTime(0, now + fade);
        setTimeout(() => g.disconnect(), (fade + 0.1) * 1000);
      }
      this.stingerGain = null;
      if (this.holdTrack && this.track === this.holdTrack) this.track = null;
      this.holdTrack = null;
      this.holdUntil = 0;
    }

    // ---- sound effects ------------------------------------------------------------------------
    async sfx(name, volume = 1) {
      if (!this.ctx || this.paused || this.settings.effects === 0 || this.voices > 22) return;
      const time = performance.now(),
        minGap = { hit: 50, ricochet: 80, 'boss-attack': 140 }[name] || 25;
      if (time - (this.last[name] || 0) < minGap) return;
      this.last[name] = time;
      if (this.synthMode) {
        if (name === 'victory' || name === 'loss') return;
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
        // The results screen opens while the defeat cadence is still ringing: let it finish, then go quiet.
        const ring = this.holdTrack === 'defeat' ? this.holdUntil - performance.now() : 0;
        clearTimeout(this.muteTimer);
        if (ring > 0)
          this.muteTimer = setTimeout(() => {
            if (this.paused) this.master.gain.setTargetAtTime(0, this.ctx.currentTime, 0.05);
          }, ring);
        else this.master.gain.setTargetAtTime(0, this.ctx.currentTime, 0.035);
        if (this.seq) clearInterval(this.seq.timer);
      }
    }
    resume() {
      this.paused = false;
      clearTimeout(this.muteTimer);
      if (this.holdTrack) this.cancelStinger(0.15);
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
