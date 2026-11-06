#!/usr/bin/env python3
"""Run the real Godot checks. A zero process exit alone is not a pass."""
from pathlib import Path
import argparse,subprocess,json,sys,re
p=argparse.ArgumentParser();p.add_argument('--godot',default='godot');p.add_argument('--logs',type=Path,default=Path('upgrade-validation'));args=p.parse_args()
root=Path(__file__).resolve().parents[1];args.logs.mkdir(parents=True,exist_ok=True)
checks={'compile_all':'0 failures','pinball_regression':'PINBALL REGRESSION PASS','menu_release_test':'MENU RELEASE PASS','human_rig_test':'HUMAN RIG PASS','avatar_pose_matrix':'AVATAR POSE PASS'}
results=[]
for name,marker in checks.items():
 try:
  r=subprocess.run([args.godot,'--headless','--xr-mode','off','--path',str(root),'--script',f'tests/upgrade/{name}.gd'],capture_output=True,text=True,timeout=90)
  log=r.stdout+r.stderr
  passed=r.returncode==0 and marker in log and not re.search(r'SCRIPT ERROR|ERROR:|FAILED|Parse Error',log)
 except subprocess.TimeoutExpired:
  log='FAILED: 90-second timeout';passed=False
 (args.logs/(name+'.txt')).write_text(log)
 results.append({'test':name,'passed':passed});print(name,'PASS' if passed else 'FAIL',flush=True)
(args.logs/'results.json').write_text(json.dumps(results,indent=2)+'\n')
sys.exit(0 if all(x['passed'] for x in results) else 1)
