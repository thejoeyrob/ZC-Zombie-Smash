#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]/'avatars'
errors=[]
for profile in sorted(d.name for d in root.iterdir() if (d/'READY.json').exists() or d.is_dir() and d.name!='source-cache'):
 marker=root/profile/'READY.json'
 if not marker.exists():errors.append(profile+': textures missing; run fetch-human-assets.py');continue
 data=json.loads(marker.read_text())
 for name,digest in data['files'].items():
  p=root/profile/name
  if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:errors.append(profile+'/'+name+': missing or altered')
if errors:
 print('\n'.join(errors));sys.exit(1)
print('Human avatar asset hashes PASS')
