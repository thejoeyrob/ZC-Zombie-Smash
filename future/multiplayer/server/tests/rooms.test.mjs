import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {WebSocket} from '../vendor/ws/wrapper.mjs';
import {startServer,validPose,validPin} from '../server.mjs';
import {newBoard,sit,roll,tickBoard} from '../board.mjs';
async function client(url){const ws=new WebSocket(url);const queue=[];const wait=[];ws.on('message',raw=>{const p=JSON.parse(raw);queue.push(p);for(const f of [...wait])f();});await once(ws,'open');return {ws,send:p=>ws.send(JSON.stringify(p)),next:(type,condition=()=>true)=>new Promise((resolve,reject)=>{let timer;const poll=()=>{const i=queue.findIndex(p=>p.type===type&&condition(p));if(i>=0){clearTimeout(timer);const wi=wait.indexOf(poll);if(wi>=0)wait.splice(wi,1);resolve(queue.splice(i,1)[0]);}};timer=setTimeout(()=>{wait.splice(wait.indexOf(poll),1);reject(Error('Timeout: '+type));},3000);wait.push(poll);poll();})};}
test('six users, full room, host controls, leases, seats, disconnect',async()=>{
 const server=startServer({port:0});await once(server.app,'listening');const url=`ws://127.0.0.1:${server.app.address().port}/shack`;const clients=[];
 try{
 const host=await client(url);clients.push(host);host.send({type:'create',protocol:1,name:'HOST'});const h=await host.next('welcome');const room=await host.next('room');
 for(let i=0;i<5;i++){const c=await client(url);clients.push(c);c.send({type:'join',protocol:1,code:room.code,name:'Guest'+i});await c.next('welcome');}
 assert.equal(server.rooms.get(room.code).members.size,6);
 const extra=await client(url);clients.push(extra);extra.send({type:'join',protocol:1,code:room.code});assert.match((await extra.next('error')).message,/full/);
 const guest=clients[1];guest.send({type:'lock',locked:true});assert.match((await guest.next('error')).message,/Host only/);
 host.send({type:'claim',station:'pinball'});await host.next('granted');guest.send({type:'claim',station:'pinball'});assert.match((await guest.next('error')).message,/in use/);
 host.send({type:'sit',seat:0});await host.next('seated');guest.send({type:'sit',seat:0});assert.match((await guest.next('error')).message,/occupied/);
 guest.send({type:'roll',dash:true});assert.match((await guest.next('error')).message,/turn/);
 host.send({type:'roll',dash:true});const board=await host.next('board',p=>p.state.phase==='result');assert.equal(board.state.players[0].occupant,h.id);
 guest.send({type:'claim',station:'pinball'});await guest.next('granted');guest.send({type:'leave'});await guest.next('ended');await host.next('room',p=>!p.owners.pinball&&p.members.length===5);
 host.send({type:'lock',locked:true});await host.next('room',p=>p.locked);extra.send({type:'join',protocol:1,code:room.code});assert.match((await extra.next('error')).message,/locked/);
 host.ws.close();await clients[2].next('ended');assert.equal(server.rooms.size,0);
 }finally{for(const c of clients)c.ws.terminate();await server.close();}
});
test('board turn, shields, risk, win, round timeout',()=>{
 const b=newBoard();assert.equal(b.players.length,6);sit(b,'a','Alice',0);assert.equal(roll(b,'b'),false);b.players[0].shield=0;roll(b,'a',true,()=>0);assert.equal(b.players[0].pos,0);tickBoard(b,3);assert.equal(b.current,1);
 b.current=0;b.phase='wait';b.players[0].pos=25;roll(b,'a',false,()=>.99);assert.equal(b.winner,0);assert.equal(b.players[0].wins,1);tickBoard(b,8);assert.equal(b.players[0].pos,0);assert.equal(b.players[0].wins,1);
 b.current=0;b.phase='wait';b.players[0].pos=0;roll(b,'a',false,()=>.34);assert.equal(b.players[0].pos,3);assert.equal(b.again,true);assert.equal(b.players[0].shield,2);
});
test('reject malformed pose and pin state',()=>{
 const xf=[0,1.6,0,0,0,0,1];const p={head:xf,left:xf,right:xf,curls:[0,0,0,0,0,0],active:[true,true],scale:1,seated:false};assert.ok(validPose(p));assert.ok(!validPose({...p,head:[NaN,1,1,1,1,1,1]}));assert.ok(!validPose({...p,head:[0,0,0,0,0,0,0]}));assert.ok(!validPin({ball:[0,1],angles:[0,0],score:-1,balls:3,play:true,over:false}));
});
test('pinball relay accepts the lease owner only, preserving ramp and lights',async()=>{
 const server=startServer({port:0});await once(server.app,'listening');const url=`ws://127.0.0.1:${server.app.address().port}/shack`;const a=await client(url),b=await client(url);try{
 a.send({type:'create',protocol:1,name:'Host'});await a.next('welcome');const room=await a.next('room');b.send({type:'join',protocol:1,code:room.code,name:'Guest'});await b.next('welcome');
 const pin={ball:[200,100],angles:[.6,.6],score:500,balls:3,play:true,over:false,ramp:0,ramp_d:120,multiplier:2,save:4,bumps:[1,0,0],targets:[true,false,false,false,false,false,false,false]};assert.ok(validPin(pin));
 let unauthorized=0;a.ws.on('message',raw=>{if(JSON.parse(raw).type==='pin')unauthorized++;});b.send({type:'pin',station:'pinball',state:pin});await new Promise(resolve=>setTimeout(resolve,100));assert.equal(unauthorized,0);
 a.send({type:'claim',station:'pinball'});await a.next('granted');a.send({type:'pin',station:'pinball',state:pin});const got=await b.next('pin');assert.deepEqual(got.state,pin);
 }finally{a.ws.terminate();b.ws.terminate();await server.close();}
});
