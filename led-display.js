/* Dot-matrix marquee in the retro console's top bar. Messages roll up from the bottom, hold, and roll off the
   top; a message wider than the bar scrolls in from the right instead. Cosmetic only: it reads a small context
   object that game.js passes in and draws into one tiny canvas, so it never touches the simulation or input.
   Drawing happens only while something moves; a held message is a still frame. */
(() => {
  'use strict';
  const COLS = 103, ROWS = 7, CELL = 6, GAP = 1; // 6 backing px per dot cell
  // Classic 5x7 font: five column bytes per glyph, least significant bit at the top.
  const RAW = '00 00 00 00 00|00 00 5F 00 00|00 07 00 07 00|14 7F 14 7F 14|24 2A 7F 2A 12|23 13 08 64 62|36 49 55 22 50|00 05 03 00 00|00 1C 22 41 00|00 41 22 1C 00|14 08 3E 08 14|08 08 3E 08 08|00 50 30 00 00|08 08 08 08 08|00 60 60 00 00|20 10 08 04 02|3E 51 49 45 3E|00 42 7F 40 00|42 61 51 49 46|21 41 45 4B 31|18 14 12 7F 10|27 45 45 45 39|3C 4A 49 49 30|01 71 09 05 03|36 49 49 49 36|06 49 49 29 1E|00 36 36 00 00|00 56 36 00 00|08 14 22 41 00|14 14 14 14 14|00 41 22 14 08|02 01 51 09 06|32 49 79 41 3E|7E 11 11 11 7E|7F 49 49 49 36|3E 41 41 41 22|7F 41 41 22 1C|7F 49 49 49 41|7F 09 09 09 01|3E 41 49 49 7A|7F 08 08 08 7F|00 41 7F 41 00|20 40 41 3F 01|7F 08 14 22 41|7F 40 40 40 40|7F 02 0C 02 7F|7F 04 08 10 7F|3E 41 41 41 3E|7F 09 09 09 06|3E 41 51 21 5E|7F 09 19 29 46|46 49 49 49 31|01 01 7F 01 01|3F 40 40 40 3F|1F 20 40 20 1F|3F 40 38 40 3F|63 14 08 14 63|07 08 70 08 07|61 51 49 45 43';
  const FONT = RAW.split('|').map((g) => g.split(' ').map((h) => parseInt(h, 16))); // ASCII 32..90
  const COLORS = { amber: '#ffb21c', green: '#52ff7e', red: '#ff4a3a', yellow: '#ffe84a' };
  const clean = (t) => String(t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().replace(/[^ -Z]/g, '').replace(/\s+/g, ' ').trim();
  const bitmap = (text) => {
    const cols = [];
    for (const ch of text) {
      const g = FONT[ch.charCodeAt(0) - 32] || FONT[31];
      for (const c of g) cols.push(c);
      cols.push(0);
    }
    cols.pop();
    return cols;
  };
  let cv = null, g = null, timer = 0, ctx = {}, list = [], idx = 0, cur = null, alertItem = null, alertTimer = 0, paused = false;
  const reduced = () => matchMedia('(prefers-reduced-motion: reduce)').matches;
  const live = () => document.body.dataset.releaseSkin === 'retro-handheld' && !document.hidden && !paused;
  function dot(x, y, on, color) {
    const cx = x * CELL + CELL / 2, cy = y * CELL + CELL / 2;
    g.fillStyle = on ? color : 'rgba(255,255,255,0.055)';
    g.beginPath();
    g.arc(cx, cy, CELL / 2 - GAP, 0, 6.2832);
    g.fill();
  }
  // oy: vertical offset in rows (0 = centred); ox: horizontal offset in columns.
  function draw(item, ox = 0, oy = 0) {
    if (!g) return;
    g.clearRect(0, 0, cv.width, cv.height);
    const cols = item ? item.bits : [], color = item ? COLORS[item.color] || COLORS.amber : '';
    for (let x = 0; x < COLS; x++) {
      const col = cols[x - ox] || 0;
      for (let y = 0; y < ROWS; y++) {
        const r = y - oy;
        dot(x, y, r >= 0 && r < 7 && ((col >> r) & 1) === 1, color);
      }
    }
  }
  const mk = (text, color) => { const t = clean(text); return t ? { text: t, color, bits: bitmap(t) } : null; };
  function playlist() {
    const L = [];
    if (ctx.over) L.push(mk('GAME OVER', 'red'));
    else if (ctx.paused) L.push(mk('PAUSED', 'amber'));
    else if (!ctx.started) { L.push(mk('ZOMBIE SMASH', 'yellow')); L.push(mk('PRESS START', 'green')); }
    else {
      L.push(mk('ZOMBIE SMASH', 'yellow'));
      L.push(mk('WAVE ' + ctx.wave, 'green'));
      if (ctx.map) L.push(mk(ctx.map, 'amber'));
      if (ctx.boss) L.push(mk('BOSS ' + ctx.boss, 'red'));
      if (ctx.name) L.push(mk(ctx.name, 'green'));
    }
    return L.filter(Boolean);
  }
  function stop() { clearTimeout(timer); timer = 0; }
  function show(item, done) {
    // roll up from the bottom, hold, roll off the top (or scroll when wider than the bar)
    cur = item;
    if (reduced()) { draw(item, Math.max(0, (COLS - item.bits.length) >> 1), 0); timer = setTimeout(done, 2600); return; }
    if (item.bits.length > COLS) {
      let x = COLS;
      const step = () => {
        if (!live()) { timer = setTimeout(step, 400); return; }
        draw(item, x, 0); x -= 1;
        if (x < -item.bits.length) done(); else timer = setTimeout(step, 28);
      };
      step(); return;
    }
    const ox = (COLS - item.bits.length) >> 1;
    let y = 8, phase = 0;
    const step = () => {
      if (!live()) { timer = setTimeout(step, 400); return; }
      if (phase === 0) { y -= 1; draw(item, ox, y); if (y <= 0) { phase = 1; timer = setTimeout(step, 2300); return; } }
      else if (phase === 1) { phase = 2; }
      else { y -= 1; draw(item, ox, y); if (y <= -8) { done(); return; } }
      timer = setTimeout(step, 55);
    };
    step();
  }
  function next() {
    stop();
    if (!cv) return;
    if (alertItem) { const a = alertItem; show(a, () => { alertItem = null; next(); }); return; }
    if (!list.length) list = playlist();
    if (!list.length) return;
    idx = (idx + 1) % list.length;
    const item = list[idx];
    show(item, () => { if (ctx.dirty) { ctx.dirty = false; list = playlist(); idx = -1; } next(); });
  }
  const api = {
    init() {
      cv = document.getElementById('ledBar');
      if (!cv) return;
      cv.width = COLS * CELL; cv.height = ROWS * CELL; g = cv.getContext('2d');
      draw(null);
      list = playlist(); idx = -1; next();
      document.addEventListener('visibilitychange', () => (document.hidden ? stop() : api.wake()));
    },
    set(next_) {
      const was = ctx.started + '|' + ctx.over;
      ctx = { ...ctx, ...next_, dirty: true };
      if (was !== ctx.started + '|' + ctx.over) { list = playlist(); idx = -1; ctx.dirty = false; if (cv) next(); }
    },
    alert(text, color = 'red') {
      const item = mk(text, color);
      if (!item || !cv || document.body.dataset.releaseSkin !== 'retro-handheld') return;
      alertItem = item; next();
    },
    pause(on) { paused = !!on; if (!paused) api.wake(); },
    wake() { if (!cv) return; stop(); if (live()) next(); else if (cur) draw(cur, Math.max(0, (COLS - cur.bits.length) >> 1), 0); },
  };
  // Grenade counter: two dot-matrix digits in the small window beside the blue ring.
  let gc = null, gg = null, gn = -1;
  api.grenades = (n) => {
    if (!gc) {
      const box = document.getElementById('grenadeLed');
      gc = box && box.querySelector('canvas');
      if (!gc) return;
      gc.width = 11 * CELL; gc.height = ROWS * CELL; gg = gc.getContext('2d');
    }
    if (n === gn) return;
    gn = n;
    const t = String(Math.max(0, Math.min(99, n | 0))), bits = bitmap(t), color = n <= 0 ? COLORS.red : n <= 2 ? COLORS.amber : COLORS.green;
    gg.clearRect(0, 0, gc.width, gc.height);
    const ox = Math.floor((11 - bits.length) / 2);
    for (let x = 0; x < 11; x++)
      for (let y = 0; y < ROWS; y++) {
        const on = (((bits[x - ox] || 0) >> y) & 1) === 1;
        gg.fillStyle = on ? color : 'rgba(255,255,255,0.06)';
        gg.beginPath(); gg.arc(x * CELL + CELL / 2, y * CELL + CELL / 2, CELL / 2 - (on ? 0.2 : GAP), 0, 6.2832); gg.fill();
      }
  };
  window.ZSLedBar = api;
})();
