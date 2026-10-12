from pathlib import Path
import json, sys
ROOT=Path(__file__).resolve().parent
m=json.loads((ROOT/'CUTSCENE-MANIFEST.json').read_text())
assert len(m['scenes'])==30
required=[]
for scene in m['scenes']:
    for name in scene['layer_file_names']:
        required.append(ROOT/scene['layers_dir']/name)
missing=[p for p in required if not p.exists()]
print('Scenes configured:',len(m['scenes']))
print('Original separate layers required:',len(required))
print('Original layers present:',len(required)-len(missing))
print('Missing layers:',len(missing))
for x in missing[:12]:print(' -',x.relative_to(ROOT))
if missing:
    print('NOT READY: Original art and animations still require production.')
    sys.exit(2)
print('Layer files present. Next: inspect characters, render 30 MP4s, and QA frames manually.')
