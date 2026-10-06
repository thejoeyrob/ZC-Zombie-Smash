/* One immutable cabinet. Skin source windows affect only decorative artwork. */
(() => {
  'use strict';
  // Preserve the actual 7.9 Toxic screen and control sizes as the reference.
  const scale = 441.470625 / 486;
  const screen = Object.freeze({x:(375-343*scale)/2,y:42.52125,w:343,h:486,scale});
  const deck = Object.freeze({y:508.6859375,scale:.94,h:123});
  const layout = Object.freeze({w:375,h:667,screen,deck,header:36.52125});
  function variables(){
    return {'--wx':screen.x,'--wy':screen.y,'--ww':screen.w*scale,'--wh':screen.h*scale,
      '--sx':screen.x,'--sy':screen.y,'--ss':scale,'--dy':deck.y,'--sd':deck.scale,'--hh':layout.header};
  }
  // Nine-slice the artwork in CSS. Only the eight chrome regions stretch;
  // the arena, HUD and controls never depend on a skin's image dimensions.
  function slices(skin){
    const [l,t,r,b]=skin.win;
    const sourceX=[0,l+4,r-4,900],sourceY=[0,t+4,b-4,1600];
    const destX=[0,screen.x,screen.x+screen.w*scale,375];
    const destY=[0,screen.y,screen.y+screen.h*scale,667];
    const regions=[];
    for(let row=0;row<3;row++)for(let col=0;col<3;col++){
      if(row===1&&col===1)continue;
      const x=destX[col],y=destY[row],w=destX[col+1]-x,h=destY[row+1]-y;
      const sx=w/(sourceX[col+1]-sourceX[col]),sy=h/(sourceY[row+1]-sourceY[row]);
      regions.push({x,y,w,h,bw:900*sx,bh:1600*sy,bx:-sourceX[col]*sx,by:-sourceY[row]*sy});
    }
    return regions;
  }
  function markup(skin){
    return slices(skin).map(r=>`<i class="shell-slice" style="left:${r.x}px;top:${r.y}px;width:${r.w}px;height:${r.h}px;background-image:url('./${skin.file}');background-size:${r.bw}px ${r.bh}px;background-position:${r.bx}px ${r.by}px"></i>`).join('');
  }
  function apply(){for(const [key,value] of Object.entries(variables()))document.body.style.setProperty(key,value+(['--ss','--sd'].includes(key)?'':'px'));}
  window.ZSConsole=Object.freeze({layout,variables,slices,markup,apply});
})();
