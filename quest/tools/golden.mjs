// Runs the JavaScript engine through scripted scenarios and writes a digest every 30 ticks to quest/tests/golden.json.
// quest/tests/trace.gd runs the same scenarios in the GDScript port and compares.
import { readFileSync, writeFileSync } from 'node:fs';
import vm from 'node:vm';
const root = new URL('../../', import.meta.url).pathname;
const ctx = { console }; ctx.window = ctx; vm.createContext(ctx);
vm.runInContext(readFileSync(root + 'game-data.js', 'utf8'), ctx);
vm.runInContext(readFileSync(root + 'engine.js', 'utf8'), ctx);
const { Game } = ctx.ZSEngine;

const AXES = [-1, -0.5, 0, 0.5, 1, 0, 1, -1];
export const SCENARIOS = [
  { name: 'wave-play-seed1', seed: 1, ticks: 7200, invincible: true },
  { name: 'wave-play-seed7', seed: 7, ticks: 7200, invincible: true },
  { name: 'wave-play-seed42-mortal', seed: 42, ticks: 6000, invincible: false },
  { name: 'wave9-dance-floor', seed: 5, ticks: 4800, invincible: true, jumpWave: 9 },
  { name: 'wave13-harvest', seed: 3, ticks: 4800, invincible: true, jumpWave: 13 },
  ...['jordan', 'glowinghumanity', 'debo', 'caffeinatedsloth', 'discoman', 'fatamy', 'drmantis'].map((id, i) => (
    { name: 'boss-' + id, seed: 100 + i, ticks: 5400, invincible: true, boss: id })),
];

function run(sc) {
  const events = {};
  const g = new Game({ seed: sc.seed, onEvent: (type) => { events[type] = (events[type] || 0) + 1; } });
  g.invincible = !!sc.invincible;
  g.start();
  if (sc.jumpWave) { g.wave = sc.jumpWave; g.prepareWave(sc.jumpWave); }
  if (sc.boss) g.skipBoss(sc.boss, 1);
  const digests = [];
  for (let i = 0; i < sc.ticks; i++) {
    g.setInput(AXES[Math.floor(i / 41) % AXES.length], i % 260 < 215);
    if (i % 333 === 150) g.grenade();
    if (i % 900 === 450 && g.player.inventory.smg > 0) g.useStored('smg');
    if (sc.boss && g.boss && i % 600 === 599) g.damage(g.boss, 40, 'dmr'); // push through the forms
    g.step(1 / 60);
    if (i % 30 === 29) {
      const sum = (a, f) => a.reduce((s, z) => s + f(z), 0);
      digests.push({
        i, score: g.score, kills: g.kills, wave: g.wave, breaches: g.breaches, lives: g.player.lives, px: g.player.x,
        gun: g.player.gun, grenades: g.player.grenades, enemies: g.enemies.length, ex: sum(g.enemies, (z) => z.x), ey: sum(g.enemies, (z) => z.y),
        bullets: g.bullets.length, shots: g.shots.length, pickups: g.pickups.length, barrels: g.barrels.length,
        boss: g.boss ? [g.boss.stage, g.boss.hp, g.boss.x, g.boss.y] : null, scene: g.scene ? g.scene.kind : null,
        seed: g.seed, nextId: g.nextId, over: g.over, special: g.player.special ? g.player.special.id : null,
      });
    }
  }
  return { name: sc.name, events, digests };
}
if (process.argv[1] === new URL(import.meta.url).pathname) {
  const out = SCENARIOS.map(run);
  writeFileSync(root + 'quest/tests/golden.json', JSON.stringify(out));
  for (const o of out) console.log(o.name, 'digests', o.digests.length, 'last score', o.digests.at(-1).score, 'wave', o.digests.at(-1).wave, JSON.stringify(o.events));
}
