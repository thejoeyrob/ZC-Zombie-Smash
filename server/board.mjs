export const names=['DEBO','DR MANTIS','DISCO MAN','FAT AMY'];
export const SEATS=names.length;
const kind={4:'grenade',13:'grenade',22:'grenade',6:'zombie',11:'zombie',17:'zombie',24:'zombie',3:'heart',9:'heart',15:'heart',20:'heart',26:'heart',8:'boss',14:'boss',19:'boss',25:'boss'};
export function newBoard(){return {players:names.map(name=>({name,occupant:'',pos:0,skip:false,shield:1,wins:0})),current:0,winner:-1,phase:'wait',remaining:1.6,message:'RACE TO THE LAB — FOUR SEATS',die:1,again:false,round:1,deck:[]};}
export function sit(b,id,name,seat){if(!Number.isInteger(seat)||seat<0||seat>=SEATS||(b.players[seat].occupant&&b.players[seat].occupant!==id))return false;stand(b,id);Object.assign(b.players[seat],{occupant:id,name});if(seat===b.current&&b.phase==='wait')b.remaining=25;return true;}
export function stand(b,id){for(let i=0;i<SEATS;i++)if(b.players[i].occupant===id){Object.assign(b.players[i],{occupant:'',name:names[i]});if(i===b.current)b.remaining=Math.min(b.remaining,1.6);}}
export function roll(b,id,dash=false,random=Math.random){if(b.phase!=='wait'||b.players[b.current].occupant!==id)return false;
 const p=b.players[b.current];b.die=1+Math.floor(random()*6);b.phase='result';b.remaining=2.2;b.again=false;
 if(p.skip){p.skip=false;b.message=p.name+' MISSES A TURN';return true;}
 let move=b.die+(dash?2:0);let detail='';
 if(dash&&b.die===1){if(p.shield>0){p.shield--;detail='SHIELD SAVED THE DASH';}else{move=-2;detail='DASH FAILED — BACK 2';}}
 p.pos=Math.max(0,Math.min(28,p.pos+move));
 if(p.pos<28&&move>0){switch(kind[p.pos]){
 case 'grenade':p.pos=Math.min(28,p.pos+3);detail='GRENADE +3';break;
 case 'heart':p.shield=Math.min(2,p.shield+1);b.again=true;detail='HEART: SHIELD + ROLL AGAIN';break;
 case 'zombie':case 'boss':if(p.shield){p.shield--;detail='SHIELD BLOCKED ATTACK';}else if(kind[p.pos]==='boss'){p.skip=true;detail='BOSS: MISS NEXT TURN';}else{p.pos=Math.max(0,p.pos-2);detail='ZOMBIE: BACK 2';}break;
 default:if([2,10,16,23].includes(p.pos)){if(!b.deck.length){b.deck=[0,1,2,3,4,5];for(let i=5;i>0;i--){const j=Math.floor(random()*(i+1));[b.deck[i],b.deck[j]]=[b.deck[j],b.deck[i]];}}const card=b.deck.pop();const moves=[0,2,-1,0,1,3];if(card===0||card===3)p.shield=Math.min(2,p.shield+1);else p.pos=Math.max(0,Math.min(28,p.pos+moves[card]));detail=['SUPPLY: SHIELD','SHORTCUT +2','AMBUSH -1','MEDKIT: SHIELD','RESCUE +1','POWER SURGE +3'][card];}
 }}
 b.message=`${p.name}: ${dash?'DASH':'STEADY'} ${b.die}  ${detail}`;
 if(p.pos>=28){b.winner=b.current;p.wins++;b.phase='win';b.remaining=7;b.message=p.name+' WINS!';}return true;
}
export function tickBoard(b,dt,random=Math.random){b.remaining-=dt;if(b.remaining>0)return;
 if(b.phase==='win'){b.round++;for(const p of b.players)Object.assign(p,{pos:0,skip:false,shield:1});b.winner=-1;b.current=(b.round-1)%SEATS;b.deck=[];b.phase='wait';b.remaining=b.players[b.current].occupant?25:1.6;return;}
 if(b.phase==='result'){if(!b.again)b.current=(b.current+1)%SEATS;b.phase='wait';b.remaining=b.players[b.current].occupant?25:1.6;b.message=b.players[b.current].name+' — STEADY or DASH';return;}
 roll(b,b.players[b.current].occupant,false,random);
}
