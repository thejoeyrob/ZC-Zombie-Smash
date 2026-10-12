#!/usr/bin/env python3
"""Zombie Smash 30-scene cinematic parallax compiler.
Artwork NOT included. Requires original RGBA assets in manifest paths.
Uses independent one-way horizontal parallax and separate typewritten comic balloons.
"""
from __future__ import annotations
import argparse, json, math, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE=Path(__file__).resolve().parent
MANIFEST=HERE/'CUTSCENE-MANIFEST.json'
FONT_MONO='/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
FONT_BOLD='/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'
W,H=720,960


def load_font(path, size):
    if Path(path).exists(): return ImageFont.truetype(path,size)
    return ImageFont.load_default(size=size)

def rgb(h):
    h=h.strip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))

def find_scene(scene_id):
    manifest=json.loads(MANIFEST.read_text())
    match=next((s for s in manifest['scenes'] if s['id']==scene_id),None)
    if not match:
        raise ValueError(f'Unknown scene {scene_id} (see CUTSCENE-MANIFEST.json)')
    boss=next(b for b in manifest['characters'] if b['id']==match['boss'])
    return match,boss,manifest

def load_original_planes(scene):
    root=HERE/scene['layers_dir']
    paths=[root/name for name in scene['layer_file_names']]
    missing=[p for p in paths if not p.exists()]
    if missing:
        raise FileNotFoundError('Original layered artwork is not available yet: '+', '.join(str(p) for p in missing))
    bg,mid,fg=(Image.open(p).convert('RGBA') for p in paths)
    if bg.getchannel('A').getextrema()[0]<255:
        raise ValueError('background.webp is not fully opaque')
    for name,im in [('midground',mid),('foreground',fg)]:
        alpha=im.getchannel('A')
        if alpha.getextrema() in ((0,0),(255,255)):
            raise ValueError(f'{name}.png must have a cut-out silhouette (transparent outside and solid inside)')
    return bg,mid,fg

def fit_cover(img, width, height):
    factor=max(width/img.width,height/img.height)
    return img.resize((math.ceil(img.width*factor),math.ceil(img.height*factor)),Image.Resampling.LANCZOS)

def fit_actor(img, max_width, max_height):
    s=min(max_width/img.width,max_height/img.height)
    return img.resize((round(img.width*s),round(img.height*s)),Image.Resampling.LANCZOS)

def wrap_text(draw, string, font, maxw):
    lines=[]; cur=''
    for token in string.split(' '):
        trial=(cur+' '+token).strip()
        if cur and draw.textlength(trial,font=font)>maxw:
            lines.append(cur);cur=token
        else:cur=trial
    if cur:lines.append(cur)
    return lines

def write_bubble(c, text, speaker, box, accent, progress, tail_side='left'):
    if progress<=0:return
    d=ImageDraw.Draw(c,'RGBA')
    x0,y0,x1,y1=box
    font=load_font(FONT_MONO,23)
    fn=load_font(FONT_BOLD,20)
    while font.size>14:
        lines=wrap_text(d,text,font,x1-x0-34)
        if (len(lines)* (font.size+6)+37)<=y1-y0:break
        font=load_font(FONT_MONO,font.size-1)
    lines=wrap_text(d,text,font,x1-x0-34)
    reveal=math.ceil(len(text)*min(1,max(0,progress)))
    revealed=text[:reveal]
    lines=wrap_text(d,revealed,font,x1-x0-34)
    # Opaque cream bubble plus short triangular pointer, no translucent fill through character.
    d.rounded_rectangle((x0,y0,x1,y1),radius=19,fill=(250,241,215,250),outline=(11,11,14,255),width=5)
    if tail_side=='right':
        d.polygon([(x1-42,y1-1),(x1-12,y1-1),(x1-8,y1+16)],fill=(250,241,215,255))
    else:
        d.polygon([(x0+14,y1-1),(x0+45,y1-1),(x0+10,y1+16)],fill=(250,241,215,255))
    d.text((x0+18,y0+9),speaker.upper(),font=fn,fill=rgb(accent),stroke_width=1,stroke_fill=(14,14,16))
    for i,line in enumerate(lines):
        ty=y0+37+i*(font.size+6)
        if ty+font.size>y1-8:break
        d.text((x0+17,ty),line,font=font,fill=(22,25,29,255))
    if 0<progress<1 and int(progress*24)%2==0 and lines:
        last=lines[-1]
        ty=y0+37+(len(lines)-1)*(font.size+6)
        px=x0+17+d.textlength(last,font=font)+2
        if px+9<x1-13 and ty+font.size<y1-8:
            d.rectangle((round(px),ty+3,round(px+4),ty+font.size+1),fill=(23,26,32,255))

