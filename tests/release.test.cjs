const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const context = {window: {}};
vm.createContext(context);
for (const file of ['game-data.js', 'engine.js']) vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8'), context);
Object.assign(context, context.window);
const {Game} = context.ZSEngine;
const clone = value => JSON.parse(JSON.stringify(value));
const fresh = () => {const g = new Game(); g.start(); return g;};

test('arena weapon time is preserved through every cinematic kind', () => {
  for (const kind of ['arrival', 'mutation', 'down', 'loss']) {
    const g = fresh();
    g.player.special = {id: 'hose', left: 4};
    g.scene = {kind, bossId: 'jordan', phase: 2, time: 0, duration: 30, mediaControlled: true};
    for (let i = 0; i < 600; i++) g.step(1 / 60);
    assert.equal(g.player.special.left, 4, kind);
    g.scene = null;
    g.step(0.05);
    assert.equal(g.player.special.left, 3.95);
    g.player.special.left = 0.01;
    g.step(0.05);
    assert.equal(g.player.special, null);
  }
});

test('invalid saves fail without changing the current run', () => {
  const g = fresh();
  const saved = g.snapshot();
  for (const mutate of [s => delete s.enemies, s => s.enemies = [null],
    s => s.enemies = [{type: 'unknown'}], s => s.player.gun = 'unknown',
    s => s.wave = -1, s => s.player.x = null, s => s.boss = {bossId: 'unknown'},
    s => s.scene = {kind: 'unknown'}, s => s.over = true]) {
    const broken = clone(saved); mutate(broken);
    assert.equal(g.restore(broken), false);
    assert.deepEqual(g.snapshot(), saved);
  }
});

test('restore owns its data, resets controls and migrates missing optional fields', () => {
  const g = fresh(); g.spawn('normal');
  const saved = g.snapshot();
  delete saved.arcs; delete saved.beams; delete saved.barrels;
  saved.input = {axis: 1, fire: true}; saved.step = null;
  const restored = new Game();
  assert.equal(restored.restore(saved), true);
  assert.equal(typeof restored.step, 'function');
  assert.equal(restored.player.ammo, Infinity);
  assert.equal(restored.input.axis, 0); assert.equal(restored.input.fire, false);
  restored.step(0.05);
  assert.equal(saved.t, 0);
  assert.notEqual(restored.enemies[0], saved.enemies[0]);
});

test('all boss forms survive save and restore and can return to combat', () => {
  for (const boss of context.ZSData.BOSSES) for (let stage = 1; stage <= boss.stages; stage++) {
    const g = fresh(); g.spawnBoss(boss.id, stage);
    g.scene = {kind: 'mutation', bossId: boss.id, stage, phase: 0, time: 3, duration: 5, mediaControlled: true};
    const restored = new Game();
    assert.equal(restored.restore(g.snapshot()), true);
    assert.equal(restored.scene.mediaControlled, false);
    assert.equal(restored.scene.time, 0);
    restored.advanceScene();
    restored.step(0.05);
    assert.equal(restored.boss.bossId, boss.id);
    assert.equal(restored.boss.stage, stage);
    assert(Number.isFinite(restored.boss.hp));
  }
});

test('release assets, script versions and all 33 films are packaged', () => {
  const read = name => fs.readFileSync(path.join(root, name), 'utf8');
  const version = read('VERSION.txt').trim();
  const sw = read('sw.js');
  assert(sw.includes(`zombie-smash-v${version}`));
  const assets = new Set([...sw.match(/const ASSETS\s*=\s*\[(.*?)\];/s)[1].matchAll(/['"]([^'"]+)['"]/g)].map(m => m[1].replace(/^\.\//, '')));
  for (const asset of assets) assert(fs.existsSync(path.join(root, asset)), asset);
  for (const [,file,v] of read('index.html').matchAll(/(?:src|href)="\.\/([^"?]+)\?v=([^"]+)"/g)) {
    assert.equal(v, version, file); assert(assets.has(file), file);
  }
  const clips = JSON.parse(read('scene-clips.json')).clips;
  assert.equal(Object.keys(clips).length, 30);
  for (const file of [...Object.values(clips), 'story-1.mp4', 'story-2.mp4', 'story-3.mp4']) assert(assets.has(file), file);
});
