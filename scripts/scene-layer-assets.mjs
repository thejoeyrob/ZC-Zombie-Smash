import { readFileSync, existsSync, statSync } from 'node:fs';
import { dirname, resolve, relative } from 'node:path';

// Read only files named by the catalogue. Do not ship master PNGs, previews or unrelated files.
export function sceneLayerAssets(root) {
  const base = resolve(root, 'scene-layers');
  const index = resolve(base, 'index.json');
  if (!existsSync(index)) return [];
  const assets = new Set(['./scene-layers/index.json']);
  const file = (dir, name) => {
    if (typeof name !== 'string' || !/^[a-zA-Z0-9_./-]+$/.test(name) ||
        name.startsWith('/') || name.split('/').some(p => !p || p === '.' || p === '..'))
      throw Error('Invalid scene asset path: ' + name);
    const path = resolve(dir, name);
    if (!existsSync(path) || !statSync(path).isFile()) throw Error('Missing scene asset: ' + path);
    assets.add('./' + relative(root, path).split('\\').join('/'));
    return path;
  };
  const scenes = JSON.parse(readFileSync(index, 'utf8')).scenes;
  if (!scenes || typeof scenes !== 'object' || Array.isArray(scenes)) throw Error('Invalid scene catalogue');
  for (const [id, entry] of Object.entries(scenes)) {
    const manifestPath = file(base, entry);
    const m = JSON.parse(readFileSync(manifestPath, 'utf8'));
    if (m.scene !== id || !Number.isInteger(m.width) || !Number.isInteger(m.height) ||
        m.width < 1 || m.height < 1 || m.width > 1600 || m.height > 2000 ||
        !Array.isArray(m.panels) || m.panels.length < 2 || m.panels.length > 3)
      throw Error('Invalid scene manifest: ' + id);
    for (const p of m.panels) {
      if (!Number.isFinite(p.seconds) || p.seconds < 1 || p.seconds > 15 ||
          typeof p.caption !== 'string' || p.caption.length > 280 ||
          !Array.isArray(p.layers) || p.layers.length !== 5) throw Error('Invalid panel: ' + id);
      for (const l of p.layers) {
        if (!Number.isFinite(l.depth) || l.depth < 0 || l.depth > 1) throw Error('Invalid depth: ' + id);
        file(dirname(manifestPath), l.file);
      }
    }
  }
  // The opening story layers (optional): one manifest per story card, each naming its own layer files.
  const open = resolve(root, 'opening-layers'), openIndex = resolve(open, 'index.json');
  if (existsSync(openIndex)) {
    assets.add('./opening-layers/index.json');
    for (const entry of Object.values(JSON.parse(readFileSync(openIndex, 'utf8')).scenes || {})) {
      const mp = file(open, entry);
      for (const l of JSON.parse(readFileSync(mp, 'utf8')).layers || []) file(dirname(mp), l.file);
    }
  }
  return [...assets].sort();
}
