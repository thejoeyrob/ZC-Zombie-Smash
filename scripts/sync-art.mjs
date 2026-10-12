// Finds finished scene clips and extra console skins in the project folder and wires them into the game.
//   - scene-<boss>-<scene>.mp4   -> scene-clips.json   (scene = intro, form2, form3, bossdown, joeydown)
//   - console-<id>.webp          -> skins-extra.json   (settings come from art-pipeline/CONSOLE-DESIGN-MANIFEST.json)
// It also keeps the offline file list in sw.js (and so the iPhone build) up to date.
// Run: node scripts/sync-art.mjs
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const files = new Set(readdirSync(root));
const BOSSES = [
  'jordan',
  'glowinghumanity',
  'debo',
  'caffeinatedsloth',
  'discoman',
  'fatamy',
  'drmantis',
];
const SCENES = ['intro', 'form2', 'form3', 'bossdown', 'joeydown'];

const clips = {};
for (const boss of BOSSES)
  for (const scene of SCENES) {
    const name = `scene-${boss}-${scene}.mp4`;
    if (files.has(name)) clips[`${boss}/${scene}`] = name;
  }
writeFileSync(join(root, 'scene-clips.json'), JSON.stringify({ clips }, null, 2) + '\n');

const manifestPath = join(root, 'art-pipeline/CONSOLE-DESIGN-MANIFEST.json');
const builtIn = readFileSync(join(root, 'game-data.js'), 'utf8');
const skins = [];
if (existsSync(manifestPath)) {
  for (const s of JSON.parse(readFileSync(manifestPath, 'utf8')).skins || []) {
    const file = `console-${s.id}.webp`;
    if (!files.has(file) || builtIn.includes(`file: '${file}'`)) continue;
    skins.push({
      id: s.id,
      name: s.displayName || s.id,
      file,
      win: s.win,
      accent: s.accent,
      bleed: s.bleed,
      fire: s.fire,
      grenade: s.grenade,
      stick: s.stick,
    });
  }
}
writeFileSync(join(root, 'skins-extra.json'), JSON.stringify({ skins }, null, 2) + '\n');

// Offline file list in sw.js.
const swPath = join(root, 'sw.js');
let sw = readFileSync(swPath, 'utf8');
const wanted = [
  './scene-clips.json',
  './skins-extra.json',
  ...Object.values(clips).map((f) => './' + f),
  ...skins.map((s) => './' + s.file),
];
const lines = sw.split('\n').filter((l) => {
  const m = /^\s*'\.\/([^']+)',\s*$/.exec(l);
  return !(
    m &&
    (/^scene-.+\.mp4$/.test(m[1]) ||
      /^(scene-clips|skins-extra)\.json$/.test(m[1]) ||
      skins.some((s) => s.file === m[1]))
  );
});
const at = lines.findIndex((l) => l.includes("'./story-1.mp4'"));
if (at < 0) throw new Error('Could not find the story clips in the sw.js file list');
lines.splice(at, 0, ...wanted.map((w) => `  '${w}',`));
sw = lines.join('\n');
writeFileSync(swPath, sw);
console.log(`Scene clips: ${Object.keys(clips).length} of 30 · extra skins: ${skins.length} of 8`);
