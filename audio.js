/* Web Audio engine. Music is played from files (the cinematic ARCADE score is pre-rendered, so nothing is
   synthesized while you play), sound effects are short recorded buffers, and iPhone silent mode is bypassed. */
(() => {
  'use strict';

  // Sets: ARCADE (rendered cinematic score + recorded effects), NEW (new tune and effects), ORIGINAL (first mix).
  const SETS = ['arcade', 'neo', 'original'];
  const NEW_SFX = new Set(['pistol', 'hit', 'pickup', 'boost', 'victory', 'loss', 'whoosh']);
  // Lengths (seconds) of the one-shot ARCADE stingers, so the music resumes at the right moment.
  const STINGER_LENGTH = { victory: 10, defeat: 12.2 };
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
      this.streams = new Map(); // music file -> { el, gain } (one permanent element per file, created when first needed)
      this.music = null; // the stream that is playing now: { file, el, gain, source }
      this.track = null;
      this.wantTrack = null;
      this.paused = true;
      this.last = {};
      this.voices = 0;
      this.seq = null; // kept for the game's watchdog; nothing is sequenced live any more
      this.keepAlive = null;
      this.disco = false; // the disco theme is a different key, so its stingers use their own recording
      this.holdTrack = null; // a one-shot stinger (victory or defeat) that must finish before music resumes
      this.holdUntil = 0;
      this.lastRebuild = 0;
      const defaults = { music: 0.4, effects: 0.72, set: 'arcade' };
      try {
        this.settings = { ...defaults, ...(JSON.parse(localStorage.getItem('zs7-audio')) || {}) };
      } catch {
        this.settings = defaults;
      }
      if (!SETS.includes(this.settings.set)) this.settings.set = 'arcade';
      for (const key of ['music', 'effects']) {
        const value = Number(this.settings[key]);
        this.settings[key] = Number.isFinite(value)
          ? Math.max(0, Math.min(1, value))
          : defaults[key];
      }
      this.fxEpoch = 0;
      this.musicSeq = 0;
      // iPhone: Web Audio is silenced by the ring/silent switch unless the page asks for "playback" audio.
      this.playbackSession();
    }
    // True for the ARCADE set, which has its own victory and defeat stingers.
    get synthMode() {
      return this.settings.set === 'arcade';
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
    // ---- context ---------------------------------------------------------------------------------
    async unlock() {
      try {
        this.playbackSession();
        this.startKeepAlive();
        if (!this.ctx) {
          this.ctx = new (window.AudioContext || window.webkitAudioContext)();
          const ctx = this.ctx;
          this.master = ctx.createGain();
          const comp = ctx.createDynamicsCompressor();
          comp.threshold.value = -14;
          comp.knee.value = 14;
          comp.ratio.value = 5;
          comp.attack.value = 0.004;
          comp.release.value = 0.18;
          this.master.connect(comp);
          comp.connect(ctx.destination);
          this.fx = ctx.createGain();
          this.fx.gain.value = this.settings.effects;
          this.fx.connect(this.master);
          this.musicBus = ctx.createGain();
          this.musicBus.gain.value = this.settings.music;
          this.musicBus.connect(this.master);
          this.master.gain.value = this.paused ? 0 : 1;
          ctx.onstatechange = () => {
            if (ctx === this.ctx && ctx.state !== 'running' && !document.hidden)
              setTimeout(() => this.revive(), 400);
          };
          for (const name of FILES) this.buffer(this.sfxFile(name));
        }
        if (this.ctx.state !== 'running') await this.ctx.resume();
        if (this.wantTrack && !this.paused) this.playMusic(this.wantTrack);
      } catch {}
    }
    sfxFile(name) {
      const base = name === 'doom' ? 'boss-attack' : name;
      return this.settings.set === 'neo' && NEW_SFX.has(base) ? 'new-' + base + '.mp3' : 'sfx-' + base + '.mp3';
    }
    // Which file plays a track in the current set.
    musicFile(track) {
      const set = this.settings.set;
      if (set === 'neo') return track === 'main' ? 'new-main.mp3' : 'music-' + track + '.mp3';
      if (set === 'arcade' && track !== 'debo') {
        // After the first boss the wave music is the recorded tune; before that it is the rendered score.
        if (track === 'main' && this.afterBoss) return 'music-main.mp3';
        return 'arc-' + track + '.mp3';
      }
      return 'music-' + track + '.mp3';
    }
    loops(track) {
      return this.settings.set === 'arcade' || track !== 'entrance';
    }
    async buffer(file) {
      if (this.buffers.has(file)) return this.buffers.get(file);
      if (this.loading.has(file)) return this.loading.get(file);
      const decodeContext = this.ctx;
      if (!decodeContext) return null;
      const task = fetch('./' + file)
        .then((r) => {
          if (!r.ok) throw Error(file);
          return r.arrayBuffer();
        })
        .then((b) => decodeContext.decodeAudioData(b))
        .then((b) => {
          this.buffers.set(file, b);
          return b;
        })
        .catch(() => null)
        .finally(() => {
          if (this.loading.get(file) === task) this.loading.delete(file);
        });
      this.loading.set(file, task);
      return task;
    }

    // ---- music -------------------------------------------------------------------------------
    // Music streams from the file instead of being decoded to memory: low memory, no long decode, nothing runs
    // while it plays. One element per file is kept and reused, so switching tracks creates nothing new.
    stream(file) {
      let s = this.streams.get(file);
      if (s && s.ctx === this.ctx) return s;
      const el = new Audio('./' + file);
      el.preload = 'auto';
      el.setAttribute('playsinline', '');
      const src = this.ctx.createMediaElementSource(el),
        gain = this.ctx.createGain();
      gain.gain.value = 0;
      src.connect(gain);
      gain.connect(this.musicBus);
      s = { file, el, gain, ctx: this.ctx };
      this.streams.set(file, s);
      return s;
    }
    // iPhone only lets an audio element start inside a tap. Start every music file once, silently, during the first
    // touch so later track changes (boss reveals, victory) can begin on their own.
    prime() {
      if (!this.ctx || this.primedCtx === this.ctx) return;
      this.primedCtx = this.ctx;
      const files = new Set(['main', 'entrance', 'boss', 'disco', 'debo'].map((t) => this.musicFile(t)));
      if (this.synthMode) {
        files.add('music-main.mp3');
        for (const n of ['victory', 'defeat', 'victory-d', 'defeat-d']) files.add('arc-' + n + '.mp3');
      }
      for (const f of files) {
        try {
          const s = this.stream(f);
          if (this.music && this.music.el === s.el) continue;
          s.el
            .play()
            .then(() => {
              if (!this.music || this.music.el !== s.el) {
                s.el.pause();
                s.el.currentTime = 0;
              }
            })
            .catch(() => {});
        } catch {}
      }
    }
    preload(track) {
      try {
        if (this.ctx) this.stream(this.musicFile(track));
      } catch {}
    }
    stopMusic(fade = 0.4) {
      const old = this.music;
      this.music = null;
      if (!old || !this.ctx) return;
      const now = this.ctx.currentTime;
      old.gain.gain.cancelScheduledValues(now);
      old.gain.gain.setValueAtTime(old.gain.gain.value, now);
      old.gain.gain.linearRampToValueAtTime(0, now + fade);
      setTimeout(() => {
        if (this.music !== old) {
          try {
            old.el.pause();
          } catch {}
        }
      }, (fade + 0.1) * 1000);
    }
    async playMusic(track) {
      // The opening story plays the wave music (the recorded entrance cue is only a few seconds long).
      if (track === 'story') track = this.synthMode ? 'entrance' : 'main';
      this.wantTrack = track;
      if (!this.ctx || this.paused || (this.track === track && this.music)) return;
      // A victory or defeat stinger finishes first; the hold timer then plays whatever is wanted.
      if (this.holdTrack && this.holdUntil > performance.now()) return;
      this.track = track;
      this.disco = track === 'disco';
      const seq = ++this.musicSeq;
      let s;
      try {
        s = this.stream(this.musicFile(track));
      } catch {
        if (this.track === track) this.track = null;
        return;
      }
      s.el.loop = this.loops(track);
      this.stopMusic(0.4);
      try {
        s.el.currentTime = 0;
      } catch {}
      try {
        await s.el.play();
      } catch {
        // Not allowed yet (needs a tap) or interrupted: the next revive/touch asks again.
        if (seq === this.musicSeq && this.track === track) this.track = null;
        return;
      }
      // Another request started while this one was starting: only the newest may keep playing.
      if (seq !== this.musicSeq || this.paused || this.wantTrack !== track) {
        if (seq === this.musicSeq && this.track === track) this.track = null;
        try {
          s.el.pause();
        } catch {}
        return;
      }
      const now = this.ctx.currentTime;
      s.gain.gain.cancelScheduledValues(now);
      s.gain.gain.setValueAtTime(0, now);
      s.gain.gain.linearRampToValueAtTime(1, now + 0.4);
      this.music = { file: s.file, el: s.el, gain: s.gain, source: { stop: () => s.el.pause() } };
      if (!s.el.loop) {
        s.el.onended = () => {
          if (this.music && this.music.el === s.el && this.track === track) {
            this.music = null;
            this.track = null;
            if (this.wantTrack && this.wantTrack !== track) this.playMusic(this.wantTrack);
          }
        };
      }
    }

    // ---- stingers: victory after a boss, defeat when Joey falls (ARCADE set) --------------------------
    // The running music fades out and the stinger plays all the way through, in the key of the music it replaced.
    stinger(name) {
      if (!this.ctx || this.paused || !this.synthMode) return;
      const key = name + (this.disco ? '-d' : '');
      this.cancelStinger(0.05);
      this.stopMusic(name === 'defeat' ? 0.3 : 0.45);
      let s;
      try {
        s = this.stream('arc-' + key + '.mp3');
      } catch {
        return;
      }
      s.el.loop = false;
      try {
        s.el.currentTime = 0;
      } catch {}
      s.el.play().catch(() => {});
      const now = this.ctx.currentTime;
      s.gain.gain.cancelScheduledValues(now);
      s.gain.gain.setValueAtTime(1, now);
      const length = STINGER_LENGTH[name] || 10;
      this.stingerStream = s;
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
        try {
          s.el.pause();
        } catch {}
        this.stingerStream = null;
        if (!this.paused && this.wantTrack) this.playMusic(this.wantTrack);
      }, length * 1000);
    }
    cancelStinger(fade = 0.2) {
      clearTimeout(this.holdTimer);
      const s = this.stingerStream;
      if (s && this.ctx) {
        const now = this.ctx.currentTime;
        s.gain.gain.cancelScheduledValues(now);
        s.gain.gain.setValueAtTime(s.gain.gain.value, now);
        s.gain.gain.linearRampToValueAtTime(0, now + fade);
        setTimeout(() => {
          try {
            s.el.pause();
          } catch {}
        }, (fade + 0.1) * 1000);
      }
      this.stingerStream = null;
      if (this.holdTrack && this.track === this.holdTrack) this.track = null;
      this.holdTrack = null;
      this.holdUntil = 0;
    }

    // ---- sound effects ------------------------------------------------------------------------
    duckMusic(depth = 0.64, duration = 0.45) {
      if (!this.ctx || this.paused) return;
      const p = this.musicBus.gain,
        now = this.ctx.currentTime;
      if (p.cancelAndHoldAtTime) p.cancelAndHoldAtTime(now);
      else {
        p.cancelScheduledValues(now);
        p.setValueAtTime(p.value, now);
      }
      p.linearRampToValueAtTime(this.settings.music * depth, now + 0.025);
      p.linearRampToValueAtTime(this.settings.music, now + duration);
    }
    // Plain HTML audio is the safety net for effects when the Web Audio context is asleep or a file did not decode.
    fallbackSfx(name, volume = 1) {
      if (this.paused || this.settings.effects === 0) return;
      const t = performance.now();
      if (t - (this.last['f' + name] || 0) < 60) return;
      this.last['f' + name] = t;
      try {
        const el = new Audio('./' + this.sfxFile(name));
        el.volume = Math.min(1, volume * this.settings.effects);
        el.play().catch(() => {});
      } catch {}
    }
    async sfx(name, volume = 1) {
      if (this.ctx && this.ctx.state !== 'running') return this.fallbackSfx(name, volume);
      if (!this.ctx || this.paused || this.settings.effects === 0 || this.voices >= 22) return;
      const time = performance.now(),
        minGap = { hit: 50, ricochet: 80, 'boss-attack': 140 }[name] || 25;
      if (time - (this.last[name] || 0) < minGap) return;
      this.last[name] = time;
      if (['grenade', 'doom', 'hurt'].includes(name))
        this.duckMusic(name === 'hurt' ? 0.78 : 0.6, name === 'grenade' ? 0.65 : 0.42);
      // ARCADE plays its own stingers for the boss win and the defeat, so the recorded cues stay quiet there.
      if (this.synthMode && (name === 'victory' || name === 'loss')) return;
      const epoch = this.fxEpoch;
      const buffer = await this.buffer(this.sfxFile(name));
      if (!buffer) return this.fallbackSfx(name, volume);
      if (this.paused || epoch !== this.fxEpoch || this.voices >= 22 || performance.now() - time > 450)
        return;
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
      if (!['music', 'effects'].includes(kind) || !Number.isFinite(Number(value))) return;
      this.settings[kind] = Math.max(0, Math.min(1, Number(value)));
      this.save();
      if (this.ctx) {
        if (kind === 'effects')
          this.fx.gain.setTargetAtTime(this.settings.effects, this.ctx.currentTime, 0.03);
        else {
          this.musicBus.gain.cancelScheduledValues(this.ctx.currentTime);
          this.musicBus.gain.setTargetAtTime(this.settings.music, this.ctx.currentTime, 0.05);
        }
      }
    }
    setSoundSet(name) {
      this.settings.set = SETS.includes(name) ? name : 'arcade';
      this.fxEpoch++;
      this.save();
      if (!this.ctx) return;
      for (const n of FILES) this.buffer(this.sfxFile(n));
      if (this.track && !this.holdTrack) {
        this.stopMusic(0.15);
        this.track = null;
      }
      if (this.wantTrack && !this.paused) this.playMusic(this.wantTrack);
    }
    // Hard reset for "no sound": throw the context away and build a fresh one.
    reset() {
      this.keepAlive?.pause();
      this.keepAlive = null;
      this.paused = false;
      return this.rebuild(true);
    }
    // Throw the context away and make a fresh one (inside a real touch it starts running at once).
    rebuild(force = false) {
      const now = performance.now();
      // A touch never rebuilds a working engine more than once every few seconds.
      if (!force && now - this.lastRebuild < 4000) return Promise.resolve();
      this.lastRebuild = now;
      this.musicSeq++;
      this.fxEpoch++;
      this.cancelStinger(0);
      for (const s of this.streams.values()) {
        try {
          s.el.pause();
        } catch {}
      }
      this.streams.clear();
      this.loading.clear();
      try {
        this.ctx?.close();
      } catch {}
      this.ctx = null;
      this.music = null;
      this.track = null;
      return this.unlock();
    }
    // Wake the audio up after the app was in the background: iOS suspends, interrupts or even closes the context.
    // `gesture` is true when this runs from a real tap, the only moment a fresh context may start playing.
    async revive(gesture = false) {
      if (!this.ctx) return;
      this.playbackSession();
      if (this.keepAlive?.paused) this.keepAlive.play().catch(() => {});
      if (gesture) this.prime();
      if (this.ctx.state === 'running') return;
      if (this.ctx.state === 'closed' || gesture) {
        // Rebuilt synchronously inside the tap so the new context is allowed to start.
        await this.rebuild();
        return this.afterRevive();
      }
      try {
        await Promise.race([this.ctx.resume(), new Promise((r) => setTimeout(r, 700))]);
      } catch {}
      // Still asleep without a tap: leave it for the next touch, which rebuilds it.
      if (this.ctx.state !== 'running') return;
      this.afterRevive();
    }
    afterRevive() {
      if (!this.ctx || this.ctx.state !== 'running') return;
      // Clear any master mute left over from an earlier pause when the game is running again.
      if (!this.paused) this.master.gain.setTargetAtTime(1, this.ctx.currentTime, 0.02);
      if (this.wantTrack && !this.paused && !this.music && !this.holdTrack) {
        this.track = null;
        this.playMusic(this.wantTrack);
      }
    }
    pause(immediate = false) {
      this.paused = true;
      this.fxEpoch++;
      if (immediate) this.keepAlive?.pause();
      if (this.ctx) {
        // The results screen opens while the defeat stinger is still ringing: let it finish, then go quiet.
        const ring =
          !immediate && this.holdTrack === 'defeat' ? this.holdUntil - performance.now() : 0;
        clearTimeout(this.muteTimer);
        const quiet = () => {
          if (!this.paused || !this.ctx) return;
          this.master.gain.setTargetAtTime(0, this.ctx.currentTime, 0.05);
          // Stop streaming while paused.
          try {
            this.music?.el.pause();
          } catch {}
        };
        if (ring > 0) this.muteTimer = setTimeout(quiet, ring);
        else {
          this.master.gain.setTargetAtTime(0, this.ctx.currentTime, 0.035);
          this.muteTimer = setTimeout(quiet, 120);
        }
      }
    }
    resume() {
      this.paused = false;
      clearTimeout(this.muteTimer);
      if (this.holdTrack) this.cancelStinger(0.15);
      if (this.ctx) {
        this.master.gain.setTargetAtTime(1, this.ctx.currentTime, 0.025);
        if (this.music) this.music.el.play().catch(() => {});
      }
      this.revive(true);
      this.unlock();
    }
  }
  window.ZSAudio = AudioSystem;
})();
