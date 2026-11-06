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
 function roster(r){broadcast(r,{type:'room',code:r.code,host:r.host,locked:r.locked,owners:r.owners,members:[...r.members.values()].map(c=>({id:c.id,name:c.name,skin:c.skin}))});}
 function release(r,c){stand(r.board,c.id);for(const k of Object.keys(r.owners))if(r.owners[k]===c.id)delete r.owners[k];}
 function leave(c){const r=rooms.get(c.room);c.room='';if(!r)return;
  if(r.host===c.id){for(const m of r.members.values()){m.room='';send(m,{type:'ended',message:'Host left. You are now playing solo.'});}rooms.delete(r.code);return;}
  release(r,c);r.members.delete(c.id);roster(r);
 }
 wss.on('connection',c=>{c.id=randomUUID();c.room='';c.alive=true;c.window=Date.now();c.count=0;c.admissions=0;c.connected=Date.now();clients.add(c);
 c.on('pong',()=>c.alive=true);c.on('error',()=>{});c.on('close',()=>{leave(c);clients.delete(c);});
 c.on('message',(raw,binary)=>{if(binary)return c.close(1003,'Text only');const now=Date.now();if(now-c.window>=1000){c.window=now;c.count=0;}if(++c.count>30)return c.close(1008,'Rate limit');
 let p;try{p=JSON.parse(raw.toString());}catch{return c.close(1007,'Invalid JSON');}if(!p||typeof p!=='object'||Array.isArray(p))return;
 const error=message=>send(c,{type:'error',message,request:p.request||''});
 if(p.type==='create'||p.type==='join'){
  if(c.room)return error('Leave your current room first.');if(++c.admissions>12)return c.close(1008,'Too many room attempts');if(p.protocol!==1)return error('Please update the game.');
  c.name=String(p.name||'PLAYER').replace(/[^a-zA-Z0-9 _-]/g,'').trim().slice(0,20)||'PLAYER';c.skin=['human_m01','human_f02'].includes(p.skin)?p.skin:'human_m01';
  let r;if(p.type==='create'){if(rooms.size>=100)return error('Server busy. Try later.');let code;do{code=String(randomInt(10000000,100000000));}while(rooms.has(code));r={code,host:c.id,locked:false,members:new Map(),owners:{},board:newBoard()};rooms.set(code,r);}else{r=rooms.get(String(p.code));if(!r)return error('Room not found.');if(r.locked)return error('Room is locked.');if(r.members.size>=6)return error('Room is full (6 players).');}
  c.room=r.code;r.members.set(c.id,c);send(c,{type:'welcome',id:c.id});roster(r);send(c,{type:'board',state:{...r.board,deck:[]}});return;
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
 case 'roll':if(!roll(r.board,c.id,p.dash===true,random))return error('Wait for your turn.');break;
 case 'pose':if(validPose(p.pose))broadcast(r,{type:'pose',id:c.id,pose:p.pose},c);break;
 case 'pin':if(['pinball','pinball2'].includes(p.station)&&r.owners[p.station]===c.id&&validPin(p.state))broadcast(r,{type:'pin',station:p.station,state:p.state},c);break;
 case 'appearance':if(['human_m01','human_f02'].includes(p.skin)){c.skin=p.skin;roster(r);}break;
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
