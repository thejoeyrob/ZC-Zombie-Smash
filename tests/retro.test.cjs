const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const context = {window: {}, document: {body: {style: {setProperty() {}}}}};
vm.createContext(context);
for (const file of ['game-data.js', 'engine.js', 'console-layout.js']) vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8'), context);
Object.assign(context, context.window);
const {Game} = context.ZSEngine;
const {leds} = context.ZSConsole;
const fresh = () => {const g = new Game(); g.start(); return g;};

test('power lamp: dormant, steady, one-heart blink, game over', () => {
  const idle = new Game();
  assert.equal(leds(idle).power, 'off');
  const g = fresh();
  assert.equal(leds(g, false).power, 'off');
  assert.equal(leds(g).power, 'on');
  g.player.lives = 2;
  assert.equal(leds(g).power, 'on');
  g.player.lives = 1;
  assert.equal(leds(g).power, 'low');
  g.over = true;
  assert.equal(leds(g).power, 'off');
});

test('weapon lamp: pistol is not special; stored, equipped and arena weapons are', () => {
  const g = fresh();
  assert.equal(leds(g).weapon, 'off');
  g.player.inventory.smg = 40;
  assert.equal(leds(g).weapon, 'ready');
  g.player.inventory.smg = 0;
  g.player.gun = 'smg';
  assert.equal(leds(g).weapon, 'active');
  g.player.gun = 'pistol';
  g.player.special = {id: 'hose', left: 5};
  assert.equal(leds(g).weapon, 'active');
  g.player.special = null;
  assert.equal(leds(g).weapon, 'off');
  g.player.inventory.dmr = 12;
  g.over = true;
  assert.equal(leds(g).weapon, 'off');
});

test('retro skin ships every sprite, each is cached for offline play, the superseded svg is gone', () => {
  const skin = context.ZSData.SKINS.find(s => s.id === 'retro-handheld');
  const sw = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
  for (const file of [skin.file, 'retro-stick.png', 'retro-fire.png', 'retro-grenade.png', 'retro-menu.png', 'retro-led-power.png', 'retro-led-weapon.png', 'intro-jw.png', 'led-display.js']) {
    assert.ok(fs.existsSync(path.join(root, file)), file);
    assert.ok(sw.includes(`'./${file}'`), file + ' in sw.js');
  }
  assert.ok(!fs.existsSync(path.join(root, 'console-retro-handheld.svg')));
  assert.ok(!sw.includes('console-retro-handheld.svg'));
});

test('marquee font covers the printable range and the page loads the script', () => {
  const src = fs.readFileSync(path.join(root, 'led-display.js'), 'utf8');
  const raw = src.match(/const RAW = '([^']+)'/)[1].split('|');
  assert.equal(raw.length, 59); // ASCII 32..90
  for (const g of raw) assert.equal(g.split(' ').length, 5);
  assert.ok(fs.readFileSync(path.join(root, 'index.html'), 'utf8').includes('led-display.js'));
});
