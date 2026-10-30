// Exports the shared game data (bosses, arena maps) from game-data.js to quest/data/zs_data.json.
import { readFileSync, writeFileSync } from 'node:fs';
import vm from 'node:vm';
const root = new URL('../../', import.meta.url).pathname;
const ctx = { window: {} }; vm.createContext(ctx);
vm.runInContext(readFileSync(root + 'game-data.js', 'utf8'), ctx);
const d = ctx.window.ZSData;
const out = { W: d.W, H: d.H, BOSSES: d.BOSSES, MAPS: d.MAPS };
writeFileSync(root + 'quest/data/zs_data.json', JSON.stringify(out));
console.log('bosses', d.BOSSES.length, 'maps', d.MAPS.length);
