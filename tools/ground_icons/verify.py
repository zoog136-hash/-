#!/usr/bin/env python3
"""Execute real Main before/after probes, UI captures and unchanged loot suites."""
import argparse, hashlib, json, os, re, subprocess, sys
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--godot',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--install',action='store_true')
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
engine=str(Path(a.godot).resolve());summary=[]
protected=['scripts/world.gd','scripts/player.gd','scripts/ui/inven_inventory_icons.gd','scripts/ui/item_visual.gd','data/game_db_v17.json','data/catalog_v19.json','data/inven_inventory_icons.json','data/l1j/live_visual_bindings.json','data/visuals/runtime_manifest.json']
protected += [str(f) for f in Path('scripts/loot').glob('*.gd')]
before_hashes={f:hashlib.sha256(Path(f).read_bytes()).hexdigest() for f in protected}
def run(label,script=None,render=False,stage='after',timeout=240,importing=False):
    env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1',XDG_DATA_HOME=str(out/'user-data'/label),GROUND_STAGE=stage,GROUND_REPORT=str(out/(stage+'-probe.json')),GROUND_CAPTURES=str(out/(stage+'-captures')))
    # CI has no audio hardware. Select Dummy explicitly rather than ignoring
    # real engine ERROR lines or treating an ALSA fallback as a game failure.
    command=[engine,'--audio-driver','Dummy','--path','.']
    if importing:command+=['--headless','--editor','--import']
    elif render:command=['xvfb-run','-a']+command+['--rendering-method','gl_compatibility','--script','res://tests/'+script+'.gd']
    else:command+=['--headless','--script','res://tests/'+script+'.gd']
    try:
        child=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,env=env,timeout=timeout,text=True)
        text=child.stdout;code=child.returncode
    except subprocess.TimeoutExpired as e:
        text=e.stdout.decode('utf-8','replace') if isinstance(e.stdout,bytes) else e.stdout or ''
        text+='\nTIMEOUT\n';code=124
    (out/(label+'.log')).write_text(text)
    ok=code==0 and not re.search(r'SCRIPT ERROR|Parse Error|Failed to load script|ERROR:',text)
    summary.append({'test':label,'ok':ok,'exit_code':code})
    (out/'test-summary.json').write_text(json.dumps(summary,indent=2))
    print(label,'PASS' if ok else 'FAIL',flush=True)
    print('\n'.join(text.splitlines()[-12:]),flush=True)
    return ok
if a.install:
    if not run('before-import',importing=True,stage='before'):sys.exit(1)
    if not run('before-probe','ground_category_probe',stage='before'):sys.exit(1)
    if not run('before-capture','capture_ground_categories',render=True,stage='before'):sys.exit(1)
    subprocess.run([sys.executable,'tools/ground_icons/build.py','--write'],check=True)
    subprocess.run([sys.executable,'tools/ground_icons/install.py'],check=True)
else:subprocess.run([sys.executable,'tools/ground_icons/build.py'],check=True)
if not run('after-import',importing=True):sys.exit(1)
run('after-probe','ground_category_probe')
for test in ['inven_inventory_icons_test','item_visual_test','ground_drop_smoke_test','ground_loot_system_test','aden_ground_continuity_test','remake_ui_local_item_icons_test','ui_stage4_item_instance_test','original_skill_warehouse_migration_test']:
    run(test,test)
run('eight_interactions_test','eight_interactions_test',render=True)
run('after-capture','capture_ground_categories',render=True)
now={f:hashlib.sha256(Path(f).read_bytes()).hexdigest() for f in protected}
if now!=before_hashes:raise SystemExit('Protected name/effect/loot/inventory/gameplay files changed')
proof={'base_main':'ca90291506a0f726108ccf95a9eb43a5734c8342','protected_source_sha256':now,'protected_unchanged':True,'inventory_rows_identical':None}
if a.install and (out/'after-probe.json').is_file():
    before=json.loads((out/'before-probe.json').read_text());after=json.loads((out/'after-probe.json').read_text())
    if before['inventory_rows']!=after['inventory_rows']:raise SystemExit('Inventory descriptor/pixel regression')
    proof['inventory_rows_identical']=len(after['inventory_rows'])
    proof['runtime_count']=after['runtime_count'];proof['natural_loot_count']=after['natural_loot_count'];proof['ground_routes']=after['routes'];proof['ground_categories']=after['categories']
(out/'preservation-proof.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2))
print('GROUND_PROTECTED_FILES_UNCHANGED',len(now),'INVENTORY_ROWS',proof['inventory_rows_identical'],flush=True)
sys.exit(0 if all(s['ok'] for s in summary) else 1)
