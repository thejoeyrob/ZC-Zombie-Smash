/* Zombie Smash sound engine (7.62).
   Everything is pre-rendered: the effects and the music are WAV files that are decoded once and played through Web Audio.
   Nothing is synthesised while you play, so the processor cost is a handful of buffer players, and a sound starts on the
   very next audio block (the call and the haptic buzz happen in the same event, so they land together).
   Reliability: one context that is resumed on every touch, key press, focus and state change; a watchdog that restarts
   missing music; the music is re-requested whenever the engine wakes up; and a plain <audio> fallback if Web Audio
   cannot run on the device. */
(() => {
  const SFX_FILES = ['click', 'chime', 'back', 'toggle', 'key', 'error', 'page', 'pistol', 'smg', 'shotgun', 'dmr', 'burst', 'hose', 'rainbow', 'bass', 'beans',
    'laser', 'remover', 'purge', 'hit', 'kill', 'ricochet', 'bosshit', 'throw', 'explosion', 'hurt', 'breach', 'pickup', 'heart', 'goldheart', 'boost1',
    'boost2', 'boost3', 'power', 'switch', 'target', 'clear', 'alarm', 'warn', 'doom', 'mutation'];
  // Per effect: gap = minimum ms between two plays, cap = most that may sound at once, rate = random pitch spread, pri = important
  // (always heard, may take a voice from a minor sound), duck = [music level, seconds] for a brief dip under big sounds.
  const CFG = {
    pistol: { gap: 45, cap: 3, rate: 0.03 }, smg: { gap: 32, cap: 3, rate: 0.04 }, shotgun: { gap: 60, cap: 2 }, dmr: { gap: 60, cap: 2 },
    burst: { gap: 70, cap: 2 }, hose: { gap: 40, cap: 3, rate: 0.05 }, rainbow: { gap: 60, cap: 2 }, bass: { gap: 90, cap: 2 },
    beans: { gap: 25, cap: 4, rate: 0.07 }, laser: { gap: 60, cap: 2 }, remover: { gap: 60, cap: 2 }, purge: { gap: 60, cap: 2 },
    hit: { gap: 55, cap: 2, rate: 0.08 }, kill: { gap: 50, cap: 3, rate: 0.07 }, ricochet: { gap: 90, cap: 2 }, bosshit: { gap: 90, cap: 2, rate: 0.04 },
    throw: { pri: 1 }, explosion: { pri: 1, cap: 2, duck: [0.5, 0.8] }, hurt: { pri: 1, duck: [0.6, 0.45] }, breach: { pri: 1 },
    pickup: { pri: 1 }, heart: { pri: 1 }, goldheart: { pri: 1 }, boost1: { pri: 1 }, boost2: { pri: 1 }, boost3: { pri: 1 }, power: { pri: 1 },
    switch: { pri: 1 }, target: { pri: 1 }, clear: { pri: 1 }, alarm: { pri: 1, cap: 1 }, warn: { pri: 1, cap: 1, gap: 120 },
    doom: { pri: 1, cap: 1, duck: [0.45, 1.0] }, mutation: { pri: 1, cap: 1, duck: [0.5, 1.0] }, page: { cap: 2 },
  };
  const MUSIC = ['home', 'story', 'wave1', 'wave2', 'wave3', 'warning', 'boss', 'finale', 'disco', 'over'];
  const GAME_TRACKS = new Set(['wave1', 'wave2', 'wave3', 'warning', 'boss', 'finale', 'disco']);
  const STINGS = { victory: 6.0, defeat: 6.6, highscore: 7.0, wavestart: 1.9 };
  const MAX_VOICES = 16, MINOR_LIMIT = 11, CACHE_TRACKS = 6;

  class AudioSystem {
    constructor() {
      this.ctx = null;
      this.mode = 'web'; // 'web' (Web Audio) or 'html' (plain audio elements, only if Web Audio will not run)
      this.buffers = new Map(); // decoded sound files
      this.loading = new Map();
      this.problems = []; // what went wrong loading or starting sound, shown on the BOT_ tester CHEATS page
      this.paused = false;
      this.wave = 1;
      this.bossTrack = 'boss';
      this.wantTrack = null; // what the game last asked to hear
      this.gated = false; // true during the power-on sequence: music is wanted but waits for the sequence to finish
      this.track = null; // what is actually playing
      this.cur = null; // { id, source, gain }
      this.hold = 0; // performance.now() until which a one-shot sting owns the music slot
      this.holdTimer = 0;
      this.lastPlay = {};
      this.live = {};
      this.voices = new Set();
      this.epoch = 0;
      this.musicSeq = 0;
      this.wakes = 0;
      this.keepAlive = null;
      this.recent = []; // last few things the engine did, for the CHEATS page
      const defaults = { music: 0.55, effects: 0.8 };
      try {
        this.settings = { ...defaults, ...(JSON.parse(localStorage.getItem('zs7-audio')) || {}) };
      } catch {
        this.settings = defaults;
      }
      for (const key of ['music', 'effects']) {
        const v = Number(this.settings[key]);
        this.settings[key] = Number.isFinite(v) ? Math.max(0, Math.min(1, v)) : defaults[key];
      }
      this.playbackSession();
    }

    // ---- session / context ----------------------------------------------------------------------
    // iPhone: Web Audio is silenced by the ring/silent switch unless the page asks for "playback" audio (the native app also
    // sets this, see the TestFlight workflow).
    playbackSession() {
      try { if (navigator.audioSession) navigator.audioSession.type = 'playback'; } catch {}
    }
    // Older iPhones have no Audio Session API. A silent looping <audio> clip switches Safari to playback audio.
    startKeepAlive() {
      if (this.keepAlive || navigator.audioSession) return;
      try {
        const n = 800, buf = new ArrayBuffer(44 + n), v = new DataView(buf), str = (o, s) => [...s].forEach((c, i) => v.setUint8(o + i, c.charCodeAt(0)));
        str(0, 'RIFF'); v.setUint32(4, 36 + n, true); str(8, 'WAVEfmt '); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
        v.setUint32(24, 8000, true); v.setUint32(28, 8000, true); v.setUint16(32, 1, true); v.setUint16(34, 8, true); str(36, 'data'); v.setUint32(40, n, true);
        for (let i = 0; i < n; i++) v.setUint8(44 + i, 128);
        const el = new Audio(URL.createObjectURL(new Blob([buf], { type: 'audio/wav' })));
        el.loop = true;
        el.setAttribute('playsinline', '');
        this.keepAlive = el;
        el.play().catch(() => { this.keepAlive = null; });
      } catch {}
    }
    build() {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) throw Error('no Web Audio');
      let ctx;
      try { ctx = new Ctx({ latencyHint: 'interactive' }); } catch { ctx = new Ctx(); }
      this.ctx = ctx;
      // game bus (effects + music) -> limiter -> speakers; menu sounds join after the game bus so a paused game never mutes them
      const limiter = ctx.createDynamicsCompressor();
      limiter.threshold.value = -8; limiter.knee.value = 8; limiter.ratio.value = 10; limiter.attack.value = 0.002; limiter.release.value = 0.12;
      limiter.connect(ctx.destination);
      this.out = limiter;
      this.gameBus = ctx.createGain(); this.gameBus.connect(limiter);
      this.uiBus = ctx.createGain(); this.uiBus.gain.value = this.settings.effects; this.uiBus.connect(limiter);
      this.fx = ctx.createGain(); this.fx.gain.value = this.settings.effects; this.fx.connect(this.gameBus);
      // music chain: track -> duck (under big effects) -> pause (quieter when paused) -> muffle -> user volume -> game bus
      this.musicVol = ctx.createGain(); this.musicVol.gain.value = this.settings.music; this.musicVol.connect(this.gameBus);
      this.muffle = ctx.createBiquadFilter(); this.muffle.type = 'lowpass'; this.muffle.frequency.value = 20000; this.muffle.Q.value = 0.4; this.muffle.connect(this.musicVol);
      this.pauseGain = ctx.createGain(); this.pauseGain.connect(this.muffle);
      this.duckGain = ctx.createGain(); this.duckGain.connect(this.pauseGain);
      ctx.onstatechange = () => {
        this.note('state ' + ctx.state);
        if (ctx !== this.ctx) return;
        if (ctx.state === 'running') this.afterWake();
        else if (!document.hidden) setTimeout(() => this.revive(), 300);
      };
    }
    note(s) { this.recent.push(((performance.now() / 1000) | 0) + 's ' + s); if (this.recent.length > 12) this.recent.shift(); }
    // Called at start-up and from every touch/key: makes sure a context exists and is running.
    async unlock() {
      try {
        this.playbackSession();
        this.startKeepAlive();
        if (!this.ctx) {
          try { this.build(); } catch (e) { this.useHtml('Web Audio unavailable: ' + (e?.message || e)); return; }
          this.preloadEffects();
        }
        if (this.ctx.state !== 'running') await Promise.race([this.ctx.resume().catch(() => {}), new Promise((r) => setTimeout(r, 600))]);
        if (this.ctx.state === 'running') this.afterWake();
        else if (++this.wakes > 6 && this.mode === 'web') this.useHtml('audio context would not start');
      } catch (e) { this.problems.push('unlock: ' + (e?.message || e)); }
    }
    // The engine is awake: start whatever music was asked for while it slept.
    afterWake() {
      if (!this.ctx || this.ctx.state !== 'running') return;
      this.wakes = 0;
      if (this.wantTrack && !this.cur && !this.holding()) this.playMusic(this.wantTrack);
    }
    // Wake the engine after the app was in the background, a call or an alert (iOS suspends or interrupts the context).
    // `gesture` is true inside a real tap, the only moment a closed context may be replaced.
    async revive(gesture = false) {
      this.playbackSession();
      if (this.keepAlive?.paused) this.keepAlive.play().catch(() => {});
      if (!this.ctx) return gesture ? this.unlock() : undefined;
      if (this.ctx.state === 'closed') return this.rebuild();
      if (this.ctx.state !== 'running') {
        try { await Promise.race([this.ctx.resume(), new Promise((r) => setTimeout(r, 700))]); } catch {}
        if (this.ctx.state !== 'running' && gesture && this.mode === 'web' && ++this.wakes > 4) return this.rebuild();
      }
      if (this.ctx.state === 'running') this.afterWake();
    }
    // Throw the context away and start a fresh one (decoded files are decoded again for it).
    async rebuild() {
      this.epoch++;
      this.voices.forEach((v) => v.done());
      try { this.cur?.source.stop(); } catch {}
      this.cur = null; this.track = null;
      this.buffers.clear(); this.loading.clear();
      try { this.ctx?.close(); } catch {}
      this.ctx = null; this.wakes = 0;
      return this.unlock();
    }
    reset() { this.paused = false; this.mode = 'web'; return this.rebuild(); }

    // ---- plain <audio> fallback -----------------------------------------------------------------
    useHtml(why) {
      this.mode = 'html';
      this.problems.push('fallback to plain audio: ' + why);
      this.htmlTrack(this.wantTrack);
    }
    htmlTrack(id) {
      if (this.mode !== 'html') return;
      const t = this.resolve(id);
      if (!t || (this.htmlEl && this.htmlId === t)) return;
      try {
        this.htmlEl?.pause();
        const el = new Audio('./mus-' + t + '.wav');
        el.loop = !STINGS[t];
        el.volume = this.settings.music;
        this.htmlEl = el; this.htmlId = t; this.track = t;
        el.play().catch(() => {});
      } catch {}
    }

    // ---- loading --------------------------------------------------------------------------------
    file(name) { return (STINGS[name] || MUSIC.includes(name) || name === 'boot' ? 'mus-' : 'snd-') + name + '.wav'; }
    async buffer(name) {
      const file = this.file(name);
      if (this.buffers.has(file)) { const b = this.buffers.get(file); this.buffers.delete(file); this.buffers.set(file, b); return b; }
      if (this.loading.has(file)) return this.loading.get(file);
      const ctx = this.ctx, epoch = this.epoch;
      if (!ctx) return null;
      const task = fetch('./' + file)
        .then((r) => { if (!r.ok) throw Error('HTTP ' + r.status); return r.arrayBuffer(); })
        .then((b) => new Promise((ok, no) => { const p = ctx.decodeAudioData(b, ok, no); p?.then?.(ok, no); }))
        .then((b) => { if (epoch === this.epoch) { this.buffers.set(file, b); this.trim(); } return b; })
        .catch((e) => { this.problems.push(file + ': ' + (e?.message || e?.name || 'could not load or decode')); return null; })
        .finally(() => { if (this.loading.get(file) === task) this.loading.delete(file); });
      this.loading.set(file, task);
      return task;
    }
    // Keep memory sane: all effects stay; only the most recently used music files stay decoded.
    trim() {
      const keep = this.cur ? this.file(this.cur.id) : null;
      const music = [...this.buffers.keys()].filter((f) => f.startsWith('mus-') && f !== keep);
      let extra = music.length - (CACHE_TRACKS - (keep ? 1 : 0));
      for (const f of music) { if (extra-- <= 0) break; this.buffers.delete(f); }
    }
    async preloadEffects() {
      await this.buffer('boot');
      for (const n of SFX_FILES) {
        if (!this.ctx) return;
        await this.buffer(n);
      }
    }
    // Load likely-next music in the background, one at a time, without disturbing play.
    prefetch(names) {
      if (!this.ctx) return;
      let i = 0;
      const next = () => {
        if (i >= names.length || !this.ctx) return;
        const n = names[i++];
        const run = () => this.buffer(n).then(() => setTimeout(next, 400));
        (window.requestIdleCallback || ((f) => setTimeout(f, 300)))(run, { timeout: 2000 });
      };
      next();
    }

    // ---- music ----------------------------------------------------------------------------------
    waveTrack() { return this.wave <= 3 ? 'wave1' : this.wave <= 8 ? 'wave2' : 'wave3'; }
    setWave(n) { this.wave = Math.max(1, n | 0); }
    resolve(id) {
      if (id === 'main') return this.waveTrack();
      if (id === 'menu') return 'home';
      if (id === 'entrance') return 'warning';
      if (id === 'boss') return this.bossTrack;
      return id;
    }
    // Which battle theme belongs to which boss.
    setBoss(id) { this.bossTrack = id === 'discoman' ? 'disco' : id === 'drmantis' ? 'finale' : 'boss'; }
    holding() { return this.hold > performance.now(); }
    // Ask for a track. It starts as soon as it is decoded, cross-fading from whatever is playing.
    async playMusic(id, opt = {}) {
      this.wantTrack = id;
      const track = this.resolve(id);
      if (this.gated) return;
      if (this.mode === 'html') return this.htmlTrack(id);
      if (!this.ctx || this.ctx.state !== 'running' || this.holding()) return;
      if (this.cur?.id === track) return;
      const epoch = this.epoch, mine = ++this.musicSeq;
      const buf = await this.buffer(track);
      if (!buf || mine !== this.musicSeq || epoch !== this.epoch || this.resolve(this.wantTrack) !== track || this.holding()) {
        if (!buf && this.resolve(this.wantTrack) === track) this.problems.push('no music buffer for ' + track);
        return;
      }
      if (this.cur?.id === track) return;
      this.startTrack(track, buf, opt.fade ?? (this.cur ? 0.9 : 0.6));
    }
    startTrack(track, buf, fade) {
      const ctx = this.ctx, now = ctx.currentTime;
      this.stopMusic(Math.min(fade, 0.9), true);
      const source = ctx.createBufferSource(), gain = ctx.createGain();
      source.buffer = buf; source.loop = true;
      source.connect(gain); gain.connect(this.duckGain);
      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(1, now + Math.max(0.05, fade));
      try { source.start(now); } catch (e) { this.problems.push('start ' + track + ': ' + (e?.message || e)); return; }
      this.cur = { id: track, source, gain };
      this.track = track;
      this.applyPause();
      this.note('music ' + track);
      // keep the next likely tracks decoded so a change never waits
      if (GAME_TRACKS.has(track)) this.prefetch([this.waveTrack(), 'warning', this.bossTrack, 'home']);
    }
    // Fade the playing music out (a short fade at every ending, so nothing stops abruptly).
    stopMusic(fade = 0.4, replacing = false) {
      if (!replacing) { this.musicSeq = (this.musicSeq || 0) + 1; this.wantTrack = null; }
      if (this.htmlEl && !replacing) { this.htmlEl.pause(); this.htmlEl = null; this.htmlId = null; }
      const old = this.cur;
      if (!old || !this.ctx) return;
      this.cur = null; this.track = null;
      const now = this.ctx.currentTime;
      try {
        old.gain.gain.cancelScheduledValues(now);
        old.gain.gain.setValueAtTime(old.gain.gain.value, now);
        old.gain.gain.linearRampToValueAtTime(0, now + Math.max(0.03, fade));
        old.source.stop(now + Math.max(0.03, fade) + 0.05);
        old.source.onended = () => { try { old.source.disconnect(); old.gain.disconnect(); } catch {} };
      } catch {}
    }
    // A short fanfare that owns the music until it has finished (victory, defeat, high score).
    async stinger(name) {
      const dur = STINGS[name];
      if (!dur || this.mode === 'html') return;
      if (!this.ctx || this.ctx.state !== 'running') return;
      const buf = await this.buffer(name);
      if (!buf || !this.ctx) return;
      this.stopMusic(0.25, true);
      const ctx = this.ctx, source = ctx.createBufferSource(), gain = ctx.createGain();
      source.buffer = buf; source.connect(gain); gain.connect(this.pauseGain);
      gain.gain.value = 1;
      try { source.start(ctx.currentTime + 0.05); } catch { return; }
      const len = buf.duration * 1000;
      this.hold = performance.now() + len;
      this.holdSource = source;
      clearTimeout(this.holdTimer);
      this.holdTimer = setTimeout(() => this.endHold(), len + 60);
      source.onended = () => { try { source.disconnect(); gain.disconnect(); } catch {} };
      this.note('sting ' + name);
    }
    endHold() {
      this.hold = 0; this.holdSource = null;
      if (this.wantTrack) this.playMusic(this.wantTrack, { fade: 1.1 });
    }
    // A short flourish played over the music (new wave). The music dips under it and carries on.
    async sting(name) {
      if (!this.ctx || this.ctx.state !== 'running' || this.settings.effects === 0 || this.holding()) return;
      const buf = await this.buffer(name);
      if (!buf || !this.ctx) return;
      this.duck(0.55, buf.duration * 0.7);
      const ctx = this.ctx, source = ctx.createBufferSource(), gain = ctx.createGain();
      source.buffer = buf; source.connect(gain); gain.connect(this.fx);
      gain.gain.value = 0.9;
      try { source.start(); } catch { return; }
      source.onended = () => { try { source.disconnect(); gain.disconnect(); } catch {} };
    }
    // Brief dip in the music under a big effect.
    duck(level = 0.6, seconds = 0.5) {
      if (!this.ctx || !this.duckGain) return;
      const p = this.duckGain.gain, now = this.ctx.currentTime;
      p.cancelScheduledValues(now);
      p.setValueAtTime(p.value, now);
      p.linearRampToValueAtTime(level, now + 0.03);
      p.linearRampToValueAtTime(1, now + seconds);
    }
    // The boot sequence: starts in step with the power-on animation (offset = seconds of animation already played).
    async boot(offset = 0) {
      if (!this.ctx || this.ctx.state !== 'running') return false;
      const buf = await this.buffer('boot');
      if (!buf || !this.ctx) return false;
      const ctx = this.ctx, source = ctx.createBufferSource(), gain = ctx.createGain();
      source.buffer = buf; source.connect(gain); gain.connect(this.uiBus);
      gain.gain.value = 0.9;
      const off = typeof offset === 'function' ? offset() : offset;   // read after decoding, so a late start still lands in step
      const at = Math.max(0, Math.min(Number(off) || 0, buf.duration - 0.2));
      try { source.start(ctx.currentTime + 0.02, at); } catch { return false; }
      this.bootNode = { source, gain };
      source.onended = () => { try { source.disconnect(); gain.disconnect(); } catch {} if (this.bootNode?.source === source) this.bootNode = null; };
      this.note('boot +' + at.toFixed(2));
      return true;
    }
    // Skipping the power-on sequence: let the sound go quiet quickly instead of cutting off.
    stopBoot(fade = 0.35) {
      const n = this.bootNode;
      if (!n || !this.ctx) return;
      this.bootNode = null;
      const now = this.ctx.currentTime;
      try { n.gain.gain.cancelScheduledValues(now); n.gain.gain.setValueAtTime(n.gain.gain.value, now); n.gain.gain.linearRampToValueAtTime(0, now + fade); n.source.stop(now + fade + 0.05); } catch {}
    }
    // When the game is paused behind a menu, battle music drops back and goes muffled; menu music is left alone.
    applyPause() {
      if (!this.ctx) return;
      const game = this.cur && GAME_TRACKS.has(this.cur.id), on = this.paused && game, now = this.ctx.currentTime;
      this.pauseGain.gain.setTargetAtTime(on ? 0.35 : 1, now, 0.08);
      this.muffle.frequency.setTargetAtTime(on ? 700 : 20000, now, 0.08);
    }
    pause() {
      this.paused = true;
      for (const v of [...this.voices]) if (!v.ui) v.fadeOut();
      this.applyPause();
    }
    resume() {
      this.paused = false;
      this.applyPause();
      this.revive(true);
    }

    // ---- effects --------------------------------------------------------------------------------
    // In-game effect. Dropped silently if the engine is asleep (a late shot sound is worse than none).
    sfx(name, volume = 1, rate = 1) {
      if (this.mode === 'html') return;
      if (!this.ctx || this.ctx.state !== 'running') { this.revive(); return; }
      if (this.paused || this.settings.effects === 0) return;
      this.play(name, volume, rate, false);
    }
    // Menu / button sound: works whether or not the game is paused; the first tap wakes the engine, then plays.
    async ui(name, volume = 1) {
      if (this.settings.effects === 0 || this.mode === 'html') return;
      if (!this.ctx) await this.unlock();
      else if (this.ctx.state !== 'running') await this.revive(true);
      if (!this.ctx || this.ctx.state !== 'running') return;
      this.play(name, volume, 1, true);
    }
    play(name, volume, rate, ui) {
      const cfg = CFG[name] || {}, buf = this.buffers.get(this.file(name));
      if (!buf) { this.buffer(name); return; }
      const t = performance.now();
      if (t - (this.lastPlay[name] ?? -1e9) < (cfg.gap ?? 25)) return;
      const live = this.live[name] || 0;
      if (live >= (cfg.cap ?? 3)) return;
      if (this.voices.size >= (cfg.pri || ui ? MAX_VOICES : MINOR_LIMIT)) {
        if (!cfg.pri && !ui) return;
        const victim = [...this.voices].find((v) => !v.pri && !v.ui);
        if (victim) victim.done(); else return;
      }
      this.lastPlay[name] = t;
      const ctx = this.ctx, source = ctx.createBufferSource(), gain = ctx.createGain();
      source.buffer = buf;
      const spread = cfg.rate ? 1 + (Math.random() * 2 - 1) * cfg.rate : 1;
      source.playbackRate.value = rate * spread;
      gain.gain.value = volume;
      source.connect(gain); gain.connect(ui ? this.uiBus : this.fx);
      if (cfg.duck) this.duck(cfg.duck[0], cfg.duck[1]);
      let ended = false;
      const voice = {
        pri: !!cfg.pri, ui,
        done: () => {
          if (ended) return; ended = true;
          this.voices.delete(voice); this.live[name] = Math.max(0, (this.live[name] || 1) - 1);
          source.onended = null;
          try { source.stop(); } catch {}
          try { source.disconnect(); gain.disconnect(); } catch {}
        },
        fadeOut: () => {
          try { gain.gain.setTargetAtTime(0, ctx.currentTime, 0.015); } catch {}
          setTimeout(voice.done, 90);
        },
      };
      this.voices.add(voice); this.live[name] = live + 1;
      source.onended = voice.done;
      try { source.start(); } catch { voice.done(); }
    }

    // ---- settings -------------------------------------------------------------------------------
    save() { try { localStorage.setItem('zs7-audio', JSON.stringify(this.settings)); } catch {} }
    set(kind, value) {
      if (!['music', 'effects'].includes(kind) || !Number.isFinite(Number(value))) return;
      this.settings[kind] = Math.max(0, Math.min(1, Number(value)));
      this.save();
      if (this.htmlEl && kind === 'music') this.htmlEl.volume = this.settings.music;
      if (!this.ctx) return;
      const now = this.ctx.currentTime;
      if (kind === 'effects') { this.fx.gain.setTargetAtTime(this.settings.effects, now, 0.03); this.uiBus.gain.setTargetAtTime(this.settings.effects, now, 0.03); }
      else this.musicVol.gain.setTargetAtTime(this.settings.music, now, 0.05);
    }

    // ---- watchdog and status --------------------------------------------------------------------
    // Called every couple of seconds by the game: wakes a sleeping engine and restarts music that should be playing.
    watchdog() {
      if (document.hidden) return;
      if (this.mode === 'html') { if (this.htmlEl?.paused && this.wantTrack) this.htmlEl.play().catch(() => {}); return; }
      if (!this.ctx) return;
      if (this.ctx.state !== 'running') { this.revive(); return; }
      if (this.wantTrack && !this.cur && !this.holding() && this.settings.music > 0) this.playMusic(this.wantTrack);
    }
    status() {
      const c = this.ctx;
      return [
        'mode ' + this.mode, 'engine ' + (c ? c.state + ' ' + c.sampleRate + 'Hz' : 'not started'), 'playing ' + (this.track || 'nothing'),
        'wanted ' + (this.wantTrack || 'nothing'), 'decoded ' + this.buffers.size + ' files', 'voices ' + this.voices.size,
        'volume music ' + Math.round(this.settings.music * 100) + ' effects ' + Math.round(this.settings.effects * 100),
        this.problems.length ? 'PROBLEMS: ' + this.problems.slice(-4).join(' | ') : 'no problems',
        'recent: ' + this.recent.slice(-5).join(', '),
      ];
    }
  }
  window.ZSAudio = AudioSystem;
})();
