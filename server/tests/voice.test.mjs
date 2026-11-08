import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {WebSocket} from '../vendor/ws/wrapper.mjs';
import {startServer} from '../server.mjs';
function open(url){const ws=new WebSocket(url);const text=[],bin=[];ws.on('message',(raw,isBinary)=>{if(isBinary)bin.push(Buffer.from(raw));else text.push(JSON.parse(raw.toString()));});return once(ws,'open').then(()=>({ws,text,bin}));}
const until=async(f,ms=2000)=>{const t=Date.now();while(Date.now()-t<ms){const v=f();if(v)return v;await new Promise(r=>setTimeout(r,10));}throw new Error('timeout');};
test('voice pieces reach everyone else in the room with the sender id, and nobody outside it',async()=>{
 const server=startServer({port:0});await once(server.app,'listening');const url=`ws://127.0.0.1:${server.app.address().port}/shack`;const all=[];
 try{
  const a=await open(url),b=await open(url),c=await open(url);all.push(a,b,c);
  a.ws.send(JSON.stringify({type:'create',protocol:1,name:'A'}));const wa=await until(()=>a.text.find(m=>m.type==='welcome'));const room=await until(()=>a.text.find(m=>m.type==='room'));
  b.ws.send(JSON.stringify({type:'join',protocol:1,code:room.code,name:'B'}));const wb=await until(()=>b.text.find(m=>m.type==='welcome'));
  c.ws.send(JSON.stringify({type:'create',protocol:1,name:'C'}));await until(()=>c.text.find(m=>m.type==='welcome'));
  assert.ok(wa.vid>=1&&wb.vid>=1&&wa.vid!==wb.vid);
  const roster=await until(()=>b.text.filter(m=>m.type==='room').pop());assert.ok(roster.members.every(m=>Number.isInteger(m.vid)));
  const piece=Buffer.from(new Array(640).fill(0x7f));a.ws.send(piece,{binary:true});
  const got=await until(()=>b.bin[0]);assert.equal(got[0],wa.vid);assert.equal(got.length,641);
  await new Promise(r=>setTimeout(r,150));assert.equal(a.bin.length,0,'sender does not hear itself');assert.equal(c.bin.length,0,'another room hears nothing');
  a.ws.send(Buffer.alloc(5000),{binary:true});await new Promise(r=>setTimeout(r,150));assert.equal(b.bin.length,1,'oversized piece is dropped');
 }finally{for(const x of all)x.ws.terminate();await server.close();}
});
