// Frustration (UK) / Trouble (US): four players, four pegs each, a loop of 28 spaces and a four-space home lane per player.
// A peg's place: -1 = in its home area, 0..27 = on the loop counted from its own start space, 28..31 = in its home lane (31 is the last hole).
// Roll a 6 to bring a peg out onto your start space (and roll again). Land on another player's peg and it goes back home.
// You cannot land on your own peg, and you need the exact number to go past the end of your lane. First to fill all four holes wins.
// The same rules are in quest/scripts/board_game.gd (used when playing without a room); keep the two in step.
export const names=['OPEN SEAT','OPEN SEAT','OPEN SEAT','OPEN SEAT'];
export const SEATS=names.length;
export const LOOP=28, LANE_END=31;
export const START=[24,3,10,17];
export function newBoard(){return {players:names.map(name=>({name,occupant:'',pegs:[-1,-1,-1,-1],wins:0})),current:0,winner:-1,phase:'wait',remaining:1.6,die:1,tries:3,again:false,legal:[],last:'',message:'FRUSTRATION — FOUR SEATS',round:1,deck:[]};}
export function sit(b,id,name,seat){
 if(!id||!Number.isInteger(seat)||seat<0||seat>=SEATS||(b.players[seat].occupant&&b.players[seat].occupant!==id))return false;
 if(b.players[seat].occupant===id)return true;
 stand(b,id);Object.assign(b.players[seat],{occupant:id,name});
 if(!b.players[b.current].occupant){b.current=seat;b.phase='wait';b.legal=[];b.again=false;b.tries=3;}
 b.message='PRESS DOME TO ROLL';return true;
}
export function stand(b,id){
 if(!id)return;
 for(let i=0;i<SEATS;i++)if(b.players[i].occupant===id){
  Object.assign(b.players[i],{occupant:'',name:names[i],pegs:[-1,-1,-1,-1]});
  if(i===b.current){b.again=false;nextTurn(b);}
 }
}
const onBoard=p=>p.pegs.some(r=>r>=0);
export function absSpace(seat,rel){return (START[seat]+rel)%LOOP;}
export function legalMoves(b){const p=b.players[b.current],d=b.die,out=[];
 for(let k=0;k<4;k++){const r=p.pegs[k];let t;
  if(r<0){if(d!==6)continue;t=0;}else{t=r+d;if(t>LANE_END)continue;}
  if(p.pegs.some((q,j)=>j!==k&&q===t))continue;
  out.push(k);}
 return out;}
export function roll(b,id,_dash,random=Math.random){if(!id||b.phase!=='wait'||b.players[b.current].occupant!==id)return false;return doRoll(b,random);}
function doRoll(b,random){const p=b.players[b.current];
 b.die=1+Math.floor(random()*6);b.legal=legalMoves(b);
 if(b.legal.length===0){b.phase='pass';b.remaining=1.4;
  b.message=`${p.name} ROLLS ${b.die} — NO MOVE`;return true;}
 b.phase='move';
 b.remaining=(p.occupant&&b.legal.length>1)?25:1.0;
 b.message=`${p.name} ROLLS ${b.die}`+(b.legal.length>1?' — CHOOSE A PEG':'');
 return true;}
export function aiPick(b){const p=b.players[b.current],d=b.die;let best=b.legal[0],bs=-1;
 for(const k of b.legal){const r=p.pegs[k];const t=r<0?0:r+d;let s=t;
  if(r<0)s+=40;
  if(t>=28)s+=35;
  if(t<=27){const a=absSpace(b.current,t);for(let i=0;i<SEATS;i++)if(i!==b.current)for(const q of b.players[i].pegs)if(q>=0&&q<=27&&absSpace(i,q)===a)s+=60;}
  if(r>=0&&r<28&&t>=28)s+=10;
  if(s>bs){bs=s;best=k;}}
 return best;}
export function move(b,id,k){if(!id||b.phase!=='move'||b.players[b.current].occupant!==id)return false;if(!b.legal.includes(k))return false;return doMove(b,k);}
function doMove(b,k){const p=b.players[b.current],d=b.die,r=p.pegs[k];const t=r<0?0:r+d;p.pegs[k]=t;
 let detail=r<0?'PEG OUT':'';b.last=`${b.current}:${k}`;
 if(t<=27){const a=absSpace(b.current,t);
  for(let i=0;i<SEATS;i++)if(i!==b.current)for(let j=0;j<4;j++){const q=b.players[i].pegs[j];if(q>=0&&q<=27&&absSpace(i,q)===a){b.players[i].pegs[j]=-1;detail=`SENDS ${b.players[i].name} HOME`;}}}
 else if(t===LANE_END&&p.pegs.filter(q=>q>=28).length===4){}
 else detail=detail||'IN THE HOME LANE';
 b.message=`${p.name}: ${d}  ${detail}`.trim();
 if(p.pegs.every(q=>q>=28)){b.winner=b.current;p.wins++;b.phase='win';b.remaining=8;b.message=p.name+' WINS!';return true;}
 b.again=d===6;
 b.phase='after';b.remaining=0.9;return true;}
function nextTurn(b){
 const repeat=b.again&&!!b.players[b.current].occupant;
 if(!repeat)for(let n=1;n<=SEATS;n++){const candidate=(b.current+n)%SEATS;if(b.players[candidate].occupant){b.current=candidate;break;}}
 b.again=false;b.tries=3;b.legal=[];b.phase='wait';b.remaining=0;
 b.message=b.players[b.current].occupant?b.players[b.current].name+' — PRESS DOME':'TAKE A SEAT TO PLAY';
}
export function tickBoard(b,dt,random=Math.random){
 if(!b.players[b.current].occupant){nextTurn(b);return;}
 if(b.phase==='wait'||b.phase==='move')return;
 b.remaining-=dt;if(b.remaining>0)return;
 switch(b.phase){
 case 'win':b.round++;for(const p of b.players)p.pegs=[-1,-1,-1,-1];b.winner=-1;b.again=false;nextTurn(b);break;
 case 'after':nextTurn(b);break;
 case 'pass':{const p=b.players[b.current];if(!onBoard(p)&&b.tries>1){b.tries--;b.legal=[];b.phase='wait';b.remaining=0;b.message='PRESS DOME / '+b.tries+' TRIES LEFT';}else nextTurn(b);break;}
 }
}
