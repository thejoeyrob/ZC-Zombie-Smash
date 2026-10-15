const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),storage=new Map(),context={window:{},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},crypto:require('node:crypto').webcrypto,addEventListener(){},document:{addEventListener(){},hidden:false},setTimeout,clearTimeout,AbortController,console};vm.createContext(context);
for(const f of ['game-data.js','engine.js','scores.js'])vm.runInContext(fs.readFileSync(path.join(root,f),'utf8'),context);Object.assign(context,context.window);const {ZSData:D,ZSEngine:E,ZSScores:Scores}=context.window;
(async()=>{
 const a=new Scores();a.recordLocal({name:'Player',score:12345,seconds:2});assert.equal(new Scores().getBest(' player '),12345);a.recordLocal({name:'Player',score:2});assert.equal(a.getBest('player'),12345);a.recordLocal({name:'Practice',score:999999,practice:true});assert.equal(a.getBest('practice'),0);assert.equal(a.getBest('constructor'),0);
 a.rpc=async()=>{const e=Error('offline');e.status=404;throw e;};await a.finish({name:'Player',score:13000,kills:2,seconds:3,wave:1,ticket:'t1'});assert.equal(a.pending.length,1);
 let release;a.rpc=()=>new Promise(r=>release=r);const first=a.flush();const second=a.finish({name:'Player',score:14000,kills:3,seconds:4,wave:2,ticket:'t2'});release(true);await new Promise(r=>setImmediate(r));release(true);await Promise.all([first,second]);assert.equal(a.pending.length,0);assert.equal(new Scores().getBest('PLAYER'),14000);
 a.rpc=async()=>({wrong:true});assert.equal((await a.board()).online,false);
 const g=new E.Game();g.start();g.updateArena(0);g.arena.targets.forEach(t=>g.hitArenaTarget(t));assert.equal(g.arena.cool,12);assert.equal(g.arena.slow,4);g.updateArena(12);assert(g.arena.targets.every(t=>!t.lit));
 g.barrels=[];
 const t=g.arena.targets[0];g.bullets=[{x:t.x,y:t.y+30,vx:0,vy:-600,life:1,pierce:1,hit:[],damage:1,gun:'pistol'}];g.updateBullets(.1);assert(t.lit);assert.equal(g.bullets.length,1);
 for(let map=0;map<7;map++)for(const type of Object.keys(E.ENEMIES).filter(x=>x!=='mantismini')){
  g.reset();g.start();g.prepareWave(map*2+1);g.barrels=[];const z=g.spawn(type);g.target=g.spawned;g.player.inv=999;
  assert(D.MAPS[map].entries.some(([x,y])=>Math.abs(z.x-x)<=4&&z.y===y));assert(z.route);
  const start=z.x;for(let i=0;i<800 && !z.dead && !g.scene;i++){g.step(.02);assert(z.x>=D.MAPS[map].corridor[0]&&z.x<=D.MAPS[map].corridor[1]);}
  assert.notEqual(z.x,start);
 }
 g.reset();g.start();g.spawn('normal');g.updateArena(0);const saved=g.snapshot(),restored=new E.Game();assert(restored.restore(saved));assert.equal(restored.enemies[0].speed,g.enemies[0].speed);assert.equal(restored.enemies[0].route.toX,g.enemies[0].route.toX);
 for(let i=0;i<14;i++)assert.equal(D.mapIndex(i+1),Math.floor(i/2));assert.equal(D.mapIndex(15),0);assert.equal(D.mapIndex(28),6);assert.equal(D.mapIndex(29),0);
 g.prepareWave(9);g.updateArena(0);g.arena.targets.forEach(t=>g.hitArenaTarget(t));assert.equal(g.player.shield,3);
 g.spawnBoss('discoman');g.boss.attack=0;for(let i=0;i<200&&!g.shots.some(s=>s.kind==='record');i++)g.updateBoss(.02);assert(g.shots.some(s=>s.kind==='record'));
 const source=fs.readFileSync(path.join(root,'game.js'),'utf8');assert(source.includes('CHEATS'));assert(source.includes('feedToken'));assert(!source.includes('iconPanel'));
 console.log('PASS: local persistence, queued retry/concurrency, invalid responses, floor targets, 70 enemy/map routes, route saves, map progression, vinyl attacks and cheat retention.');
})().catch(e=>{console.error(e);process.exitCode=1;});
