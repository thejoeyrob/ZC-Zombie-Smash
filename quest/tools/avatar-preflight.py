#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]/'avatars'
errors=[]
for profile in ['male','female']:
 marker=root/profile/'READY.json'
 if not marker.exists():errors.append(profile+': textures missing; run fetch-human-assets.py');continue
 data=json.loads(marker.read_text())
 for name,digest in data['files'].items():
  p=root/profile/name
  if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:errors.append(profile+'/'+name+': missing or altered')
if errors:
 print('\n'.join(errors));sys.exit(1)
print('Human avatar asset hashes PASS')
