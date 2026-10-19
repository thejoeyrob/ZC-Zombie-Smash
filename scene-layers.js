/* Optional, manifest-driven comic scenes. The cabinet geometry is owned by console-layout.js. */
(() => {
  'use strict';
  const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
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
      if (p.view && (!['x', 'y', 'zoom'].every(k => Number.isFinite(p.view[k])) ||
          p.view.x < 0 || p.view.x > 1 || p.view.y < 0 || p.view.y > 1 ||
          p.view.zoom < 1 || p.view.zoom > 3)) throw Error('Invalid camera: ' + id);
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
      let disposed = false, manifest = null, images = new Map(), canvas = null, caption = null;
      let start = 0, total = 0, lastText = '', lastFrame = '';
      const alive = () => !disposed && scene.phase === phase && isCurrent();
      const timeout = setTimeout(() => controller.abort(), 4500);
      const handle = {
        scene, phase,
        dispose() {
          disposed = true;
          clearTimeout(timeout);
          controller.abort();
          // Preserve the final frame for the existing exit fade.
          images.clear();
          canvas = null;
          manifest = null;

        },
        tick: (time) => {
          if (!alive() || !canvas || !manifest) return;
          const t = clamp(time - start, 0, total);
          const host = canvas.parentElement;
          const dpr = Math.min(2, window.devicePixelRatio || 1);
          const w = Math.max(1, Math.round(host.clientWidth * dpr));
          const h = Math.max(1, Math.round(host.clientHeight * dpr));
          const reduced = this.reduced.matches;
          const signature = [t.toFixed(4), w, h, reduced].join(':');
          if (signature === lastFrame) return;
          lastFrame = signature;
          if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
          const ctx = canvas.getContext('2d', { alpha: false });
          let begin = 0, i = 0;
          for (; i < manifest.panels.length - 1; i++) {
            if (t < begin + manifest.panels[i].seconds) break;
            begin += manifest.panels[i].seconds;
          }
          const panel = manifest.panels[i], elapsed = t - begin;
          const progress = reduced ? 0.5 : t / total;
          const draw = (p, q, offset) => {
            ctx.save();
            ctx.beginPath(); ctx.rect(offset, 0, w, h); ctx.clip();
            ctx.fillStyle = '#190f0b'; ctx.fillRect(offset, 0, w, h);
            const view = p.view || { x: 0.5, y: 0.5, zoom: 1 };
            // Fixed overscan and fixed panel crops; no animated zoom, stretch or back-and-forth motion.
            const scale = Math.max(w / manifest.width, h / manifest.height) * 1.05 * view.zoom;
            const iw = manifest.width * scale, ih = manifest.height * scale;
            const margin = Math.min((iw - w) / 2, 0.018 * manifest.width * scale);
            const x = clamp(w / 2 - view.x * iw, w - iw + margin, -margin);
            const y = clamp(h / 2 - view.y * ih, h - ih, 0);
            for (const l of p.layers) {
              const dx = (q - 0.5) * 0.03 * manifest.width * l.depth * scale;
              ctx.drawImage(images.get(l.file), offset + x + dx, y, iw, ih);
            }
            ctx.restore();
          };
          ctx.fillStyle = '#190f0b'; ctx.fillRect(0, 0, w, h);
          const entrance = reduced ? 1 : clamp(elapsed / 0.32, 0, 1);
          if (i && entrance < 1) draw(manifest.panels[i - 1], progress, 0);
          const direction = panel.slide === 'from-right' ? 1 : -1;
          draw(panel, progress, direction * w * Math.pow(1 - entrance, 3));
          const count = reduced ? panel.caption.length : Math.min(panel.caption.length, Math.floor(Math.max(0, elapsed - 0.15) * 44));
          const text = panel.caption.slice(0, count);
          if (text !== lastText) { caption.textContent = text; lastText = text; }
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
        const files = [...new Set(m.panels.flatMap(p => p.layers.map(l => l.file)))];
        // Only the active scene is decoded. Panel crops share the same five images.
        const loaded = await Promise.all(files.map(async file => {
          const im = await loadImage(dir + file, controller.signal);
          if (im.naturalWidth !== m.width || im.naturalHeight !== m.height) throw Error('Unaligned scene image');
          return [file, im];
        }));
        if (!alive()) return;
        const host = box.querySelector('.comic-layers');
        caption = box.querySelector('.comic-dialogue');
        if (!host || !caption) return;
        manifest = m;
        images = new Map(loaded);
        total = m.panels.reduce((n, p) => n + p.seconds, 0);
        scene.mediaControlled = false;
        scene.time = 0;
        start = 0;
        scene.duration = total;
        canvas = document.createElement('canvas');
        canvas.className = 'layer-canvas';
        canvas.setAttribute('aria-hidden', 'true');
        host.replaceChildren(canvas);
        caption.textContent = '';
        box.classList.add('layer-mode');
        handle.tick(0);
      })().catch(() => {
        // The existing comic remains visible and keeps its original timer on any load error.
        if (!disposed) this.failed.add(id);
      }).finally(() => clearTimeout(timeout));
      return handle;
    }
  }
  SceneLayers.sceneId = sceneId;
  SceneLayers.validate = validate;
  window.ZSSceneLayers = SceneLayers;
})();