def composite(scene,boss,planes,t):
    bg,mid,fg=planes
    # One direction, no reverse. Slight native overscan is enforced by BG resize.
    q=min(1,max(0,t/scene['duration_sec']))
    backdrop=fit_cover(bg,W+90,H+50)
    boss_img=fit_actor(mid,round(W*.72),round(H*.65))
    joe_img=fit_actor(fg,round(W*.58),round(H*.63))
    surface=Image.new('RGBA',(W,H),(11,11,13,255))
    bx=round((W-backdrop.width)/2-14+28*q); by=round((H-backdrop.height)/2)
    mx=round(W*.57-boss_img.width*.5-24+48*q); my=round(H*.74-boss_img.height)
    fx=round(W*.26-joe_img.width*.45-37+75*q); fy=round(H*.79-joe_img.height)
    surface.alpha_composite(backdrop,(bx,by))
    surface.alpha_composite(boss_img,(mx,my))
    surface.alpha_composite(joe_img,(fx,fy))
    # No illustration artwork behind text becomes transparent; bubble is drawn fully opaque.
    d=ImageDraw.Draw(surface,'RGBA')
    d.rectangle((0,0,W,59),fill=(10,12,14,243))
    d.rectangle((0,54,W,59),fill=rgb(boss['accent']))
    label=load_font(FONT_BOLD,32)
    d.text((18,11),boss['name'].upper(),font=label,fill=(244,243,238))
    tag=load_font(FONT_BOLD,19)
    st=(f"FORM {scene['form']} OF {boss['forms']}" if scene['scene'].startswith('form') else scene['scene'].replace('bossdown','BOSS DOWN').replace('joeydown','JOEY DOWN').upper())
    d.text((W-18,20),st,font=tag,fill=rgb(boss['accent']),anchor='ra')
    # Compositions need speech at top and bottom; keep viewport faces in center.
    dialogue=scene['dialogue']
    if len(dialogue)>1:
        write_bubble(surface,dialogue[0]['text'],dialogue[0]['speaker'],(30,94,348,221),boss['accent'],q/.44,tail_side='left')
        write_bubble(surface,dialogue[1]['text'],dialogue[1]['speaker'],(372,730,686,896),boss['accent'],(q-.28)/.55,tail_side='right')
    else:
        write_bubble(surface,dialogue[0]['text'],dialogue[0]['speaker'],(340,730,688,903),boss['accent'],q/.64,tail_side='right')
    return surface.convert('RGB')

def write_scene(scene_id,out,fps=24,crf=23):
    scene,boss,_=find_scene(scene_id)
    planes=load_original_planes(scene)
    total=math.ceil(scene['duration_sec']*fps)
    out=Path(out);out.parent.mkdir(parents=True,exist_ok=True)
    cmd=['ffmpeg','-v','error','-y','-f','rawvideo','-pixel_format','rgb24','-video_size',f'{W}x{H}',
         '-framerate',str(fps),'-i','-','-c:v','libx264','-preset','medium','-crf',str(crf),
         '-pix_fmt','yuv420p','-movflags','+faststart',str(out)]
    proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stderr=subprocess.PIPE)
    try:
        for i in range(total):
            t=i/fps
            im=composite(scene,boss,planes,t)
            proc.stdin.write(im.tobytes())
    finally:
        proc.stdin.close()
    msg=proc.stderr.read().decode('utf-8','ignore');ret=proc.wait()
    if ret:raise RuntimeError(f'ffmpeg failed: {msg[-1200:]}')
    print(f'Built {out} ({out.stat().st_size/1024:.0f} KB, {total} frames)')

if __name__=='__main__':
    pa=argparse.ArgumentParser(description='Compile a Zombie Smash 3-plane boss transition into MP4')
    pa.add_argument('scene_id',help='Example: scene-jordan-intro; use --all for all 30 scenes',nargs='?')
    pa.add_argument('--all',action='store_true')
    pa.add_argument('--out-dir',default=str(HERE/'renders'))
    pa.add_argument('--fps',type=int,default=24)
    pa.add_argument('--crf',type=int,default=23)
    args=pa.parse_args()
    manifest=json.loads(MANIFEST.read_text())
    ids=[s['id'] for s in manifest['scenes']] if args.all else [args.scene_id]
    if not all(ids):pa.error('Supply a scene_id or --all')
    for ident in ids:
        write_scene(ident,Path(args.out_dir)/f'{ident}.mp4',fps=args.fps,crf=args.crf)
