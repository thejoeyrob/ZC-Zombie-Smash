/* Layered comic scenes. Every boss scene is five aligned pictures (background, scenery, boss, Joey, foreground)
   stacked in one full-window stage. A camera pushes in on the boss and then on Joey (found from the real cut-outs),
   the layers drift at different depths for real parallax, and each new shot slides in behind a comic wipe.
   Only transforms change per frame, so it stays smooth. The cabinet geometry is owned by console-layout.js. */
(() => {
  'use strict';
  const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
  const ease = (x) => 1 - Math.pow(1 - clamp(x, 0, 1), 3);
  const safePath = (s) => typeof s === 'string' && /^[a-zA-Z0-9_./-]+$/.test(s) &&
    !s.startsWith('/') && !s.split('/').some(p => !p || p === '.' || p === '..');
  const sceneId = (s) => {
    if (!s?.bossId || (s.kind === 'arrival' && s.phase < 2)) return null;
    const suffix = s.kind === 'arrival' ? (s.startStage > 1 ? 'form' + s.startStage : 'intro') :
      s.kind === 'mutation' ? 'form' + s.stage : s.kind === 'down' ? 'bossdown' :
        s.kind === 'loss' ? 'joeydown' : null;
    return suffix ? s.bossId + '-' + suffix : null;
  };
  function validate(m, id) {
    if (m?.scene !== id || !Number.isInteger(m.width) || !Number.isInteger(m.height) ||
        m.width < 1 || m.height < 1 || m.width > 1600 || m.height > 2000 ||
        !Array.isArray(m.panels) || m.panels.length < 2 || m.panels.length > 3)
      throw Error('Invalid scene manifest: ' + id);
    for (const p of m.panels) {
      if (!Number.isFinite(p.seconds) || p.seconds < 1 || p.seconds > 15 ||
          typeof p.caption !== 'string' || p.caption.length > 280 ||
          !Array.isArray(p.layers) || p.layers.length !== 5 ||
          !p.layers.every(l => safePath(l.file) && Number.isFinite(l.depth) && l.depth >= 0 && l.depth <= 1))
        throw Error('Invalid scene panel: ' + id);
    }
    return m;
  }
  async function json(url, signal) {
    const r = await fetch(url, { signal });
    if (!r.ok) throw Error('Scene unavailable: ' + r.status);
    return r.json();
  }
  function loadImage(url, signal) {
    return new Promise((resolve, reject) => {
      const im = new Image();
      im.decoding = 'async';
      const cleanup = () => { im.onload = im.onerror = null; signal.removeEventListener('abort', abort); };
      const abort = () => { cleanup(); im.removeAttribute('src'); reject(Error('Scene cancelled')); };
      im.onload = () => { cleanup(); resolve(im); };
      im.onerror = () => { cleanup(); reject(Error('Scene image unavailable')); };
      if (signal.aborted) return abort();
      signal.addEventListener('abort', abort, { once: true });
      im.src = url;
    });
  }
  // Where a cut-out sits in the picture (0..1), found from its opaque pixels.
  function centreOf(im) {
    try {
      const w = 72, h = Math.round((72 * im.naturalHeight) / im.naturalWidth), c = document.createElement('canvas');
      c.width = w; c.height = h;
      const x = c.getContext('2d', { willReadFrequently: true });
      x.drawImage(im, 0, 0, w, h);
      const d = x.getImageData(0, 0, w, h).data;
      let sx = 0, sy = 0, n = 0, x0 = w, x1 = 0, y0 = h, y1 = 0;
      for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (d[(j * w + i) * 4 + 3] > 40) {
        sx += i; sy += j; n++; x0 = Math.min(x0, i); x1 = Math.max(x1, i); y0 = Math.min(y0, j); y1 = Math.max(y1, j);
      }
      if (n < 20) return null;
      return { x: sx / n / w, y: sy / n / h, w: (x1 - x0) / w, h: (y1 - y0) / h };
    } catch { return null; }
  }
  // The camera for each shot: wide, then in on the boss, then in on Joey (or the impact between them).
  function shots(count, boss, joey) {
    const mid = boss && joey ? { x: (boss.x + joey.x) / 2, y: (boss.y + joey.y) / 2 } : boss || joey || { x: 0.5, y: 0.5 };
    const zoomFor = (c) => clamp(0.7 / Math.max(c?.w || 0.5, (c?.h || 0.5) * 0.8), 1.1, 1.3);
    const head = (c) => c ? c.y - c.h * 0.12 : 0.5;
    const list = [
      { x: 0.5, y: 0.5, z0: 1.02, z1: 1.1 },
      { x: boss ? boss.x : mid.x, y: boss ? head(boss) : mid.y, z0: 1.08, z1: boss ? zoomFor(boss) : 1.25 },
      { x: joey ? joey.x : mid.x, y: joey ? head(joey) : mid.y, z0: 1.08, z1: joey ? zoomFor(joey) : 1.25 },
    ];
    return count === 2 ? [list[0], list[1]] : list;
  }
  // Builds the stage inside `host` and returns update(t) to place the layers for time t.
  function buildStage(host, w, h, images, panels, shotList, depths, reduced) {
    host.replaceChildren();
    const stage = document.createElement('div');
    stage.className = 'ls-stage';
    const els = images.map((im, i) => {
      const el = im.cloneNode(false);
      el.className = 'ls-layer ls-l' + i;
      el.alt = '';
      el.draggable = false;
      stage.appendChild(el);
      return el;
    });
    const wipe = document.createElement('i');
    wipe.className = 'ls-wipe';
    host.append(stage, wipe);
    const total = panels.reduce((n, p) => n + p.seconds, 0);
    let last = '';
    function update(t) {
      t = clamp(t, 0, total);
      let begin = 0, i = 0;
      for (; i < panels.length - 1; i++) {
        if (t < begin + panels[i].seconds) break;
        begin += panels[i].seconds;
      }
      const sec = panels[i].seconds, local = t - begin, p = clamp(local / sec, 0, 1);
      const key = Math.round(t * 60) + ':' + w + 'x' + h;
      if (key === last) return i;
      last = key;
      const s = shotList[Math.min(i, shotList.length - 1)];
      const iw = images[0].naturalWidth, ih = images[0].naturalHeight;
      const cover = Math.max(w / iw, h / ih);
      const zoom = reduced ? (s.z0 + s.z1) / 2 : s.z0 + (s.z1 - s.z0) * p;
      // The shot slides in from the side, behind a wipe.
      const enter = reduced ? 1 : ease(local / 0.42);
      const dir = panels[i].slide === 'from-right' ? 1 : -1;
      const slide = (1 - enter) * dir * w * 0.55;
      // One camera for every layer: keep the picture covering the window, then place each layer around the same
      // focal point so the boss, Joey and scenery always line up.
      const sc0 = cover * zoom, m = 0.03 * iw * sc0;
      const tx0 = clamp(w / 2 - s.x * iw * sc0, w - iw * sc0 + m, -m);
      const ty0 = clamp(h / 2 - s.y * ih * sc0, h - ih * sc0, 0);
      const fx = (w / 2 - tx0) / (iw * sc0), fy = (h / 2 - ty0) / (ih * sc0);
      els.forEach((el, k) => {
        const depth = depths[k];
        const sc = cover * zoom * (1 + (depth - 0.5) * 0.06);
        // Nearer layers travel further as the camera drifts: a real parallax.
        const drift = reduced ? 0 : (p - 0.5) * (depth - 0.4) * 0.05 * iw * cover;
        const tx = w / 2 - fx * iw * sc + drift + slide * (0.55 + depth * 0.6);
        const ty = h / 2 - fy * ih * sc;
        el.style.transform = 'translate3d(' + tx.toFixed(1) + 'px,' + ty.toFixed(1) + 'px,0) scale(' + sc.toFixed(4) + ')';
      });
      if (!reduced) {
        const wp = i === 0 ? 1 : clamp(local / 0.5, 0, 1);
        wipe.style.opacity = wp < 1 ? '1' : '0';
        wipe.style.transform = 'translate3d(' + ((wp * 2 - 1) * 140).toFixed(1) + '%,0,0) skewX(-18deg)';
      }
      return i;
    }
    return { update, total };
  }
  class SceneLayers {
    constructor(base = './scene-layers/') {
      this.base = base;
      this.failed = new Set();
      this.reduced = matchMedia('(prefers-reduced-motion: reduce)');
      const abort = new AbortController();
      const timer = setTimeout(() => abort.abort(), 4500);
      this.index = json(base + 'index.json', abort.signal).then(j => j.scenes || {}).catch(() => ({}))
        .finally(() => clearTimeout(timer));
    }
    mount(box, scene, isCurrent) {
      const id = sceneId(scene);
      if (!id || this.failed.has(id)) return null;
      const phase = scene.phase;
      const controller = new AbortController();
      let disposed = false, manifest = null, built = null, caption = null, title = null;
      let lastText = '', host = null;
      const alive = () => !disposed && scene.phase === phase && isCurrent();
      const timeout = setTimeout(() => controller.abort(), 4500);
      const handle = {
        scene, phase,
        dispose() {
          disposed = true;
          clearTimeout(timeout);
          controller.abort();
          built = null;
          manifest = null;
        },
        tick: (time) => {
          if (!alive() || !built || !manifest) return;
          const i = built.update(time);
          const panel = manifest.panels[i];
          const begin = manifest.panels.slice(0, i).reduce((n, p) => n + p.seconds, 0);
          const elapsed = time - begin;
          const count = this.reduced.matches ? panel.caption.length :
            Math.min(panel.caption.length, Math.floor(Math.max(0, elapsed - 0.3) * 40));
          const text = panel.caption.slice(0, count);
          if (text !== lastText) { caption.textContent = text; lastText = text; }
          caption.classList.toggle('ls-quiet', !panel.caption);
          caption.setAttribute('aria-label', panel.caption);
          box.dataset.layerPanel = String(panel.id);
        },
      };
      (async () => {
        const index = await this.index;
        const path = index[id];
        if (!path || !alive()) return;
        if (!safePath(path)) throw Error('Invalid scene path');
        const m = validate(await json(this.base + path, controller.signal), id);
        const dir = this.base + path.slice(0, path.lastIndexOf('/') + 1);
        // All panels share the same five aligned pictures: bottom to top.
        const first = m.panels[0].layers;
        const loaded = await Promise.all(first.map(l => loadImage(dir + l.file, controller.signal)));
        if (!alive()) return;
        if (loaded.some(im => im.naturalWidth !== m.width || im.naturalHeight !== m.height)) throw Error('Unaligned scene image');
        host = box.querySelector('.comic-layers');
        caption = box.querySelector('.comic-dialogue');
        title = box.querySelector('.comic-heading');
        if (!host || !caption) return;
        box.classList.add('layer-mode');
        const w = host.clientWidth || 343, h = host.clientHeight || 412;
        const boss = centreOf(loaded[2]), joey = centreOf(loaded[3]);
        manifest = m;
        built = buildStage(host, w, h, loaded, m.panels, shots(m.panels.length, boss, joey), first.map(l => l.depth), this.reduced.matches);
        scene.mediaControlled = false;
        scene.time = 0;
        scene.duration = built.total;
        caption.textContent = '';
        box.classList.add('layer-mode');
        handle.tick(0);
      })().catch(() => {
        // The existing comic remains visible and keeps its original timer on any load error.
        if (!disposed) this.failed.add(id);
      }).finally(() => clearTimeout(timeout));
      return handle;
    }
    // The opening story cards: layered pictures with a slow push and parallax, plus a title and typed caption.
    // `onEnd` runs when the card finishes; `onFail` runs if its art cannot be loaded (use the old video instead).
    mountStory(host, index, onEnd, onFail) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 6000);
      let disposed = false, paused = false, ended = false, t = 0, raf = 0, built = null, m = null, last = 0;
      let titleEl, capEl, lastText = '';
      const reduced = this.reduced.matches;
      const api = {
        currentTime: 0,
        pause() { paused = true; },
        play() { paused = false; return Promise.resolve(); },
        removeAttribute() {}, load() {},
        dispose() { disposed = true; cancelAnimationFrame(raf); clearTimeout(timeout); controller.abort(); built = null; },
      };
      const step = (now) => {
        if (disposed) return;
        raf = requestAnimationFrame(step);
        const dt = Math.min(0.1, (now - last) / 1000 || 0);
        last = now;
        if (!built || paused || document.hidden) return;
        t += dt;
        api.currentTime = t;
        const total = m.seconds;
        // One-way drift: no zoom back and forth.
        built.update(Math.min(t, total));
        const text = m.caption.slice(0, reduced ? m.caption.length : Math.min(m.caption.length, Math.floor(Math.max(0, t - 0.7) * 34)));
        if (text !== lastText) { capEl.textContent = text; lastText = text; }
        if (t >= total + 0.3 && !ended) { ended = true; onEnd?.(); }
      };
      (async () => {
        const base = './opening-layers/';
        const idx = await json(base + 'index.json', controller.signal);
        const path = idx.scenes?.['story-' + (index + 1)];
        if (!path || !safePath(path)) throw Error('No opening scene');
        m = await json(base + path, controller.signal);
        if (!Array.isArray(m.layers) || m.layers.length < 2 || m.layers.length > 8 || !m.layers.every(l => safePath(l.file)))
          throw Error('Invalid opening scene');
        const dir = base + path.slice(0, path.lastIndexOf('/') + 1);
        const images = await Promise.all(m.layers.map(l => loadImage(dir + l.file, controller.signal)));
        if (disposed) return;
        host.replaceChildren();
        host.classList.add('ls-story');
        const stageHost = document.createElement('div');
        stageHost.className = 'ls-story-stage';
        host.appendChild(stageHost);
        titleEl = document.createElement('div');
        titleEl.className = 'ls-story-title';
        titleEl.textContent = m.title || '';
        capEl = document.createElement('div');
        capEl.className = 'ls-story-caption';
        capEl.setAttribute('aria-label', m.caption || '');
        const count = document.createElement('div');
        count.className = 'ls-story-count';
        count.textContent = (index + 1) + ' / 3';
        host.append(titleEl, capEl, count);
        const w = host.clientWidth || 343, h = host.clientHeight || 412;
        const centre = centreOf(images[images.length - 2] || images[0]);
        const cam = [{ x: 0.5, y: 0.5, z0: 1.0, z1: 1.1 }];
        if (centre) cam[0].y = clamp(centre.y, 0.45, 0.55);
        built = buildStage(stageHost, w, h, images, [{ seconds: m.seconds, caption: '', slide: 'from-left' }], cam, m.layers.map(l => l.depth), reduced);
        last = performance.now();
      })().catch(() => {
        if (!disposed && !ended) { disposed = true; cancelAnimationFrame(raf); onFail?.(); }
      }).finally(() => clearTimeout(timeout));
      raf = requestAnimationFrame(step);
      return api;
    }
  }
  SceneLayers.sceneId = sceneId;
  SceneLayers.validate = validate;
  window.ZSSceneLayers = SceneLayers;
})();
