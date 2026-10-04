/* Zombie Smash 7.6. Fixed-step, fixed-world portrait simulation. */
(() => {
'use strict';
const {W,H,BOSSES}=window.ZSData;
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const ENEMIES={
 normal:{hp:2,speed:28,r:13,points:120,art:'zombie-normal.webp',height:42},
 runner:{hp:2,speed:49,r:12,points:180,art:'zombie-runner.webp',height:42},
 helmet:{hp:4,speed:25,r:14,points:240,art:'zombie-helmet.webp',height:46},
 toxic:{hp:4,speed:24,r:15,points:320,art:'zombie-toxic.webp',height:48},
 armored:{hp:6,speed:24,r:17,points:420,art:'zombie-armored.webp',height:52},
 berserker:{hp:5,speed:36,r:16,points:500,art:'zombie-berserker.webp',height:50},
 brute:{hp:9,speed:19,r:21,points:700,art:'zombie-brute.webp',height:65},
 titan:{hp:15,speed:17,r:24,points:1050,art:'zombie-titan.webp',height:75},
 fuse:{hp:3,speed:33,r:14,points:380,art:'zombie-fuse.webp',height:52},
 bulwark:{hp:9,speed:20,r:19,points:650,art:'zombie-bulwark.webp',height:61}
};
// 7.6.2: zombies are 45% larger (hitbox +30%) and 20% slower so the extra size doesn't make them feel faster.
for(const s of Object.values(ENEMIES)){s.height=Math.round(s.height*1.45);s.r=Math.round(s.r*1.3);s.speed=+(s.speed*.8).toFixed(1)}
const GUNS={
 pistol:{name:'PISTOL',delay:.22,damage:1.5,speed:600,ammo:Infinity,art:'bullet-pistol.webp'},
 smg:{name:'SMG',delay:.09,damage:1.15,speed:660,ammo:100,art:'bullet-smg.webp'},
 shotgun:{name:'SCATTER',delay:.54,damage:1.7,speed:550,ammo:24,art:'bullet-pistol.webp'},
 dmr:{name:'DMR-82',delay:.42,damage:9,speed:800,ammo:24,pierce:3,art:'bullet-dmr.webp'},
 burst:{name:'PULSE',delay:.26,damage:1.6,speed:670,ammo:60,art:'bullet-smg.webp'}
};
function segmentDistance(px,py,x1,y1,x2,y2){const dx=x2-x1,dy=y2-y1,q=clamp(((px-x1)*dx+(py-y1)*dy)/(dx*dx+dy*dy||1),0,1);return Math.hypot(px-x1-q*dx,py-y1-q*dy)}
class Game{
 constructor({onEvent=()=>{},seed=Date.now()}={}){this.onEvent=onEvent;this.seed=seed>>>0;this.reset();}
 rand(){this.seed=(1664525*this.seed+1013904223)>>>0;return this.seed/4294967296;}
 emit(type,data={}){this.onEvent(type,data)}
 reset(){Object.assign(this,{t:0,wave:1,score:0,kills:0,breaches:0,combo:0,multiplier:1,comboLeft:0,spawned:0,resolved:0,target:10,spawnIn:.6,enemies:[],bullets:[],shots:[],pickups:[],grenades:[],barrels:[],effects:[],pops:[],boss:null,scene:null,nextIn:0,active:false,over:false,practice:false,maxLives:5,invincible:false,infiniteAmmo:false,nextId:1,bossesDown:[],banner:'HOLD THE LINE',bannerLeft:2.4,hitStop:0,shake:0,dangerSource:null,player:{x:W/2,y:H-52,lives:5,gun:'pistol',ammo:Infinity,grenades:3,cool:0,inv:1.2,shield:0,rapid:0,fireFx:0,inventory:{smg:0,shotgun:0,dmr:0,burst:0}},input:{axis:0,fire:false}});}
 start(){this.active=true;if(!this.barrels.length)this.spawnBarrels();this.emit('music',{track:'main'});this.emit('wave',{wave:1});}
 setInput(axis,fire){this.input.axis=clamp(Number(axis)||0,-1,1);this.input.fire=!!fire;}
 resetInput(){this.input={axis:0,fire:false};}
 prepareWave(n){this.wave=n;this.target=Math.min(34,8+n*2);this.spawned=0;this.resolved=0;this.spawnIn=.55;this.nextIn=0;this.boss=null;this.banner=n>14?'INFINITE SURVIVAL':`WAVE ${n}`;this.bannerLeft=1.8;this.player.inv=Math.max(this.player.inv,1.1);this.spawnBarrels();this.emit('wave',{wave:n});this.emit('music',{track:'main'});}

 spawnBarrels(){this.barrels=[];const count=1+Math.floor(this.rand()*Math.min(5,2+Math.floor(this.wave/3)));for(let i=0;i<count;i++){let x,y;for(let tries=0;tries<40;tries++){x=32+this.rand()*(W-64);y=95+this.rand()*(H-195);if(this.barrels.every(b=>Math.hypot(b.x-x,b.y-y)>44))break;}if(this.barrels.some(b=>Math.hypot(b.x-x,b.y-y)<=44))continue;this.barrels.push({id:this.nextId++,x,y,hp:2,dead:false});}}
 explodeBarrel(barrel){if(!barrel||barrel.dead)return;barrel.dead=true;const r=W*.20;this.effects.push({kind:'barrelBlast',x:barrel.x,y:barrel.y,r,life:.58,total:.58,color:'#ff9d35'});this.shake=Math.max(this.shake,2.6);this.emit('explosion');for(const z of [...this.enemies,...(this.boss?[this.boss]:[])])if(!z.dead&&Math.hypot(z.x-barrel.x,z.y-barrel.y)<r+z.r)this.damage(z,z.boss?9:12,'barrel');for(const other of this.barrels)if(!other.dead&&other!==barrel&&Math.hypot(other.x-barrel.x,other.y-barrel.y)<r*.9)this.explodeBarrel(other);}
 chooseType(){const w=this.wave,r=this.rand();if(w<3)return r<.76?'normal':'runner';if(w<5)return r<.45?'normal':r<.65?'runner':r<.85?'helmet':'fuse';if(w<8)return r<.25?'normal':r<.40?'runner':r<.57?'helmet':r<.73?'toxic':r<.88?'fuse':'bulwark';const pool=['normal','runner','helmet','toxic','armored','berserker','brute','fuse','bulwark',...(w>10?['titan']:[])];return pool[Math.floor(r*pool.length)];}
 spawn(type=this.chooseType(),x=null,y=-28,minion=false){const spec=ENEMIES[type],z={id:this.nextId++,type,...spec,maxHp:spec.hp,x:x??(36+this.rand()*(W-72)),y,age:0,attack:2+this.rand()*2,flash:0,dead:false,minion,charge:0,baseX:0};z.baseX=z.x;z.speed*=(1+Math.min(.6,(this.wave-1)*.035))*Math.min(1,.85+(this.wave-1)*.0375);this.enemies.push(z);if(!minion)this.spawned++;return z;}
 step(dt){if(!this.active||this.over)return;dt=Math.min(dt,.05);this.t+=dt;this.shake=Math.max(0,this.shake-dt*16);this.bannerLeft=Math.max(0,this.bannerLeft-dt);this.effects=this.effects.filter(f=>(f.life-=dt)>0);this.pops=this.pops.filter(p=>(p.life-=dt)>0);for(const f of this.effects){f.x+=(f.vx||0)*dt;f.y+=(f.vy||0)*dt;}
  if(this.scene){this.scene.time+=dt;if(this.scene.time>=this.scene.duration)this.advanceScene();return;}
  const p=this.player;p.inv=Math.max(0,p.inv-dt);p.cool=Math.max(0,p.cool-dt);p.shield=Math.max(0,p.shield-dt);p.rapid=Math.max(0,p.rapid-dt);p.fireFx=Math.max(0,p.fireFx-dt);
  p.speedUp=Math.max(0,(p.speedUp||0)-dt);{const target=this.input.axis*212*(p.speedUp>0?1.55:1);p.vx=(p.vx||0)+(target-(p.vx||0))*Math.min(1,dt*16);if(!target&&Math.abs(p.vx)<1)p.vx=0;p.x=clamp(p.x+p.vx*dt,28,W-28);}p.y=H-52;
  if(this.hitStop>0){this.hitStop-=dt;return;}
  if(this.nextIn>0){this.nextIn-=dt;if(this.nextIn<=0)this.prepareWave(this.wave+1);this.updatePickups(dt);return;}
  if(this.comboLeft>0){this.comboLeft-=dt;if(this.comboLeft<=0)this.resetCombo();}
  if(this.input.fire)this.fire();
  if(!this.boss&&this.spawned<this.target){this.spawnIn-=dt;if(this.spawnIn<=0&&this.enemies.length<13){const z=this.spawn();if(this.spawned%5===0)z.x=p.x;this.spawnIn=Math.max(.38,.84-this.wave*.024)+(this.rand()-.5)*.18;}}
  if(this.boss)this.updateBoss(dt);
  for(const z of this.enemies){if(z.dead)continue;z.age+=dt;z.flash=Math.max(0,z.flash-dt);z.attack-=dt;let speed=z.speed;
   if(z.type==='runner'&&z.age>2){const phase=(z.age-2)%3.2;if(phase<.45){speed=2;z.charge=1}else if(phase<1){speed*=2.6;z.charge=2}else z.charge=0;}
   if(z.type==='berserker')z.x=clamp(z.baseX+Math.sin(z.age*2.7)*28,20,W-20);
   if(['brute','titan','armored'].includes(z.type))z.x+=clamp(p.x-z.x,-1,1)*11*dt;
   z.y+=speed*dt;
   if(z.type==='toxic'&&z.attack<=0&&z.y>25&&z.y<p.y-70){this.aimedShot(z.x,z.y,'venom',100,8);z.attack=4.2;}
   if(z.type==='fuse'&&z.y>p.y-16){z.dead=true;this.resolve(z);this.explode(z.x,z.y,60,3,false);if(Math.hypot(z.x-p.x,z.y-p.y)<72)this.hurt('The Fuse detonated too close.');}
   if(Math.hypot(z.x-p.x,z.y-p.y)<z.r+15){this.hurt('The horde reached Joey Rob.');z.y+=18;}
   if(z.y>H+20){z.dead=true;this.resolve(z);if(!z.minion){this.breaches++;this.resetCombo();this.emit('breach');this.banner='BASE BREACH';this.bannerLeft=.9;if(this.breaches>=10)this.end('The camp was overrun.');}}
  }
  this.updateBullets(dt);this.updateShots(dt);this.updatePickups(dt);this.updateGrenades(dt);this.enemies=this.enemies.filter(z=>!z.dead);this.barrels=this.barrels.filter(b=>!b.dead);
  if(!this.scene&&!this.boss&&this.spawned>=this.target&&this.resolved>=this.target&&!this.enemies.length&&!this.over){const def=BOSSES.find(b=>b.wave===this.wave&&!this.bossesDown.includes(b.id));if(def)this.queueBoss(def.id);else{this.nextIn=1.55;this.banner='WAVE CLEAR';this.bannerLeft=1.55;this.emit('clear');}}
 }
 fire(){const p=this.player;if(!this.active||this.over||this.scene||p.cool>0||this.nextIn>0)return false;if(p.ammo<=0&&!this.infiniteAmmo)this.equip('pistol');const gun=GUNS[p.gun],angles=p.gun==='shotgun'?[-.17,-.085,0,.085,.17]:p.gun==='burst'?[-.055,0,.055]:[0];for(const a of angles)this.bullets.push({id:this.nextId++,x:p.x,y:p.y-27,prevX:p.x,prevY:p.y-27,vx:Math.sin(a)*gun.speed,vy:-Math.cos(a)*gun.speed,damage:gun.damage,gun:p.gun,pierce:gun.pierce||1,hit:[],life:1.5});p.cool=gun.delay*(p.rapid>0?.65:1);if(Number.isFinite(p.ammo)&&!this.infiniteAmmo)p.ammo--;p.fireFx=.065;this.emit('shot',{gun:p.gun});return true;}
 updateBullets(dt){for(const b of this.bullets){b.prevX=b.x;b.prevY=b.y;b.x+=b.vx*dt;b.y+=b.vy*dt;b.life-=dt;const dx=b.x-b.prevX,dy=b.y-b.prevY,length=dx*dx+dy*dy||1;
  const hits=[...this.enemies,...(this.boss?[this.boss]:[]),...this.barrels].filter(z=>!z.dead&&!b.hit.includes(z.id)&&segmentDistance(z.x,z.y,b.prevX,b.prevY,b.x,b.y)<(z.r??12)+3).sort((a,z)=>((a.x-z.x)*dx+(a.y-z.y)*dy)/length);
  for(const z of hits){if(b.pierce<=0||z.dead||this.scene)break;b.hit.push(z.id);b.pierce--;if(z.r!==undefined)this.damage(z,b.damage,b.gun);else{z.hp-=b.damage;if(z.hp<=0)this.explodeBarrel(z);else this.emit('ricochet');}}
 }this.bullets=this.bullets.filter(b=>b.pierce>0&&b.life>0&&b.y>-35&&b.x>-20&&b.x<W+20);}
 damage(z,amount,source='pistol'){if(z.dead||this.scene||z.boss&&z.phaseGrace>0)return;const shield=z.type==='bulwark'&&(z.age%3.5)<2&&source!=='grenade'&&source!=='chain'&&source!=='dmr';if(shield){amount*=.28;this.emit('ricochet');}z.hp-=amount;z.flash=.07;this.burst(z.x,z.y,shield?'#8de8ff':'#fbd078',3,35);if(z.boss){
   // Each form owns a health segment. Excess damage never skips a reveal or a form.
   const floor=z.maxHp*(z.stages-z.stage)/z.stages;
   if(z.stage<z.stages&&z.hp<=floor){z.hp=floor;z.stage++;z.attack=1.35;z.wind=0;this.shots=[];this.bullets=[];this.grenades=[];this.emit('mutation',{stage:z.stage});this.scene={kind:'mutation',phase:0,time:0,duration:z.stage===3?2.8:1.8,bossId:z.bossId,stage:z.stage};this.resetInput();}
   else if(z.hp<=0)this.killBoss();return;}

  if(z.hp<=0){z.dead=true;this.resolve(z);this.kills++;this.combo++;this.comboLeft=7;const previous=this.multiplier;this.multiplier=this.combo>=30?10:this.combo>=20?4:this.combo>=10?2:1;const points=z.points*this.multiplier;this.addPoints(points,z.x,z.y);if(this.multiplier>previous)this.emit('boost',{multiplier:this.multiplier});this.burst(z.x,z.y,z.type==='fuse'?'#9cff65':'#bfd595',8,60);this.emit('kill',{type:z.type});if(z.type==='fuse')this.explode(z.x,z.y,85,6,false);if(this.kills%12===0||this.rand()<.045)this.drop(z.x,z.y);}
 }
 resolve(z){if(z.resolved)return;z.resolved=true;if(!z.minion)this.resolved++;}
 addPoints(n,x,y){this.score+=Math.round(n);this.pops.push({x,y,text:'+'+Math.round(n).toLocaleString(),life:.9});if(this.pops.length>12)this.pops.shift();}
 resetCombo(){this.combo=0;this.multiplier=1;this.comboLeft=0;}
 hurt(reason){const p=this.player;if(this.over||this.scene||p.inv>0||p.shield>0||this.invincible)return;p.lives--;p.inv=1.25;this.shake=2;this.resetCombo();this.emit('hurt');if(p.lives<=0)this.end(reason);}
 equip(gun,ammo=null){const g=GUNS[gun];if(!g)return;this.player.gun=gun;this.player.ammo=ammo??g.ammo;this.banner=g.name+' READY';this.bannerLeft=1.2;}
 useStored(gun){const p=this.player;if(!this.active||!p.inventory?.[gun]||!GUNS[gun]||this.scene||this.over||gun===p.gun)return false;const ammo=p.inventory[gun];if(p.gun!=='pistol'&&p.ammo>0)p.inventory[p.gun]=p.ammo;p.inventory[gun]=0;this.equip(gun,ammo);this.emit('weaponUse',{gun});return true;}
 drop(x,y,forced){const types=['grenade','shield','heart','smg','shotgun','burst','dmr'];let type=forced;if(!type){const r=this.rand();type=this.player.lives<=2&&r<.35?'heart':r<.48?'grenade':r<.62?'shield':r<.76?'speed':types[3+Math.floor(this.rand()*4)];}this.pickups.push({x:clamp(x,20,W-20),y:clamp(y,20,H-45),type,life:13,age:0});}
 updatePickups(dt){const p=this.player;for(const item of this.pickups){item.age+=dt;item.life-=dt;item.y=Math.min(H-52,item.y+37*dt);if(Math.hypot(item.x-p.x,item.y-p.y)<28){if(GUNS[item.type]){const p=this.player;if((p.inventory[item.type]||0)>0||(p.gun===item.type&&p.ammo>0)){this.addPoints(200,item.x,item.y);this.banner=GUNS[item.type].name+' ALREADY STORED';this.bannerLeft=.9;}else{p.inventory[item.type]=GUNS[item.type].ammo;this.banner=GUNS[item.type].name+' STORED';this.bannerLeft=1.2;}}else if(item.type==='heart')p.lives=Math.min(this.maxLives||5,p.lives+1);else if(item.type==='grenade')p.grenades=Math.min(9,p.grenades+2);else if(item.type==='speed'){p.speedUp=7;this.banner='SPEED UP';this.bannerLeft=1;}else if(item.type==='shield')p.shield=7;item.life=0;this.emit('pickup',{type:item.type});}}this.pickups=this.pickups.filter(i=>i.life>0);}
 grenade(){const p=this.player;if(!this.active||this.over||this.scene||this.nextIn>0||p.grenades<=0)return false;p.grenades--;const tx=p.x,ty=Math.max(48,p.y-H*.50);this.grenades.push({sx:p.x,sy:p.y-20,x:p.x,y:p.y-20,tx,ty,age:0,duration:.52});this.emit('throw');return true;}
 updateGrenades(dt){for(const g of this.grenades){g.age+=dt;const q=clamp(g.age/g.duration,0,1);g.x=g.sx+(g.tx-g.sx)*q;g.y=g.sy+(g.ty-g.sy)*q-Math.sin(q*Math.PI)*35;if(q>=1)this.explode(g.tx,g.ty,125,20,true);}this.grenades=this.grenades.filter(g=>g.age<g.duration);}
 explode(x,y,r,damage,grenade){this.effects.push({kind:'ring',x,y,r,life:.48,total:.48,color:grenade?'#ffd27b':'#92ee56'});this.burst(x,y,grenade?'#ffb341':'#a2ed55',24,160);if(grenade){this.shake=3;this.hitStop=.025;this.emit('explosion');}for(const z of [...this.enemies,...(this.boss?[this.boss]:[])])if(!z.dead&&Math.hypot(z.x-x,z.y-y)<r+z.r)this.damage(z,damage,grenade?'grenade':'chain');this.shots=this.shots.filter(s=>Math.hypot(s.x-x,s.y-y)>r);for(const barrel of this.barrels)if(!barrel.dead&&Math.hypot(barrel.x-x,barrel.y-y)<r*.85)this.explodeBarrel(barrel);}
 burst(x,y,color,n,speed){for(let i=0;i<n;i++){const a=this.rand()*Math.PI*2,v=speed*(.4+this.rand()*.6),life=.16+this.rand()*.25;this.effects.push({kind:'spark',x,y,vx:Math.cos(a)*v,vy:Math.sin(a)*v,color,life,total:life,r:1+this.rand()*2});}if(this.effects.length>180)this.effects.splice(0,this.effects.length-180);}
 aimedShot(x,y,kind,speed=120,r=9,offset=0){const a=Math.atan2(this.player.y-y,this.player.x-x)+offset;this.shots.push({x,y,vx:Math.cos(a)*speed,vy:Math.sin(a)*speed,kind,r,life:5,age:0});}
 queueBoss(id,stage=1){const def=BOSSES.find(b=>b.id===id);if(!def)return;this.boss=null;this.enemies=[];this.shots=[];this.bullets=[];this.grenades=[];this.pickups=[];this.scene={kind:'arrival',bossId:id,phase:0,time:0,duration:.7,startStage:stage};this.resetInput();this.emit('entrance',{id});this.emit('music',{track:id==='discoman'?'disco':'boss'});}
 advanceScene(){const s=this.scene;if(!s)return;if(s.kind==='arrival'&&s.phase<2){s.phase++;s.time=0;s.duration=s.phase===1?2.1:2.8;this.emit('panel',{phase:s.phase});return;}this.scene=null;if(s.kind==='arrival')this.spawnBoss(s.bossId,s.startStage||1);if(s.kind==='down'){this.nextIn=1.2;this.banner='BOSS DOWN · KEEP MOVING';this.bannerLeft=1.2;this.drop(W/2,H-75,'heart');this.drop(W/2+60,H-130,'dmr');}if(s.kind==='mutation'){this.player.inv=1.5;if(this.boss)this.boss.phaseGrace=1.4;this.emit('music',{track:this.boss?.bossId==='discoman'?'disco':'boss'});}if(s.kind==='loss'){this.over=true;this.active=false;this.emit('over',{reason:s.reason});}}
 spawnBoss(id,stage=1){const b=BOSSES.find(x=>x.id===id);if(!b)return;this.boss={id:this.nextId++,boss:true,bossId:id,name:b.name,x:W/2,y:105,r:31,maxHp:b.hp,hp:b.hp*(1-(stage-1)/b.stages),stages:b.stages,stage,phaseGrace:1.4,age:0,attack:1.2,flash:0,dead:false,wind:0,cycle:0};this.player.inv=1.5;this.banner='';this.emit('fight',{id});}
 setTenHearts(on){this.practice=true;this.maxLives=on?10:5;this.player.lives=on?10:Math.min(this.player.lives,5);}
 skipBoss(id,stage=1){this.practice=true;this.active=true;this.over=false;this.nextIn=0;this.player.lives=this.maxLives||5;this.player.grenades=9;this.player.inv=2;this.spawned=this.target;this.resolved=this.target;const def=BOSSES.find(b=>b.id===id);this.wave=def.wave;this.queueBoss(id,clamp(stage,1,def.stages));}
 updateBoss(dt){const b=this.boss;if(!b||b.dead)return;b.phaseGrace=Math.max(0,(b.phaseGrace||0)-dt);b.age+=dt;b.flash=Math.max(0,b.flash-dt);b.attack-=dt;if(!this.shots.some(s=>s.kind==='chain'&&s.life>0)){const targetX=W/2+Math.sin(b.age*(.6+b.stage*.13))*Math.min(95,62+b.stage*11);b.x+=clamp(targetX-b.x,-90*dt,90*dt);b.y=105+Math.sin(b.age*.8)*7;}if(b.attack>.6&&b.attack<1.1)b.wind=1;else b.wind=0;if(b.attack>0)return;b.cycle++;b.attack=Math.max(.9,2.3-b.stage*.28);
  switch(b.bossId){
   case 'jordan':for(let i=-1;i<=1;i++)this.aimedShot(b.x,b.y,'ember',112+b.stage*12,8,i*.25);break;
   case 'glowinghumanity':for(let i=-2;i<=2;i++)this.aimedShot(b.x,b.y,b.stage===2&&i===0?'bodypart':'venom',105+b.stage*5,i===0?13:9,i*.22);break;
   case 'debo':{const dx=this.player.x-b.x,dy=this.player.y-b.y,l=Math.hypot(dx,dy);this.shots.push({kind:'chain',ox:b.x,oy:b.y,x:b.x,y:b.y,dx:dx/l,dy:dy/l,reach:l+22,r:17,age:0,life:2.2,wind:.65});if(b.stage===2)for(const offset of [-.28,.28])this.aimedShot(b.x,b.y,'handcuffs',125,11,offset);b.attack=2.7;break;}
   case 'caffeinatedsloth':for(const offset of [-.24,0,.24])this.aimedShot(b.x,b.y,b.stage>1?'venom':'coffee',150+b.stage*16,11,offset);b.attack=b.stage>1?.78:1.08;break;
   case 'discoman':for(let i=-2;i<=2;i++)this.aimedShot(b.x,b.y,'disco',105+b.stage*20,12,i*.32);b.attack=1.9;break;
   case 'fatamy':this.aimedShot(b.x-20,b.y,b.cycle%2?'burger':'donut',110,18,-.2);this.aimedShot(b.x+20,b.y,'donut',130,14,.2);break;
   case 'drmantis':for(let i=-1;i<=1;i++)this.aimedShot(b.x,b.y,b.stage===3?'venom':'missile',140+b.stage*12,10,i*.27);if(b.stage>=2&&b.cycle%3===0&&this.enemies.length<3){this.spawn('runner',b.x-35,b.y+40,true);this.spawn('runner',b.x+35,b.y+40,true);}break;
  }this.emit('bossAttack',{id:b.bossId});
 }
 updateShots(dt){const p=this.player;for(const s of this.shots){s.age+=dt;s.life-=dt;if(s.kind==='chain'){const q=s.age<s.wind?0:s.age<s.wind+.45?(s.age-s.wind)/.45:s.age<s.wind+.75?1:Math.max(0,1-(s.age-s.wind-.75)/.65);s.x=s.ox+s.dx*s.reach*q;s.y=s.oy+s.dy*s.reach*q;if(s.age>s.wind+1.4)s.life=0;}else{s.x+=s.vx*dt;s.y+=s.vy*dt;if(['donut','disco'].includes(s.kind)&&(s.x<s.r||s.x>W-s.r)){s.vx*=-1;s.x=clamp(s.x,s.r,W-s.r);}}if(s.kind==='chain'&&s.age<s.wind)continue;if(Math.hypot(s.x-p.x,s.y-p.y)<s.r+10){this.hurt(this.boss?BOSSES.find(b=>b.id===this.boss.bossId).playerLoss:'Toxic spit caught Joey.');if(s.kind!=='chain')s.life=0;}}
  this.shots=this.shots.filter(s=>s.life>0&&s.y<H+35&&s.x>-60&&s.x<W+60);}
 killBoss(){const b=this.boss,def=BOSSES.find(d=>d.id===b.bossId);if(b.dead)return;b.dead=true;this.kills++;this.addPoints(def.points*this.multiplier,b.x,b.y);this.bossesDown.push(b.bossId);this.shots=[];this.enemies=[];this.bullets=[];this.burst(b.x,b.y,def.accent,35,120);this.scene={kind:'down',bossId:b.bossId,stage:b.stage,phase:0,time:0,duration:3.4};this.resetInput();this.emit('bossDown');this.boss=null;}
 end(reason){if(this.over||this.scene?.kind==='loss')return;const id=this.boss?.bossId;this.dangerSource=id;this.scene={kind:'loss',bossId:id,phase:0,time:0,duration:id?3.2:1.1,reason};this.resetInput();this.emit('death');}
 snapshot(){const copy=JSON.parse(JSON.stringify(this));delete copy.onEvent;copy.input={axis:0,fire:false};return copy;}
 restore(saved){if(!saved||typeof saved.t!=='number'||!saved.player)return false;const fn=this.onEvent;Object.assign(this,saved);this.onEvent=fn;this.player.ammo=this.player.ammo??GUNS[this.player.gun].ammo;this.player.inventory={smg:0,shotgun:0,dmr:0,burst:0,...(this.player.inventory||{})};this.player.y=H-52;if(!Array.isArray(saved.barrels))this.spawnBarrels();else this.barrels=saved.barrels;this.resetInput();return true;}
}
window.ZSEngine={Game,ENEMIES,GUNS,segmentDistance,clamp};
})();
