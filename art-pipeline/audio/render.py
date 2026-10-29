"""Render the whole Zombie Smash sound library into the repository root: python3 art-pipeline/audio/render.py <outdir>"""
import sys, os, json
import numpy as np
from synth import *
import sfx, tracks, stingers
from music_lib import WARN

# peak level of each effect (1.0 = full scale); the game mixes them with its own effects volume
LEVEL = dict(click=.5, chime=.7, back=.5, toggle=.5, key=.45, error=.6, page=.4,
             pistol=.8, smg=.62, shotgun=.9, dmr=.9, burst=.7, hose=.6, rainbow=.6, bass=.9, beans=.5, laser=.65, remover=.55, purge=.7,
             hit=.5, kill=.7, ricochet=.45, bosshit=.8, throw=.6, explosion=.95, hurt=.8, breach=.7,
             pickup=.65, heart=.7, goldheart=.75, boost1=.6, boost2=.65, boost3=.7, power=.7, switch=.5, target=.6, clear=.7,
             alarm=.7, warn=.7, doom=.9, mutation=.85)

def trim_lead(x, thresh=0.01):
    i = np.argmax(np.abs(x) > thresh); return x[max(0, i - 8):]

out = sys.argv[1]; os.makedirs(out, exist_ok=True)
manifest = {'sfx': {}, 'music': {}}
for name, fn in sfx.S.items():
    x = trim_lead(fn()); x = x / max(1e-6, np.abs(x).max()) * LEVEL.get(name, .7)
    save(f'{out}/snd-{name}.wav', x); manifest['sfx'][name] = round(len(x) / SR, 3)
for name, fn in tracks.TRACKS.items():
    x = fn(); save(f'{out}/mus-{name}.wav', x); manifest['music'][name] = round(x.shape[1] / SR, 3)
for name, fn in stingers.STING.items():
    x = fn(); save(f'{out}/mus-{name}.wav', x); manifest['music'][name] = round(x.shape[1] / SR, 3)
json.dump(manifest, open(f'{out}/audio-manifest.json', 'w'), indent=1)
print('\n'.join(sorted(set(WARN))) or 'no warnings')
tot = sum(os.path.getsize(f'{out}/{f}') for f in os.listdir(out))
print(len(manifest['sfx']), 'effects,', len(manifest['music']), 'music files,', round(tot / 1e6, 1), 'MB')
