(() => {
  'use strict';
  // The packaged iPhone app loads from capacitor://; on the web we keep the install and admin tools.
  const nativeApp = location.protocol === 'capacitor:' || !!window.Capacitor?.isNativePlatform?.();
  const newId = () =>
    crypto.randomUUID?.() ??
    '10000000-1000-4000-8000-100000000000'.replace(/[018]/g, (c) =>
      (c ^ (crypto.getRandomValues(new Uint8Array(1))[0] & (15 >> (c / 4)))).toString(16),
    );
  const $ = (id) => document.getElementById(id),
    esc = (s) =>
      String(s ?? '').replace(
        /[&<>"']/g,
        (c) =>
          ({
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;',
          })[c],
      );
  const read = (k, f) => {
      try {
        return JSON.parse(localStorage.getItem(k)) ?? f;
      } catch {
        return f;
      }
    },
    write = (k, v) => {
      try {
        localStorage.setItem(k, JSON.stringify(v));
      } catch {}
    };
  const { BOSSES, SKINS, MAPS } = ZSData,
    audio = new ZSAudio(),
    haptics = new ZSHaptics(),
    scores = new ZSScores(),
    renderer = new ZSRenderer($('gameCanvas'));
  const APP_VER =
    (document.querySelector('script[src*="game.js"]')?.src.match(/[?&]v=([\d.]+)/) || [])[1] || '';
  // Finished scene clips and extra console skins are listed by scripts/sync-art.mjs.
  // A scene with no listed clip, or a clip that fails to load, uses the built-in scene.
  let sceneClips = {};
  let soundPreview = 0;
  const failedClips = new Set();
  fetch('./scene-clips.json')
    .then((r) => r.json())
    .then((j) => {
      sceneClips = j.clips || {};
    })
    .catch(() => {});
  let pendingReload = false;
  function reloadWhenSafe() {
    if (!pendingReload || (typeof game !== 'undefined' && game.active && !paused)) return;
    pendingReload = false;
    location.reload();
  }
  // BOT_ before a player name switches on cheat mode: it is never shown, it dispenses the secret skins
  // and it opens the CHEATS menu, where every cheat has a code made of joystick flicks and button taps.
  const BOT_PREFIX = /^bot_/i;
  const parseName = (raw) => {
    raw = String(raw ?? '').trim();
    const isBot = BOT_PREFIX.test(raw);
    return {
      bot: isBot,
      name: isBot ? raw.replace(BOT_PREFIX, '').trim() : raw,
    };
  };
  const unlockedSkins = () => new Set(read('zs7-unlocked', []));
  const beatenBosses = () => new Set(read('zs7-beaten', []));
  // Character skins unlock when their boss is beaten; secret custom skins unlock through BOT mode.
  const skinLocked = (skin) =>
    skin.boss
      ? !beatenBosses().has(skin.boss) && !unlockedSkins().has(skin.id)
      : !!skin.secret && !unlockedSkins().has(skin.id);
  const lockText = (skin) => {
    const boss = BOSSES.find((b) => b.id === skin.boss);
    return boss
      ? `${skin.name} skin needs to be unlocked. Beat ${boss.name} first.`
      : `${skin.name} skin needs to be unlocked. It is a secret finish.`;
  };
  function unlockSecretSkins() {
    const have = unlockedSkins();
    let added = 0;
    for (const s of SKINS)
      if ((s.secret || s.boss) && !have.has(s.id)) {
        have.add(s.id);
        added++;
      }
    write('zs7-unlocked', [...have]);
    return added;
  }
  let bot = false,
    pendingBot = false,
    cheatBuf = '',
    cheatLast = 0,
    stickDir = 0;
  let ready = false,
    paused = true,
    landscape = false,
    admin = false,
    run = null,
    pendingName = '',
    sceneKey = '',
    panel = '',
    lastTime = 0,
    accumulator = 0,
    saveClock = 0,
    toastTimer,
    installPrompt,
    lastFit = '';
  let storyStep = 0,
    storyTimer = null,
    storyVideo = null,
    storyReplay = false;
  let stickOrigin = null,
    touchAxis = 0,
    touchFire = false,
    stickId = null,
    fireId = null,
    keys = new Set(),
    padGrenade = false;
  const game = new ZSEngine.Game({ onEvent: event });
  function toast(message) {
    $('toast').textContent = message;
    $('toast').hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => ($('toast').hidden = true), 3100);
  }
  function clearInput() {
    flickUntil = 0;
    stickOrigin = null;
    touchAxis = 0;
    touchFire = false;
    stickId = null;
    fireId = null;
    keys.clear();
    stickDir = 0;
    game.resetInput();
    $('stickKnob').style.transform = 'translateX(0)';
    $('fireButton').classList.remove('pressed');
    $('joystick').setAttribute('aria-valuenow', '0');
  }
  function save() {
    if (run && game.active && !game.over)
      write('zs7-run', {
        engine: game.snapshot(),
        run: { id: run.id, name: run.name, ticket: run.ticket, bot, cheated: !!run.cheated },
      });
    else if (game.over)
      try {
        localStorage.removeItem('zs7-run');
      } catch {}
  }
  function pause(immediate = false) {
    paused = true;
    clearInput();
    audio.pause(immediate);
    $('cinematic').querySelector('video')?.pause();
    $('cinematic').classList.add('motion-paused');
    save();
    reloadWhenSafe();
  }
  // The music for a boss fight: Debo and Disco Man have their own themes.
  const bossTrack = (id) => (id === 'debo' ? 'debo' : id === 'discoman' ? 'disco' : 'boss');
  function resume() {
    if (!game.active || game.over || landscape) return;
    paused = false;
    $('cinematic').classList.remove('motion-paused');
    accumulator = 0;
    lastTime = performance.now();
    audio.resume();
    audio.playMusic(
      game.boss?.bossId === 'debo' || (game.scene?.bossId === 'debo' && game.scene.phase >= 2)
        ? 'debo'
        : game.scene?.kind === 'arrival'
          ? 'entrance'
          : game.boss
            ? bossTrack(game.boss.bossId)
            : game.scene?.bossId === 'debo' && game.scene.phase >= 2
              ? 'debo'
              : 'main',
    );
  }
  function closePanel() {
    soundPreview++;
    endPreview();
    // The menu was opened during the story: carry on with the clip that was playing.
    if (storyActive && panel !== 'story') {
      panel = '';
      showStory(pendingName, storyStep);
      return;
    }
    panel = '';
    $('overlay').hidden = true;
    clearInput();
    if (game.active && !game.over) {
      if (!awaitStart) resume();
    } else showStart();
    $('menuButton').focus({ preventScroll: true });
  }
  function showPanel(kind, title, html, { closable = true, start = false } = {}) {
    soundPreview++;
    if (kind !== 'skins') endPreview();
    clearTimeout(storyTimer);
    pause();
    panel = kind;
    const box = $('overlay');
    box.classList.remove('story-mode');
    box.hidden = false;
    box.innerHTML =
      (title
        ? `<div class="panel-head"><h2>${esc(title)}</h2>${closable ? '<button data-action="close" aria-label="Close panel">×</button>' : ''}</div>`
        : '') + `<div class="panel-content ${start ? 'start-panel' : ''}">${html}</div>`;
  }
  function showStart() {
    storyActive = false;
    $('fireButton')?.classList.remove('story-hint');
    awaitStart = false;
    $('startPrompt').hidden = true;
    const name = read('zs7-name', ''),
      saved = read('zs7-run', null),
      hi = Object.entries(scores.best || {}).sort((a, b) => b[1] - a[1])[0] || ['', 0],
      beaten = beatenBosses();
    showPanel(
      'start',
      '',
      `<div class="title-screen"><div class="title-art" aria-hidden="true"></div><i class="title-glow" aria-hidden="true"></i><i class="title-fire" aria-hidden="true"></i><canvas id="titleFx" aria-hidden="true"></canvas><i class="title-shine" aria-hidden="true"></i><div class="title-ui"><div class="title-top"><div class="title-hi"><span>1UP <b>${esc(parseName(name).name || '---')}</b></span><span>HI <b>${Number(hi[1]).toLocaleString()}</b> ${esc(hi[0].toUpperCase())}</span></div><h1 class="title-logo" aria-label="Zombie Smash"><span class="tl-1" aria-hidden="true">${[...'ZOMBIE'].map((ch, i) => `<i class="l" style="--i:${i}">${ch}</i>`).join('')}</span><span class="tl-2" aria-hidden="true">${[...'SMASH'].map((ch, i) => `<i class="l" style="--i:${i + 6}">${ch}</i>`).join('')}</span></h1><div class="title-tag">HOLD THE LINE</div></div><div class="title-bottom"><form id="startForm"><label class="name-field">PLAYER NAME<input name="username" id="username" value="${esc(name)}" maxlength="24" minlength="2" autocomplete="off" autocorrect="off" autocapitalize="none" spellcheck="false" placeholder="ENTER NAME" required></label><button class="primary-action press-start" id="startButton" ${ready ? '' : 'disabled'}>${ready ? '▶ PRESS START ◀' : 'LOADING THE HORDE…'}</button></form>${saved?.engine?.active ? `<button class="secondary-action title-continue" data-action="continue">CONTINUE ${esc(saved.run?.name)} · WAVE ${saved.engine.wave}</button>` : ''}<div class="title-bosses" aria-label="Bosses defeated">${BOSSES.map((b) => `<span class="tb ${beaten.has(b.id) ? 'down' : ''}" style="--c:${b.accent}"><img src="./${b.sprites[0]}" alt="${esc(b.name)}"></span>`).join('')}</div><div class="title-count">${beaten.size} OF ${BOSSES.length} BOSSES DOWN</div><div class="loading-line" id="loadingLine">${ready ? 'NO LOGIN · NO ADS · V' + APP_VER : 'Loading game artwork…'}</div></div></div></div>`,
      { start: true, closable: false },
    );
    titleEmbers();
  }
  // Embers drifting up the title art. Runs only while the title screen is on show.
  function titleEmbers() {
    const cv = $('titleFx');
    if (!cv || matchMedia('(prefers-reduced-motion:reduce)').matches) return;
    const rect = cv.getBoundingClientRect(),
      dpr = Math.min(2, devicePixelRatio || 1),
      w = (cv.width = Math.max(1, Math.round(rect.width * dpr))),
      h = (cv.height = Math.max(1, Math.round(rect.height * dpr))),
      c = cv.getContext('2d'),
      mk = (fresh) => ({
        x: Math.random() * w,
        y: fresh ? h + Math.random() * 40 : Math.random() * h,
        r: (0.8 + Math.random() * 1.8) * dpr,
        v: (14 + Math.random() * 38) * dpr,
        a: Math.random() * 6.28,
        s: 0.6 + Math.random() * 1.6,
        hue: 18 + Math.random() * 28,
      }),
      sparks = Array.from({ length: 46 }, () => mk(false));
    let last = performance.now();
    const loop = (now) => {
      if (!cv.isConnected) return;
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      c.clearRect(0, 0, w, h);
      c.globalCompositeOperation = 'lighter';
      for (const p of sparks) {
        p.y -= p.v * dt;
        p.a += p.s * dt;
        p.x += Math.sin(p.a) * 12 * dpr * dt;
        if (p.y < -10) Object.assign(p, mk(true));
        const fade = Math.min(1, p.y / (h * 0.5)),
          g = c.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.r * 4);
        g.addColorStop(0, `hsla(${p.hue},100%,70%,${0.85 * fade})`);
        g.addColorStop(1, `hsla(${p.hue},100%,50%,0)`);
        c.fillStyle = g;
        c.beginPath();
        c.arc(p.x, p.y, p.r * 4, 0, 6.28);
        c.fill();
      }
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }
  // Retro attract mode: a low-resolution canvas scaled up with hard pixels. Joey shoots zombies down a street under a red moon.
  let titleBounds = null;
  function titleScene() {
    const cv = $('titleCanvas');
    if (!cv) return;
    const rect = cv.getBoundingClientRect(),
      W = 150,
      H = Math.max(180, Math.round((W * rect.height) / Math.max(1, rect.width)));
    cv.width = W;
    cv.height = H;
    const c = cv.getContext('2d');
    c.imageSmoothingEnabled = false;
    const reduced = matchMedia('(prefers-reduced-motion:reduce)').matches,
      imgs = {},
      names = [
        'player-transparent',
        'zombie-normal',
        'zombie-runner',
        'zombie-helmet',
        'zombie-toxic',
        'zombie-brute',
        'bullet-pistol',
      ];
    for (const n of names) {
      const im = new Image();
      im.src = './' + n + '.webp';
      imgs[n] = im;
    }
    if (!titleBounds)
      fetch('./art-bounds.json')
        .then((r) => r.json())
        .then((b) => {
          titleBounds = b;
        })
        .catch(() => {
          titleBounds = {};
        });
    const hz = Math.round(H * 0.31),
      stars = Array.from({ length: 42 }, () => [
        Math.random() * W,
        Math.random() * hz * 0.9,
        Math.random() * 6,
      ]),
      city = (minH, maxH, minW, maxW) => {
        const a = [];
        let x = -6;
        while (x < W + 20) {
          const w = minW + Math.random() * (maxW - minW);
          a.push([x, w, minH + Math.random() * (maxH - minH), Math.random()]);
          x += w + Math.random() * 2;
        }
        return a;
      },
      far = city(10, 30, 8, 16),
      near = city(6, 22, 10, 20);
    const sprite = (n, cx, base, h, flash) => {
      const im = imgs[n];
      if (!im || !im.complete || !im.naturalWidth) return;
      const b = (titleBounds && titleBounds[n + '.webp']) || [
          0,
          0,
          im.naturalWidth,
          im.naturalHeight,
        ],
        s = h / b[3],
        w = b[2] * s;
      c.drawImage(
        im,
        b[0],
        b[1],
        b[2],
        b[3],
        Math.round(cx - w / 2),
        Math.round(base - h),
        Math.round(w),
        Math.round(h),
      );
      if (flash) {
        c.globalCompositeOperation = 'lighter';
        c.globalAlpha = 0.7;
        c.drawImage(
          im,
          b[0],
          b[1],
          b[2],
          b[3],
          Math.round(cx - w / 2),
          Math.round(base - h),
          Math.round(w),
          Math.round(h),
        );
        c.globalAlpha = 1;
        c.globalCompositeOperation = 'source-over';
      }
    };
    const kinds = [
        'zombie-normal',
        'zombie-normal',
        'zombie-runner',
        'zombie-helmet',
        'zombie-toxic',
        'zombie-brute',
      ],
      joeyBase = Math.round(H * 0.645),
      joey = { x: W / 2, cool: 0, fire: 0 },
      zs = [],
      bullets = [],
      bits = [],
      pops = [];
    let t = 0,
      spawn = 0.2,
      last = performance.now();
    const px = (x, y, w, h, col) => {
      c.fillStyle = col;
      c.fillRect(Math.round(x), Math.round(y), w, h);
    };
    function step(dt) {
      t += dt;
      spawn -= dt;
      if (spawn <= 0 && zs.length < 6) {
        spawn = 0.75 + Math.random() * 0.7;
        const k = kinds[Math.floor(Math.random() * kinds.length)];
        zs.push({
          x: 22 + Math.random() * (W - 44),
          y: hz + 2,
          k,
          hp: k === 'zombie-brute' ? 4 : k === 'zombie-helmet' ? 3 : 2,
          flash: 0,
          v: k === 'zombie-runner' ? 13 : 7 + Math.random() * 3,
        });
      }
      for (const z of zs) {
        z.y += z.v * dt;
        z.flash = Math.max(0, z.flash - dt);
      }
      const target = zs.filter((z) => z.y < joeyBase - 10).sort((a, b) => b.y - a.y)[0];
      if (target) joey.x += Math.max(-40 * dt, Math.min(40 * dt, target.x - joey.x));
      else joey.x += (W / 2 - joey.x) * Math.min(1, dt * 2);
      joey.cool -= dt;
      joey.fire = Math.max(0, joey.fire - dt);
      if (target && target.y > H * 0.44 && Math.abs(target.x - joey.x) < 5 && joey.cool <= 0) {
        joey.cool = 0.26;
        joey.fire = 0.07;
        bullets.push({ x: joey.x, y: joeyBase - 34 });
      }
      for (const b of bullets) {
        b.y -= 125 * dt;
        for (const z of zs) {
          const s = 0.42 + 0.58 * Math.min(1, (z.y - hz) / (joeyBase - hz)),
            hh = 42 * s;
          if (!z.dead && !b.dead && Math.abs(b.x - z.x) < 7 * s && b.y < z.y && b.y > z.y - hh) {
            b.dead = true;
            z.hp--;
            z.flash = 0.08;
            if (z.hp <= 0) {
              z.dead = true;
              pops.push({
                x: z.x,
                y: z.y - hh,
                life: 0.9,
                txt: '+' + (z.k === 'zombie-brute' ? 700 : z.k === 'zombie-runner' ? 180 : 120),
              });
              for (let i = 0; i < 10; i++)
                bits.push({
                  x: z.x,
                  y: z.y - hh / 2,
                  vx: (Math.random() - 0.5) * 70,
                  vy: -Math.random() * 50,
                  life: 0.5,
                  col: i % 3 ? '#9cff65' : '#fff6c0',
                });
            }
          }
        }
        if (b.y < hz - 4) b.dead = true;
      }
      for (const q of bits) {
        q.x += q.vx * dt;
        q.y += q.vy * dt;
        q.vy += 120 * dt;
        q.life -= dt;
      }
      for (const p of pops) {
        p.y -= 14 * dt;
        p.life -= dt;
      }
      for (let i = zs.length - 1; i >= 0; i--)
        if (zs[i].dead || zs[i].y > joeyBase + 4) zs.splice(i, 1);
      for (let i = bullets.length - 1; i >= 0; i--) if (bullets[i].dead) bullets.splice(i, 1);
      for (let i = bits.length - 1; i >= 0; i--) if (bits[i].life <= 0) bits.splice(i, 1);
      for (let i = pops.length - 1; i >= 0; i--) if (pops[i].life <= 0) pops.splice(i, 1);
    }
    function draw() {
      const g = c.createLinearGradient(0, 0, 0, hz);
      g.addColorStop(0, '#10061e');
      g.addColorStop(0.55, '#3a1250');
      g.addColorStop(1, '#a02a3a');
      c.fillStyle = g;
      c.fillRect(0, 0, W, hz + 1);
      for (const s of stars) if (Math.floor(t * 2 + s[2]) % 3) px(s[0], s[1], 1, 1, '#f4efd0');
      const mx = W * 0.74,
        my = hz * 0.38;
      c.fillStyle = '#ff6a4a33';
      c.beginPath();
      c.arc(mx, my, 20, 0, 7);
      c.fill();
      c.fillStyle = '#ff6a4a55';
      c.beginPath();
      c.arc(mx, my, 16, 0, 7);
      c.fill();
      c.fillStyle = '#ffd6a0';
      c.beginPath();
      c.arc(mx, my, 12, 0, 7);
      c.fill();
      px(mx - 5, my - 4, 3, 3, '#e8b27c');
      px(mx + 2, my + 2, 4, 3, '#e8b27c');
      const sky = (arr, col, sp, lit) => {
        const off = (t * sp) % 1000;
        for (const b of arr) {
          const x = ((((b[0] - off) % (W + 40)) + W + 40) % (W + 40)) - 20;
          px(x, hz - b[2], Math.round(b[1]), Math.round(b[2]), col);
          if (lit)
            for (let yy = hz - b[2] + 3; yy < hz - 3; yy += 5)
              for (let xx = x + 2; xx < x + b[1] - 2; xx += 4)
                if ((xx * 7 + yy * 13 + Math.floor(t * 1.5 + b[3] * 9)) % 7 === 0)
                  px(xx, yy, 1, 2, '#ffd25a');
        }
      };
      sky(far, '#24103a', 1.2, false);
      sky(near, '#140a24', 2.6, true);
      c.fillStyle = '#1a1222';
      c.fillRect(0, hz, W, H - hz);
      const road = c.createLinearGradient(0, hz, 0, H);
      road.addColorStop(0, '#3a1a30');
      road.addColorStop(1, '#120c18');
      c.fillStyle = road;
      c.beginPath();
      c.moveTo(W / 2 - 4, hz);
      c.lineTo(W / 2 + 4, hz);
      c.lineTo(W * 1.18, H);
      c.lineTo(-W * 0.18, H);
      c.fill();
      c.strokeStyle = '#5a3d58';
      c.lineWidth = 1;
      c.beginPath();
      c.moveTo(W / 2 - 4, hz);
      c.lineTo(-W * 0.18, H);
      c.moveTo(W / 2 + 4, hz);
      c.lineTo(W * 1.18, H);
      c.stroke();
      for (let k = 0; k < 9; k++) {
        const u = ((k + t * 0.55) % 9) / 9,
          y = hz + (H - hz) * u * u;
        px(
          W / 2 - (1 + 3 * u) / 2,
          y,
          Math.max(1, Math.round(1 + 3 * u)),
          Math.max(1, Math.round(2 + 7 * u)),
          '#d8c15a',
        );
      }
      for (const z of zs.slice().sort((a, b) => a.y - b.y)) {
        const s = 0.42 + 0.58 * Math.min(1, (z.y - hz) / (joeyBase - hz));
        c.fillStyle = '#00000066';
        c.fillRect(Math.round(z.x - 7 * s), Math.round(z.y - 1), Math.round(14 * s), 2);
        sprite(z.k, z.x + Math.sin(t * 4 + z.x) * 0.7, z.y, 42 * s, z.flash > 0);
      }
      c.fillStyle = '#00000066';
      c.fillRect(Math.round(joey.x - 9), joeyBase - 1, 18, 2);
      sprite('player-transparent', joey.x, joeyBase, 40, false);
      if (joey.fire > 0) {
        px(joey.x - 2, joeyBase - 46, 4, 5, '#fff6c0');
        px(joey.x - 1, joeyBase - 50, 2, 4, '#ffb340');
        px(joey.x - 5, joeyBase - 44, 3, 2, '#ffb340');
        px(joey.x + 2, joeyBase - 44, 3, 2, '#ffb340');
      }
      for (const b of bullets) {
        px(b.x - 1, b.y, 2, 5, '#fff6c0');
        px(b.x, b.y - 2, 1, 2, '#ffb340');
      }
      for (const q of bits) px(q.x, q.y, 2, 2, q.col);
      c.fillStyle = '#ffe094';
      c.font = 'bold 8px Barlow, sans-serif';
      c.textAlign = 'center';
      for (const p of pops) {
        c.globalAlpha = Math.min(1, p.life * 2);
        c.fillStyle = '#000';
        c.fillText(p.txt, Math.round(p.x) + 1, Math.round(p.y) + 1);
        c.fillStyle = '#ffe094';
        c.fillText(p.txt, Math.round(p.x), Math.round(p.y));
        c.globalAlpha = 1;
      }
    }
    function frame(now) {
      if (!cv.isConnected) return;
      const dt = Math.min(0.05, (now - last) / 1000 || 0);
      last = now;
      if (!document.hidden) {
        step(reduced ? 0 : dt);
        draw();
      }
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }
  function menu() {
    if (panel === 'menu') {
      closePanel();
      return;
    }
    showPanel(
      'menu',
      'GAME MENU',
      `${game.active ? '<button class="primary-action" data-action="close">RESUME GAME</button>' : '<button class="primary-action" data-action="home">PLAY ZOMBIE SMASH</button>'}<button class="menu-action" data-action="skins">CONSOLE SKINS <small>${SKINS.filter((x) => !skinLocked(x)).length} of ${SKINS.length} unlocked →</small></button>${coffeeOn() ? `<button class="menu-action" data-action="coffee">${nativeApp ? 'TIP JAR' : 'BUY ME A COFFEE'} <small>Support the developer →</small></button>` : ''}<button class="menu-action" data-action="board">HIGH SCORES <small>The leaderboard →</small></button><button class="menu-action" data-action="sound">MUSIC & SOUND <small>Set your mix →</small></button><button class="menu-action" data-action="story">THE STORY <small>Replay the comic →</small></button><button class="menu-action" data-action="help">HOW TO PLAY <small>Controls & boosts →</small></button>${nativeApp ? '' : '<button class="menu-action" data-action="install">INSTALL GAME <small>Play from Home Screen →</small></button>'}${game.active ? '<button class="menu-action" data-action="restart">NEW GAME <small>Start over as the same player →</small></button><button class="menu-action" data-action="home">HOME SCREEN <small>Back to the title →</small></button>' : ''}${bot ? '<button class="menu-action cheat-entry" data-action="cheats">CHEATS <small>BOT mode · codes →</small></button>' : ''}${nativeApp ? '' : `<button class="menu-action" data-action="admin">${admin ? 'ADMIN CONTROLS' : 'ADMIN CODE'} <small>${admin ? 'Bosses & cheats →' : 'Unlock tools →'}</small></button>`}<p class="menu-note">${run ? 'Playing as ' + esc(run.name) : 'Zombie Smash'} · v${APP_VER}<br>Portrait arcade · Joey Rob vs Dr Mantis</p>`,
    );
  }
  // A thank-you / tip screen shown after PRESS START, before the story. One switch turns it off.
  // Hidden inside the iPhone app so App Review has nothing to object to; the web version still shows it.
  // Web version: a Buy Me a Coffee link. iPhone app: an optional in-app tip jar (App Store in-app purchases), shown only
  // when the store has returned the tip products. Tips unlock nothing.
  const COFFEE_URL = 'https://buymeacoffee.com/JoeyRob',
    TIP_IDS = ['zs_tip_small', 'zs_tip_medium', 'zs_tip_large'];
  let tipProducts = [];
  let tipQty = 1;
  const tipPrice = (t, q) => {
    try {
      return new Intl.NumberFormat(undefined, { style: 'currency', currency: t.currencyCode }).format(t.price * q);
    } catch {
      return q === 1 ? t.priceString : q + ' × ' + t.priceString;
    }
  };
  const coffeeOn = () => (nativeApp ? tipProducts.length > 0 : true);
  if (nativeApp && window.Capacitor?.Plugins?.NativePurchases)
    window.Capacitor.Plugins.NativePurchases.getProducts({ productIdentifiers: TIP_IDS, productType: 'inapp' })
      .then((r) => {
        tipProducts = (r?.products || []).filter((x) => TIP_IDS.includes(x.identifier)).sort((a, b) => a.price - b.price);
      })
      .catch(() => {});
  let coffeeNext = null;
  function showCoffee(next, fromMenu = false, skipLabel = '') {
    coffeeNext = next;
    tipQty = 1;
    const beans = Array.from(
      { length: 14 },
      (_, i) =>
        `<i class="bean" style="--x:${Math.round(Math.random() * 100)}%;--d:${(Math.random() * 6).toFixed(2)}s;--t:${(5 + Math.random() * 5).toFixed(2)}s;--s:${(0.7 + Math.random() * 0.7).toFixed(2)}"></i>`,
    ).join('');
    showPanel(
      'coffee',
      '',
      `<div class="coffee-screen"><div class="coffee-beans" aria-hidden="true">${beans}</div><div class="coffee-ui"><div class="coffee-kicker">ENJOYING THE FIGHT?</div><h2 class="coffee-title"><span>FUEL</span><span>THE DEV</span></h2><div class="coffee-art" aria-hidden="true"><img class="coffee-joey" src="./player-victory.webp" alt=""><img class="coffee-sloth" src="./boss-caffeinatedsloth-stage1.webp" alt=""><svg class="coffee-cup" viewBox="0 0 120 120"><g class="steam"><path d="M38 34c-8-8 8-14 0-24M60 34c-8-8 8-14 0-24M82 34c-8-8 8-14 0-24" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="4" stroke-linecap="round"/></g><path d="M22 42h76l-8 56a10 10 0 0 1-10 8H40a10 10 0 0 1-10-8z" fill="#fff6dc" stroke="#2a160a" stroke-width="5" stroke-linejoin="round"/><path d="M98 52h8a12 12 0 0 1 0 28h-12" fill="none" stroke="#2a160a" stroke-width="5" stroke-linecap="round"/><path d="M26 50h68l-2 14H28z" fill="#6b3a1a"/><path d="M44 64v14c0 5 8 5 8 0V64M70 64v22c0 6 9 6 9 0V64" fill="#7dff2a" stroke="#2a8a10" stroke-width="2"/><text x="60" y="95" text-anchor="middle" font-family="Barlow,sans-serif" font-weight="900" font-size="20" fill="#2a160a">ZS</text></svg></div><p class="coffee-copy">Zombie Smash is <b>free</b>. No ads. No login. If you're having fun, you can help the next boss get built.</p>${nativeApp ? `<div class="tip-qty"><button data-tipqty="-1" aria-label="Fewer coffees">−</button><span>HOW MANY? <b id="tipQty">${tipQty}</b></span><button data-tipqty="1" aria-label="More coffees">+</button></div><div class="tip-grid">${tipProducts.map((t) => `<button class="bmc tip" data-tip="${esc(t.identifier)}"><b>${esc(t.title || 'TIP')}</b><span data-tipprice="${esc(t.identifier)}">${esc(tipPrice(t, tipQty))}</span></button>`).join('')}</div>` : `<a class="bmc" href="${COFFEE_URL}" target="_blank" rel="noopener noreferrer"><span class="bmc-cup">☕</span> BUY JOEY A COFFEE</a>`}<button class="coffee-skip" data-action="coffee-skip">${fromMenu ? 'BACK TO MENU' : skipLabel || 'NOT NOW · ON TO THE STORY ▶'}</button></div></div>`,
      { start: true, closable: false },
    );
  }
  function start(raw, skipIntro = false) {
    storyReplay = false;
    audio.unlock();
    raw = String(raw ?? '').trim();
    const { bot: isBot, name } = parseName(raw);
    if (!scores.validName(name)) {
      toast('Use 2–24 letters, numbers, spaces, dots, dashes or underscores. Keep it friendly.');
      return;
    }
    write('zs7-name', raw);
    pendingName = name;
    pendingBot = isBot;
    if (!skipIntro) {
      if (coffeeOn()) showCoffee(() => showStory(name, 0));
      else showStory(name, 0);
      return;
    }
    // Every run starts with the coffee screen (web version only), then plays.
    if (coffeeOn()) showCoffee(() => beginRun(name), false, 'NOT NOW · PLAY ▶');
    else beginRun(name);
  }
  // The intro is three animated clips (burned-in captions) that fill the gameplay screen.
  // FIRE skips exactly one clip per press, and each clip moves on by itself when it ends.
  let storyActive = false,
    storyPreload = null;
  function showStory(name, index = 0) {
    pendingName = name;
    storyStep = index;
    storyActive = true;
    if (panel !== 'story' || !$('storyVideo')) {
      showPanel(
        'story',
        '',
        '<div class="story-full"><video id="storyVideo" muted playsinline webkit-playsinline preload="auto" disablepictureinpicture aria-label="The story so far"></video></div>',
        { closable: false },
      );
      $('overlay').classList.add('story-mode');
      $('fireButton').classList.add('story-hint');
      audio.resume();
      audio.playMusic('story');
    }
    const v = $('storyVideo');
    storyVideo = v;
    v.onended = () => {
      if (storyActive && panel === 'story') storyNext();
    };
    // If a clip cannot load, move on instead of leaving a black screen.
    v.onerror = () => {
      setTimeout(() => {
        if (storyActive && panel === 'story' && storyVideo === v) storyNext();
      }, 400);
    };
    v.src = `./story-${index + 1}.mp4`;
    v.currentTime = 0;
    v.play().catch(() => {});
    audio.sfx('whoosh', 0.7);
    if (index < 2) {
      storyPreload = document.createElement('video');
      storyPreload.preload = 'auto';
      storyPreload.muted = true;
      storyPreload.src = `./story-${index + 2}.mp4`;
    }
  }
  function storyNext() {
    if (!storyActive) return;
    haptics.impact('LIGHT', 'ui', 0, true);
    if (storyStep < 2) showStory(pendingName, storyStep + 1);
    else storyEnd();
  }
  function storyEnd() {
    storyActive = false;
    $('fireButton').classList.remove('story-hint');
    const v = $('storyVideo');
    if (v) {
      v.onended = null;
      v.pause();
      v.removeAttribute('src');
      v.load?.();
    }
    storyVideo = null;
    storyPreload = null;
    $('overlay').classList.remove('story-mode');
    $('overlay').innerHTML = '';
    if (storyReplay) {
      storyReplay = false;
      closePanel();
    } else beginRun(pendingName || parseName(read('zs7-name', 'Player')).name || 'Player');
  }
  // After the intro (and before every run) the game waits: any button starts it, and that press does nothing else.
  let awaitStart = false,
    padHeld = false;
  function armStart() {
    awaitStart = true;
    paused = true;
    clearInput();
    $('startPrompt').hidden = false;
    audio.pause();
  }
  function startNow() {
    if (!awaitStart || panel) return false;
    awaitStart = false;
    $('startPrompt').hidden = true;
    haptics.impact('MEDIUM', 'ui', 0, true);
    resume();
    return true;
  }
  function padWatch() {
    try {
      const pad = Array.from(navigator.getGamepads?.() || []).find(Boolean),
        any = !!pad && pad.buttons.some((b) => b.pressed);
      if (any && !padHeld) {
        if (storyActive) {
          if (pad.buttons[0]?.pressed || pad.buttons[7]?.pressed) storyNext();
        } else if (awaitStart) startNow();
      }
      padHeld = any;
    } catch {}
  }

  function beginRun(name) {
    clearTimeout(storyTimer);
    write('zs7-story-seen', true);
    bot = pendingBot;
    run = { id: newId(), name, ticket: null, submitted: false, bot };
    if (bot) {
      const added = unlockSecretSkins();
      setTimeout(
        () =>
          toast(
            added
              ? 'BOT MODE · ' + added + ' SECRET SKINS DISPENSED · CHEATS MENU UNLOCKED'
              : 'BOT MODE · CHEATS MENU UNLOCKED',
          ),
        600,
      );
    }
    const thisRun = run;
    thisRun.ticketPromise = scores.begin(name).then((ticket) => {
      thisRun.ticket = ticket;
      if (run === thisRun) save();
      return ticket;
    });
    game.reset();
    $('overlay').hidden = true;
    panel = '';
    sceneKey = '';
    game.start();
    save();
    armStart();
  }
  let previewing = '';
  function paintSkin(skin) {
    document.body.dataset.releaseSkin = skin.id;
    document.body.classList.toggle('deck3d', !!skin.deck3d);
    for (const [k, v] of Object.entries({
      '--skin-art': `url('./${skin.file}')`,
      '--accent': skin.accent,
      '--bleed': skin.bleed,
      '--fire': skin.fire || '#ef3042',
      '--grenade': skin.grenade || '#159de8',
      '--stick': skin.stick || '#d8a34e',
    }))
      document.body.style.setProperty(k, v);
    document.querySelector('.shell-art').innerHTML = ZSConsole.markup(skin);
  }
  function applySkin(id) {
    // An extra skin is still loading at start-up, so the saved choice is only overwritten by a real match.
    const wanted = SKINS.find((s) => s.id === id && !skinLocked(s)),
      skin = wanted || SKINS.find((s) => !skinLocked(s)) || SKINS[0];
    previewing = '';
    paintSkin(skin);
    if (wanted) write('zs7-skin', skin.id);
  }
  // A locked skin can be tried on the console while the skins menu is open. Leaving the menu puts the
  // chosen skin back and says what unlocks it.
  function previewSkin(id) {
    const skin = SKINS.find((x) => x.id === id);
    if (!skin) return;
    previewing = skin.id;
    paintSkin(skin);
  }
  function endPreview() {
    if (!previewing) return;
    const skin = SKINS.find((x) => x.id === previewing);
    previewing = '';
    const saved = SKINS.find((x) => x.id === read('zs7-skin', 'toxic-pop') && !skinLocked(x));
    paintSkin(saved || SKINS[0]);
    if (skin) toast(lockText(skin));
  }
  function skins(group) {
    const current = read('zs7-skin', 'toxic-pop'),
      open = SKINS.filter((x) => !skinLocked(x)).length,
      tile = (s) => {
        const locked = skinLocked(s),
          boss = BOSSES.find((b) => b.id === s.boss),
          badge = locked ? (boss ? 'BEAT ' + boss.name.split(' ')[0] : 'SECRET') : '';
        return `<button class="skin-choice ${current === s.id && !locked ? 'selected' : ''} ${locked ? 'locked' : ''} ${previewing === s.id ? 'previewing' : ''}" ${locked ? `data-preview="${s.id}"` : `data-skin="${s.id}" aria-pressed="${current === s.id}"`}><span class="skin-thumbnail" aria-hidden="true"><span class="skin-miniature" style="--accent:${s.accent};--stick:${s.stick};--fire:${s.fire};--grenade:${s.grenade}">${ZSConsole.markup(s)}<i class="preview-screen"></i><i class="preview-stick"></i><i class="preview-fire"></i><i class="preview-grenade"></i></span></span><b>${s.name}</b>${locked ? `<small>🔒 ${badge}</small>` : ''}</button>`;
      },
      grid = (list) => `<div class="skin-options">${list.map(tile).join('')}</div>`,
      characters = SKINS.filter((x) => x.group === 'character'),
      customs = SKINS.filter((x) => x.group !== 'character'),
      count = (list) => `${list.filter((x) => !skinLocked(x)).length} of ${list.length}`;
    if (!group)
      return showPanel(
        'skins',
        'CHOOSE YOUR CONSOLE',
        `<p class="menu-note">${open} of ${SKINS.length} unlocked. Tap a locked skin to try it on; it goes back when you close the menu. Character skins unlock as you beat each boss.</p><button class="skin-group-card" data-action="skins-char"><b>SPECIAL CHARACTER SKINS</b><span>${count(characters)} unlocked</span><i aria-hidden="true">›</i></button><button class="skin-group-card" data-action="skins-custom"><b>CUSTOM SKINS</b><span>${count(customs)} unlocked</span><i aria-hidden="true">›</i></button><button class="secondary-action" data-action="menu">‹ BACK TO MENU</button>`,
      );
    const list = group === 'char' ? characters : customs;
    showPanel(
      'skins',
      group === 'char' ? 'CHARACTER SKINS' : 'CUSTOM SKINS',
      `<button class="back-link" data-action="skins">‹ BACK</button><p class="menu-note">${count(list)} unlocked. Same arena, same controls, same aim — whichever finish you pick.</p>${grid(list)}<button class="secondary-action" data-action="skins">‹ BACK TO SKIN TYPES</button>`
    );
  }
  async function board() {
    const local = () => `<h3 class="skin-group">ON THIS DEVICE</h3>${scores.localBoard().map((r,i)=>`<div class="board-row"><b class="rank">${i+1}</b><span>${esc(r.name)}<small>PERSONAL BEST</small></span><b class="points">${r.score.toLocaleString()}</b></div>`).join('') || '<p class="menu-note">Finish a run to set your first score.</p>'}`;
    showPanel('board', 'HIGH SCORES', local()+'<p class="menu-note">Connecting to the global board…</p><button class="secondary-action" data-action="menu">BACK TO MENU</button>');
    const result = await scores.board();
    if (panel !== 'board') return;
    const rows = Array.isArray(result.rows) ? result.rows : [],
      nameOf = (r) => String(r.username || r.name || r.gamertag || ''),
      isCheat = (r) => nameOf(r).toLowerCase().endsWith(CHEAT_MARK),
      plain = (n) => (n.toLowerCase().endsWith(CHEAT_MARK) ? n.slice(0, -CHEAT_MARK.length) : n),
      scoreOf = (r) => Number(r.score || r.high_score || 0),
      me = (run?.name || parseName(read('zs7-name', '')).name).trim(),
      mine = me ? scores.getBest(me) : 0,
      listed = rows.some(
        (r) => plain(nameOf(r)).toLowerCase() === me.toLowerCase() && scoreOf(r) >= mine,
      ),
      youRow =
        mine > 0 && !listed
          ? `<div class="board-row you"><b class="rank">YOU</b><span>${esc(me)}<small>YOUR BEST · NOT ON THE BOARD</small></span><b class="points">${mine.toLocaleString()}</b></div>`
          : '';
    $('overlay').querySelector('.panel-content').innerHTML =
      local() + `<h3 class="skin-group">GLOBAL LEADERBOARD</h3><p class="menu-note">${result.online ? 'Online leaderboard' : 'Saved leaderboard · offline'}${result.online ? '' : `<br>Could not reach the online board${result.error ? ' (' + esc(result.error) + ')' : ''}.`}<br>Original records are preserved. New runs use your player name.</p>${rows.map((r, i) => `<div class="board-row ${isCheat(r) ? 'cheat' : ''}"><b class="rank">${i + 1}</b><span>${esc(plain(nameOf(r)))}${isCheat(r) ? '<i class="cheat-mark" title="A cheat code was used">✦</i>' : ''}${r.legacy ? '<small>ORIGINAL RECORD</small>' : ''}</span><b class="points">${scoreOf(r).toLocaleString()}</b></div>`).join('')}${youRow}${result.online ? '' : '<button class="secondary-action" data-action="board">TRY AGAIN</button>'}<button class="secondary-action" data-action="menu">BACK TO MENU</button>`;
  }
  function sound() {
    const set = ['arcade', 'original', 'chip', 'early'].includes(audio.settings.set)
      ? audio.settings.set
      : 'new';
    showPanel(
      'sound',
      'MUSIC & SOUND',
      `<p class="menu-note">ARCADE pairs the cinematic score with recorded weapon effects. Choose your sound, adjust the mix and set haptics. Sound may play even with the iPhone silent switch on.</p><div class="setting"><span>SOUND SET</span><span class="segmented"><button data-sound-set="arcade" aria-pressed="${set === 'arcade'}" class="${set === 'arcade' ? 'on' : ''}">ARCADE</button><button data-sound-set="new" aria-pressed="${set === 'new'}" class="${set === 'new' ? 'on' : ''}">SCORE</button><button data-sound-set="chip" aria-pressed="${set === 'chip'}" class="${set === 'chip' ? 'on' : ''}">DARK</button><button data-sound-set="early" aria-pressed="${set === 'early'}" class="${set === 'early' ? 'on' : ''}">OLD</button><button data-sound-set="original" aria-pressed="${set === 'original'}" class="${set === 'original' ? 'on' : ''}">ORIGINAL</button></span></div><label class="setting">MUSIC <input aria-label="Music volume" data-volume="music" type="range" min="0" max="100" value="${audio.settings.music * 100}"></label><label class="setting">EFFECTS <input aria-label="Effects volume" data-volume="effects" type="range" min="0" max="100" value="${audio.settings.effects * 100}"></label><label class="setting">HAPTICS <input type="checkbox" data-haptics ${haptics.on ? 'checked' : ''}></label><button class="secondary-action" data-action="preview-sound">PREVIEW MIX</button><button class="secondary-action" data-action="fix-sound">NO SOUND? RESET AUDIO</button><button class="secondary-action" data-action="menu">BACK TO MENU</button>`,
    );
  }
  function help() {
    showPanel(
      'help',
      'HOLD THE LINE',
      `<p class="menu-note"><strong>MOVE</strong> — slide the left joystick sideways. Joey stays on his defence line.<br><br><strong>FIRE</strong> — hold the red button. Drag and fire together.<br><br><strong>GRENADE</strong> — tap the blue centre button. The grenade travels straight up Joey's current lane — there is no auto-aim. Line yourself up first.<br><br><strong>BOOST</strong> — chain kills within 7 seconds: 10 kills = ×2, 20 = ×4, 30 = ×10. Taking damage or letting a zombie into camp breaks the chain.<br><br><strong>WATCH THE HORDE</strong> — runners warn before charging, toxic zombies fire slime, Fuse tanks can chain-react, and Bulwark shields open between pulses. DMR rounds and grenades punch through shields.<br><br><strong>BARRELS</strong> — shoot the red hazard barrels. Their blast radius is 20% of the arena width and can chain into nearby barrels. Debo’s thrown barrels land inside a wide marked ring: move clear of the whole ring, or shoot them early near him.<br><br><strong>PICKUPS</strong> — drops are deliberately rarer. Walk into a drop or shoot it to collect it; drops stay about 15 seconds, even through boss scenes. A gold heart adds a bonus life, up to 10. Special guns are stored in the four HUD slots; tap the stored weapon you want, even while moving. You can hold one ammo run of each gun type.<br><br><strong>ARENA TARGETS</strong> — shoot all three numbered floor lights to trigger the arena boost. They recharge after 12 seconds. Zombies emerge from marked floor entrances and fan out into the arena.<br><br><strong>BOSSES</strong> — a new boss arrives every second wave. Watch the warning before each attack. Defeat Mantis to reach infinite survival.<br><br>MENU — the button under the grenade pauses the game and opens the menu.<br><br>Keyboard: ← → or A / D · Space = fire · G = grenade · P = pause.<br>Gamepad: left stick · A / right trigger = fire · B = grenade.</p><button class="secondary-action" data-action="menu">BACK TO MENU</button>`,
    );
  }
  function install() {
    const installed = matchMedia('(display-mode:standalone)').matches || navigator.standalone;
    showPanel(
      'install',
      'TAKE THE HORDE WITH YOU',
      `<img class="start-art" src="./game-banner.webp" alt="Zombie Smash game advertisement"><h3 style="font:900 26px Barlow;color:#ffdc8b;margin:12px 0">SEVEN BOSSES. ONE LAST STAND.</h3><p class="menu-note">Big boss reveals. Explosive weapons. Your next high score.<br>Launch straight from your Home Screen, and play offline once the game has finished downloading.</p>${installed ? '<p class="menu-note">✓ You’re already playing the installed game.</p>' : installPrompt ? '<button class="primary-action" data-action="install-now">INSTALL ZOMBIE SMASH</button>' : '<p class="menu-note"><strong>iPhone / iPad</strong><br>Open this game in Safari. Tap Share, then “Add to Home Screen”.<br><br><strong>Android</strong><br>Open your browser menu and choose “Install app” or “Add to Home screen”.</p>'}<p class="menu-note" id="offlineStatus">${read('zs7-offline-ready', false) ? 'Game download complete · offline play ready.' : 'Keep the game open while its artwork and music download.'}</p><button class="secondary-action" data-action="menu">BACK TO MENU</button>`,
    );
  }
  function adminPanel() {
    if (!admin) {
      showPanel(
        'admin',
        'ADMIN CODE',
        `<p class="menu-note">Use your existing admin code to unlock boss selection and practice cheats.</p><form id="adminForm"><label class="name-field">ADMIN CODE<input type="password" name="code" id="adminCode" autocomplete="off" required></label><button class="primary-action">UNLOCK</button></form><p class="menu-note" id="adminStatus"></p>`,
      );
      return;
    }
    showPanel(
      'admin',
      'BOSSES & CHEATS',
      `<p class="menu-note">Using a cheat or boss jump makes the run practice-only. Practice scores never enter the board.</p><label class="setting">INVINCIBLE <input type="checkbox" data-cheat="invincible" ${game.invincible ? 'checked' : ''}></label><label class="setting">UNLIMITED AMMO <input type="checkbox" data-cheat="infiniteAmmo" ${game.infiniteAmmo ? 'checked' : ''}></label><label class="setting">10 HEARTS (5 RED + 5 GOLD) <input type="checkbox" data-cheat="tenHearts" ${(game.maxLives || 5) > 5 ? 'checked' : ''}></label><button class="secondary-action" data-action="grenades">REFILL GRENADES</button><div style="display:flex;gap:5px">${Object.keys(
        ZSEngine.GUNS,
      )
        .map(
          (g) =>
            `<button class="secondary-action" data-gun="${g}" style="font-size:11px">${g.toUpperCase()}</button>`,
        )
        .join(
          '',
        )}</div>${BOSSES.map((b) => `<div class="boss-choice"><img src="./${b.sprites[0]}" alt=""><div><b>${b.name}</b>${Array.from({ length: b.stages }, (_, i) => `<button data-boss="${b.id}" data-stage="${i + 1}">FORM ${i + 1}</button>`).join(' ')}</div></div>`).join('')}`,
    );
  }
  function practice() {
    if (!admin) return false;
    if (!run || !game.active) {
      run = { id: newId(), name: read('zs7-name', 'Player'), ticket: null };
      game.reset();
      game.start();
    }
    game.practice = true;
    return true;
  }
  // Cheat codes. Tokens: L / R = joystick pushed fully left / right (release between), F = FIRE tap, G = GRENADE tap.
  // Codes only work in BOT mode, while playing, with about two seconds at most between taps.
  const CHEATS = [
    {
      id: 'invincible',
      name: 'INVINCIBLE',
      info: 'Nothing can hurt Joey.',
      seq: 'LLRRFF',
      state: () => game.invincible,
      run: () => (game.invincible = !game.invincible),
    },
    {
      id: 'ammo',
      name: 'UNLIMITED AMMO',
      info: 'Every gun, no reloading.',
      seq: 'FFGGLR',
      state: () => game.infiniteAmmo,
      run: () => (game.infiniteAmmo = !game.infiniteAmmo),
    },
    {
      id: 'hearts',
      name: '10 HEARTS',
      info: '5 red + 5 gold hearts.',
      seq: 'RRLLGF',
      state: () => (game.maxLives || 5) > 5,
      run: () => game.setTenHearts((game.maxLives || 5) <= 5),
    },
    {
      id: 'grenades',
      name: 'REFILL GRENADES',
      info: 'Back to 9 grenades.',
      seq: 'GGGLL',
      run: () => (game.player.grenades = 9),
    },
    {
      id: 'guns',
      name: 'ALL SPECIAL GUNS',
      info: 'SMG, scatter, DMR and pulse stored with full ammo.',
      seq: 'FGFGLR',
      run: () => {
        for (const g of ['smg', 'shotgun', 'dmr', 'burst'])
          if (game.player.gun !== g) game.player.inventory[g] = ZSEngine.GUNS[g].ammo;
      },
    },
    {
      id: 'wave',
      name: 'SKIP WAVE',
      info: 'Clears the current wave.',
      seq: 'RLRLFF',
      run: () => {
        if (game.boss || game.scene) return;
        game.enemies = [];
        game.spawned = game.resolved = game.target;
      },
    },
    {
      id: 'boss',
      name: 'JUMP TO NEXT BOSS',
      info: 'Starts the next boss you have not beaten.',
      seq: 'LRLRGG',
      run: () => {
        const next = BOSSES.find((b) => !game.bossesDown.includes(b.id));
        if (next) {
          game.skipBoss(next.id, 1);
          sceneKey = '';
        }
      },
    },
  ];
  const glyph = { L: '◀', R: '▶', F: 'FIRE', G: 'NADE' };
  // A run that used a cheat code outside BOT mode still counts on the board, but is marked: it is entered
  // under the player's name plus a short tag, which the board shows as a coloured name with a star.
  const CHEAT_MARK = '.cht';
  function markCheated() {
    if (!run || run.cheated) return;
    const r = run;
    r.cheated = true;
    const flagged = r.name.slice(0, 24 - CHEAT_MARK.length).trim() + CHEAT_MARK;
    r.ticket = null;
    r.ticketPromise = scores.begin(flagged).then((ticket) => {
      r.ticket = ticket;
      if (run === r) save();
      return ticket;
    });
  }
  function feedToken(token) {
    if (paused || !game.active || game.over) return;
    const now = performance.now();
    if (now - cheatLast > 2200) cheatBuf = '';
    cheatLast = now;
    cheatBuf = (cheatBuf + token).slice(-8);
    const hit = CHEATS.find((c) => cheatBuf.endsWith(c.seq));
    if (!hit) return;
    cheatBuf = '';
    const wasPractice = game.practice;
    if (!bot) markCheated();
    hit.run();
    // Some cheats flag the engine as practice-only; outside BOT mode the run still counts (it is marked instead).
    game.practice = bot ? true : wasPractice;
    save();
    audio.sfx('boost');
    haptics.notify('SUCCESS', 'cheat', 0);
    toast(
      'CHEAT · ' +
        hit.name +
        (hit.state ? (hit.state() ? ' ON' : ' OFF') : '') +
        (bot ? ' · scores off' : ' · score marked ✦'),
    );
  }
  function trackStick(axis) {
    const dir = axis < -0.6 ? -1 : axis > 0.6 ? 1 : Math.abs(axis) < 0.25 ? 0 : stickDir;
    if (dir !== stickDir) {
      stickDir = dir;
      if (dir) feedToken(dir < 0 ? 'L' : 'R');
    }
  }
  function cheatsPanel() {
    showPanel(
      'cheats',
      'CHEATS',
      `<p class="menu-note">BOT mode is on. While you play, enter a code on the console: push the joystick fully ◀ or ▶ (let go between pushes) and tap FIRE or the grenade button. Keep each tap within about 2 seconds. Any cheat makes the run practice-only: scores stay off the board. Outside BOT mode the same codes work too, and the score counts but is marked ✦ on the board.</p>${CHEATS.map(
        (c) =>
          `<div class="cheat-row"><div class="cheat-top"><b>${c.name}</b>${c.state ? `<span class="cheat-state ${c.state() ? 'on' : ''}">${c.state() ? 'ON' : 'OFF'}</span>` : ''}</div><small>${c.info}</small><div class="cheat-code">${[...c.seq].map((t) => `<i class="code-chip ${t}">${glyph[t]}</i>`).join('')}</div></div>`,
      ).join('')}<button class="secondary-action" data-action="menu">BACK TO MENU</button>`,
    );
  }
  let coffeeShownFor = null;
  function results(reason, afterCoffee = false) {
    // The coffee screen also appears when a run ends (web version only); the score is saved first.
    if (coffeeOn() && !afterCoffee && !game.practice && coffeeShownFor !== run?.id) {
      coffeeShownFor = run?.id;
      save();
      submitScore();
      showCoffee(() => results(reason, true), false, 'NOT NOW · SEE MY SCORE ▶');
      return;
    }
    showPanel(
      'results',
      game.practice ? 'PRACTICE COMPLETE' : 'RUN COMPLETE',
      `<div style="text-align:center"><p class="menu-note">${esc(run?.name)} · ${esc(reason)}</p><div class="score-result">${game.score.toLocaleString()}</div><div class="result-stats"><span><b>${game.wave}</b>WAVE</span><span><b>${game.kills}</b>KILLS</span><span><b>${game.bossesDown.length}</b>BOSSES</span></div><p class="menu-note" id="scoreStatus">${game.practice ? 'Practice run · not added to the board.' : run?.cheated ? 'Cheats used · your score will be marked ✦ on the board.' : 'Saving your score…'}</p><button class="primary-action" data-action="retry">ONE MORE RUN</button><button class="secondary-action" data-action="board">HIGH SCORES</button><button class="secondary-action" data-action="home">CHANGE PLAYER NAME</button></div>`,
      { closable: false },
    );
    save();
    submitScore();
  }
  async function submitScore() {
    if (!run || run.submitted) return;
    run.submitted = true;
    const completed = run,
      record = {
        id: run.id,
        name: run.name,
        score: game.score,
        kills: game.kills,
        seconds: game.t,
        wave: game.wave,
        practice: game.practice,
      };
    scores.recordLocal(record);
    save();
    if (run.ticketPromise) await run.ticketPromise;
    const result = await scores.finish({ ...record, ticket: completed.ticket });
    if (run !== completed) return;
    const status = $('scoreStatus');
    if (status)
      status.textContent = {
        practice: 'Practice run · not added to the board.',
        online: 'Score saved to the online leaderboard.',
        pending:
          'Saved on this device. Online upload queued for reconnection' +
          (scores.lastError ? ' (' + scores.lastError + ').' : '.'),
        local:
          'Saved on this device. This run has no online ticket' +
          (scores.lastError ? ' (' + scores.lastError + ').' : '.'),
        rejected:
          'Saved on this device. The online board could not accept this run' +
          (scores.lastError ? ' (' + scores.lastError + ').' : '.'),
      }[result.status];
  }
  // Phone vibration for gunfire, hits, damage and the big boss moments.
  function buzz(type, data) {
    switch (type) {
      case 'shot':
        haptics.impact(
          data.gun === 'shotgun' || data.gun === 'dmr' ? 'MEDIUM' : 'LIGHT',
          'shot',
          data.gun === 'smg' ? 85 : 55,
        );
        break;
      case 'hit':
        haptics.impact('LIGHT', 'hit', data.boss ? 70 : 90);
        break;
      case 'kill':
        haptics.impact('MEDIUM', 'kill', 60);
        break;
      case 'hurt':
        haptics.notify('ERROR', 'hurt', 0);
        break;
      case 'breach':
        haptics.notify('WARNING', 'breach', 0);
        break;
      case 'explosion':
        haptics.impact('HEAVY', 'boom', 60, true);
        break;
      case 'throw':
        haptics.impact('LIGHT', 'throw', 100);
        break;
      case 'pickup':
        haptics.notify('SUCCESS', 'pickup', 80);
        break;
      case 'boost':
        haptics.impact('MEDIUM', 'boost', 150, true);
        break;
      case 'bossAttack':
        haptics.impact('MEDIUM', 'bossAttack', 220, true);
        break;
      case 'entrance':
        haptics.notify('WARNING', 'entrance', 0);
        break;
      case 'panel':
        // Phase 1 of a boss arrival is Joey's shocked face.
        if (data.phase === 1) haptics.shock();
        break;
      case 'mutation':
        if (data.stage === 3) haptics.shock();
        else haptics.impact('HEAVY', 'mutation', 0, true);
        break;
      case 'bossDown':
        haptics.notify('SUCCESS', 'bossDown', 0);
        break;
      case 'death':
        haptics.notify('ERROR', 'death', 0);
        break;
    }
  }
  function event(type, data) {
    if (type === 'bossDown' && game.scene?.bossId && !game.practice) {
      const id = game.scene.bossId,
        had = beatenBosses();
      if (!had.has(id)) {
        had.add(id);
        write('zs7-beaten', [...had]);
        const skin = SKINS.find((x) => x.boss === id);
        if (skin) toast(skin.name + ' skin unlocked · Menu → Console Skins');
      }
    }
    if (type === 'panel' && data.phase === 2 && game.scene?.bossId === 'debo') {
      audio.playMusic('debo'); // the boss reveal: Debo's theme starts as he appears
    }
    if (type === 'entrance' && data.id === 'debo') audio.buffer('music-debo.mp3'); // preload
    if (type === 'music') {
      const debo = game.scene?.bossId === 'debo' || game.boss?.bossId === 'debo';
      if (game.scene?.kind === 'arrival')
        audio.playMusic(debo && game.scene.phase >= 2 ? 'debo' : 'entrance');
      else audio.playMusic(debo && data.track === 'boss' ? 'debo' : data.track);
      return;
    }
    const sounds = {
      shot: data.gun,
      kill: 'hit',
      ricochet: 'ricochet',
      boost: 'boost',
      breach: 'hurt',
      clear: 'pickup',
      hurt: 'hurt',
      pickup: 'pickup',
      throw: 'throw',
      explosion: 'grenade',
      entrance: 'alarm',
      panel: 'whoosh',
      mutation: 'alarm',
      bossAttack: 'boss-attack',
      bossDown: 'victory',
      death: 'loss',
    };
    // The new sound set closes a boss fight and a defeat with music stingers instead of the old effects.
    if (audio.synthMode && type === 'bossDown') audio.stinger('victory');
    else if (audio.synthMode && type === 'death') audio.stinger('defeat');
    else if (sounds[type])
      audio.sfx(sounds[type], type === 'kill' ? 0.55 : type === 'entrance' ? 0.6 : 1);
    buzz(type, data);
    if (type === 'fight') {
      audio.playMusic(data.id === 'debo' ? 'debo' : data.id === 'discoman' ? 'disco' : 'boss');
      audio.sfx('doom');
    }
    if (type === 'over') results(data.reason);
    if (type === 'wave') save();
  }
  // Which finished clip (if any) covers the scene that is playing now.
  function sceneClipFor(s) {
    // Warning and Joey's shocked reaction always play first; the boss clip takes over at the reveal.
    if (!s.bossId || (s.kind === 'arrival' && s.phase < 2)) return null;
    const name =
        s.kind === 'arrival'
          ? 'intro'
          : s.kind === 'mutation'
            ? 'form' + s.stage
            : s.kind === 'down'
              ? 'bossdown'
              : s.kind === 'loss'
                ? 'joeydown'
                : null,
      file = name && sceneClips[s.bossId + '/' + name];
    return file && !failedClips.has(file) ? file : null;
  }
  function unclipBox(box) {
    box.style.bottom = box.style.zIndex = '';
    box.closest('.screen')?.classList.remove('clip-full');
  }
  function removeSceneClip(box) {
    const v = box.querySelector('video.scene-clip');
    if (!v) return;
    v._dispose?.();
    v.pause();
    v.removeAttribute('src');
    v.load();
    v.remove();
  }
  function mountSceneClip(box, s, file) {
    const v = document.createElement('video');
    const originalDuration = s.duration;
    const phase = s.phase;
    let disposed = false,
      lastProgress = performance.now(),
      lastTime = -1;
    const current = () => !disposed && game.scene === s && s.phase === phase && v.isConnected;
    const restore = () => {
      if (!current()) return;
      failedClips.add(file);
      s.mediaControlled = false;
      s.duration = originalDuration;
      s.time = 0;
      removeSceneClip(box);
      box.classList.remove('clip-mode', 'clip-ready');
      unclipBox(box);
      sceneKey = '';
    };
    v.className = 'scene-clip';
    v.muted = true;
    v.playsInline = true;
    v.setAttribute('playsinline', '');
    v.setAttribute('webkit-playsinline', '');
    v.setAttribute('aria-label', 'Boss scene');
    v.preload = 'auto';
    s.mediaControlled = true;
    s.time = 0;
    v.addEventListener('playing', () => {
      if (!current()) return;
      lastProgress = performance.now();
      box.classList.add('clip-ready');
    });
    v.addEventListener('ended', () => {
      if (!current()) return;
      s.mediaControlled = false;
      s.duration = 0.25;
      s.time = 0;
    });
    v.addEventListener('error', restore);
    const watchdog = setInterval(() => {
      if (!current()) return;
      if (paused || document.hidden) {
        lastProgress = performance.now();
        return;
      }
      if (v.currentTime > lastTime + 0.01) {
        lastTime = v.currentTime;
        lastProgress = performance.now();
      }
      if (!v.ended && performance.now() - lastProgress > 4500) restore();
    }, 250);
    v._dispose = () => {
      disposed = true;
      clearInterval(watchdog);
    };
    box.prepend(v);
    box.classList.add('clip-mode');
    v.src = './' + file;
    v.play().catch(() => {
      if (current() && !paused && !document.hidden) restore();
    });
  }
  function comicFor(s) {
    // The warning and Joey's shocked, shaking reaction come first; the illustrated scene starts at the reveal.
    if(!s?.bossId || (s.kind==='arrival' && s.phase<2)) return null;
    const suffix=s.kind==='mutation'?'form'+s.stage:s.kind==='down'?'bossdown':s.kind==='loss'?'joeydown':s.startStage>1?'form'+s.startStage:'intro';
    const file=`comic-${s.bossId}-${suffix}.webp`, im=renderer.images[file];
    return im?.complete && im.naturalWidth ? file : null;
  }
  function cinematic() {
    const s = game.scene,
      box = $('cinematic');
    if (!s) {
      // Fade the scene out into the game instead of cutting.
      if (!box.hidden && box.classList.contains('comic-mode') && !box.classList.contains('leaving')) {
        box.classList.add('leaving');
        setTimeout(() => {
          box.classList.remove('leaving', 'comic-mode');
          if (!game.scene) cinematic();
        }, 320);
        return;
      }
      if (box.classList.contains('leaving')) return;
      box.hidden = true;
      sceneKey = '';
      box.classList.remove('clip-mode', 'clip-ready');

      unclipBox(box);
      removeSceneClip(box);
      return;
    }
    const clip = sceneClipFor(s);
    const playing = box.querySelector('video.scene-clip');
    if (playing) {
      if (paused) playing.pause();
      else if (!playing.ended && playing.paused && playing.readyState > 2)
        playing.play().catch(() => {});
    }
    const key = [s.kind, s.bossId, s.phase, s.stage].join(':');
    if (sceneKey === key) return;
    removeSceneClip(box);
    sceneKey = key;
    box.hidden = false;
    box.classList.remove('clip-mode', 'clip-ready');
    const b = BOSSES.find((b) => b.id === s.bossId);

    unclipBox(box);
    box.className = s.kind === 'down' ? 'scene-down' : '';
    box.style.setProperty('--scene-color', b?.accent || '#b45139');
    const comic = comicFor(s);
    if(comic && b) {
      const reaction=s.kind==='arrival' && s.phase===1;
      const title=reaction?'JOEY ROB':s.kind==='down'?'BOSS DOWN':s.kind==='loss'?'LINE BROKEN':b.name;
      const line=reaction?b.announce:s.kind==='mutation'?(b.stageLines[s.stage-1]||b.react):s.kind==='down'?b.finalLine:s.kind==='loss'?b.playerLoss:b.tease;
      const nextIndex=BOSSES.indexOf(b)+1;
      const detail=s.kind==='down'?(nextIndex<MAPS.length?'NEXT: '+MAPS[nextIndex].name:'INFINITE SURVIVAL UNLOCKED'):s.kind==='mutation'?(s.stage===3?'FINAL MUTATION':'THREAT EVOLVING'):b.title;
      s.mediaControlled=false; s.duration=reaction?3:Math.max(5.2,line.length*0.035+2);
      box.classList.add('comic-mode');box.classList.toggle('motion-paused',paused);
      box.innerHTML=`<div class="comic-layers" aria-hidden="true"><img class="comic-plate comic-l1" src="./${comic}" alt=""><img class="comic-plate comic-l2" src="./${comic}" alt=""><img class="comic-plate comic-l3" src="./${comic}" alt=""></div><span class="sr-only">${esc(b.name)} story scene</span><div class="comic-embers" aria-hidden="true">${Array.from({length:14},(_,i)=>`<i style="left:${(i*37+11)%96}%;animation-delay:${-(i*0.9)%7}s;animation-duration:${5+(i%4)*1.7}s"></i>`).join('')}</div><div class="comic-atmosphere" aria-hidden="true"></div><div class="comic-heading"><small>${esc(detail)}</small><h2>${esc(title)}</h2></div><div class="comic-dialogue">${esc(line)}${s.kind==='down'?'<br>'+esc(b.victory):''}</div>`;
      box.onclick = null;
      return;
    }
    let content = '';
    if (s.kind === 'arrival'  && s.phase === 0)
      content = '<div class="scene-alert">WARNING!<small>HOSTILE APPROACHING</small></div>';
    else if (s.kind === 'mutation') {
      const reaction = s.stage === 3;
      content = `<div class="scene-name long">${esc(b.name)}<span>${reaction ? 'FINAL MUTATION' : 'TRANSFORMATION'}</span></div><div class="scene-figures ${reaction ? 'dual' : ''}">${reaction ? '<img class="scene-art joey" src="./joey-reaction-close.webp" alt="Joey Rob reacts to the final mutation">' : ''}<img class="scene-art" src="./${b.sprites[s.stage - 1]}" alt="${esc(b.name)} form ${s.stage}"></div><div class="scene-copy"><small>${reaction ? 'JOEY ROB' : 'THREAT EVOLVING'}</small><p>${esc(b.stageLines[s.stage - 1] || b.react)}</p></div>`;
    } else if (s.kind === 'arrival' && s.phase === 1)
      content = `<div class="scene-name">JOEY ROB<span>SOMETHING’S COMING…</span></div><div class="scene-figures"><img class="scene-art joey" src="./joey-reaction-close.webp" alt="Joey Rob reacts in shock"></div><div class="scene-copy"><small>JOEY ROB</small><p>${esc(b.announce)}</p></div>`;
    else if (b) {
      const line = s.kind === 'down' ? b.finalLine : s.kind === 'loss' ? b.playerLoss : b.tease;
      content = `<div class="scene-name ${b.name.length > 14 ? 'long' : ''}">${s.kind === 'down' ? 'BOSS DOWN' : esc(b.name)}<span>${esc(b.title)}</span></div><div class="scene-figures"><img class="scene-art" src="./${b.sprites[(s.stage || s.startStage || 1) - 1]}" alt="${esc(b.name)}"></div><div class="scene-copy"><small>${esc(b.name)}</small><p>${esc(line)}</p></div>`;
    } else
      content = '<div class="scene-alert">LINE BROKEN<small>THE HORDE GOT THROUGH</small></div>';
    box.innerHTML =
      '<div class="scene-backdrop"></div><div class="scene-lines"></div>' +
      content +
      '';
    box.onclick = (e) => {
      if (!paused && e.target.closest('.scene-next')) game.advanceScene();
    };
    if (clip) mountSceneClip(box, s, clip);
  }

  function hud() {
    const p = game.player;
    $('joystick').classList.toggle('sped', (p.speedUp || 0) > 0);
    $('waveValue').textContent = game.wave;
    $('leftValue').textContent = game.boss ? 'BOSS' : Math.max(0, game.target - game.resolved);
    $('scoreValue').textContent = game.score.toLocaleString();
    $('bestValue').textContent = scores.getBest(run?.name || read('zs7-name', '')).toLocaleString();
    {
      const max = game.maxLives || 5,
        l = Math.max(0, p.lives),
        el = $('healthValue');
      el.classList.toggle('tenhearts', max > 5);
      if (el.dataset.health !== max + ':' + l) {
        el.dataset.health = max + ':' + l;
        el.innerHTML = Array.from(
          { length: max },
          (_, i) =>
            `<span class="heart${i >= 5 ? ' gold' : ''}${i < l ? '' : ' empty'}">${i < l ? '♥' : '♡'}</span>`,
        ).join('');
      }
    }
    $('healthValue').setAttribute('aria-label', p.lives + ' hearts');
    $('gunValue').textContent = ZSEngine.GUNS[p.gun].name;
    $('ammoValue').textContent = !Number.isFinite(p.ammo) || game.infiniteAmmo ? '∞' : p.ammo;
    $('baseValue').textContent = game.breaches + '/10';
    $('grenadeValue').textContent = p.grenades;
    $('grenadeButton').classList.toggle('empty', p.grenades === 0);
    $('grenadeButton').setAttribute('aria-label', 'Throw grenade, ' + p.grenades + ' remaining');
    $('boostText').textContent = 'BOOST ×' + game.multiplier;
    $('boostFill').style.width = Math.max(0, (game.comboLeft / 7) * 100) + '%';
    $('comboText').textContent =
      game.combo >= 30
        ? '×10 · KEEP IT GOING'
        : (game.combo < 10 ? 10 : game.combo < 20 ? 20 : 30) -
          game.combo +
          ' KILLS TO ×' +
          (game.combo < 10 ? 2 : game.combo < 20 ? 4 : 10);
    for (const gun of ['smg', 'shotgun', 'dmr', 'burst']) {
      const el = $('inv-' + gun);
      const active = p.gun === gun,
        ammo = active ? p.ammo : p.inventory?.[gun] || 0;
      if (el) el.textContent = ammo || '—';
      const btn = document.querySelector(`[data-weapon="${gun}"]`);
      if (btn) {
        btn.disabled = active || !(ammo > 0);
        btn.classList.toggle('ready', ammo > 0);
        btn.classList.toggle('equipped', active);
        btn.setAttribute(
          'aria-label',
          `${active ? 'Equipped' : 'Use'} ${ZSEngine.GUNS[gun].name}, ${ammo} rounds`,
        );
      }
    }
    $('mapLabel').textContent = $('mapTag').textContent = MAPS[ZSData.mapIndex(game.wave)].name;
    $('headerName').textContent = run?.name || 'JOEY ROB VS DR MANTIS';
  }
  function inputs() {
    let axis =
        touchAxis +
        (keys.has('ArrowRight') || keys.has('KeyD') ? 1 : 0) -
        (keys.has('ArrowLeft') || keys.has('KeyA') ? 1 : 0),
      fire = touchFire || keys.has('Space'),
      grenade = false;
    stick.classList.toggle('push-l', axis < -0.15);
    stick.classList.toggle('push-r', axis > 0.15);
    // Holding FIRE a couple of seconds into a boss scene skips to the next part.
    if (fire && game.scene?.bossId && !paused && game.scene.time >= 2) game.advanceScene();
    try {
      const pad = Array.from(navigator.getGamepads?.() || []).find(Boolean);
      if (pad) {
        if (Math.abs(pad.axes[0] || 0) > 0.14) axis = pad.axes[0];
        if (pad.buttons[14]?.pressed) axis = -1;
        if (pad.buttons[15]?.pressed) axis = 1;
        fire ||= !!(pad.buttons[0]?.pressed || pad.buttons[7]?.pressed);
        grenade = !!pad.buttons[1]?.pressed;
        if (grenade && !padGrenade) game.grenade();
      }
    } catch {}
    if (stickId !== null && performance.now() < flickUntil && Math.sign(axis) !== -flickDir)
      axis = flickDir;
    padGrenade = grenade;
    trackStick(axis);
    game.setInput(axis, fire);
  }
  function fit() {
    const root = document.documentElement,
      focused = /INPUT|TEXTAREA/.test(document.activeElement?.tagName || ''),
      vv = visualViewport,
      w = Math.max(1, root.clientWidth || innerWidth),
      h = Math.max(1, root.clientHeight || innerHeight),
      keyboard = focused && vv && vv.height < innerHeight * 0.78,
      newLandscape = w > h * 1.04;
    landscape = newLandscape;
    $('rotateGate').hidden = !landscape;
    if (landscape) {
      if (game.active && !paused) {
        pause();
        menu();
      }
      return;
    }
    if (keyboard) return;
    const safe = getComputedStyle(document.documentElement),
      top =
        parseFloat(safe.getPropertyValue('--safe-top')) ||
        0 ||
        (navigator.standalone === true ? 20 : 0),
      bottom = parseFloat(safe.getPropertyValue('--safe-bottom')) || 0,
      usableHeight = Math.max(1, h - top - bottom),
      scale = Math.min(w / 375, usableHeight / 667),
      T = top + (usableHeight - 667 * scale) / 2,
      shift = 0,
      key = w + 'x' + h + '@' + scale.toFixed(4) + '/' + top + '/' + bottom;
    if (key === lastFit) return;
    lastFit = key;
    document.documentElement.style.setProperty('--console-scale', scale);
    document.documentElement.style.setProperty('--hs', shift.toFixed(1) + 'px');
    document.body.classList.toggle('sb-overlap', shift > 6);
    $('cabinet').style.left = w / 2 + 'px';
    $('cabinet').style.top = T + 333.5 * scale + 'px';
    renderer.resize();
  }
  function frame(now) {
    fit();
    if (storyActive || awaitStart) padWatch();
    const dt = Math.min(0.1, (now - lastTime) / 1000 || 0);
    lastTime = now;
    if (!paused && !landscape && !document.hidden && ready) {
      inputs();
      accumulator += dt;
      let steps = 0;
      while (accumulator >= 1 / 60 && steps++ < 6) {
        game.step(1 / 60);
        accumulator -= 1 / 60;
      }
      saveClock += dt;
      if (saveClock > 5) {
        saveClock = 0;
        save();
      }
    } else accumulator = 0;
    renderer.draw(game);
    cinematic();
    hud();
    requestAnimationFrame(frame);
  }
  let flickDir = 0,
    flickUntil = 0,
    stickHist = [],
    stickVal = 0;
  const stick = $('joystick');
  // Floating stick: wherever the thumb lands on the pad becomes the centre; only dragging sideways steers.
  // Past full deflection the centre follows the thumb so reversing is instant, and a quick flick gives a short full-speed burst.
  function moveStick(e) {
    if (e.pointerId !== stickId || stickOrigin === null) return;
    const range = stick.getBoundingClientRect().width * 0.16,
      list = e.getCoalescedEvents?.().length ? e.getCoalescedEvents() : [e];
    for (const ev of list) {
      let dx = ev.clientX - stickOrigin;
      if (dx > range) {
        stickOrigin += dx - range;
        dx = range;
      } else if (dx < -range) {
        stickOrigin += dx + range;
        dx = -range;
      }
      const now = performance.now();
      stickHist.push([now, ev.clientX]);
      while (stickHist.length > 1 && now - stickHist[0][0] > 150) stickHist.shift();
      stickVal = dx / range;
      const a = Math.abs(stickVal);
      touchAxis = a < 0.1 ? 0 : Math.sign(stickVal) * Math.pow((a - 0.1) / 0.9, 0.8);
      const moved = ev.clientX - stickHist[0][1];
      if (Math.abs(moved) > range * 0.4) {
        flickDir = Math.sign(moved);
        flickUntil = now + 170;
      }
    }
    $('stickKnob').style.transform = `translateX(${stickVal * 25}px)`;
    stick.style.setProperty('--lean', stickVal.toFixed(2));
    stick.setAttribute('aria-valuenow', Math.round(touchAxis * 100));
  }
  stick.addEventListener('pointerdown', (e) => {
    if (awaitStart || storyActive) {
      e.preventDefault();
      startNow();
      return;
    }
    if (paused || !game.active || game.scene) return;
    e.preventDefault();
    stickId = e.pointerId;
    stickOrigin = e.clientX;
    stickHist = [[performance.now(), e.clientX]];
    stickVal = 0;
    touchAxis = 0;
    stick.setPointerCapture(e.pointerId);
    audio.unlock();
  });
  stick.addEventListener('pointermove', moveStick);
  for (const type of ['pointerup', 'pointercancel', 'lostpointercapture'])
    stick.addEventListener(type, (e) => {
      if (e.pointerId === stickId) {
        stickId = null;
        stickOrigin = null;
        flickUntil = 0;
        touchAxis = 0;
        stickVal = 0;
        $('stickKnob').style.transform = 'translateX(0)';
        stick.style.setProperty('--lean', '0');
        stick.setAttribute('aria-valuenow', '0');
      }
    });
  $('fireButton').addEventListener('pointerdown', (e) => {
    if (storyActive) {
      e.preventDefault();
      storyNext();
      return;
    }
    if (awaitStart) {
      e.preventDefault();
      startNow();
      return;
    }
    feedToken('F');
    if (!paused) haptics.impact('MEDIUM', 'press', 0, true);
    if (paused || !game.active) return;
    e.preventDefault();
    fireId = e.pointerId;
    e.currentTarget.setPointerCapture(e.pointerId);
    touchFire = true;
    e.currentTarget.classList.add('pressed');
    audio.unlock();
    // During a boss scene a press (or holding FIRE) skips ahead once the scene has run for a couple of seconds.
    if (game.scene) {
      if (game.scene.bossId && game.scene.time >= 2) game.advanceScene();
      return;
    }
    game.fire();
  });
  for (const type of ['pointerup', 'pointercancel', 'lostpointercapture'])
    $('fireButton').addEventListener(type, (e) => {
      if (e.pointerId === fireId) {
        touchFire = false;
        fireId = null;
        e.currentTarget.classList.remove('pressed');
      }
    });
  $('grenadeButton').addEventListener('pointerdown', (e) => {
    if (storyActive) return;
    if (awaitStart) {
      e.preventDefault();
      startNow();
      return;
    }
    feedToken('G');
    if (paused) return;
    // A firm press when a grenade is thrown, a light tick when the pouch is empty.
    haptics.impact(game.player.grenades > 0 ? 'MEDIUM' : 'LIGHT', 'press', 0, true);
    e.preventDefault();
    audio.unlock();
    game.grenade();
  });
  // Stored-weapon buttons react to the first touch. A 'click' is not sent on iPhone while another finger
  // is held on the joystick, which made guns selectable only after letting go.
  function equipStored(weapon) {
    if (paused || !game.useStored(weapon)) return;
    audio.sfx('pickup');
    haptics.impact('MEDIUM', 'weapon', 0, true);
    toast(ZSEngine.GUNS[weapon].name + ' equipped');
  }
  $('weaponRack').addEventListener('pointerdown', (e) => {
    if (awaitStart) {
      e.preventDefault();
      startNow();
      return;
    }
    const b = e.target.closest('[data-weapon]');
    if (!b || b.disabled) return;
    e.preventDefault();
    audio.unlock();
    equipStored(b.dataset.weapon);
  });
  $('weaponRack').addEventListener('click', (e) => {
    const b = e.target.closest('[data-weapon]');
    if (b && e.detail === 0) equipStored(b.dataset.weapon); // keyboard / assistive technology
  });
  // One MENU button: it pauses the game and opens the menu (press again to resume).
  // pointerdown, not click, so it also works while a thumb is already on the joystick.
  const menuButton = $('menuButton');
  let menuDownAt = 0;
  menuButton.addEventListener('pointerdown', (e) => {
    e.preventDefault();
    menuDownAt = performance.now();
    // A name box still holding the keyboard would swallow the first tap on a phone.
    if (document.activeElement?.blur && /INPUT|TEXTAREA/.test(document.activeElement.tagName))
      document.activeElement.blur();
    // MENU works on every screen. It does not count as "any button" for starting the game.
    if (storyActive && panel === 'story') {
      storyVideo?.pause();
      clearTimeout(storyTimer);
    }
    menuButton.classList.add('pressed');
    audio.unlock();
    haptics.impact('LIGHT', 'ui', 0, true);
    menu();
  });
  for (const type of ['pointerup', 'pointercancel', 'pointerleave'])
    menuButton.addEventListener(type, () => menuButton.classList.remove('pressed'));
  menuButton.addEventListener('click', (e) => {
    // Keyboard / assistive technology only: a tap already opened the menu on pointerdown.
    if (e.detail === 0 && performance.now() - menuDownAt > 800) menu();
  });
  addEventListener('keydown', (e) => {
    if (/INPUT|TEXTAREA/.test(e.target.tagName)) return;
    if (storyActive) {
      if (e.code === 'Space' || e.code === 'Enter') {
        e.preventDefault();
        if (!e.repeat) storyNext();
      }
      return;
    }
    if (awaitStart) {
      e.preventDefault();
      if (!e.repeat) startNow();
      return;
    }
    if (
      ['ArrowLeft', 'ArrowRight', 'Space', 'KeyA', 'KeyD', 'KeyG', 'KeyP', 'Escape'].includes(
        e.code,
      )
    )
      e.preventDefault();
    if (e.code === 'Escape' || e.code === 'KeyP') {
      if (!e.repeat) {
        if (panel && game.active) closePanel();
        else menu();
      }
      return;
    }
    if (paused) return;
    keys.add(e.code);
    if (e.code === 'Space' && !e.repeat) {
      feedToken('F');
      audio.unlock();
      game.fire();
    }
    if (e.code === 'KeyG' && !e.repeat) {
      feedToken('G');
      game.grenade();
    }
  });
  addEventListener('keyup', (e) => keys.delete(e.code));
  $('overlay').addEventListener('keydown', (e) => {
    if (e.key !== 'Tab') return;
    const nodes = [...$('overlay').querySelectorAll('button:not(:disabled),input,a[href]')];
    if (!nodes.length) return;
    const first = nodes[0],
      last = nodes.at(-1);
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  });
  $('overlay').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (e.target.id === 'startForm') {
      if (ready) start($('username').value);
    }
    if (e.target.id === 'adminForm') {
      const button = e.target.querySelector('button'),
        code = $('adminCode').value;
      $('adminCode').value = '';
      button.disabled = true;
      try {
        admin = (await scores.admin(code)) === true;
        if (admin) adminPanel();
        else $('adminStatus').textContent = 'Code not accepted. Try again.';
      } catch {
        $('adminStatus').textContent = 'Could not verify the code. Check your connection.';
      } finally {
        button.disabled = false;
      }
    }
  });
  // Every menu button, skin tile and switch gives a light tap.
  $('overlay').addEventListener('pointerdown', (e) => {
    const b = e.target.closest('button:not(:disabled)');
    if (b) haptics.impact('LIGHT', 'ui', 0, true);
    if (storyActive && storyVideo?.paused) storyVideo.play().catch(() => {});
  });
  $('overlay').addEventListener('change', (e) => {
    if (e.target.type === 'checkbox') haptics.impact('LIGHT', 'ui', 0, true);
  });
  $('overlay').addEventListener('input', (e) => {
    const kind = e.target.dataset.volume;
    if (kind) audio.set(kind, e.target.value / 100);
  });
  $('overlay').addEventListener('change', (e) => {
    if (e.target.hasAttribute('data-haptics')) {
      haptics.set(e.target.checked);
      return;
    }
    const cheat = e.target.dataset.cheat;
    if (cheat && admin && practice()) {
      if (cheat === 'tenHearts') game.setTenHearts(e.target.checked);
      else game[cheat] = e.target.checked;
      save();
      toast('Practice mode · scores off');
    }
  });
  $('overlay').addEventListener('click', async (e) => {
    const button = e.target.closest('button');
    if (!button) return;
    if (button.dataset.preview) {
      previewSkin(button.dataset.preview);
      document.querySelectorAll('.skin-choice').forEach((b) => {
        b.classList.toggle('previewing', b.dataset.preview === button.dataset.preview);
      });
      return;
    }
    if (button.dataset.soundSet) {
      audio.setSoundSet(button.dataset.soundSet);
      document.querySelectorAll('[data-sound-set]').forEach((b) => {
        const on = b.dataset.soundSet === button.dataset.soundSet;
        b.classList.toggle('on', on);
        b.setAttribute('aria-pressed', on);
      });
      audio.resume();
      audio.sfx('pickup');
      setTimeout(() => {
        if (paused) audio.pause();
      }, 1200);
      return;
    }
    if (button.dataset.tipqty) {
      tipQty = Math.max(1, Math.min(10, tipQty + Number(button.dataset.tipqty)));
      const q = document.getElementById('tipQty');
      if (q) q.textContent = tipQty;
      document.querySelectorAll('[data-tipprice]').forEach((el) => {
        const t = tipProducts.find((x) => x.identifier === el.dataset.tipprice);
        if (t) el.textContent = tipPrice(t, tipQty);
      });
      return;
    }
    if (button.dataset.tip && nativeApp) {
      (async () => {
        try {
          await window.Capacitor.Plugins.NativePurchases.purchaseProduct({
            productIdentifier: button.dataset.tip,
            productType: 'inapp',
            quantity: tipQty,
            isConsumable: true,
          });
          toast('Thank you! You just fuelled the next boss ☕');
          haptics.notify('SUCCESS', 'ui', 0);
        } catch (err) {
          if (!/cancel/i.test(String(err?.message || err))) toast('The purchase did not go through.');
        }
      })();
      return;
    }
    if (button.dataset.skin) {
      applySkin(button.dataset.skin);
      document.querySelectorAll('[data-skin]').forEach((b) => {
        const selected = b.dataset.skin === button.dataset.skin;
        b.classList.toggle('selected', selected);
        b.setAttribute('aria-pressed', selected);
      });
      return;
    }
    if (button.dataset.boss && admin) {
      practice();
      game.skipBoss(button.dataset.boss, Number(button.dataset.stage));
      sceneKey = '';
      closePanel();
      save();
      return;
    }
    if (button.dataset.gun && admin) {
      practice();
      game.equip(button.dataset.gun);
      toast('Weapon ready · practice mode');
      return;
    }
    switch (button.dataset.action) {
      case 'close':
        closePanel();
        break;
      case 'home':
        showStart();
        break;
      case 'menu':
        menu();
        break;
      case 'skins':
        skins();
        break;
      case 'skins-char':
        skins('char');
        break;
      case 'skins-custom':
        skins('custom');
        break;
      case 'coffee':
        showCoffee(menu, true);
        break;
      case 'coffee-skip': {
        const go = coffeeNext;
        coffeeNext = null;
        go?.();
        break;
      }
      case 'board':
        board();
        break;
      case 'sound':
        sound();
        break;
      case 'help':
        help();
        break;
      case 'cheats':
        if (bot) cheatsPanel();
        break;
      case 'install':
        if (!nativeApp) install();
        break;
      case 'admin':
        if (!nativeApp) adminPanel();
        break;
      case 'restart':
        showPanel(
          'restart',
          'START A NEW RUN?',
          `<p class="menu-note">Your current run will end without submitting its score.</p><button class="primary-action" data-action="newgame-go">START A NEW GAME</button><button class="secondary-action" data-action="home">CHOOSE A DIFFERENT PLAYER</button><button class="secondary-action" data-action="close">KEEP PLAYING</button>`,
        );
        break;
      case 'newgame-go':
        if (run?.name) start((run.bot ? 'BOT_' : '') + run.name, true);
        else showStart();
        break;
      case 'retry':
        start((run.bot ? 'BOT_' : '') + run.name, true);
        break;
      case 'story':
        storyReplay = true;
        showStory(parseName(read('zs7-name', 'Player')).name || 'Player', 0);
        break;
      case 'grenades':
        if (practice()) {
          game.player.grenades = 9;
          toast('Grenades refilled · practice mode');
        }
        break;
      case 'continue':
        {
          const saved = read('zs7-run', null);
          if (ready && saved && game.restore(saved.engine)) {
            run = saved.run;
            bot = !!run.bot;
            sceneKey = '';
            closePanel();
          }
        }
        break;
      case 'fix-sound': {
        audio.reset();
        toast('Audio reset · playing a test sound');
        setTimeout(() => audio.sfx('pickup'), 350);
        break;
      }
      case 'preview-sound': {
        const preview = ++soundPreview;
        audio.resume();
        audio.playMusic('main');
        ['pistol', 'hit', 'shotgun', 'grenade', 'pickup'].forEach((n, i) =>
          setTimeout(
            () => {
              if (preview === soundPreview && panel === 'sound') audio.sfx(n);
            },
            500 + i * 650,
          ),
        );
        haptics.impact('MEDIUM', 'preview', 0, true);
        setTimeout(() => {
          if (preview === soundPreview && paused) audio.pause();
        }, 5000);
        break;
      }
      case 'install-now':
        if (installPrompt) {
          await installPrompt.prompt();
          installPrompt = null;
          install();
        }
        break;
    }
  });
  addEventListener('resize', () => {
    lastFit = '';
  });
  visualViewport?.addEventListener('resize', () => {
    lastFit = '';
  });
  screen.orientation?.addEventListener('change', () => {
    lastFit = '';
  });
  addEventListener('blur', () => {
    clearInput();
    if (game.active && !panel && !awaitStart) {
      pause();
      menu();
    }
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      pause(true);
      storyVideo?.pause();
      if (game.active && !panel && !awaitStart) menu();
    } else {
      audio.revive();
      if (storyActive) {
        audio.resume();
        storyVideo?.play().catch(() => {});
      }
    }
  });
  for (const ev of ['pageshow', 'focus']) addEventListener(ev, () => audio.revive());
  // iOS can silently interrupt audio mid-game (calls, alerts, Siri): check often and bring it back.
  setInterval(() => {
    if (!document.hidden && audio.ctx && audio.ctx.state !== 'running') audio.revive();
  }, 2500);
  for (const ev of ['pointerdown', 'touchend'])
    document.addEventListener(ev, () => audio.revive(true), { capture: true, passive: true });
  addEventListener('pagehide', save);
  document.addEventListener('contextmenu', (e) => {
    if (!e.target.closest?.('input,textarea')) e.preventDefault();
  });
  addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    installPrompt = e;
  });
  ZSConsole.apply();
  applySkin(read('zs7-skin', 'toxic-pop'));
  fetch('./skins-extra.json')
    .then((r) => r.json())
    .then((j) => {
      let added = 0;
      for (const s of j.skins || [])
        if (
          s?.id &&
          s.file &&
          Array.isArray(s.win) &&
          s.win.length === 4 &&
          !SKINS.some((x) => x.id === s.id)
        ) {
          s.group = 'character';
          s.deck3d = true; // illustrated 3D decks get the 3D controls (the build regenerates this file)
          if (s.id !== 'joeyrob') s.boss = s.id;
          SKINS.push(s);
          added++;
        }
      if (added) applySkin(read('zs7-skin', 'toxic-pop'));
    })
    .catch(() => {});
  showStart();
  requestAnimationFrame(frame);
  renderer
    .load((fraction) => {
      const line = $('loadingLine');
      if (line) line.textContent = 'Loading game artwork · ' + Math.round(fraction * 100) + '%';
    })
    .then(() => {
      ready = true;
      if (panel === 'start') {
        const b = $('startButton');
        b.disabled = false;
        b.textContent = '▶ PRESS START ◀';
        $('loadingLine').textContent = 'NO LOGIN · NO ADS · V' + APP_VER;
      }
      renderer.draw(game);
    })
    .catch((error) => {
      const line = $('loadingLine');
      if (line) line.textContent = 'Artwork download interrupted. Reload to retry.';
      toast(error.message);
    });
  scores.flush();
  if ('serviceWorker' in navigator) {
    const hadController = !!navigator.serviceWorker.controller;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (!hadController) return;
      pendingReload = true;
      reloadWhenSafe();
    });
    navigator.serviceWorker
      .register('./sw.js', { updateViaCache: 'none' })
      .then((reg) => {
        reg.update().catch(() => {});
        document.addEventListener('visibilitychange', () => {
          if (document.hidden) reloadWhenSafe();
          else reg.update().catch(() => {});
        });
        setInterval(() => reg.update().catch(() => {}), 600000);
        return navigator.serviceWorker.ready;
      })
      .then(() =>
        navigator.serviceWorker.controller?.postMessage({
          type: 'CACHE_STATUS',
        }),
      )
      .catch(() => {});
    navigator.serviceWorker.addEventListener('message', (e) => {
      if (e.data?.type === 'OFFLINE_READY') {
        write('zs7-offline-ready', true);
        if ($('offlineStatus'))
          $('offlineStatus').textContent = 'Game download complete · offline play ready.';
      }
    });
  }
  {
    const intro = $('studioIntro');
    if (intro) {
      const done = () => intro.remove();
      intro.addEventListener('pointerdown', done);
      setTimeout(done, 2900);
    }
  }
  window.ZSInspect = () => ({
    world: { width: ZSData.W, height: ZSData.H },
    player: { x: game.player.x, y: game.player.y },
    wave: game.wave,
    score: game.score,
    kills: game.kills,
    bullets: game.bullets.length,
    shots: game.shots.length,
    grenades: game.player.grenades,
    paused,
    landscape,
    scene: game.scene?.kind,
    scenePhase: game.scene?.phase,
    boss: game.boss?.bossId,
    stage: game.boss?.stage,
    practice: game.practice,
    active: game.active,
    over: game.over,
    panel,
    ready,
  });
})();
