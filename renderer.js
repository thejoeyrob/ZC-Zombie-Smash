(() => {
  'use strict';
  const { W, H, BOSSES, MAPS } = ZSData,
    { ENEMIES, GUNS, SPECIALS, BARREL, clamp } = ZSEngine;
  const files = [
    ...MAPS.map((m) => m.file),
    ...Object.values(ENEMIES).map((e) => e.art),
    ...BOSSES.flatMap((b) => b.sprites),
    'player-transparent.webp',
    'player-fire.webp',
    'player-hit.webp',
    'player-portrait.webp',
    'player-wounded.webp',
    'player-victory.webp',
    'joey-reaction-close.webp',
    'prop-barrel.webp',
    ...Object.values(GUNS).map((g) => g.art),
    ...['heart', 'clock', 'speed', 'shield', 'bomb', 'smg', 'dmr'].map(
      (k) => 'pickup-' + k + '.webp',
    ),
    ...[
      'chain',
      'ember',
      'coffee',
      'missile',
      'burger',
      'donut',
      'handcuffs',
      'venom',
      'bodypart',
      'disco',
    ]
      .concat(['green', 'pink', 'blue', 'orange', 'yellow', 'violet'].map((c) => 'glowstick-' + c))
      .map((k) => 'weapon-' + k + '.webp'),
  ];
  class Renderer {
    constructor(canvas) {
      this.canvas = canvas;
      this.c = canvas.getContext('2d', { alpha: false, desynchronized: true });
      this.images = {};
      this.bounds = {};
      this.variants = new Map();
      this.autoDpr = 2;
      this.pressure = { elapsed: 0, slow: 0, frames: 0, calm: 0, cooldown: 0 };
      this.backdrop = null;
      this.floorLayer = null;
      this.enemyOrder = [];
      this.reduced = matchMedia('(prefers-reduced-motion:reduce)').matches;
      this.resize();
    }
    resize() {
      const dpr = Math.min(this.autoDpr, devicePixelRatio || 1),
        r = this.canvas.getBoundingClientRect(),
        scale = Math.max(0.5, r.width / W);
      const width = Math.max(1, Math.round(W * dpr * scale)),
        height = Math.max(1, Math.round(H * dpr * scale));
      if (this.canvas.width === width && this.canvas.height === height && this.haze) return;
      this.canvas.width = width;
      this.canvas.height = height;
      this.backdrop = this.floorLayer = null;
      this.c.setTransform(this.canvas.width / W, 0, 0, this.canvas.height / H, 0, 0);
      this.c.imageSmoothingEnabled = true;
      this.c.imageSmoothingQuality = 'high';
      this.haze = this.c.createLinearGradient(0, 0, 0, 55);
      this.haze.addColorStop(0, '#050908a0');
      this.haze.addColorStop(1, '#05090800');
    }
    get light() { return this.autoDpr < 2; }
    // Only observed gameplay frames count. Lower decoration quality without changing simulation or enemies.
    observeFrame(ms, active) {
      const p = this.pressure;
      if (!active || ms <= 0 || ms > 250) { p.elapsed = p.slow = p.frames = p.calm = 0; return; }
      p.elapsed += ms; p.frames++; p.slow += ms > 22 ? 1 : 0;
      p.cooldown = Math.max(0, p.cooldown - ms);
      if (p.elapsed < 1000) return;
      const ratio = p.slow / p.frames;
      p.calm = ratio < 0.05 ? p.calm + p.elapsed : 0;
      let next = this.autoDpr;
      if (ratio > 0.18 && !p.cooldown) next = Math.max(1.25, next - 0.25);
      else if (p.calm > 12000 && !p.cooldown) next = Math.min(2, next + 0.25);
      p.elapsed = p.slow = p.frames = 0;
      if (next !== this.autoDpr) {
        this.autoDpr = next; p.cooldown = 4000; p.calm = 0;
        document.body.classList.toggle('render-lite', this.light);
        this.resize();
      }
    }
    async load(progress = () => {}) {
      try {
        this.bounds = await (await fetch('./art-bounds.json')).json();
      } catch {}
      let count = 0;
      const failed = [];
      const list = [...new Set(files)];
      await Promise.all(
        list.map(
          (file) =>
            new Promise((resolve) => {
              const im = new Image();
              im.decoding = 'async';
              this.images[file] = im;
              im.onload = () => {
                progress(++count / list.length);
                resolve();
              };
              im.onerror = () => {
                failed.push(file);
                progress(++count / list.length);
                resolve();
              };
              im.src = './' + file;
            }),
        ),
      );
      if (failed.length) throw Error('Missing artwork: ' + failed.slice(0, 3).join(', '));
      // Warm flash/rim variants before PRESS START, in small batches so the loading screen stays responsive.
      const jobs = [];
      for (const e of Object.values(ENEMIES)) {
        for (const rim of [false, true]) for (const bright of [false, true])
          if (rim || bright) jobs.push([e.art, e.height * 0.82, e.height, rim, bright]);
      }
      for (const boss of BOSSES) boss.sprites.forEach((file, i) =>
        jobs.push([file, 130, boss.id === 'drmantis' && i === 2 ? 139 : 113, false, true]));
      for (let i = 0; i < jobs.length; i++) {
        const [file, w, h, rim, bright] = jobs[i], im = this.images[file];
        const b = this.bounds[file] || [0, 0, im.naturalWidth, im.naturalHeight];
        const k = Math.min(w / b[2], h / b[3]);
        this.variant(file, b[2] * k, b[3] * k, rim, bright);
        if (i % 4 === 3) await new Promise(resolve => setTimeout(resolve, 0));
      }
    }
    fit(file, x, y, w, h, { alpha = 1, flip = false, bright = false, rot = 0, rim = false } = {}) {
      const im = this.images[file];
      if (!im?.complete || !im.naturalWidth) return;
      const c = this.c,
        b = this.bounds[file] || [0, 0, im.naturalWidth, im.naturalHeight],
        scale = Math.min(w / b[2], h / b[3]),
        dw = b[2] * scale,
        dh = b[3] * scale;
      c.save();
      c.globalAlpha = alpha;
      c.translate(x + w / 2, y + h / 2);
      if (rot) c.rotate(rot);
      if (flip) c.scale(-1, 1);
      // The soft rim light and the hit flash (a canvas shadow and a filter) are expensive to compute live, so each
      // look is painted once per sprite size and reused. Plain sprites are drawn straight from their image: copying
      // every sprite into its own small canvas was measured and made busy screens slower.
      const pad = rim ? 10 : 0, v = this.variant(file, dw, dh, rim, bright);
      if (v) c.drawImage(v, -dw / 2 - pad, -dh / 2 - pad, v.logicalW, v.logicalH);
      else c.drawImage(im, ...b, -dw / 2, -dh / 2, dw, dh);
      c.restore();
    }
    variant(file, dw, dh, rim, bright) {
      if (!rim && !bright) return null;
      const im = this.images[file];
      if (!im?.naturalWidth) return null;
      const b = this.bounds[file] || [0, 0, im.naturalWidth, im.naturalHeight];
      const pad = rim ? 10 : 0,
        key = file + '|' + Math.round(dw) + 'x' + Math.round(dh) + (rim ? 'r' : '') + (bright ? 'b' : '');
      let v = this.variants.get(key);
      if (!v && (rim || bright)) {
        if (this.variants.size >= 160) this.variants.delete(this.variants.keys().next().value);
        // Painted at double size and drawn back at half size, so the copy is as sharp as the original artwork.
        const K = 2;
        v = document.createElement('canvas');
        v.width = Math.ceil((dw + pad * 2) * K);
        v.height = Math.ceil((dh + pad * 2) * K);
        v.logicalW = v.width / K;
        v.logicalH = v.height / K;
        const vc = v.getContext('2d');
        vc.imageSmoothingQuality = 'high';
        if (bright) vc.filter = 'brightness(1.7)';
        if (rim) {
          vc.shadowColor = 'rgba(255,248,215,0.8)';
          vc.shadowBlur = 5 * K;
        }
        vc.drawImage(im, ...b, pad * K, pad * K, dw * K, dh * K);
        this.variants.set(key, v);
      }
      return v;
    }
    // Bullets of the special weapons are drawn from shapes, so they need no artwork.
    specialBullet(b, g) {
      const c = this.c,
        ang = Math.atan2(b.vy, b.vx);
      c.save();
      c.translate(b.x, b.y);
      switch (b.sp) {
        case 'hose':
          c.rotate(ang);
          c.globalAlpha = 0.45;
          c.fillStyle = '#2aa8ff';
          c.beginPath();
          c.ellipse(-3, 0, 17, 7, 0, 0, Math.PI * 2);
          c.fill();
          c.globalAlpha = 1;
          c.fillStyle = '#d6f3ff';
          c.beginPath();
          c.ellipse(0, 0, 11, 4, 0, 0, Math.PI * 2);
          c.fill();
          break;
        case 'rainbow':
          c.fillStyle = `hsl(${(g.t * 420 + b.id * 47) % 360},100%,62%)`;
          c.beginPath();
          c.arc(0, 0, 5.5, 0, Math.PI * 2);
          c.fill();
          c.fillStyle = '#fff';
          c.beginPath();
          c.arc(-1, -1, 2, 0, Math.PI * 2);
          c.fill();
          break;
        case 'bass': {
          const k = 1 + Math.sin(g.t * 26 + b.id) * 0.18;
          c.strokeStyle = '#ffb23d';
          c.lineWidth = 3;
          c.beginPath();
          c.arc(0, 0, 11 * k, 0, Math.PI * 2);
          c.stroke();
          c.strokeStyle = '#fff2c4';
          c.lineWidth = 1.6;
          c.beginPath();
          c.arc(0, 0, 6.5 * k, 0, Math.PI * 2);
          c.stroke();
          c.fillStyle = '#fff6d6';
          c.beginPath();
          c.arc(0, 0, 3, 0, Math.PI * 2);
          c.fill();
          break;
        }
        case 'beans':
          c.rotate(ang);
          c.fillStyle = '#7a4a1f';
          c.beginPath();
          c.ellipse(0, 0, 4.4, 2.8, 0, 0, Math.PI * 2);
          c.fill();
          c.strokeStyle = '#d9a566';
          c.lineWidth = 0.9;
          c.beginPath();
          c.moveTo(-3.4, 0);
          c.lineTo(3.4, 0);
          c.stroke();
          break;
        case 'remover':
          c.fillStyle = 'rgba(255,196,226,0.9)';
          c.beginPath();
          c.arc(0, 0, 7, 0, Math.PI * 2);
          c.arc(-7, 5, 4, 0, Math.PI * 2);
          c.arc(6, 6, 3, 0, Math.PI * 2);
          c.fill();
          c.fillStyle = '#fff';
          c.beginPath();
          c.arc(-2, -2.5, 2.2, 0, Math.PI * 2);
          c.fill();
          break;
        case 'purge':
          c.globalAlpha = 0.4;
          c.fillStyle = '#7dff2a';
          c.beginPath();
          c.arc(0, 0, 10, 0, Math.PI * 2);
          c.fill();
          c.globalAlpha = 1;
          c.fillStyle = '#d4ff9a';
          c.beginPath();
          c.arc(0, 0, 5, 0, Math.PI * 2);
          c.fill();
          break;
      }
      c.restore();
    }
    // The laser column and the chain-lightning arcs.
    specialEffects(g) {
      const c = this.c;
      for (const b of g.beams || []) {
        const k = b.life / b.total,
          w = b.width * (0.55 + 0.45 * k),
          hue = (g.t * 900) % 360;
        c.save();
        c.globalCompositeOperation = 'lighter';
        c.globalAlpha = 0.55 * k + 0.25;
        c.fillStyle = `hsl(${hue},100%,60%)`;
        c.fillRect(b.x - w, 0, w * 2, b.y);
        c.globalAlpha = 0.9;
        c.fillStyle = '#fff';
        c.fillRect(b.x - w * 0.28, 0, w * 0.56, b.y);
        c.restore();
      }
      for (const a of g.arcs || []) {
        c.save();
        c.globalCompositeOperation = 'lighter';
        c.strokeStyle = '#b8ff5a';
        c.lineWidth = 2.4;
        c.globalAlpha = Math.min(1, a.life / a.total + 0.2);
        c.beginPath();
        c.moveTo(a.x1, a.y1);
        const n = 5;
        for (let i = 1; i < n; i++) {
          const t = i / n;
          c.lineTo(a.x1 + (a.x2 - a.x1) * t + (Math.random() - 0.5) * 12, a.y1 + (a.y2 - a.y1) * t + (Math.random() - 0.5) * 12);
        }
        c.lineTo(a.x2, a.y2);
        c.stroke();
        c.restore();
      }
    }
    text(str, x, y, size = 11, color = '#fff', align = 'center') {
      const c = this.c;
      c.font = `800 ${size}px Barlow, sans-serif`;
      c.textAlign = align;
      c.fillStyle = color;
      c.shadowColor = '#000';
      c.shadowBlur = 3;
      c.fillText(str, x, y);
      c.shadowBlur = 0;
    }
    draw(g) {
      const c = this.c;
      c.save();
      const map = MAPS[ZSData.mapIndex(g.wave)];
      this.drawBackdrop(map);
      const opens = g.openings || [];
      if (ZSData.mapIndex(g.wave) === 4 && map.tileGrid) this.drawDiscoFloor(g, map, opens);
      this.arenaAtmosphere(g, map);
      // Floor access hatches sit entirely on open ground, away from the scenery. The Neon Palace uses its dance-floor tiles instead.
      if (map.entryStyle !== 'tile' && map.entryStyle !== 'portal' && map.entryStyle !== 'edge') for(const [x,y] of map.entries) {
        c.fillStyle='#102b2be0'; c.strokeStyle=map.accent; c.lineWidth=1.5;
        c.beginPath(); c.ellipse(x,y+12,18,7,0,0,Math.PI*2); c.fill(); c.stroke();
        c.strokeStyle='#bac7bd88';
        for(let n=-10;n<=10;n+=5){ c.beginPath();c.moveTo(x+n,y+8);c.lineTo(x+n,y+16);c.stroke(); }
      }
      if (map.entryStyle === 'portal') for (const [x,y] of map.entries) {
        const active = opens.some(o => Math.abs(o.x-x) < 1 && Math.abs(o.y-y) < 1);
        c.save(); c.strokeStyle = map.accent; c.lineWidth = active ? 2.2 : 1;
        c.fillStyle = active ? '#112a10e0' : '#173d1940';
        c.beginPath(); c.ellipse(x,y+12,27,10,0,0,Math.PI*2); c.fill(); c.stroke();
        c.globalAlpha = active ? .9 : .45;
        for(let k=0;k<8;k++) { const a=k*Math.PI/4+(this.reduced?0:g.t*.35); c.beginPath(); c.moveTo(x+Math.cos(a)*29,y+12+Math.sin(a)*12);c.lineTo(x+Math.cos(a)*33,y+12+Math.sin(a)*15);c.stroke(); }
        c.restore();
      }
      for(const target of g.arena?.targets || []) {
        c.fillStyle=target.lit?map.accent:'#182b30b8';c.strokeStyle=map.accent;c.lineWidth=1.4;
        c.beginPath();c.arc(target.x,target.y,12,0,Math.PI*2);c.fill();c.stroke();
        c.fillStyle=target.lit?'#102027':'#fff';c.font='bold 12px sans-serif';c.textAlign='center';
        c.fillText(String(g.arena.targets.indexOf(target)+1),target.x,target.y+4);
        if(g.arena.cool){c.beginPath();c.arc(target.x,target.y,16,-Math.PI/2,-Math.PI/2+Math.PI*2*g.arena.cool/12);c.stroke();}
      }
      if (g.shake && !this.reduced)
        c.translate(Math.sin(g.t * 93) * g.shake, Math.cos(g.t * 111) * g.shake * 0.55);
      c.fillStyle = this.haze;
      c.fillRect(0, 0, W, 55);
      c.strokeStyle = '#89baa52b';
      c.setLineDash([4, 5]);
      c.beginPath();
      c.moveTo(0, H - 38);
      c.lineTo(W, H - 38);
      c.stroke();
      c.setLineDash([]);
      for (const item of g.pickups) {
        if (item.life < 3 && Math.floor(item.age * (item.life < 1.2 ? 14 : 8)) % 2) continue;
        const x = item.x,
          y = item.y + Math.sin(item.age * 5) * 2;
        c.fillStyle = '#6bbfe52a';
        c.beginPath();
        c.arc(x, y, 16, 0, Math.PI * 2);
        c.fill();
        c.strokeStyle =
          item.type === 'goldheart' ? '#ffd24a' : item.type === 'heart' ? '#ff6d7a' : '#84d7f4';
        c.lineWidth = item.type === 'goldheart' ? 2 : 1;
        c.stroke();
        if (item.type === 'goldheart') {
          this.goldHeart(x, y, 1 + Math.sin(item.age * 6) * 0.06);
          continue;
        }
        const art =
          { shotgun: 'pickup-smg.webp', burst: 'pickup-dmr.webp', grenade: 'pickup-bomb.webp' }[
            item.type
          ] || 'pickup-' + item.type + '.webp';
        this.fit(art, x - 12, y - 12, 24, 24);
      }
      for (const barrel of g.barrels || []) this.barrel(barrel);
      const order = this.enemyOrder;
      order.length = 0;
      for (const z of g.enemies) order.push(z);
      if (g.boss) order.push(g.boss);
      order.sort((a, b) => a.y - b.y);
      for (const z of order) this.enemy(z, g);
      for (const b of g.bullets) {
        if (b.sp) {
          this.specialBullet(b, g);
          continue;
        }
        c.save();
        c.translate(b.x, b.y);
        c.rotate(Math.atan2(b.vy, b.vx) + Math.PI / 6);
        this.fit(GUNS[b.gun].art, -11, -7.5, 22, 15);
        c.restore();
      }
      this.specialEffects(g);
      for (const s of g.shots) this.shot(s, g);
      const p = g.player;
      if (!g.over) {
        c.fillStyle = '#0007';
        c.beginPath();
        c.ellipse(p.x, p.y + 30, 28, 7, 0, 0, Math.PI * 2);
        c.fill();
        if (p.special) {
          // The special weapon wraps Joey in its colour; it flickers when about to run out.
          const sp = SPECIALS.find((s) => s.id === p.special.id);
          if (sp && (p.special.left > 2 || Math.floor(g.t * 8) % 2)) {
            c.save();
            c.strokeStyle = sp.color;
            c.lineWidth = 2.5;
            c.globalAlpha = 0.6 + 0.3 * Math.sin(g.t * 9);
            c.beginPath();
            c.ellipse(p.x, p.y - 6, 41, 49, 0, 0, Math.PI * 2);
            c.stroke();
            c.restore();
          }
        }
        if (p.shield > 0 || g.invincible) {
          c.strokeStyle = '#8bdffc';
          c.lineWidth = 2;
          c.beginPath();
          c.ellipse(p.x, p.y - 6, 38, 46, 0, 0, Math.PI * 2);
          c.stroke();
        }
        const bob = this.reduced ? 0 : Math.abs(g.input.axis) > 0.1 ? Math.sin(g.t * 18) * 1.2 : 0;
        const art =
          p.hit > 0 && p.hit < 1.2
            ? 'player-hit.webp'
            : p.fireFx > 0
              ? 'player-fire.webp'
              : 'player-transparent.webp';
        this.fit(art, p.x - 35, p.y - 55 + bob, 70, 91, {
          alpha: p.hit > 0 && Math.floor(g.t * 12) % 2 ? 0.58 : 1,
        });
        if (p.fireFx > 0) {
          const fx = p.x,
            fy = p.y - 52,
            k = Math.min(1, p.fireFx / 0.065);
          c.save();
          c.globalCompositeOperation = 'lighter';
          c.globalAlpha = 0.55 + 0.45 * k;
          const gr = c.createRadialGradient(fx, fy, 1, fx, fy, 17);
          gr.addColorStop(0, '#fffbe0');
          gr.addColorStop(0.35, '#ffd35a');
          gr.addColorStop(1, '#ff7a1800');
          c.fillStyle = gr;
          c.beginPath();
          c.arc(fx, fy, 17, 0, Math.PI * 2);
          c.fill();
          c.fillStyle = '#ffe9a0';
          for (const a of [-0.5, 0, 0.5]) {
            c.save();
            c.translate(fx, fy);
            c.rotate(a);
            c.beginPath();
            c.moveTo(-3, 0);
            c.lineTo(0, -24 + Math.abs(a) * 14);
            c.lineTo(3, 0);
            c.closePath();
            c.fill();
            c.restore();
          }
          c.restore();
        }
      }
      for (const grenade of g.grenades)
        this.fit('pickup-bomb.webp', grenade.x - 10, grenade.y - 10, 20, 20);
      let sparkIndex = 0;
      for (const f of g.effects) {
        if (this.light && f.kind === 'spark' && ++sparkIndex % 2 === 0) continue;
        c.globalAlpha = clamp(f.life / f.total, 0, 1);
        if (f.kind === 'ring' || f.kind === 'barrelBlast') {
          const q = 1 - f.life / f.total;
          c.strokeStyle = f.color;
          c.lineWidth = (f.kind === 'barrelBlast' ? 8 : 5) * (1 - q);
          c.beginPath();
          c.arc(f.x, f.y, f.r * q, 0, Math.PI * 2);
          c.stroke();
          c.fillStyle = f.kind === 'barrelBlast' ? '#ff7a2038' : f.color + '35';
          c.fill();
          if (f.kind === 'barrelBlast') {
            c.fillStyle = '#ffe1a0aa';
            c.beginPath();
            c.arc(f.x, f.y, Math.max(2, f.r * q * 0.3), 0, Math.PI * 2);
            c.fill();
          }
        } else {
          c.fillStyle = f.color;
          c.fillRect(f.x, f.y, f.r * 1.7, f.r * 1.7);
        }
      }
      c.globalAlpha = 1;
      for (const pop of g.pops)
        this.text(
          pop.text,
          pop.x,
          pop.y - (1 - pop.life) * 22,
          13,
          g.multiplier > 1 ? '#ffe467' : '#fff',
        );
      if (g.boss) {
        const b = g.boss,
          def = BOSSES.find((d) => d.id === b.bossId);
        c.fillStyle = '#070c0dda';
        c.fillRect(10, 5, W - 20, 26);
        this.text(b.name + '  /  ' + b.stage + ' OF ' + b.stages, W / 2, 16, 10, def.accent);
        c.fillStyle = '#333';
        c.fillRect(17, 22, W - 34, 4);
        const hp = Math.max(0, b.hp / b.maxHp);
        if (!this.bossHealth || this.bossHealth.id !== b.id || hp > this.bossHealth.hp)
          this.bossHealth = {id: b.id, hp, trail: hp, at: g.t, time: g.t};
        const health = this.bossHealth;
        if (hp < health.hp) { health.hp = hp; health.at = g.t; }
        if (g.t - health.at > 0.18 || this.reduced)
          health.trail = this.reduced ? hp : hp + (health.trail - hp) * Math.exp(-Math.max(0, g.t - health.time) * 8);
        health.time = g.t;
        c.fillStyle = '#fff0bd';
        c.fillRect(17, 22, (W - 34) * health.trail, 4);
        c.fillStyle = def.accent;
        c.fillRect(17, 22, (W - 34) * hp, 4);
      }
      if (g.active && !g.over && !g.scene && (p.lives <= 1 || g.breaches >= 8)) {
        c.strokeStyle = p.lives <= 1 ? '#ff6666' : '#ffbf68';
        c.globalAlpha = this.reduced ? 0.5 : 0.38 + Math.sin(g.t * 3) * 0.12;
        c.lineWidth = 2;
        c.strokeRect(1, 1, W - 2, H - 2);
        c.globalAlpha = 1;
      }
      if (g.bannerLeft > 0 && !g.scene) {
        c.fillStyle = '#08100dcc';
        c.fillRect(26, 47, W - 52, 28);
        this.text(g.banner, W / 2, 66, 16, '#f5da98');
      }
      c.restore();
    }

    drawBackdrop(map) {
      const im = this.images[map.file];
      if (!im?.complete || !im.naturalWidth) {
        this.c.fillStyle = '#141b19'; this.c.fillRect(0, 0, W, H); return;
      }
      if (!this.backdrop || this.backdrop.file !== map.file) {
        const canvas = document.createElement('canvas');
        canvas.width = this.canvas.width; canvas.height = this.canvas.height;
        const c = canvas.getContext('2d', {alpha: false});
        c.setTransform(canvas.width / W, 0, 0, canvas.height / H, 0, 0);
        c.imageSmoothingQuality = 'high';
        const k = Math.max(W / im.naturalWidth, H / im.naturalHeight);
        c.drawImage(im, (W - im.naturalWidth * k) / 2, (H - im.naturalHeight * k) / 2,
          im.naturalWidth * k, im.naturalHeight * k);
        c.fillStyle = '#07110c08'; c.fillRect(0, 0, W, H);
        this.backdrop = {file: map.file, canvas};
      }
      this.c.drawImage(this.backdrop.canvas, 0, 0, W, H);
    }
    drawDiscoFloor(g, map, opens) {
      const tick = Math.floor(g.t * (this.light ? 15 : 30));
      if (!this.floorLayer) {
        const canvas = document.createElement('canvas');
        canvas.width = this.canvas.width; canvas.height = this.canvas.height;
        this.floorLayer = {canvas, tick: -1};
      }
      const layer = this.floorLayer;
      if (layer.tick !== tick) {
        const main = this.c, c = layer.canvas.getContext('2d');
        c.setTransform(layer.canvas.width / W, 0, 0, layer.canvas.height / H, 0, 0);
        c.clearRect(0, 0, W, H);
        this.c = c;
        try { this.discoFloor(g, map, opens); } finally { this.c = main; }
        layer.tick = tick;
      }
      this.c.drawImage(layer.canvas, 0, 0, W, H);
    }

    // Vector gold heart: the artwork only has a red one, and canvas filters are not reliable on iPhone.
    goldHeart(x, y, k = 1) {
      const c = this.c;
      c.save();
      c.translate(x, y + 1);
      c.scale(k, k);
      c.beginPath();
      c.moveTo(0, 9);
      c.bezierCurveTo(-15, -1, -10, -12, 0, -5);
      c.bezierCurveTo(10, -12, 15, -1, 0, 9);
      c.closePath();
      const g = c.createLinearGradient(-9, -10, 9, 10);
      g.addColorStop(0, '#fff3a6');
      g.addColorStop(0.45, '#ffc93c');
      g.addColorStop(1, '#c47a10');
      c.fillStyle = g;
      c.shadowColor = '#ffb300';
      c.shadowBlur = 8;
      c.fill();
      c.shadowBlur = 0;
      c.lineWidth = 1.2;
      c.strokeStyle = '#7a4a08';
      c.stroke();
      c.fillStyle = '#fffbe0cc';
      c.beginPath();
      c.ellipse(-4.6, -4.2, 2.6, 1.6, -0.6, 0, Math.PI * 2);
      c.fill();
      c.restore();
    }
    barrel(b) {
      if (!b || b.dead) return;
      const c = this.c,
        w = b.thrown ? BARREL.throwWidth : BARREL.width,
        h = b.thrown ? BARREL.throwHeight : BARREL.height;
      c.save();
      if (b.thrown) {
        // A fixed landing mark makes the faster throw readable; it never follows Joey.
        if (Number.isFinite(b.tx) && Number.isFinite(b.ty)) {
          c.strokeStyle = '#ffb36ba8';
          c.lineWidth = 1.4;
          c.setLineDash([4, 4]);
          c.beginPath();
          c.ellipse(b.tx, b.ty, BARREL.throwBlast, 12, 0, 0, Math.PI * 2);
          c.stroke();
          c.setLineDash([]);
          c.beginPath();
          c.moveTo(b.tx - 5, b.ty - 5);
          c.lineTo(b.tx + 5, b.ty + 5);
          c.moveTo(b.tx + 5, b.ty - 5);
          c.lineTo(b.tx - 5, b.ty + 5);
          c.stroke();
        }
        c.translate(b.x, b.y);
        c.rotate(b.rot);
        this.fit('prop-barrel.webp', -w / 2, -h / 2, w, h);
      } else {
        c.fillStyle = '#0007';
        c.beginPath();
        c.ellipse(b.x, b.y + h * 0.4, w * 0.42, 5, 0, 0, Math.PI * 2);
        c.fill();
        this.fit('prop-barrel.webp', b.x - w / 2, b.y - h / 2, w, h);
      }
      c.restore();
    }
    // Neon Palace: the painted floor's own tile grid is lit in three colour schemes, tiles black out where zombies
    // rise, and spotlights, chase lights and a gentle strobe keep the room moving.
    discoFloor(g, map, opens) {
      const c = this.c, { cols, rows, pts } = map.tileGrid, P = (r, k) => pts[r * (cols + 1) + k];
      const t = this.reduced ? 0 : g.t, phase = Math.floor(t / 3) % 3;
      const schemes = [[320, 185], [42, 280], [130, 215]], beat = (t * 2) % 1;
      c.save();
      for (let row = 0; row < rows; row++)
        for (let col = 0; col < cols; col++) {
          const a = P(row, col), b = P(row, col + 1), d = P(row + 1, col + 1), e = P(row + 1, col);
          const cx = (a[0] + b[0] + d[0] + e[0]) / 4, cy = (a[1] + b[1] + d[1] + e[1]) / 4;
          const dark = opens.reduce((m, o) => Math.abs(o.x - cx) < 2 && Math.abs(o.y - (cy - 12)) < 2 ? Math.max(m, o.age < 1.5 ? 1 : Math.max(0, 1 - (o.age - 1.5) / 0.5)) : m, 0);
          const hue = schemes[phase][(row + col + Math.floor(t / 1.5)) % 2];
          const pulse = this.reduced ? 0.5 : 0.5 + 0.5 * Math.sin(t * 2.4 + row * 0.9 + col * 1.7);
          const chase = this.reduced ? 0 : Math.max(0, 1 - Math.abs(((t * 1.1) % (rows + 2)) - row - 1) * 0.9) * 0.14;
          const poly = (inset) => {
            c.beginPath();
            c.moveTo(a[0] + inset, a[1] + inset); c.lineTo(b[0] - inset, b[1] + inset);
            c.lineTo(d[0] - inset, d[1] - inset); c.lineTo(e[0] + inset, e[1] - inset); c.closePath();
          };
          poly(1.2);
          c.fillStyle = `hsla(${hue},100%,${58 + pulse * 12}%,${0.25 + pulse * 0.13 + chase})`;
          c.fill();
          if (dark > 0) { poly(0.6); c.fillStyle = `rgba(3,0,8,${0.95 * dark})`; c.fill(); }
        }
      if (!this.reduced) {
        c.globalCompositeOperation = 'lighter';
        // Four sweeping spotlights from the top corners and the sides.
        const beams = [[18, 20, 0], [W - 18, 20, 1.6], [0, 200, 3.1], [W, 200, 4.7]];
        beams.forEach(([bx, by, ph], i) => {
          const ang = Math.PI / 2 + Math.sin(t * 0.9 + ph) * 0.75 * (bx < W / 2 ? 1 : -1) * (i > 1 ? 0.8 : 1);
          const hue = (t * 40 + i * 90) % 360, len = 360, spread = 0.11;
          const g2 = c.createRadialGradient(bx, by, 0, bx, by, len);
          g2.addColorStop(0, `hsla(${hue},100%,70%,0.34)`);
          g2.addColorStop(1, `hsla(${hue},100%,60%,0)`);
          c.fillStyle = g2;
          c.beginPath(); c.moveTo(bx, by);
          c.lineTo(bx + Math.cos(ang - spread) * len, by + Math.sin(ang - spread) * len);
          c.lineTo(bx + Math.cos(ang + spread) * len, by + Math.sin(ang + spread) * len);
          c.closePath(); c.fill();
        });
        // Chase lights down both sides, flashing on the beat.
        for (let i = 0; i < 9; i++) {
          const on = (Math.floor(t * 4) + i) % 3 === 0, y = 60 + i * 38;
          for (const x of [7, W - 7]) {
            c.fillStyle = `hsla(${(i * 40 + t * 60) % 360},100%,65%,${on ? 0.55 + 0.35 * (1 - beat) : 0.12})`;
            c.beginPath(); c.arc(x, y, on ? 4.5 : 3, 0, Math.PI * 2); c.fill();
          }
        }

      }
      c.restore();
    }
    arenaAtmosphere(g, map) {
      const c=this.c,index=ZSData.mapIndex(g.wave),t=this.reduced?0:g.t;
      c.save();
      // Activity stays at the perimeter so projectiles and targets remain readable.
      if(index===0 || index===2) {
        for(let i=0;i<10;i++) {
          const side=i%2?W-25:25,y=65+((i*37-t*(index===0?14:5))%260+260)%260;
          c.fillStyle=index===0?'#ffc27866':'#ffe8ae44';
          c.fillRect(side+Math.sin(i+t*.6)*6,y,index===0?2:1.5,2);
        }
      } else if(index===3) {
        c.strokeStyle='#fff5dd44';c.lineWidth=2;
        for(const x of [27,W-27]) for(let i=0;i<3;i++) {
          const y=100+i*80; c.beginPath();c.moveTo(x,y+18);c.bezierCurveTo(x+9*Math.sin(t*.7+i),y+9,x-6,y,x,y-10);c.stroke();
        }
      } else if(index!==4) {
        const alpha=this.reduced ? .25 : .2+.14*(.5+.5*Math.sin(t*1.1));
        c.globalAlpha=alpha;c.fillStyle=map.accent;
        for(const x of [22,W-22])for(let i=0;i<4;i++){c.beginPath();c.arc(x,90+i*70,4,0,Math.PI*2);c.fill();}
      }
      c.restore();
    }
    enemy(z, g) {
      if (z.dead) return;
      const c = this.c,
        def = z.boss ? BOSSES.find((b) => b.id === z.bossId) : null,
        h = z.boss ? (z.bossId === 'drmantis' && z.stage === 3 ? 139 : 113) : z.height,
        w = z.boss ? 130 : h * 0.82;
      c.save();
      if(!z.boss && z.emerge>0) {
        c.globalAlpha = 1-z.emerge/0.45;
        c.beginPath();c.rect(0,z.y-h*.55*(1-z.emerge/0.45),W,H);c.clip();
      }
      c.fillStyle = '#0006';
      c.beginPath();
      c.ellipse(z.x, z.y + h * 0.34, w * 0.29, 5, 0, 0, Math.PI * 2);
      c.fill();
      if (z.charge === 1) {
        c.strokeStyle = '#fa994d';
        c.lineWidth = 1.5;
        c.beginPath();
        c.arc(z.x, z.y, w * 0.5, 0, Math.PI * 2);
        c.stroke();
      }
      if (z.boss && z.wind) {
        this.text('ATTACK!', z.x, z.y - h * 0.62 - 5, 9, '#ffb04c');
      }
      const wobble = this.reduced ? 0 : Math.sin(z.age * (z.type === 'runner' ? 16 : 8)) * 1.4,
        art = def
          ? def.sprites[z.stage - 1]
          : z.type === 'helmet' && z.hp < 2.2
            ? 'zombie-normal.webp'
            : z.art;
      const jx = z.shake ? Math.sin(z.age * 70) * 2.6 : 0;
      if (z.mode === 'shake') {
        c.save();
        c.setLineDash([6, 5]);
        c.strokeStyle = '#ff5a4acc';
        c.lineWidth = 2;
        c.beginPath();
        c.moveTo(z.x, z.y);
        c.lineTo(g.player.x, g.player.y);
        c.stroke();
        c.restore();
      }
      const lean = z.boss && !this.reduced ? clamp((z.vx || 0) / 1100, -0.13, 0.13) : 0,
        hover =
          z.boss && !this.reduced && !(z.mode || '').startsWith('c')
            ? Math.sin(z.age * 2.4) * 2.4
            : 0;
      this.fit(art, z.x - w / 2 + jx, z.y - h * 0.55 + wobble + hover, w, h, {
        bright: z.flash > 0,
        rot: lean,
        rim: !z.boss && g.enemies.length <= 8,
      });
      if (z.type === 'bulwark' && z.age % 3.5 < 2) {
        c.strokeStyle = '#82dffeaa';
        c.lineWidth = 2;
        c.beginPath();
        c.arc(z.x, z.y + 2, 23, 0.1, Math.PI - 0.1);
        c.stroke();
      }
      if (!z.boss && z.maxHp > 2 && z.hp < z.maxHp) {
        c.fillStyle = '#080808';
        c.fillRect(z.x - 20, z.y - h * 0.58 - 3, 40, 3);
        c.fillStyle = '#ddb969';
        c.fillRect(z.x - 20, z.y - h * 0.58 - 3, (40 * z.hp) / z.maxHp, 3);
      }
      c.restore();
    }
    shot(s) {
      if(s.kind==='record') {
        const c=this.c; c.save();c.translate(s.x,s.y);c.rotate(this.reduced?0:(s.age||0)*7);
        c.fillStyle='#15131c';c.strokeStyle='#cab5e4';c.lineWidth=1.2;
        c.beginPath();c.arc(0,0,12,0,Math.PI*2);c.fill();c.stroke();
        c.strokeStyle='#62586e';for(const r of [7,9]){c.beginPath();c.arc(0,0,r,0,Math.PI*2);c.stroke();}
        c.fillStyle='#ff6bc8';c.beginPath();c.arc(0,0,4.5,0,Math.PI*2);c.fill();
        c.fillStyle='#fff';c.fillRect(-1,-1,2,2);c.restore();return;
      }
      const c = this.c;
      if (s.kind === 'chain') {
        if (s.age < s.wind) {
          c.save();
          c.setLineDash([5, 5]);
          c.strokeStyle = '#ffd26877';
          c.beginPath();
          c.moveTo(s.ox, s.oy);
          c.lineTo(s.ox + s.dx * s.reach, s.oy + s.dy * s.reach);
          c.stroke();
          c.restore();
          return;
        }
        const length = Math.hypot(s.x - s.ox, s.y - s.oy);
        for (let d = 0; d < length; d += 10) {
          const q = d / length,
            x = s.ox + (s.x - s.ox) * q,
            y = s.oy + (s.y - s.oy) * q;
          c.save();
          c.translate(x, y);
          c.rotate(Math.atan2(s.dy, s.dx));
          c.strokeStyle = d % 20 ? '#fff0ac' : '#a97520';
          c.lineWidth = 2;
          c.beginPath();
          c.ellipse(0, 0, 6, 3, 0, 0, Math.PI * 2);
          c.stroke();
          c.restore();
        }
        this.fit('weapon-chain.webp', s.x - 22, s.y - 22, 44, 44);
        return;
      }
      c.save();
      c.translate(s.x, s.y);
      if (s.kind === 'missile') c.rotate(Math.atan2(s.vy, s.vx) + Math.PI / 4);
      else
        c.rotate(
          s.age * ({ disco: 3, handcuffs: 5, glowstick: 5, tea: 4, bodypart: 3.5 }[s.kind] || 1.7),
        );
      {
        const k = s.kind === 'glowstick' ? 1.6 : 1,
          f =
            s.kind === 'glowstick'
              ? 'weapon-glowstick-' + (s.color || 'green') + '.webp'
              : 'weapon-' + s.kind + '.webp';
        this.fit(f, -s.r * 1.4 * k, -s.r * 1.4 * k, s.r * 2.8 * k, s.r * 2.8 * k);
      }
      c.restore();
    }
  }
  window.ZSRenderer = Renderer;
  window.ZSRenderer.assets = [...new Set(files)];
})();
