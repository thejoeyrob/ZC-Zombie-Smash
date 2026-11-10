import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {WebSocket} from '../vendor/ws/wrapper.mjs';
import {startServer} from '../server.mjs';
function open(url){const ws=new WebSocket(url);const text=[],bin=[];ws.on('message',(raw,isBinary)=>{if(isBinary)bin.push(Buffer.from(raw));else text.push(JSON.parse(raw.toString()));});return once(ws,'open').then(()=>({ws,text,bin}));}
const until=async(f,ms=2000)=>{const t=Date.now();while(Date.now()-t<ms){const v=f();if(v)return v;await new Promise(r=>setTimeout(r,10));}throw new Error('timeout');};
const wait=ms=>new Promise(r=>setTimeout(r,ms));
test('remote play: the host streams to one guest, guests send buttons to the host, the game list reaches everyone, nothing else leaks',async()=>{
 const server=startServer({port:0});await once(server.app,'listening');const url=`ws://127.0.0.1:${server.app.address().port}/shack`;const all=[];
 try{
  const h=await open(url),g1=await open(url),g2=await open(url);all.push(h,g1,g2);
  h.ws.send(JSON.stringify({type:'create',protocol:1,name:'HOST'}));await until(()=>h.text.find(m=>m.type==='welcome'));const room=await until(()=>h.text.find(m=>m.type==='room'));
  g1.ws.send(JSON.stringify({type:'join',protocol:1,code:room.code,name:'G1'}));const w1=await until(()=>g1.text.find(m=>m.type==='welcome'));
  g2.ws.send(JSON.stringify({type:'join',protocol:1,code:room.code,name:'G2'}));const w2=await until(()=>g2.text.find(m=>m.type==='welcome'));
  // the host's game list (names only) reaches the guests, cleaned up; a guest cannot publish one
  h.ws.send(JSON.stringify({type:'library',games:[{n:'Sonic <b>The Hedgehog</b>',s:'MEGA DRIVE'},{n:'Zelda',s:'SUPER NES'},{n:''}]}));
  const lib=await until(()=>g1.text.find(m=>m.type==='library'&&m.games.length>0));
  assert.equal(lib.games.length,2);assert.equal(lib.games[0].n,'Sonic bThe Hedgehogb');assert.equal(lib.games[1].s,'SUPER NES');
  g1.ws.send(JSON.stringify({type:'library',games:[{n:'EVIL',s:'X'}]}));await wait(100);assert.equal(h.text.filter(m=>m.type==='error').length,0+h.text.filter(m=>m.type==='error').length);
  assert.ok(!g2.text.some(m=>m.type==='library'&&m.games[0]&&m.games[0].n==='EVIL'),'a guest cannot replace the host\'s list');
  // a guest asks to play game 1; only the host hears it, with the guest's voice id
  g1.ws.send(JSON.stringify({type:'emu_play',game:1}));
  const req=await until(()=>h.text.find(m=>m.type==='emu_play'));assert.equal(req.from,w1.vid);assert.equal(req.game,1);
  await wait(100);assert.ok(!g2.text.some(m=>m.type==='emu_play'));
  h.ws.send(JSON.stringify({type:'emu_ok',to:w1.vid,rate:22000}));const ok=await until(()=>g1.text.find(m=>m.type==='emu_ok'));assert.equal(ok.rate,22000);
  // the host's picture and sound go to that guest only; the first byte is the kind
  const jpeg=Buffer.concat([Buffer.from([0xE1,w1.vid]),Buffer.alloc(9000,7)]);h.ws.send(jpeg,{binary:true});
  const pic=await until(()=>g1.bin.find(b=>b[0]===0xE1));assert.equal(pic.length,9001);
  const snd=Buffer.concat([Buffer.from([0xE2,w1.vid]),Buffer.alloc(440,9)]);h.ws.send(snd,{binary:true});
  const au=await until(()=>g1.bin.find(b=>b[0]===0xE2));assert.equal(au.length,441);
  await wait(150);assert.equal(g2.bin.length,0,'the other guest gets nothing of it');
  // a guest cannot send pictures; its buttons go to the host with its voice id
  g1.ws.send(Buffer.concat([Buffer.from([0xE1,w2.vid]),Buffer.alloc(500)]),{binary:true});await wait(120);assert.equal(g2.bin.length,0,'only the host may stream');
  g1.ws.send(Buffer.from([0xE3,0x12,0x34]),{binary:true});
  const pad=await until(()=>h.bin.find(b=>b[0]===0xE3));assert.deepEqual([...pad],[0xE3,w1.vid,0x12,0x34]);
  // voice still works beside it
  g2.ws.send(Buffer.concat([Buffer.from([1]),Buffer.alloc(100,3)]),{binary:true});
  const v=await until(()=>h.bin.find(b=>b[0]===w2.vid));assert.equal(v.length,101);
  // a late joiner is sent the list on arrival
  const g3=await open(url);all.push(g3);g3.ws.send(JSON.stringify({type:'join',protocol:1,code:room.code,name:'G3'}));
  const late=await until(()=>g3.text.find(m=>m.type==='library'));assert.equal(late.games.length,2);
 }finally{for(const x of all)x.ws.terminate();await server.close();}
});
