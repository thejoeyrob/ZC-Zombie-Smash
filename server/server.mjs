import http from 'node:http';
import {randomInt,randomUUID} from 'node:crypto';
import {WebSocketServer,WebSocket} from './vendor/ws/wrapper.mjs';
import {newBoard,sit,stand,roll,tickBoard} from './board.mjs';
import {pathToFileURL} from 'node:url';
const stations=new Set(['m0','m1','m2','m3','m4','m5','pinball','pinball2']);
const send=(ws,p)=>{if(ws.readyState===WebSocket.OPEN&&ws.bufferedAmount<65536)ws.send(JSON.stringify(p));};
export function startServer({port=Number(process.env.PORT||8080),host=process.env.BIND||'127.0.0.1',random=Math.random}={}){
 const rooms=new Map(), clients=new Set(), attempts=new Map();
 const app=http.createServer((req,res)=>{res.writeHead(req.url==='/health'?200:404,{'Content-Type':'application/json'});res.end(JSON.stringify({ok:req.url==='/health',protocol:1}));});
 const wss=new WebSocketServer({noServer:true,maxPayload:16384,perMessageDeflate:false});
 app.on('upgrade',(req,socket,head)=>{
  // Rate limit the actual TCP peer. Do NOT trust client-supplied X-Forwarded-For.
  const ip=socket.remoteAddress||'unknown',now=Date.now();let r=attempts.get(ip);if(!r||now-r.at>60000)r={at:now,n:0};r.n++;attempts.set(ip,r);
  if(req.url!=='/shack'||clients.size>=600||r.n>120){socket.end('HTTP/1.1 429 Too Many Requests\r\nConnection: close\r\n\r\n');return;}
  wss.handleUpgrade(req,socket,head,ws=>wss.emit('connection',ws,req));
 });
 function broadcast(r,p,except=null){for(const c of r.members.values())if(c!==except)send(c,p);}
 function roster(r){broadcast(r,{type:'room',code:r.code,host:r.host,locked:r.locked,owners:r.owners,members:[...r.members.values()].map(c=>({id:c.id,name:c.name,skin:c.skin,vid:c.vid}))});}
 function release(r,c){stand(r.board,c.id);for(const k of Object.keys(r.owners))if(r.owners[k]===c.id)delete r.owners[k];}
 function leave(c){const r=rooms.get(c.room);c.room='';if(!r)return;
  if(r.host===c.id){for(const m of r.members.values()){m.room='';send(m,{type:'ended',message:'Host left. You are now playing solo.'});}rooms.delete(r.code);return;}
  release(r,c);r.members.delete(c.id);roster(r);
 }
 wss.on('connection',c=>{c.id=randomUUID();c.room='';c.alive=true;c.window=Date.now();c.count=0;c.vwindow=Date.now();c.vcount=0;c.vid=0;c.admissions=0;c.connected=Date.now();clients.add(c);
 c.on('pong',()=>c.alive=true);c.on('error',()=>{});c.on('close',()=>{leave(c);clients.delete(c);});
 c.on('message',(raw,binary)=>{const now=Date.now();if(binary)raw=Buffer.from(raw);
 if(binary){
  const vr0=rooms.get(c.room);
  // remote play: the host streams a game it is running to one guest (0xE1 picture, 0xE2 sound, [kind, guest voice id, ...]); a guest sends its buttons to the host (0xE3, [kind, ...]). The game files never leave the host.
  if(vr0&&raw.length>=2&&(raw[0]===0xE1||raw[0]===0xE2||raw[0]===0xE3)){
   if(now-c.ewindow>=1000||c.ewindow===undefined){c.ewindow=now;c.ecount=0;}if(++c.ecount>120||raw.length>16000)return;
   const host=vr0.members.get(vr0.host);
   if(raw[0]===0xE3){if(c.id===vr0.host||!host||host.readyState!==WebSocket.OPEN||raw.length>8)return;host.send(Buffer.concat([Buffer.from([0xE3,c.vid]),raw.subarray(1)]),{binary:true});return;}
   if(c.id!==vr0.host||raw.length<3)return;
   for(const m of vr0.members.values())if(m!==c&&m.vid===raw[1]&&m.readyState===WebSocket.OPEN&&m.bufferedAmount<262144)m.send(Buffer.concat([Buffer.from([raw[0]]),raw.subarray(2)]),{binary:true});
   return;
  }
  // voice: a short piece of sound for everyone else in the room, tagged with the sender's voice id
  const vr=vr0;if(!vr||!c.vid||raw.length<2||raw.length>2048)return;if(raw[0]===1)raw=raw.subarray(1);if(raw.length<1)return;
  if(now-c.vwindow>=1000){c.vwindow=now;c.vcount=0;}if(++c.vcount>40)return;
  const out=Buffer.concat([Buffer.from([c.vid]),raw]);
  for(const m of vr.members.values())if(m!==c&&m.readyState===WebSocket.OPEN&&m.bufferedAmount<131072)m.send(out,{binary:true});
  return;
 }
if(now-c.window>=1000){c.window=now;c.count=0;}if(++c.count>30)return c.close(1008,'Rate limit');
 let p;try{p=JSON.parse(raw.toString());}catch{return c.close(1007,'Invalid JSON');}if(!p||typeof p!=='object'||Array.isArray(p))return;
 const error=message=>send(c,{type:'error',message,request:p.request||''});
 if(p.type==='create'||p.type==='join'){
  if(c.room)return error('Leave your current room first.');if(++c.admissions>12)return c.close(1008,'Too many room attempts');if(p.protocol!==1)return error('Please update the game.');
  c.name=String(p.name||'PLAYER').replace(/[^a-zA-Z0-9 _-]/g,'').trim().slice(0,20)||'PLAYER';c.skin=['human_m01','human_f02','human_joeyrob','human_discoman','human_fatamy','human_drmantis','human_debo','human_glowing','human_jordan','human_riley','human_caffeinatedsloth'].includes(p.skin)?p.skin:'human_m01';
  let r;if(p.type==='create'){if(rooms.size>=100)return error('Server busy. Try later.');let code;do{code=String(randomInt(10000000,100000000));}while(rooms.has(code));r={code,host:c.id,locked:false,members:new Map(),owners:{},board:newBoard(),library:[]};rooms.set(code,r);}else{r=rooms.get(String(p.code));if(!r)return error('Room not found.');if(r.locked)return error('Room is locked.');if(r.members.size>=6)return error('Room is full (6 players).');}
  {const used=new Set([...r.members.values()].map(m=>m.vid));let v=1;while(used.has(v))v++;c.vid=v;}c.room=r.code;r.members.set(c.id,c);send(c,{type:'welcome',id:c.id,vid:c.vid});roster(r);send(c,{type:'board',state:{...r.board,deck:[]}});send(c,{type:'library',games:r.library});return;
 }
 const r=rooms.get(c.room);if(!r)return error('Create or join a room first.');
 switch(p.type){
 case 'leave':leave(c);send(c,{type:'ended',message:'Left room.'});break;
 case 'lock':if(c.id!==r.host)return error('Host only.');r.locked=!!p.locked;roster(r);break;
 case 'kick':{if(c.id!==r.host)return error('Host only.');const victim=r.members.get(p.id);if(victim&&victim!==c){leave(victim);send(victim,{type:'ended',message:'Removed by host.'});}break;}
 case 'claim':{if(!stations.has(p.station))return error('Unknown station.');if(r.owners[p.station]&&r.owners[p.station]!==c.id)return error('Station is in use.');release(r,c);r.owners[p.station]=c.id;roster(r);send(c,{type:'granted',station:p.station});break;}
 case 'release':release(r,c);roster(r);break;
 case 'sit':if(!sit(r.board,c.id,c.name,p.seat))return error('Seat is occupied.');for(const k of Object.keys(r.owners))if(r.owners[k]===c.id)delete r.owners[k];roster(r);send(c,{type:'seated',seat:p.seat});break;
 case 'stand':stand(r.board,c.id);break;
 case 'library':{if(c.id!==r.host)return error('Host only.');const games=Array.isArray(p.games)?p.games.slice(0,150).map(g=>({n:String(g&&g.n||'').replace(/[^a-zA-Z0-9 _.'&!-]/g,'').slice(0,28),s:String(g&&g.s||'').replace(/[^a-zA-Z0-9 ]/g,'').slice(0,18)})).filter(g=>g.n):[];r.library=games;broadcast(r,{type:'library',games},c);break;}
 case 'emu_play':{if(c.id===r.host)break;const h=r.members.get(r.host);if(h)send(h,{type:'emu_play',from:c.vid,game:Number.isInteger(p.game)?p.game:-1});break;}
 case 'emu_stop':{if(c.id===r.host)break;const h=r.members.get(r.host);if(h)send(h,{type:'emu_stop',from:c.vid});break;}
 case 'emu_ok':case 'emu_no':case 'emu_end':{if(c.id!==r.host)break;for(const m of r.members.values())if(m.vid===p.to)send(m,{type:p.type,message:String(p.message||'').slice(0,60),rate:Number.isFinite(p.rate)?p.rate:0,aspect:Number.isFinite(p.aspect)?p.aspect:0});break;}
 case 'roll':if(!roll(r.board,c.id,p.dash===true,random))return error('Wait for your turn.');break;
 case 'pose':if(validPose(p.pose))broadcast(r,{type:'pose',id:c.id,pose:p.pose},c);break;
 case 'pin':if(['pinball','pinball2'].includes(p.station)&&r.owners[p.station]===c.id&&validPin(p.state))broadcast(r,{type:'pin',station:p.station,state:p.state},c);break;
 case 'appearance':if(['human_m01','human_f02','human_joeyrob','human_discoman','human_fatamy','human_drmantis','human_debo','human_glowing','human_jordan','human_riley','human_caffeinatedsloth'].includes(p.skin)){c.skin=p.skin;roster(r);}break;
 default:error('Unknown action.');
 }
 });
 });
 const tick=setInterval(()=>{for(const r of rooms.values()){tickBoard(r.board,.2,random);broadcast(r,{type:'board',state:{...r.board,deck:[]}});}},200);
 const heartbeat=setInterval(()=>{const now=Date.now();for(const c of clients){if(!c.alive||(!c.room&&now-c.connected>120000)){c.terminate();continue;}c.alive=false;c.ping();}for(const [ip,r]of attempts)if(now-r.at>60000)attempts.delete(ip);},20000);
 app.listen(port,host);
 return {app,rooms,close:async()=>{clearInterval(tick);clearInterval(heartbeat);for(const c of clients)c.terminate();wss.close();await new Promise(resolve=>app.close(resolve));}};
}
function nums(x,n,bound){return Array.isArray(x)&&x.length===n&&x.every(v=>typeof v==='number'&&Number.isFinite(v)&&Math.abs(v)<=bound);}
export function validPose(p){return p&&typeof p==='object'&&['head','left','right'].every(k=>nums(p[k],7,20)&&p[k].slice(3).reduce((s,v)=>s+v*v,0)>.5&&p[k].slice(3).reduce((s,v)=>s+v*v,0)<1.5)&&(!Object.hasOwn(p,"wrists")||(Array.isArray(p.wrists)&&p.wrists.length===2&&p.wrists.every(v=>nums(v,3,20))))&&nums(p.curls,6,1)&&Array.isArray(p.active)&&p.active.length===2&&p.active.every(v=>typeof v==='boolean')&&typeof p.seated==='boolean'&&typeof p.scale==='number'&&p.scale>=.8&&p.scale<=1.3;}
export function validPin(p){return p&&nums(p.ball,2,1500)&&nums(p.angles,2,4)&&Number.isInteger(p.score)&&p.score>=0&&p.score<=1000000000&&Number.isInteger(p.balls)&&p.balls>=0&&p.balls<=5&&typeof p.play==='boolean'&&typeof p.over==='boolean'&&Number.isInteger(p.ramp)&&p.ramp>=-1&&p.ramp<=1&&Number.isFinite(p.ramp_d)&&p.ramp_d>=0&&p.ramp_d<=2000&&Number.isInteger(p.multiplier)&&p.multiplier>=1&&p.multiplier<=5&&Number.isFinite(p.save)&&p.save>=0&&p.save<=8&&nums(p.bumps,3,1)&&Array.isArray(p.targets)&&p.targets.length===8&&p.targets.every(v=>typeof v==='boolean');}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)startServer();
