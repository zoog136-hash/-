#!/usr/bin/env python3
"""Run real Godot inventory/data/interaction tests and save reproducible evidence."""
import argparse,json,os,pathlib,re,subprocess
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot',required=True)
parser.add_argument('--import-timeout',type=int,default=1800,
                    help='Complete first-time Godot import deadline, seconds')
parser.add_argument('--output',type=pathlib.Path,required=True)
args=parser.parse_args(); out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
(out/'captures').mkdir(exist_ok=True)
engine=str(pathlib.Path(args.godot).resolve()); results=[]
env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1',TWILIGHT_INVEN_REPORT=str(out/'runtime-verification.json'),TWILIGHT_INVEN_CAPTURES=str(out/'captures'))
def run(label,command,timeout=180):
    child_env=dict(env,XDG_DATA_HOME=str(out/'test-data'/label))
    try:
        result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,env=child_env,timeout=timeout,text=True)
        text=result.stdout; code=result.returncode
    except subprocess.TimeoutExpired as exc:
        text=(exc.stdout or b'').decode('utf-8','replace') if isinstance(exc.stdout,bytes) else (exc.stdout or '')
        text+='\nTEST TIMEOUT\n';code=124
    (out/(label+'.log')).write_text(text)
    ok=code==0 and not re.search(r'SCRIPT ERROR|Parse Error|Failed to load script',text)
    results.append({'test':label,'exit_code':code,'ok':ok})
    print(label,'PASS' if ok else 'FAIL',flush=True)
    print('\n'.join(text.splitlines()[-8:]),flush=True)
    return ok
# Fail closed if import is incomplete, but let large native PNG sets finish.
if not run('import',[engine,'--headless','--path','.','--editor','--import'],args.import_timeout):
    (out/'test-summary.json').write_text(json.dumps(results,indent=2));raise SystemExit(1)
for test in ['inven_inventory_icons_test','item_visual_test','item_icon_art_smoke_test','ui_stage4_item_instance_test','original_skill_warehouse_migration_test']:
    run(test,[engine,'--headless','--path','.','--script','res://tests/'+test+'.gd'])
for test in ['eight_interactions_test','capture_inven_inventory']:
    run(test,['xvfb-run','-a',engine,'--path','.','--rendering-method','gl_compatibility','--script','res://tests/'+test+'.gd'])
(out/'test-summary.json').write_text(json.dumps(results,indent=2))
raise SystemExit(0 if all(r['ok'] for r in results) else 1)
