#!/usr/bin/env python3
"""Fetch the two avatars' original MIT-licensed maps. Verify Git blob hashes before conversion.
Requires Pillow. Run from any directory; no keys, login or upload is needed.
No hand-painted/AI replacement texture is substituted if a download fails.
"""
import concurrent.futures,hashlib,json,sys,urllib.request,urllib.parse
from pathlib import Path
from PIL import Image,ImageOps
HERE=Path(__file__).resolve().parent
MANIFEST=json.loads((HERE/'avatar-download-manifest.json').read_text())
DEST=HERE.parent/'avatars'
CACHE=DEST/'source-cache'
CACHE.mkdir(exist_ok=True)
def one(item):
    path=item['path']; name=Path(path).name
    if not name.endswith('.tga'): return
    source=CACHE/name
    if not source.exists():
        url='https://raw.githubusercontent.com/'+MANIFEST['repo']+'/'+MANIFEST['commit']+'/'+urllib.parse.quote(path)
        with urllib.request.urlopen(url,timeout=90) as response:
            data=response.read(item['size']+1)
        if len(data)!=item['size']: raise RuntimeError('Size mismatch: '+path)
        if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=item['sha']:raise RuntimeError('Hash mismatch: '+path)
        source.write_bytes(data)
    data=source.read_bytes()
    if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=item['sha']:raise RuntimeError('Cached hash mismatch: '+path)
    profile='female' if 'Female_Adult_02' in path else 'male'
    output=DEST/profile/('_'.join(name.split('_')[1:]).replace('.tga','.png'))
    image=Image.open(source)
    image.thumbnail((1024,1024),Image.Resampling.LANCZOS)
    # Rocketbox normals were authored for DirectX; Godot uses OpenGL Y+ normal maps.
    if '_normal' in name:
        image=image.convert('RGB');r,g,b=image.split();image=Image.merge('RGB',(r,ImageOps.invert(g),b))
    elif image.mode not in ('RGB','RGBA'):image=image.convert('RGBA')
    image.save(output,optimize=True)
    return str(output)
def main():
    errors=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures=[pool.submit(one,item) for item in MANIFEST['files']]
        for future in futures:
            try:
                result=future.result()
                if result:print(result)
            except Exception as e: errors.append(str(e))
    if errors:
        for error in errors:print(error,file=sys.stderr)
        print('Incomplete: no READY markers written. Do not ship an untextured avatar.',file=sys.stderr)
        return 1
    for profile in ('male','female'):
        expected=['model.fbx','body_color.png','head_color.png','opacity_color.png','body_normal.png','head_normal.png']
        for name in expected:
            if not (DEST/profile/name).is_file():raise RuntimeError('Missing '+profile+'/'+name)
        (DEST/profile/'READY.json').write_text(json.dumps({'source':MANIFEST['repo'],'commit':MANIFEST['commit'],'maps':1024,'normal_y':'OpenGL','files':{name:hashlib.sha256((DEST/profile/name).read_bytes()).hexdigest() for name in expected}},indent=2)+'\n')
    print('Two textured human avatars prepared. Keep LICENSE-Microsoft.txt with the distributed work.')
    return 0
if __name__=='__main__':raise SystemExit(main())
