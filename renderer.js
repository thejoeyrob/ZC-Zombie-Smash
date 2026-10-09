(() => {
  'use strict';
  const { W, H, BOSSES, MAPS } = ZSData,
    { ENEMIES, GUNS, BARREL, clamp } = ZSEngine;
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
      'tea',
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
      this.reduced = matchMedia('(prefers-reduced-motion:reduce)').matches;
      this.resize();
    }
    resize() {
      const dpr = Math.min(3, devicePixelRatio || 1),
        r = this.canvas.getBoundingClientRect(),
        scale = Math.max(0.5, r.width / W);
      this.canvas.width = Math.max(1, Math.round(W * dpr * scale));
      this.canvas.height = Math.max(1, Math.round(H * dpr * scale));
      this.c.setTransform(this.canvas.width / W, 0, 0, this.canvas.height / H, 0, 0);
      this.c.imageSmoothingEnabled = true;
      this.c.imageSmoothingQuality = 'high';
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
    }
    fit(file, x, y, w, h, { alpha = 1, flip = false, bright = false } = {}) {
      const im = this.images[file];
      if (!im?.complete || !im.naturalWidth) return;
      const c = this.c,
        b = this.bounds[file] || [0, 0, im.naturalWidth, im.naturalHeight],
        scale = Math.min(w / b[2], h / b[3]),
        dw = b[2] * scale,
        dh = b[3] * scale;
      c.save();
      c.globalAlpha = alpha;
      if (bright) c.filter = 'brightness(1.7)';
      c.translate(x + w / 2, y + h / 2);
      if (flip) c.scale(-1, 1);
      c.drawImage(im, ...b, -dw / 2, -dh / 2, dw, dh);
      c.restore();
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
      c.clearRect(0, 0, W, H);
      c.fillStyle = '#141b19';
      c.fillRect(0, 0, W, H);
      const map = MAPS[Math.min(6, Math.floor((g.wave - 1) / 2))],
        im = this.images[map.file];
      if (im?.complete && im.naturalWidth) {
        const k = Math.max(W / im.naturalWidth, H / im.naturalHeight);
        c.drawImage(
          im,
          (W - im.naturalWidth * k) / 2,
          (H - im.naturalHeight * k) / 2,
          im.naturalWidth * k,
          im.naturalHeight * k,
        );
      }
      c.fillStyle = '#07110c24';
      c.fillRect(0, 0, W, H);
      if (g.shake && !this.reduced)
        c.translate(Math.sin(g.t * 93) * g.shake, Math.cos(g.t * 111) * g.shake * 0.55);
      const haze = c.createLinearGradient(0, 0, 0, 55);
      haze.addColorStop(0, '#050908a0');
      haze.addColorStop(1, '#05090800');
      c.fillStyle = haze;
      c.fillRect(0, 0, W, 55);
      c.strokeStyle = '#89baa52b';
      c.setLineDash([4, 5]);
      c.beginPath();
      c.moveTo(0, H - 38);
      c.lineTo(W, H - 38);
      c.stroke();
      c.setLineDash([]);
      for (const item of g.pickups) {
        if (item.life < 2 && Math.floor(item.age * 9) % 2) continue;
        const x = item.x,
          y = item.y + Math.sin(item.age * 5) * 2;
        c.fillStyle = '#6bbfe52a';
        c.beginPath();
        c.arc(x, y, 16, 0, Math.PI * 2);
        c.fill();
        c.strokeStyle = item.type === 'heart' ? '#ff6d7a' : '#84d7f4';
        c.lineWidth = 1;
        c.stroke();
        const art =
          { shotgun: 'pickup-smg.webp', burst: 'pickup-dmr.webp', grenade: 'pickup-bomb.webp' }[
            item.type
          ] || 'pickup-' + item.type + '.webp';
        this.fit(art, x - 12, y - 12, 24, 24);
      }
      for (const barrel of g.barrels || []) this.barrel(barrel);
      for (const z of [...g.enemies, ...(g.boss ? [g.boss] : [])].sort((a, b) => a.y - b.y))
        this.enemy(z, g);
      for (const b of g.bullets) {
        c.save();
        c.translate(b.x, b.y);
        c.rotate(Math.atan2(b.vy, b.vx) + Math.PI / 6);
        this.fit(GUNS[b.gun].art, -11, -7.5, 22, 15);
        c.restore();
      }
      for (const s of g.shots) this.shot(s, g);
      const p = g.player;
      if (!g.over) {
        c.fillStyle = '#0007';
        c.beginPath();
        c.ellipse(p.x, p.y + 30, 28, 7, 0, 0, Math.PI * 2);
        c.fill();
        if (p.shield > 0 || g.invincible) {
          c.strokeStyle = '#8bdffc';
          c.lineWidth = 2;
          c.beginPath();
          c.ellipse(p.x, p.y - 6, 38, 46, 0, 0, Math.PI * 2);
          c.stroke();
        }
        const bob = this.reduced ? 0 : Math.abs(g.input.axis) > 0.1 ? Math.sin(g.t * 18) * 1.2 : 0;
        const art =
          p.inv > 0 && p.inv < 1.2
            ? 'player-hit.webp'
            : p.fireFx > 0
              ? 'player-fire.webp'
              : 'player-transparent.webp';
        this.fit(art, p.x - 35, p.y - 55 + bob, 70, 91, {
          alpha: p.inv > 0 && Math.floor(g.t * 12) % 2 ? 0.58 : 1,
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
      for (const f of g.effects) {
        c.save();
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
        c.restore();
      }
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
        c.fillStyle = def.accent;
        c.fillRect(17, 22, (W - 34) * Math.max(0, b.hp / b.maxHp), 4);
      }
      if (g.bannerLeft > 0 && !g.scene) {
        c.fillStyle = '#08100dcc';
        c.fillRect(26, 47, W - 52, 28);
        this.text(g.banner, W / 2, 66, 16, '#f5da98');
      }
      if (g.practice) this.text('PRACTICE · SCORES OFF', W / 2, H - 8, 10, '#ffc16e');
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
          c.ellipse(b.tx, b.ty, ZSData.W * 0.1, 9, 0, 0, Math.PI * 2);
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
    enemy(z, g) {
      if (z.dead) return;
      const c = this.c,
        def = z.boss ? BOSSES.find((b) => b.id === z.bossId) : null,
        h = z.boss ? (z.bossId === 'drmantis' && z.stage === 3 ? 139 : 113) : z.height,
        w = z.boss ? 130 : h * 0.82;
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
      this.fit(art, z.x - w / 2 + jx, z.y - h * 0.55 + wobble, w, h, { bright: z.flash > 0 });
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
    }
    shot(s) {
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
