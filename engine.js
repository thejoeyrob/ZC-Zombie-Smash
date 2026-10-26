/* Zombie Smash 7.10. Fixed-step, fixed-world portrait simulation. */
(() => {
  'use strict';
  const { W, H, BOSSES } = window.ZSData;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const ENEMIES = {
    normal: { hp: 2, speed: 28, r: 13, points: 120, art: 'zombie-normal.webp', height: 42 },
    runner: { hp: 2, speed: 49, r: 12, points: 180, art: 'zombie-runner.webp', height: 42 },
    helmet: { hp: 4, speed: 25, r: 14, points: 240, art: 'zombie-helmet.webp', height: 46 },
    toxic: { hp: 4, speed: 24, r: 15, points: 320, art: 'zombie-toxic.webp', height: 48 },
    armored: { hp: 6, speed: 24, r: 17, points: 420, art: 'zombie-armored.webp', height: 52 },
    berserker: { hp: 5, speed: 36, r: 16, points: 500, art: 'zombie-berserker.webp', height: 50 },
    brute: { hp: 9, speed: 19, r: 21, points: 700, art: 'zombie-brute.webp', height: 65 },
    titan: { hp: 15, speed: 17, r: 24, points: 1050, art: 'zombie-titan.webp', height: 75 },
    fuse: { hp: 3, speed: 33, r: 14, points: 380, art: 'zombie-fuse.webp', height: 52 },
    bulwark: { hp: 9, speed: 20, r: 19, points: 650, art: 'zombie-bulwark.webp', height: 61 },
    mantismini: {
      hp: 1,
      speed: 36,
      r: 11,
      points: 150,
      art: 'boss-drmantis-stage3.webp',
      height: 44,
    },
  };
  // 7.6.2: zombies are 45% larger (hitbox +30%) and 20% slower so the extra size doesn't make them feel faster.
  for (const s of Object.values(ENEMIES)) {
    s.height = Math.round(s.height * 1.45);
    s.r = Math.round(s.r * 1.3);
    s.speed = +(s.speed * 0.8).toFixed(1);
  }
  const BARREL = Object.freeze({
    width: 40,
    height: 54,
    hitRadius: 17,
    throwWidth: 38,
    throwHeight: 50,
    throwHitRadius: 16,
    throwBlast: Math.round(W * 0.17),
    flight: 1.08,
    chainWind: 0.34,
    chainExtend: 0.22,
  });
  const GLOW = ['green', 'pink', 'blue', 'orange', 'yellow', 'violet'];
  // The reward for lighting all three floor targets: a temporary special weapon themed on the arena's boss.
  // `sound` is the existing gun sound it borrows; `hit` effects are applied in specialHit().
  const SPECIALS = [
    { id: 'hose', name: 'WATER PULSE', color: '#6fd0ff', sound: 'smg', time: 10, delay: 0.075, damage: 0.95, speed: 540, pierce: 3, life: 0.6, knock: 7, size: 6 },
    { id: 'rainbow', name: 'RAINBOW SPRAY', color: '#ff6ad5', sound: 'burst', time: 10, delay: 0.12, damage: 0.8, speed: 560, pierce: 1, life: 0.9, fan: [-0.26, -0.13, 0, 0.13, 0.26], size: 5 },
    { id: 'bass', name: 'BASS CANNON', color: '#ffb23d', sound: 'shotgun', time: 10, delay: 0.5, damage: 2.4, speed: 430, pierce: 1, life: 1.4, blast: 52, size: 9 },
    { id: 'beans', name: 'ESPRESSO BLASTER', color: '#c98a4b', sound: 'smg', time: 10, delay: 0.04, damage: 0.55, speed: 740, pierce: 1, life: 0.9, jitter: 0.09, size: 3 },
    { id: 'laser', name: 'LASER PULSE', color: '#ff2fd2', sound: 'dmr', time: 10, delay: 0.17, damage: 1.7, hitscan: true, width: 13 },
    { id: 'remover', name: 'MAKEUP REMOVER', color: '#ff9fcb', sound: 'smg', time: 10, delay: 0.13, damage: 1.0, speed: 500, pierce: 2, life: 0.8, slow: true, strip: true, size: 6 },
    { id: 'purge', name: 'PURGE ARC', color: '#9dff4a', sound: 'burst', time: 10, delay: 0.24, damage: 1.5, speed: 600, pierce: 1, life: 0.9, chain: 3, size: 5 },
  ];
  const GUNS = {
    pistol: {
      name: 'PISTOL',
      delay: 0.22,
      damage: 1.5,
      speed: 600,
      ammo: Infinity,
      art: 'bullet-pistol.webp',
    },
    smg: { name: 'SMG', delay: 0.09, damage: 1.15, speed: 660, ammo: 100, art: 'bullet-smg.webp' },
    shotgun: {
      name: 'SCATTER',
      delay: 0.54,
      damage: 1.7,
      speed: 550,
      ammo: 24,
      art: 'bullet-pistol.webp',
    },
    dmr: {
      name: 'DMR-82',
      delay: 0.42,
      damage: 9,
      speed: 800,
      ammo: 24,
      pierce: 3,
      art: 'bullet-dmr.webp',
    },
    burst: {
      name: 'PULSE',
      delay: 0.26,
      damage: 1.6,
      speed: 670,
      ammo: 60,
      art: 'bullet-smg.webp',
    },
  };
  function segmentDistance(px, py, x1, y1, x2, y2) {
    const dx = x2 - x1,
      dy = y2 - y1,
      q = clamp(((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy || 1), 0, 1);
    return Math.hypot(px - x1 - q * dx, py - y1 - q * dy);
  }
  // Joey's body is a capsule that covers the whole drawn character (head to boots), not just his centre.
  const JOEY = Object.freeze({ top: -40, bottom: 20, r: 15 });
  // How long a drop stays on the ground, counted only while play is running.
  const PICKUP_LIFE = 15;
  // Boss movement styles: where each boss roams, how fast, how it sways, and how often it lunges down the screen.
  const BOSS_MOVE = {
    jordan: {
      kind: 'wander',
      v: 92,
      x: [48, W - 48],
      y: [98, 142],
      dwell: [0.7, 1.3],
      sway: [0, 5, 0, 6],
      lunge: 0.2,
    },
    glowinghumanity: {
      kind: 'orbit',
      ax: 98,
      ay: 22,
      fx: 0.85,
      fy: 1.7,
      cy: 125,
      sway: [0, 3, 0, 4],
    },
    debo: {
      kind: 'wander',
      v: 46,
      x: [60, W - 60],
      y: [100, 135],
      dwell: [1.3, 2.2],
      sway: [0, 3.5, 0, 3.2],
      lunge: 0.5,
      follow: 0.45,
    },
    caffeinatedsloth: {
      kind: 'stopgo',
      crawl: 18,
      burst: 210,
      x: [50, W - 50],
      y: [98, 150],
      sway: [2.4, 1.2, 34, 28],
    },
    discoman: {
      kind: 'wander',
      v: 62,
      x: [56, W - 56],
      y: [100, 140],
      dwell: [0.8, 1.2],
      sway: [15, 9, 3.4, 6.8],
      lunge: 0.15,
    },
    fatamy: {
      kind: 'wander',
      v: 48,
      x: [66, W - 66],
      y: [104, 150],
      dwell: [1.4, 2.3],
      sway: [4, 5, 2.2, 4.4],
      lunge: 0.3,
    },
    drmantis: {
      kind: 'zigzag',
      v: 168,
      x: [50, W - 50],
      y: [98, 150],
      dwell: [0.55, 1.0],
      sway: [0, 4, 0, 7],
      lunge: 0.25,
    },
  };
  class Game {
    constructor({ onEvent = () => {}, seed = Date.now() } = {}) {
      this.onEvent = onEvent;
      this.seed = seed >>> 0;
      this.reset();
    }
    rand() {
      this.seed = (1664525 * this.seed + 1013904223) >>> 0;
      return this.seed / 4294967296;
    }
    emit(type, data = {}) {
      this.onEvent(type, data);
    }
    // Shortest distance from a point to Joey's body capsule.
    joeyDistance(x, y) {
      const p = this.player;
      return Math.hypot(x - p.x, y - clamp(y, p.y + JOEY.top, p.y + JOEY.bottom));
    }
    // True when a moving circle (path from x1,y1 to x2,y2, radius r) touches any part of Joey.
    joeyHit(x1, y1, x2, y2, r) {
      const steps = Math.max(1, Math.ceil(Math.hypot(x2 - x1, y2 - y1) / 5));
      for (let i = 0; i <= steps; i++)
        if (
          this.joeyDistance(x1 + ((x2 - x1) * i) / steps, y1 + ((y2 - y1) * i) / steps) <
          JOEY.r + r
        )
          return true;
      return false;
    }
    reset() {
      Object.assign(this, {
        t: 0,
        wave: 1,
        score: 0,
        kills: 0,
        breaches: 0,
        combo: 0,
        multiplier: 1,
        comboLeft: 0,
        spawned: 0,
        resolved: 0,
        target: 10,
        spawnIn: 0.6,
        enemies: [],
        openings: [],
        tileBag: [],
        tileBagMap: -1,
        bullets: [],
        shots: [],
        pickups: [],
        grenades: [],
        barrels: [],
        effects: [],
        beams: [],
        arcs: [],
        pops: [],
        boss: null,
        scene: null,
        arena: null,
        nextIn: 0,
        active: false,
        over: false,
        practice: false,
        maxLives: 5,
        invincible: false,
        infiniteAmmo: false,
        nextId: 1,
        bossesDown: [],
        banner: 'HOLD THE LINE',
        bannerLeft: 2.4,
        hitStop: 0,
        shake: 0,
        dangerSource: null,
        player: {
          x: W / 2,
          y: H - 52,
          lives: 5,
          gun: 'pistol',
          ammo: Infinity,
          grenades: 3,
          cool: 0,
          inv: 1.2,
          shield: 0,
          rapid: 0,
          fireFx: 0,
          inventory: { smg: 0, shotgun: 0, dmr: 0, burst: 0 },
        },
        input: { axis: 0, fire: false },
      });
    }
    start() {
      this.active = true;
      if (!this.barrels.length) this.spawnBarrels();
      this.emit('music', { track: 'main' });
      this.emit('wave', { wave: 1 });
    }
    setInput(axis, fire) {
      this.input.axis = clamp(Number(axis) || 0, -1, 1);
      this.input.fire = !!fire;
    }
    resetInput() {
      this.input = { axis: 0, fire: false };
    }
    prepareWave(n) {
      if (ZSData.mapIndex(this.wave) !== ZSData.mapIndex(n)) { this.arena = null; this.openings = []; this.tileBag = []; this.tileBagMap = -1; }
      this.wave = n;
      this.target = Math.min(34, 8 + n * 2);
      this.spawned = 0;
      this.resolved = 0;
      this.spawnIn = 0.55;
      this.nextIn = 0;
      this.boss = null;
      this.banner = n > 14 ? 'INFINITE SURVIVAL' : `WAVE ${n}`;
      this.bannerLeft = 1.8;
      this.player.inv = Math.max(this.player.inv, 1.1);
      this.spawnBarrels();
      this.emit('wave', { wave: n });
      this.emit('music', { track: 'main' });
    }

    spawnBarrels() {
      this.barrels = [];
      const count = 1 + Math.floor(this.rand() * Math.min(5, 2 + Math.floor(this.wave / 3)));
      for (let i = 0; i < count; i++) {
        let x, y;
        for (let tries = 0; tries < 40; tries++) {
          x = 38 + this.rand() * (W - 76);
          y = 105 + this.rand() * (H - 210);
          if (this.barrels.every((b) => Math.hypot(b.x - x, b.y - y) > 57)) break;
        }
        if (this.barrels.some((b) => Math.hypot(b.x - x, b.y - y) <= 57)) continue;
        this.barrels.push({ id: this.nextId++, x, y, hp: 2, dead: false });
      }
    }
    explodeBarrel(barrel) {
      if (!barrel || barrel.dead) return;
      barrel.dead = true;
      const r = barrel.small ? BARREL.throwBlast : W * 0.2;
      this.effects.push({
        kind: 'barrelBlast',
        x: barrel.x,
        y: barrel.y,
        r,
        life: 0.58,
        total: 0.58,
        color: '#ff9d35',
      });
      this.shake = Math.max(this.shake, 2.6);
      this.emit('explosion');
      for (const z of [...this.enemies, ...(this.boss ? [this.boss] : [])])
        if (!z.dead && Math.hypot(z.x - barrel.x, z.y - barrel.y) < r + z.r)
          this.damage(z, z.boss ? 9 : 12, 'barrel');
      if (barrel.thrown && this.boss && this.joeyDistance(barrel.x, barrel.y) < r + 8)
        this.hurt(BOSSES.find((d) => d.id === this.boss.bossId).playerLoss);
      for (const other of this.barrels)
        if (
          !other.dead &&
          other !== barrel &&
          Math.hypot(other.x - barrel.x, other.y - barrel.y) < r * 0.9
        )
          this.explodeBarrel(other);
    }
    // The introductory round remains readable; pressure builds after it and continues in survival.
    enemyPace() {
      return (
        (1 + Math.min(0.78, (this.wave - 1) * 0.045)) *
        Math.min(1, 0.9 + (this.wave - 1) * 0.04) *
        (1 + Math.min(0.5, Math.max(0, this.wave - 14) * 0.018))
      );
    }
    spawnInterval() {
      return Math.max(0.31, 0.82 - this.wave * 0.029);
    }
    enemyHealth(type) {
      return ['normal', 'runner', 'mantismini'].includes(type)
        ? 1
        : Math.min(1.32, 1 + Math.max(0, this.wave - 4) * 0.022);
    }
    chooseType() {
      const w = this.wave,
        r = this.rand();
      if (w < 3) return r < 0.76 ? 'normal' : 'runner';
      if (w < 5) return r < 0.45 ? 'normal' : r < 0.65 ? 'runner' : r < 0.85 ? 'helmet' : 'fuse';
      if (w < 8)
        return r < 0.25
          ? 'normal'
          : r < 0.4
            ? 'runner'
            : r < 0.57
              ? 'helmet'
              : r < 0.73
                ? 'toxic'
                : r < 0.88
                  ? 'fuse'
                  : 'bulwark';
      const pool = [
        'normal',
        'runner',
        'helmet',
        'toxic',
        'armored',
        'berserker',
        'brute',
        'fuse',
        'bulwark',
        ...(w > 10 ? ['titan'] : []),
      ];
      return pool[Math.floor(r * pool.length)];
    }
    spawn(type = this.chooseType(), x = null, y = -28, minion = false) {
      const spec = ENEMIES[type],
        z = {
          id: this.nextId++,
          type,
          ...spec,
          maxHp: spec.hp,
          x: x ?? 36 + this.rand() * (W - 72),
          y,
          age: 0,
          attack: 2 + this.rand() * 2,
          flash: 0,
          dead: false,
          minion,
          charge: 0,
          baseX: 0,
        };
      const spawnMap = ZSData.MAPS[ZSData.mapIndex(this.wave)];
      if (!minion && y < 0 && spawnMap.entryStyle === 'edge') {
        // The Harvest Chamber has no hatches: the horde walks in from the edges of the map.
        const entry = spawnMap.entries[this.spawned % spawnMap.entries.length],
          lane = (this.spawned * 0.61803398875 + this.rand() * 0.16) % 1;
        z.x = entry[0];
        z.y = entry[1];
        z.entryStyle = 'edge';
        z.route = {
          edge: true,
          fromX: z.x,
          fromY: z.y,
          toX: spawnMap.corridor[0] + lane * (spawnMap.corridor[1] - spawnMap.corridor[0]),
          toY: Math.max(z.y, spawnMap.fanY - 20) + this.rand() * 22,
        };
      } else if (!minion && y < 0) {
        const map = spawnMap;
        let entry;
        if (map.entryStyle === 'tile') {
          const mapId = ZSData.mapIndex(this.wave);
          if (this.tileBagMap !== mapId || !this.tileBag?.length) {
            this.tileBagMap = mapId;
            this.tileBag = map.entries.map((_, i) => i).filter(i => map.entries[i][0] >= map.corridor[0] && map.entries[i][0] <= map.corridor[1]);
            for (let i = this.tileBag.length - 1; i > 0; i--) {
              const j = Math.floor(this.rand() * (i + 1));
              [this.tileBag[i], this.tileBag[j]] = [this.tileBag[j], this.tileBag[i]];
            }
            // A shuffled bag gives variety without repeated use of one square.
            if (this.tileBag.length > 1 && this.tileBag.at(-1) === this.lastTileEntry)
              [this.tileBag[0], this.tileBag[this.tileBag.length - 1]] = [this.tileBag.at(-1), this.tileBag[0]];
          }
          this.lastTileEntry = this.tileBag.pop();
          entry = map.entries[this.lastTileEntry];
        } else entry = map.entries[this.spawned % map.entries.length];
        (this.openings ||= []).push({ x: entry[0], y: entry[1], age: 0 });
        const lane = (this.spawned * 0.61803398875 + this.rand() * 0.16) % 1;
        z.x = entry[0] + (map.entryStyle === 'tile' ? 0 : (this.rand() - 0.5) * 8);
        z.entryStyle = map.entryStyle || 'grate';
        z.y = entry[1];
        z.route = { fromX: z.x, fromY: z.y, toX: map.corridor[0] + lane * (map.corridor[1] - map.corridor[0]), toY: map.fanY + this.rand() * 22 };
        z.emerge = 0.45;
      }
      z.baseX = z.x;
      z.speed *= this.enemyPace();
      if(z.route) { z.paceFactor=(H-52-z.route.fromY)/(H-52+28); z.speed*=z.paceFactor; }
      z.hp = z.maxHp = spec.hp * this.enemyHealth(type);
      if (!minion && !z.route?.edge) {
        const m = Math.ceil(z.height * 0.41) + 2;
        z.x = clamp(z.x, m, W - m);
        z.baseX = z.x;
      }
      this.enemies.push(z);
      if (!minion) this.spawned++;
      return z;
    }
    step(dt) {
      if (this.openings?.length) this.openings = this.openings.filter((o) => (o.age += dt) < 2);
      if (!this.active || this.over) return;
      dt = Math.min(dt, 0.05);
      this.t += dt;
      this.shake = Math.max(0, this.shake - dt * 16);
      this.bannerLeft = Math.max(0, this.bannerLeft - dt);
      this.effects = this.effects.filter((f) => (f.life -= dt) > 0);
      this.beams = (this.beams || []).filter((b) => (b.life -= dt) > 0);
      this.arcs = (this.arcs || []).filter((a) => (a.life -= dt) > 0);
      this.pops = this.pops.filter((p) => (p.life -= dt) > 0);
      for (const f of this.effects) {
        f.x += (f.vx || 0) * dt;
        f.y += (f.vy || 0) * dt;
      }
      if (this.scene) {
        this.scene.time += dt;
        if (!this.scene.mediaControlled && this.scene.time >= this.scene.duration) this.advanceScene();
        return;
      }
      if (this.player.special && (this.player.special.left -= dt) <= 0) {
        this.player.special = null;
        this.banner = 'WEAPON SPENT';
        this.bannerLeft = 1;
      }
      const p = this.player;
      p.inv = Math.max(0, p.inv - dt);
      p.hit = Math.max(0, (p.hit || 0) - dt);
      p.cool = Math.max(0, p.cool - dt);
      p.shield = Math.max(0, p.shield - dt);
      p.rapid = Math.max(0, p.rapid - dt);
      p.fireFx = Math.max(0, p.fireFx - dt);
      p.speedUp = Math.max(0, (p.speedUp || 0) - dt);
      {
        const target = this.input.axis * 212 * (p.speedUp > 0 ? 1.55 : 1);
        p.vx = target;
        p.x = clamp(p.x + p.vx * dt, 28, W - 28);
      }
      p.y = H - 52;
      if (this.hitStop > 0) {
        this.hitStop -= dt;
        return;
      }
      if (this.nextIn > 0) {
        this.nextIn -= dt;
        if (this.nextIn <= 0) this.prepareWave(this.wave + 1);
        this.updatePickups(dt);
        return;
      }
      if (this.comboLeft > 0) {
        this.comboLeft -= dt;
        if (this.comboLeft <= 0) this.resetCombo();
      }
      if (this.input.fire) this.fire();
      if (!this.boss && this.spawned < this.target) {
        this.spawnIn -= dt;
        if (this.spawnIn <= 0 && this.enemies.length < 13) {
          const z = this.spawn();
          if (this.spawned % 5 === 0 && !z.route) {
            z.x = clamp(p.x, z.r + 6, W - z.r - 6);
            z.baseX = z.x;
          }
          this.spawnIn = this.spawnInterval() + (this.rand() - 0.5) * 0.14;
          if (
            this.wave >= 5 &&
            this.spawned % 7 === 0 &&
            this.spawned < this.target &&
            this.enemies.length < 12
          ) {
            const flank = Math.abs(W - 2 * z.x) < 65 ? (z.x < W / 2 ? W - 52 : 52) : W - z.x;
            this.spawn(this.wave >= 9 ? 'helmet' : 'normal', flank, -52);
            this.spawnIn += 0.22;
          }
        }
      }
      if (this.boss) this.updateBoss(dt);
      for (const z of this.enemies) {
        if (z.dead) continue;
        z.age += dt;
        z.flash = Math.max(0, z.flash - dt);
        z.attack -= dt;
        let speed = z.speed;
        if (z.type === 'runner' && z.age > 2) {
          const phase = (z.age - 2) % 3.2;
          if (phase < 0.45) {
            speed = 2;
            z.charge = 1;
          } else if (phase < 1) {
            speed *= 2.6;
            z.charge = 2;
          } else z.charge = 0;
        }
        const map = ZSData.MAPS[ZSData.mapIndex(this.wave)];
        speed *= this.arena?.slow > 0 ? 0.55 : 1;
        z.emerge = Math.max(0, (z.emerge || 0) - dt);
        if (z.emerge > 0 && (z.entryStyle === 'tile' || z.entryStyle === 'portal')) continue;
        if (z.slowT > 0) {
          z.slowT -= dt;
          speed *= 0.5;
        }
        if (z.route?.edge) {
          const dx = z.route.toX - z.x,
            dy = z.route.toY - z.y,
            d = Math.hypot(dx, dy),
            stride = speed * dt;
          if (d <= stride + 0.5) {
            z.x = z.route.toX;
            z.y = z.route.toY;
            z.baseX = z.x;
            z.route = null;
          } else {
            z.x += (dx / d) * stride;
            z.y += (dy / d) * stride;
          }
        } else if (z.route) {
          z.y += speed * dt;
          const t = clamp((z.y - z.route.fromY) / (z.route.toY - z.route.fromY), 0, 1);
          // Smooth diagonal fan-out: deterministic per run, never a column of enemies.
          const ease = t * t * (3 - 2 * t);
          z.x = z.route.fromX + (z.route.toX - z.route.fromX) * ease;
          if (t >= 1) { z.baseX = z.x; z.route = null; }
        } else {
          if (z.type === 'berserker') z.x = z.baseX + Math.sin(z.age * 2.7) * 28;
          if (['brute', 'titan', 'armored'].includes(z.type)) z.x += clamp(p.x - z.x, -1, 1) * 11 * dt;
          z.y += speed * dt;
          if (z.vx) { z.x += z.vx * dt; z.vx *= Math.max(0, 1 - dt * 0.7); if (Math.abs(z.vx) < 2) z.vx = 0; }
        }
        if (!z.minion && !z.route?.edge) {
          const m = Math.ceil(z.height * 0.41) + 2;
          z.x = clamp(z.x, Math.max(m, map.corridor[0] + Math.max(0,m-27)), Math.min(W - m, map.corridor[1] - Math.max(0,m-27)));
        }
        if (z.type === 'toxic' && z.attack <= 0 && z.y > 25 && z.y < p.y - 70) {
          this.aimedShot(z.x, z.y, 'venom', 108 + Math.min(24, this.wave * 1.5), 8);
          z.attack = Math.max(2.9, 4.1 - this.wave * 0.055);
        }
        if (z.type === 'fuse' && z.y > p.y - 16) {
          z.dead = true;
          this.resolve(z);
          this.explode(z.x, z.y, 60, 3, false);
          if (Math.hypot(z.x - p.x, z.y - p.y) < 72) this.hurt('The Fuse detonated too close.');
        }
        if (this.joeyDistance(z.x, z.y) < z.r + 12) {
          this.hurt('The horde reached Joey Rob.');
          z.y += 18;
        }
        if (z.y > H + 20) {
          z.dead = true;
          this.resolve(z);
          if (!z.minion) {
            this.breaches++;
            this.resetCombo();
            this.emit('breach');
            this.banner = 'BASE BREACH';
            this.bannerLeft = 0.9;
            if (this.breaches >= 10) this.end('The camp was overrun.');
          }
        }
      }
      for (const br of this.barrels)
        if (br.thrown && !br.dead) {
          br.age += dt;
          br.x += br.vx * dt;
          br.y += br.vy * dt;
          br.rot += dt * 5;
          if (br.age >= br.T) this.explodeBarrel(br);
        }
      this.updateArena(dt);
      this.updateBullets(dt);
      this.updateShots(dt);
      this.updatePickups(dt);
      this.updateGrenades(dt);
      this.enemies = this.enemies.filter((z) => !z.dead);
      this.barrels = this.barrels.filter((b) => !b.dead);
      if (
        !this.scene &&
        !this.boss &&
        this.spawned >= this.target &&
        this.resolved >= this.target &&
        !this.enemies.length &&
        !this.over
      ) {
        const def = BOSSES.find((b) => b.wave === this.wave && !this.bossesDown.includes(b.id));
        if (def) this.queueBoss(def.id);
        else {
          this.nextIn = 1.55;
          this.banner = 'WAVE CLEAR';
          this.bannerLeft = 1.55;
          this.emit('clear');
        }
      }
    }
    fire() {
      const p = this.player;
      if (!this.active || this.over || this.scene || p.cool > 0 || this.nextIn > 0) return false;
      if (p.special) return this.fireSpecial();
      if (p.ammo <= 0 && !this.infiniteAmmo) this.equip('pistol');
      const gun = GUNS[p.gun],
        angles =
          p.gun === 'shotgun'
            ? [-0.17, -0.085, 0, 0.085, 0.17]
            : p.gun === 'burst'
              ? [-0.055, 0, 0.055]
              : [0];
      for (const a of angles)
        this.bullets.push({
          id: this.nextId++,
          x: p.x,
          y: p.y - 27,
          prevX: p.x,
          prevY: p.y - 27,
          vx: Math.sin(a) * gun.speed,
          vy: -Math.cos(a) * gun.speed,
          damage: gun.damage,
          gun: p.gun,
          pierce: gun.pierce || 1,
          hit: [],
          life: 1.5,
        });
      p.cool = gun.delay * (p.rapid > 0 ? 0.65 : 1);
      if (Number.isFinite(p.ammo) && !this.infiniteAmmo) p.ammo--;
      p.fireFx = 0.065;
      this.emit('shot', { gun: p.gun });
      return true;
    }
    updateArena(dt) {
      const index = ZSData.mapIndex(this.wave);
      if (!this.arena || this.arena.index !== index) this.arena = { index, cool: 0, slow: 0, pulse: 0, targets: [{x:82,y:190,lit:false},{x:W/2,y:230,lit:false},{x:W-82,y:190,lit:false}] };
      const a = this.arena, cooling = a.cool > 0;
      a.cool = Math.max(0,a.cool-dt); a.slow = Math.max(0,a.slow-dt); a.pulse = Math.max(0,a.pulse-dt);
      if (cooling && !a.cool) a.targets.forEach(t => t.lit=false);
    }
    hitArenaTarget(target) {
      const a = this.arena;
      if (!a || a.cool || target.lit || this.scene || this.over) return;
      target.lit = true; this.emit('ricochet');
      if (!a.targets.every(t => t.lit)) return;
      a.cool=12; a.pulse=1.2;
      this.grantSpecial(a.index);
    }
    // All three targets lit: the arena hands Joey a temporary special weapon.
    grantSpecial(index) {
      const sp = SPECIALS[index] || SPECIALS[0];
      this.player.special = { id: sp.id, left: sp.time };
      this.player.cool = 0;
      this.banner = sp.name + '!';
      this.bannerLeft = 2.2;
      this.shake = 2;
      this.effects.push({ kind: 'ring', x: this.player.x, y: this.player.y - 20, r: 120, life: 0.6, total: 0.6, color: sp.color });
      this.burst(this.player.x, this.player.y - 20, sp.color, 26, 190);
      this.emit('boost');
      this.emit('special', { id: sp.id });
    }
    // One shot (or one sweep) of the special weapon.
    fireSpecial() {
      const p = this.player,
        sp = SPECIALS.find((s) => s.id === p.special.id);
      if (!sp) {
        p.special = null;
        return false;
      }
      p.cool = sp.delay * (p.rapid > 0 ? 0.65 : 1);
      p.fireFx = 0.065;
      if (sp.hitscan) {
        // A strobing laser column: everything in front of Joey takes the hit, shields included.
        const reach = sp.width / 2;
        for (const z of [...this.enemies, ...(this.boss ? [this.boss] : [])])
          if (!z.dead && z.y < p.y - 14 && Math.abs(z.x - p.x) < reach + (z.r || 14) * 0.8) this.damage(z, sp.damage, 'dmr');
        for (const target of this.arena?.targets || []) if (Math.abs(target.x - p.x) < reach + 12) this.hitArenaTarget(target);
        for (const item of this.pickups) if (item.life > 0 && Math.abs(item.x - p.x) < reach + 14) this.collect(item);
        for (const barrel of this.barrels) if (!barrel.dead && Math.abs(barrel.x - p.x) < reach + 12) { barrel.hp -= sp.damage; if (barrel.hp <= 0) this.explodeBarrel(barrel); }
        this.beams.push({ x: p.x, y: p.y - 30, life: 0.11, total: 0.11, width: sp.width, color: sp.color });
      } else {
        for (const a of sp.fan || [0]) {
          const j = a + (sp.jitter ? (this.rand() - 0.5) * 2 * sp.jitter : 0);
          this.bullets.push({
            id: this.nextId++,
            x: p.x,
            y: p.y - 27,
            prevX: p.x,
            prevY: p.y - 27,
            vx: Math.sin(j) * sp.speed,
            vy: -Math.cos(j) * sp.speed,
            damage: sp.damage,
            gun: 'special',
            sp: sp.id,
            pierce: sp.pierce,
            hit: [],
            life: sp.life,
          });
        }
      }
      this.emit('shot', { gun: sp.sound });
      return true;
    }
    // What a special bullet does to what it hits, besides damage.
    specialHit(b, z) {
      const sp = SPECIALS.find((s) => s.id === b.sp);
      if (!sp) return;
      if (sp.knock && !z.boss) z.y = Math.max(-10, z.y - sp.knock);
      if (sp.slow && !z.boss) z.slowT = 2.2;
      if (sp.blast) this.explode(b.x, b.y, sp.blast, sp.damage * 0.7, false);
      if (sp.chain) {
        let from = z;
        const used = new Set([z.id]);
        for (let hop = 0; hop < sp.chain; hop++) {
          let best = null,
            bd = 95;
          for (const o of this.enemies)
            if (!o.dead && !used.has(o.id)) {
              const d = Math.hypot(o.x - from.x, o.y - from.y);
              if (d < bd) {
                bd = d;
                best = o;
              }
            }
          if (!best) break;
          used.add(best.id);
          this.arcs.push({ x1: from.x, y1: from.y - 10, x2: best.x, y2: best.y - 10, life: 0.16, total: 0.16 });
          this.damage(best, sp.damage * 0.7, 'chain');
          from = best;
        }
      }
    }
    updateBullets(dt) {
      for (const b of this.bullets) {
        b.prevX = b.x;
        b.prevY = b.y;
        b.x += b.vx * dt;
        b.y += b.vy * dt;
        b.life -= dt;
        const dx = b.x - b.prevX,
          dy = b.y - b.prevY,
          length = dx * dx + dy * dy || 1;
        for (const target of this.arena?.targets || [])
          if (segmentDistance(target.x,target.y,b.prevX,b.prevY,b.x,b.y)<16) this.hitArenaTarget(target);
        const hits = [...this.enemies, ...(this.boss ? [this.boss] : []), ...this.barrels]
          .filter(
            (z) =>
              !z.dead &&
              !b.hit.includes(z.id) &&
              segmentDistance(z.x, z.y, b.prevX, b.prevY, b.x, b.y) <
                (z.r ?? (z.thrown ? BARREL.throwHitRadius : BARREL.hitRadius)) + 3,
          )
          .sort((a, z) => ((a.x - z.x) * dx + (a.y - z.y) * dy) / length);
        for (const item of this.pickups)
          if (item.life > 0 && segmentDistance(item.x, item.y, b.prevX, b.prevY, b.x, b.y) < 16 + 2)
            this.collect(item);
        for (const z of hits) {
          if (b.pierce <= 0 || z.dead || this.scene) break;
          b.hit.push(z.id);
          b.pierce--;
          if (z.r !== undefined) {
            this.damage(z, b.damage, b.sp === 'remover' ? 'dmr' : b.gun);
            if (b.sp) this.specialHit(b, z);
          }
          else {
            z.hp -= b.damage;
            if (z.hp <= 0) this.explodeBarrel(z);
            else this.emit('ricochet');
          }
        }
      }
      this.bullets = this.bullets.filter(
        (b) => b.pierce > 0 && b.life > 0 && b.y > -35 && b.x > -20 && b.x < W + 20,
      );
    }
    damage(z, amount, source = 'pistol') {
      if (z.dead || this.scene || (z.boss && z.phaseGrace > 0)) return;
      const shield =
        z.type === 'bulwark' &&
        z.age % 3.5 < 2 &&
        source !== 'grenade' &&
        source !== 'chain' &&
        source !== 'dmr';
      if (shield) {
        amount *= 0.28;
        this.emit('ricochet');
      }
      z.hp -= amount;
      z.flash = 0.07;
      this.emit('hit', { boss: !!z.boss, source });
      this.burst(z.x, z.y, shield ? '#8de8ff' : '#fbd078', 3, 35);
      if (z.boss) {
        // Each form owns a health segment. Excess damage never skips a reveal or a form.
        const floor = (z.maxHp * (z.stages - z.stage)) / z.stages;
        if (z.stage < z.stages && z.hp <= floor) {
          z.hp = floor;
          z.stage++;
          z.attack = 1.35;
          z.wind = 0;
          z.mode = 'idle';
          z.shake = 0;
          z.chainIn = null;
          z.followUps = [];
          this.barrels = this.barrels.filter((x) => !x.thrown);
          this.shots = [];
          this.bullets = [];
          this.grenades = [];
          this.emit('mutation', { stage: z.stage });
          this.scene = {
            kind: 'mutation',
            phase: 0,
            time: 0,
            duration: z.stage === 3 ? 2.8 : 1.8,
            bossId: z.bossId,
            stage: z.stage,
          };
          this.resetInput();
        } else if (z.hp <= 0) this.killBoss();
        return;
      }

      if (z.hp <= 0) {
        z.dead = true;
        this.resolve(z);
        this.kills++;
        this.combo++;
        this.comboLeft = 7;
        const previous = this.multiplier;
        this.multiplier = this.combo >= 30 ? 10 : this.combo >= 20 ? 4 : this.combo >= 10 ? 2 : 1;
        const points = z.points * this.multiplier;
        this.addPoints(points, z.x, z.y);
        if (this.multiplier > previous) this.emit('boost', { multiplier: this.multiplier });
        this.burst(z.x, z.y, z.type === 'fuse' ? '#9cff65' : '#bfd595', 8, 60);
        this.emit('kill', { type: z.type });
        if (z.type === 'fuse') this.explode(z.x, z.y, 85, 6, false);
        if (this.kills % 20 === 0 || this.rand() < 0.022) this.drop(z.x, z.y);
      }
    }
    resolve(z) {
      if (z.resolved) return;
      z.resolved = true;
      if (!z.minion) this.resolved++;
    }
    addPoints(n, x, y) {
      this.score += Math.round(n);
      this.pops.push({ x, y, text: '+' + Math.round(n).toLocaleString(), life: 0.9 });
      if (this.pops.length > 12) this.pops.shift();
    }
    resetCombo() {
      this.combo = 0;
      this.multiplier = 1;
      this.comboLeft = 0;
    }
    hurt(reason) {
      const p = this.player;
      if (this.over || this.scene || p.inv > 0 || p.shield > 0 || this.invincible) return;
      p.lives--;
      p.inv = 1.25;
      p.hit = 1.25; // the hit flash is separate from spawn/boss protection, which must not flash Joey
      this.shake = 2;
      this.resetCombo();
      this.emit('hurt');
      if (p.lives <= 0) this.end(reason);
    }
    equip(gun, ammo = null) {
      const g = GUNS[gun];
      if (!g) return;
      this.player.gun = gun;
      this.player.ammo = ammo ?? g.ammo;
      this.banner = g.name + ' READY';
      this.bannerLeft = 1.2;
    }
    useStored(gun) {
      const p = this.player;
      if (
        !this.active ||
        !p.inventory?.[gun] ||
        !GUNS[gun] ||
        this.scene ||
        this.over ||
        gun === p.gun
      )
        return false;
      const ammo = p.inventory[gun];
      if (p.gun !== 'pistol' && p.ammo > 0) p.inventory[p.gun] = p.ammo;
      p.inventory[gun] = 0;
      p.special = null; // choosing a stored gun hands back the normal weapon
      this.equip(gun, ammo);
      this.emit('weaponUse', { gun });
      return true;
    }
    drop(x, y, forced) {
      const types = ['grenade', 'shield', 'heart', 'smg', 'shotgun', 'burst', 'dmr'];
      let type = forced;
      if (!type) {
        const r = this.rand();
        type =
          (this.maxLives || 5) < 10 && this.rand() < 0.08
            ? 'goldheart'
            : this.player.lives <= 2 && r < 0.35
              ? 'heart'
              : r < 0.2
                ? 'grenade'
                : r < 0.38
                  ? 'shield'
                  : r < 0.54
                    ? 'speed'
                    : types[3 + Math.floor(this.rand() * 4)];
      }
      this.pickups.push({
        x: clamp(x, 20, W - 20),
        y: clamp(y, 20, H - 45),
        type,
        life: type === 'goldheart' ? PICKUP_LIFE + 5 : PICKUP_LIFE,
        age: 0,
      });
    }
    updatePickups(dt) {
      for (const item of this.pickups) {
        item.age += dt;
        item.life -= dt;
        item.y = Math.min(H - 52, item.y + 37 * dt);
        if (item.life > 0 && this.joeyDistance(item.x, item.y) < 22) this.collect(item);
      }
      this.pickups = this.pickups.filter((i) => i.life > 0);
    }
    // Drops are collected by touching them or by shooting them.
    collect(item) {
      if (item.life <= 0) return;
      const p = this.player;
      if (GUNS[item.type]) {
        if ((p.inventory[item.type] || 0) > 0 || (p.gun === item.type && p.ammo > 0)) {
          this.addPoints(200, item.x, item.y);
          this.banner = GUNS[item.type].name + ' ALREADY STORED';
          this.bannerLeft = 0.9;
        } else {
          p.inventory[item.type] = GUNS[item.type].ammo;
          this.banner = GUNS[item.type].name + ' STORED';
          this.bannerLeft = 1.2;
        }
      } else if (item.type === 'heart') p.lives = Math.min(this.maxLives || 5, p.lives + 1);
      else if (item.type === 'goldheart') {
        if ((this.maxLives || 5) < 10) {
          this.maxLives = (this.maxLives || 5) + 1;
          p.lives = Math.min(this.maxLives, p.lives + 1);
          this.banner = 'GOLD HEART · +1 MAX LIFE';
        } else {
          p.lives = this.maxLives;
          this.addPoints(500, item.x, item.y);
          this.banner = 'GOLD HEART · FULL HEALTH';
        }
        this.bannerLeft = 1.4;
      } else if (item.type === 'grenade') p.grenades = Math.min(9, p.grenades + 2);
      else if (item.type === 'speed') {
        p.speedUp = 7;
        this.banner = 'SPEED UP';
        this.bannerLeft = 1;
      } else if (item.type === 'shield') p.shield = 7;
      item.life = 0;
      this.emit('pickup', { type: item.type });
    }
    grenade() {
      const p = this.player;
      if (!this.active || this.over || this.scene || this.nextIn > 0 || p.grenades <= 0)
        return false;
      p.grenades--;
      const tx = p.x,
        ty = Math.max(48, p.y - H * 0.5);
      this.grenades.push({
        sx: p.x,
        sy: p.y - 20,
        x: p.x,
        y: p.y - 20,
        tx,
        ty,
        age: 0,
        duration: 0.52,
      });
      this.emit('throw');
      return true;
    }
    updateGrenades(dt) {
      for (const g of this.grenades) {
        g.age += dt;
        const q = clamp(g.age / g.duration, 0, 1);
        g.x = g.sx + (g.tx - g.sx) * q;
        g.y = g.sy + (g.ty - g.sy) * q - Math.sin(q * Math.PI) * 35;
        if (q >= 1) this.explode(g.tx, g.ty, 125, 20, true);
      }
      this.grenades = this.grenades.filter((g) => g.age < g.duration);
    }
    explode(x, y, r, damage, grenade) {
      this.effects.push({
        kind: 'ring',
        x,
        y,
        r,
        life: 0.48,
        total: 0.48,
        color: grenade ? '#ffd27b' : '#92ee56',
      });
      this.burst(x, y, grenade ? '#ffb341' : '#a2ed55', 24, 160);
      if (grenade) {
        this.shake = 3;
        this.hitStop = 0.025;
        this.emit('explosion');
      }
      for (const z of [...this.enemies, ...(this.boss ? [this.boss] : [])])
        if (!z.dead && Math.hypot(z.x - x, z.y - y) < r + z.r)
          this.damage(z, damage, grenade ? 'grenade' : 'chain');
      this.shots = this.shots.filter((s) => Math.hypot(s.x - x, s.y - y) > r);
      for (const barrel of this.barrels)
        if (!barrel.dead && Math.hypot(barrel.x - x, barrel.y - y) < r * 0.85)
          this.explodeBarrel(barrel);
    }
    burst(x, y, color, n, speed) {
      for (let i = 0; i < n; i++) {
        const a = this.rand() * Math.PI * 2,
          v = speed * (0.4 + this.rand() * 0.6),
          life = 0.16 + this.rand() * 0.25;
        this.effects.push({
          kind: 'spark',
          x,
          y,
          vx: Math.cos(a) * v,
          vy: Math.sin(a) * v,
          color,
          life,
          total: life,
          r: 1 + this.rand() * 2,
        });
      }
      if (this.effects.length > 180) this.effects.splice(0, this.effects.length - 180);
    }
    aimedShot(x, y, kind, speed = 120, r = 9, offset = 0) {
      const lead =
        this.boss && this.boss.cycle % 3 === 0 ? clamp((this.player.vx || 0) * 0.16, -32, 32) : 0;
      const a = Math.atan2(this.player.y - y, clamp(this.player.x + lead, 28, W - 28) - x) + offset;
      this.shots.push({
        x,
        y,
        vx: Math.cos(a) * speed,
        vy: Math.sin(a) * speed,
        kind,
        r,
        life: 5,
        age: 0,
      });
    }
    queueBoss(id, stage = 1) {
      const def = BOSSES.find((b) => b.id === id);
      if (!def) return;
      this.boss = null;
      this.enemies = [];
      this.shots = [];
      this.bullets = [];
      this.grenades = [];
      this.barrels = this.barrels.filter((b) => !b.thrown);
      this.scene = {
        kind: 'arrival',
        bossId: id,
        phase: 0,
        time: 0,
        duration: 0.7,
        startStage: stage,
      };
      this.resetInput();
      this.emit('entrance', { id });
      this.emit('music', { track: id === 'discoman' ? 'disco' : 'boss' });
    }
    advanceScene() {
      const s = this.scene;
      if (!s) return;
      if (s.kind === 'arrival' && s.phase < 2) {
        s.phase++;
        s.time = 0;
        s.duration = s.phase === 1 ? 2.1 : 2.8;
        this.emit('panel', { phase: s.phase });
        return;
      }
      this.scene = null;
      if (s.kind === 'arrival') this.spawnBoss(s.bossId, s.startStage || 1);
      if (s.kind === 'down') {
        this.nextIn = 1.2;
        this.banner = 'BOSS DOWN · KEEP MOVING';
        this.bannerLeft = 1.2;
        this.drop(W / 2, H - 75, 'heart');
        this.drop(W / 2 + 60, H - 130, 'dmr');
        if ((this.maxLives || 5) < 10) this.drop(W / 2 - 60, H - 150, 'goldheart');
      }
      if (s.kind === 'mutation') {
        this.player.inv = 1.5;
        if (this.boss) this.boss.phaseGrace = 1.4;
        this.emit('music', { track: this.boss?.bossId === 'discoman' ? 'disco' : 'boss' });
      }
      if (s.kind === 'loss') {
        this.over = true;
        this.active = false;
        this.emit('over', { reason: s.reason });
      }
    }
    spawnBoss(id, stage = 1) {
      const b = BOSSES.find((x) => x.id === id);
      if (!b) return;
      this.boss = {
        id: this.nextId++,
        boss: true,
        bossId: id,
        name: b.name,
        x: W / 2,
        y: id === 'drmantis' && stage === 3 ? 118 : 105,
        r: 36,
        vx: 0,
        vy: 0,
        mode: 'idle',
        shake: 0,
        maxHp: b.hp * 1.55,
        hp: b.hp * 1.55 * (1 - (stage - 1) / b.stages),
        stages: b.stages,
        stage,
        phaseGrace: 1.4,
        age: 0,
        attack: 1.55,
        flash: 0,
        dead: false,
        wind: 0,
        cycle: 0,
      };
      this.player.inv = 1.5;
      this.banner = '';
      this.emit('fight', { id });
    }
    setTenHearts(on) {
      this.practice = true;
      this.maxLives = on ? 10 : 5;
      this.player.lives = on ? 10 : Math.min(this.player.lives, 5);
    }
    skipBoss(id, stage = 1) {
      this.practice = true;
      this.active = true;
      this.over = false;
      this.nextIn = 0;
      this.player.lives = this.maxLives || 5;
      this.player.grenades = 9;
      this.player.inv = 2;
      this.spawned = this.target;
      this.resolved = this.target;
      const def = BOSSES.find((b) => b.id === id);
      this.wave = def.wave;
      this.queueBoss(id, clamp(stage, 1, def.stages));
    }
    bossMove(b, dt) {
      const p = this.player;
      if (b.mode === 'prep' || b.mode === 'shake') return;
      if (b.mode === 'charge') {
        const dx = b.tx - b.x,
          dy = b.ty - b.y,
          l = Math.hypot(dx, dy) || 1,
          step = 270 * dt;
        b.chargeT += dt;
        if (l <= step || b.chargeT > 1.2) b.mode = 'retreat';
        else {
          b.x += (dx / l) * step;
          b.y += (dy / l) * step;
        }
        return;
      }
      if (b.mode === 'retreat') {
        const dx = b.hx - b.x,
          dy = b.hy - b.y,
          l = Math.hypot(dx, dy) || 1,
          step = 150 * dt;
        if (l <= step) {
          b.x = b.hx;
          b.y = b.hy;
          b.mode = 'idle';
          b.attack = 1.9;
        } else {
          b.x += (dx / l) * step;
          b.y += (dy / l) * step;
        }
        return;
      }
      // Every boss has its own way of moving: roaming, orbiting, stop-and-go bursts or zig-zag darts,
      // with a sway on top and now and then a lunge down the screen. Never closer than half the zombie walk.
      const st = BOSS_MOVE[b.bossId] || BOSS_MOVE.jordan,
        stage = 1 + (b.stage - 1) * 0.16;
      let vmul = 1;
      b.mt = (b.mt || 0) + dt;
      if (st.kind === 'orbit') {
        const t = b.mt * (1 + (b.stage - 1) * 0.2),
          tx = W / 2 + st.ax * Math.sin(t * st.fx),
          ty = st.cy + st.ay * Math.sin(t * st.fy),
          follow = Math.min(1, dt * 5);
        b.vx = (tx - b.x) * 5;
        b.vy = (ty - b.y) * 5;
        b.x += (tx - b.x) * follow;
        b.y += (ty - b.y) * follow;
      } else {
        b.wpIn = (b.wpIn || 0) - dt;
        let moving = true;
        if (st.kind === 'stopgo') {
          // Crawl, twitch, then burst to a new spot.
          b.sgIn = (b.sgIn ?? 1.2) - dt;
          if (b.sgIn <= 0) {
            b.bursting = !b.bursting;
            b.sgIn = b.bursting ? 0.38 : 1.15 - b.stage * 0.15 + this.rand() * 0.7;
            if (b.bursting) b.wpIn = 0;
          }
          vmul = (b.bursting ? st.burst : st.crawl) / 60;
        }
        if (!b.wp || b.wpIn <= 0 || Math.hypot(b.wp[0] - b.x, b.wp[1] - b.y) < 6) {
          const dive =
            st.lunge && this.rand() < st.lunge * (0.7 + b.stage * 0.3) && b.phaseGrace <= 0;
          if (dive) {
            // Lunge down the screen to one side of Joey, then come back up.
            const side = this.rand() < 0.5 ? -1 : 1;
            b.wp = [
              clamp(p.x + side * (70 + this.rand() * 40), st.x[0], st.x[1]),
              168 + this.rand() * 14,
            ];
            b.wpIn = 0.85;
            b.lunging = true;
          } else {
            b.lunging = false;
            let wx = st.x[0] + this.rand() * (st.x[1] - st.x[0]);
            if (st.follow) wx = clamp(wx + (p.x - wx) * st.follow, st.x[0], st.x[1]);
            b.wp = [wx, st.y[0] + this.rand() * (st.y[1] - st.y[0])];
            const d = st.dwell || [1, 1.6];
            b.wpIn = d[0] + this.rand() * (d[1] - d[0]);
            if (st.kind === 'zigzag')
              b.wp[0] = clamp(
                b.x + (b.x < W / 2 ? 1 : -1) * (90 + this.rand() * 80),
                st.x[0],
                st.x[1],
              );
          }
        }
        const dx = b.wp[0] - b.x,
          dy = b.wp[1] - b.y,
          l = Math.hypot(dx, dy) || 1,
          v = (st.v || 60) * stage * vmul * (b.lunging ? 1.5 : 1);
        b.vx +=
          ((dx / l) * v - b.vx) * Math.min(1, dt * (st.kind === 'zigzag' || b.bursting ? 8 : 3));
        b.vy +=
          ((dy / l) * v - b.vy) * Math.min(1, dt * (st.kind === 'zigzag' || b.bursting ? 8 : 3));
        b.x += b.vx * dt;
        b.y += b.vy * dt;
      }
      // Sway rides on top of the path: [x amplitude, y amplitude, x speed, y speed].
      const [ax, ay, fx, fy] = st.sway,
        ox = ax * Math.sin(b.mt * fx),
        oy = ay * Math.sin(b.mt * fy);
      b.x += ox - (b.ox || 0);
      b.y += oy - (b.oy || 0);
      b.ox = ox;
      b.oy = oy;
      b.x = clamp(b.x, 67, W - 67);
      const minD = (p.y + 28) / 2,
        ddx = b.x - p.x;
      if (Math.hypot(ddx, b.y - p.y) < minD)
        b.y = p.y - Math.sqrt(Math.max(0, minD * minD - ddx * ddx));
      b.y = clamp(b.y, b.bossId === 'drmantis' && b.stage === 3 ? 111 : 98, 190);
    }
    updateBoss(dt) {
      const b = this.boss;
      if (!b || b.dead) return;
      const p = this.player,
        loss = BOSSES.find((d) => d.id === b.bossId).playerLoss;
      b.phaseGrace = Math.max(0, (b.phaseGrace || 0) - dt);
      b.age += dt;
      b.flash = Math.max(0, b.flash - dt);
      b.attack -= dt;
      if (!this.shots.some((s) => s.kind === 'chain' && s.life > 0)) this.bossMove(b, dt);
      b.wind = b.attack > 0 && b.attack <= 0.48 ? 1 : 0;
      // Later forms mix a main pattern with a brief follow-up. All use the same
      // character-specific weapons and stop immediately at a form transition.
      for (const shot of b.followUps || []) {
        shot.in -= dt;
        if (shot.in <= 0) {
          this.aimedShot(b.x, b.y, shot.kind, shot.speed, shot.r);
          this.emit('bossAttack', { id: b.bossId });
        } else b.wind = 1;
      }
      b.followUps = (b.followUps || []).filter((shot) => shot.in > 0);
      // Debo: the chain lunges through the thrown barrel as it reaches Joey's line.
      if (b.chainIn != null) {
        b.chainIn -= dt;
        if (b.chainIn <= 0) {
          b.chainIn = null;
          if (this.barrels.some((x) => x.thrown && !x.dead)) {
            const dx = b.tx - b.x,
              dy = b.ty - b.y,
              l = Math.hypot(dx, dy) || 1;
            this.shots.push({
              kind: 'chain',
              ox: b.x,
              oy: b.y,
              x: b.x,
              y: b.y,
              dx: dx / l,
              dy: dy / l,
              reach: l,
              r: 17,
              age: 0,
              life: 1.4,
              wind: BARREL.chainWind,
              ext: BARREL.chainExtend,
              hold: 0.18,
              ret: 0.32,
            });
          }
        }
      }
      // Dr Mantis form 3: mini Mantises walk down from the top and sides, one shot each.
      if (b.bossId === 'drmantis' && b.stage === 3 && b.phaseGrace <= 0) {
        b.miniIn = (b.miniIn ?? 1) - dt;
        if (b.miniIn <= 0) {
          b.miniIn = 1.2 + this.rand() * 0.7;
          if (this.enemies.filter((z) => z.type === 'mantismini' && !z.dead).length < 8) {
            const r = this.rand(),
              side = r < 0.34 ? -1 : r < 0.67 ? 1 : 0,
              z = side
                ? this.spawn('mantismini', side < 0 ? -12 : W + 12, 22 + this.rand() * 90, true)
                : this.spawn('mantismini', 30 + this.rand() * (W - 60), -24, true);
            if (side) z.vx = -side * 34;
          }
        }
      }
      // Fat Amy form 3: stop and shake, charge at where Joey stands, then retreat.
      if (b.bossId === 'fatamy' && b.stage === 3) {
        if (b.mode === 'prep') {
          b.modeT -= dt;
          b.wind = 1;
          if (b.modeT <= 0) {
            b.mode = 'shake';
            b.modeT = 1;
            b.shake = 1;
          }
          return;
        }
        if (b.mode === 'shake') {
          b.modeT -= dt;
          b.wind = 1;
          if (b.modeT <= 0) {
            b.mode = 'charge';
            b.shake = 0;
            b.hx = b.x;
            b.hy = b.y;
            b.tx = p.x;
            b.ty = p.y - 14;
            b.chargeT = 0;
            this.emit('bossAttack', { id: b.bossId });
          }
          return;
        }
        if (b.mode === 'charge') {
          if (this.joeyDistance(b.x, b.y) < b.r + 8) this.hurt(loss);
          return;
        }
        if (b.mode === 'retreat') return;
      }
      if (b.attack > 0) return;
      b.cycle++;
      b.attack = 3;
      // Disco Man's and Fat Amy's throws were too slow: their projectiles fly faster (nothing else changes).
      const FAST = b.bossId === 'discoman' || b.bossId === 'fatamy' ? 1.4 : 1,
        V = (1.1 + (b.stage - 1) * 0.045) * FAST,
        fan = (kind, n, gap, speed, r) => {
          for (let i = 0; i < n; i++)
            this.aimedShot(b.x, b.y, kind, speed * V, r, (i - (n - 1) / 2) * gap);
        };
      switch (b.bossId) {
        case 'jordan':
          fan('ember', b.stage > 1 ? 3 : b.cycle % 3 === 0 ? 2 : 1, 0.3, 150, 8);
          b.attack = b.stage > 1 ? 2.3 : 1.7;
          break;
        case 'glowinghumanity':
          if (b.stage === 1) {
            fan('glowstick', 1, 0, 125, 11);
            const s = this.shots.at(-1);
            let k;
            do {
              k = Math.floor(this.rand() * GLOW.length);
            } while (k === b.lastGlow);
            b.lastGlow = k;
            s.color = GLOW[k];
            b.attack = 2;
          } else {
            for (const side of [-1, 1])
              this.shots.push({
                x: b.x,
                y: b.y,
                vx: side * 96,
                vy: 108,
                kind: 'handcuffs',
                r: 11,
                life: 7,
                age: 0,
              });
            b.attack = 3.2;
          }
          break;
        case 'debo':
          if (b.stage === 1) {
            const dx = p.x - b.x,
              dy = p.y - b.y,
              l = Math.hypot(dx, dy);
            this.shots.push({
              kind: 'chain',
              ox: b.x,
              oy: b.y,
              x: b.x,
              y: b.y,
              dx: dx / l,
              dy: dy / l,
              reach: l + 22,
              r: 17,
              age: 0,
              life: 2.2,
              wind: 0.48,
              ext: 0.24,
              hold: 0.2,
              ret: 0.4,
            });
            b.attack = 3.3;
          } else {
            const T = BARREL.flight,
              tx = clamp(p.x, 30, W - 30),
              ty = p.y - 6,
              sy = b.y + 20;
            this.barrels.push({
              id: this.nextId++,
              x: b.x,
              y: sy,
              hp: 1.5,
              dead: false,
              thrown: true,
              small: true,
              tx,
              ty,
              vx: (tx - b.x) / T,
              vy: (ty - sy) / T,
              rot: 0,
              age: 0,
              T,
            });
            b.tx = tx;
            b.ty = ty;
            b.chainIn = T - BARREL.chainWind - BARREL.chainExtend;
            b.attack = 4.1;
          }
          break;
        case 'discoman':
          b.recordVolley = !b.recordVolley;
          if (b.stage === 1) fan(b.recordVolley ? 'record' : 'disco', 2, 0.4, 110, 12);
          else fan(b.recordVolley ? 'record' : 'disco', 3, 0.34, 115, 11);
          b.attack = 2.9;
          break;
        case 'caffeinatedsloth':
          if (b.stage === 1) {
            fan('coffee', 1, 0, 130, 11);
            b.attack = 2.1;
          } else {
            fan('coffee', 3, 0.3, 135, 11);
            b.attack = 2.7;
          }
          break;
        case 'fatamy':
          if (b.stage === 1) {
            fan('missile', 1, 0, 120, 11);
            b.attack = 2.7;
          } else if (b.stage === 2) {
            fan(this.rand() < 0.5 ? 'burger' : 'donut', 1, 0, 120, 11);
            b.attack = 2.1;
          } else {
            for (const side of [-1, 1])
              this.shots.push({
                x: b.x,
                y: b.y,
                vx: side * 98 * FAST,
                vy: 92 * FAST,
                kind: 'donut',
                r: 11,
                life: 7,
                age: 0,
              });
            b.mode = 'prep';
            b.modeT = 1.3;
            b.attack = 99;
          }
          break;
        case 'drmantis':
          if (b.stage === 1) {
            fan('bodypart', 1, 0, 125, 12);
            b.attack = 2.7;
          } else if (b.stage === 2) {
            fan('venom', 2, 0.32, 130, 10);
            b.attack = 2.5;
          } else {
            fan('bodypart', 1, 0, 125, 12);
            fan('venom', 2, 0.4, 130, 10);
            b.attack = 3.1;
          }
          break;
      }
      const follow = (kind, speed, r, delay) =>
        b.followUps.push({ kind, speed: speed * V, r, in: delay });
      if (b.stage > 1) {
        if (b.bossId === 'jordan' && b.cycle % 2 === 0) follow('ember', 155, 8, 0.32);
        if (b.bossId === 'caffeinatedsloth') follow('coffee', 142, 11, 0.3);
        if (b.bossId === 'glowinghumanity' && b.cycle % 3 === 0) follow('handcuffs', 125, 11, 0.38);
        if (b.bossId === 'fatamy' && b.stage === 2 && b.cycle % 3 === 0)
          follow(this.shots.at(-1)?.kind === 'burger' ? 'donut' : 'burger', 132, 11, 0.34);
        if (b.bossId === 'drmantis' && b.stage === 3 && b.cycle % 2 === 0)
          follow('venom', 140, 10, 0.4);
      }
      if (b.attack < 50) b.attack *= 0.78 - (b.stage - 1) * 0.035;
      this.emit('bossAttack', { id: b.bossId });
    }
    updateShots(dt) {
      const p = this.player;
      for (const s of this.shots) {
        const px = s.x,
          py = s.y;
        s.age += dt;
        s.life -= dt;
        if (s.kind === 'chain') {
          const ex = s.ext || 0.45,
            hd = s.hold || 0.3,
            rt = s.ret || 0.65,
            q =
              s.age < s.wind
                ? 0
                : s.age < s.wind + ex
                  ? (s.age - s.wind) / ex
                  : s.age < s.wind + ex + hd
                    ? 1
                    : Math.max(0, 1 - (s.age - s.wind - ex - hd) / rt);
          s.x = s.ox + s.dx * s.reach * q;
          s.y = s.oy + s.dy * s.reach * q;
          if (s.age > s.wind + ex + hd + rt) s.life = 0;
        } else {
          s.x += s.vx * dt;
          s.y += s.vy * dt;
          if (['donut', 'disco', 'handcuffs'].includes(s.kind) && (s.x < s.r || s.x > W - s.r)) {
            s.vx *= -1;
            s.x = clamp(s.x, s.r, W - s.r);
          }
        }
        if (s.kind === 'chain' && s.age < s.wind) continue;
        if (this.joeyHit(px, py, s.x, s.y, s.r * 0.6)) {
          this.hurt(
            this.boss
              ? BOSSES.find((b) => b.id === this.boss.bossId).playerLoss
              : 'Toxic spit caught Joey.',
          );
          if (s.kind !== 'chain') s.life = 0;
        }
      }
      this.shots = this.shots.filter(
        (s) => s.life > 0 && s.y < H + 35 && s.x > -60 && s.x < W + 60,
      );
    }
    killBoss() {
      const b = this.boss,
        def = BOSSES.find((d) => d.id === b.bossId);
      if (b.dead) return;
      b.dead = true;
      this.kills++;
      this.addPoints(def.points * this.multiplier, b.x, b.y);
      this.bossesDown.push(b.bossId);
      this.shots = [];
      this.enemies = [];
      this.bullets = [];
      this.grenades = [];
      this.barrels = this.barrels.filter((x) => !x.thrown);
      this.burst(b.x, b.y, def.accent, 35, 120);
      this.scene = {
        kind: 'down',
        bossId: b.bossId,
        stage: b.stage,
        phase: 0,
        time: 0,
        duration: 3.4,
      };
      this.resetInput();
      this.emit('bossDown');
      this.boss = null;
    }
    end(reason) {
      if (this.over || this.scene?.kind === 'loss') return;
      const id = this.boss?.bossId;
      this.dangerSource = id;
      this.scene = {
        kind: 'loss',
        bossId: id,
        phase: 0,
        time: 0,
        duration: id ? 3.2 : 1.1,
        reason,
      };
      this.resetInput();
      this.emit('death');
    }
    snapshot() {
      const copy = JSON.parse(JSON.stringify(this));
      delete copy.onEvent;
      copy.input = { axis: 0, fire: false };
      return copy;
    }
    restore(saved) {
      // Reject incomplete saves before touching the running game. Old saves may omit newer fields.
      if (!saved || !Number.isFinite(saved.t) || saved.t < 0 ||
          !Number.isInteger(saved.wave) || saved.wave < 1 ||
          !Number.isFinite(saved.score) || saved.score < 0 ||
          !saved.active || saved.over || !saved.player ||
          !Object.hasOwn(GUNS, saved.player.gun) ||
          !Number.isFinite(saved.player.x) || !Number.isFinite(saved.player.lives) ||
          !['enemies', 'bullets', 'shots', 'pickups', 'grenades', 'effects', 'pops', 'bossesDown']
            .every(key => Array.isArray(saved[key]) && saved[key].every(item => item != null)) ||
          saved.enemies.some(z => !Object.hasOwn(ENEMIES, z.type)) ||
          (saved.boss && !BOSSES.some(b => b.id === saved.boss.bossId)) ||
          (saved.scene && (!['arrival', 'mutation', 'down', 'loss'].includes(saved.scene.kind) ||
            (saved.scene.bossId && !BOSSES.some(b => b.id === saved.scene.bossId))))) return false;
      let copy;
      try { copy = JSON.parse(JSON.stringify(saved)); } catch { return false; }
      const fn = this.onEvent;
      this.reset();
      // Only restore state fields, never instance methods or the event callback.
      for (const key of Object.keys(this)) {
        if (key !== 'onEvent' && Object.hasOwn(copy, key)) this[key] = copy[key];
      }
      if (this.scene) { this.scene.mediaControlled = false; this.scene.time = 0; }
      this.onEvent = fn;
      this.player.ammo = this.player.ammo ?? GUNS[this.player.gun].ammo;
      this.player.inventory = {
        smg: 0,
        shotgun: 0,
        dmr: 0,
        burst: 0,
        ...(this.player.inventory || {}),
      };
      this.player.y = H - 52;
      for (const z of this.enemies) {
        const spec = ENEMIES[z.type];
        if (!spec) continue;
        const hpRatio = clamp(z.hp / (z.maxHp || spec.hp), 0, 1);
        z.height = spec.height;
        z.r = spec.r;
        z.speed = spec.speed * this.enemyPace() * (z.paceFactor || 1);
        z.maxHp = spec.hp * this.enemyHealth(z.type);
        z.hp = z.maxHp * hpRatio;
      }
      if (!Array.isArray(saved.barrels)) this.spawnBarrels();
      else this.barrels = copy.barrels;
      this.resetInput();
      return true;
    }
  }
  window.ZSEngine = { Game, ENEMIES, GUNS, SPECIALS, BARREL, segmentDistance, clamp };
})();
