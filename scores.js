/* Guest leaderboard client. No sign-in and no privileged key in the app. */
(() => {
'use strict';
const endpoint='https://xdsrnnkuxfaycnlngjbq.supabase.co/rest/v1/rpc/';
const key='sb_publishable_AicVoQAwV-KnlOs1Fc2RuQ_T81In0MC';
const read=(k,f)=>{try{return JSON.parse(localStorage.getItem(k))??f}catch{return f}},write=(k,v)=>{try{localStorage.setItem(k,JSON.stringify(v))}catch{}};
class Scores {
 constructor(){this.device=read('zs7-device',null);if(!/^[a-f0-9]{64}$/.test(this.device||'')){this.device=Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('');write('zs7-device',this.device)}this.best=read('zs7-bests',{});this.pending=read('zs7-pending',[]);this.flushing=false;this.rejected=new Set();addEventListener('online',()=>this.flush())}
 validName(name){return /^[\p{L}\p{N} _.-]{2,24}$/u.test(name.trim())&&/[\p{L}\p{N}]/u.test(name)}
 async rpc(name,body={}){const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),7000);try{const r=await fetch(endpoint+name,{method:'POST',headers:{'Content-Type':'application/json',apikey:key},body:JSON.stringify(body),signal:controller.signal});const value=await r.json();if(!r.ok){const error=Error(value.message||'Board unavailable');error.status=r.status;throw error;}return value}finally{clearTimeout(timer)}}
 async begin(name){try{return await this.rpc('zs7_begin_run',{p_device:this.device,p_name:name.trim()})}catch{return null}}
 getBest(name){return Number(this.best[name.toLowerCase()]||0)}
 async finish(run){if(run.practice)return {status:'practice'};const id=run.name.toLowerCase();this.best[id]=Math.max(this.getBest(run.name),run.score);write('zs7-bests',this.best);if(!run.ticket)return {status:'local'};const entry={p_device:this.device,p_ticket:run.ticket,p_score:run.score,p_kills:run.kills,p_seconds:Math.floor(run.seconds),p_wave:run.wave,p_practice:false};if(!this.pending.some(p=>p.p_ticket===entry.p_ticket))this.pending.push(entry);write('zs7-pending',this.pending);await this.flush();return {status:this.pending.some(p=>p.p_ticket===entry.p_ticket)?'pending':this.rejected.has(entry.p_ticket)?'rejected':'online'}}
 async flush(){if(this.flushing)return;this.flushing=true;try{for(const run of [...this.pending]){try{const accepted=await this.rpc('zs7_finish_run',run);if(accepted!==true)this.rejected.add(run.p_ticket);}catch(error){if(![400,404,409,422].includes(error.status))break;this.rejected.add(run.p_ticket);}this.pending=this.pending.filter(p=>p.p_ticket!==run.p_ticket);write('zs7-pending',this.pending);}}finally{this.flushing=false}}

 async board(){try{const rows=await this.rpc('zs7_leaderboard');write('zs7-board',rows);return {rows,online:true}}catch{let rows=read('zs7-board',null);if(!rows)try{rows=await(await fetch('./legacy-board.json')).json()}catch{rows=[]}return {rows,online:false}}}
 async admin(code){return this.rpc('zs7_admin',{p_device:this.device,p_code:code})}
}
window.ZSScores=Scores;
})();
