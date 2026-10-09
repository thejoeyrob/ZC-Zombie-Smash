import { readFileSync, mkdirSync, rmSync, copyFileSync, existsSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const out = join(root, 'www');
const match = readFileSync(join(root, 'sw.js'), 'utf8').match(/const ASSETS=\[(.*?)\];/s);
if (!match) throw new Error('Could not find the ASSETS list in sw.js');

const files = new Set([...match[1].matchAll(/"([^"]+)"/g)].map(m => m[1].replace(/^\.\//, '')));
for (const extra of ['index.html', 'manifest.webmanifest', 'privacy.html']) files.add(extra);
files.delete('sw.js');

rmSync(out, { recursive: true, force: true });
let bytes = 0;
const missing = [];
for (const f of files) {
  const src = join(root, f);
  if (!existsSync(src)) { missing.push(f); continue; }
  mkdirSync(dirname(join(out, f)), { recursive: true });
  copyFileSync(src, join(out, f));
  bytes += statSync(src).size;
}
if (missing.length) throw new Error('Listed in sw.js but missing on disk: ' + missing.join(', '));
console.log(`www/ ready: ${files.size} files, ${(bytes / 1048576).toFixed(1)} MB`);
