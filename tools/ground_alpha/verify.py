#!/usr/bin/env python3
"""Reproduce the white-matte defect and test real Main without editing inventory."""
from __future__ import annotations
import argparse, hashlib, json, os, re, subprocess, sys
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from test_project_support import run_isolated, timeout_budget

def sha(data):return hashlib.sha256(data).hexdigest()

def run_engine(command,env,*,script=None,importing=False):
    """Keep full asset import bounded separately from individual gameplay tests."""
    budget=timeout_budget('import' if importing else (script or ''),240,900)
    try:
        child=run_isolated(command,env=env,timeout=budget,cwd=str(ROOT))
        return child.stdout+child.stderr,child.returncode,budget
    except subprocess.TimeoutExpired as exc:
        def text(value):
            return value.decode('utf-8','replace') if isinstance(value,bytes) else (value or '')
        return text(exc.stdout)+text(exc.stderr)+'\nTIMEOUT\n',124,budget
    except OSError as exc:
        return 'PROCESS_START_FAILED '+str(exc)+'\n',125,budget

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true');args=parser.parse_args()
    os.chdir(ROOT);out=args.output.resolve();out.mkdir(parents=True,exist_ok=True);engine=str(Path(args.godot).resolve());results=[]
    tested_sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    protected=['scripts/world.gd','scripts/player.gd','scripts/ui/item_visual_resolver.gd','scripts/ui/inven_inventory_icons.gd','scripts/ui/item_visual.gd','data/catalog_v19.json','data/game_db_v17.json','data/inven_inventory_icons.json','data/l1j/live_visual_bindings.json','data/visuals/runtime_manifest.json']
    protected += [str(p) for p in Path('scripts/loot').glob('*.gd') if p.name!='drop_visual.gd']
    original={p:sha(Path(p).read_bytes()) for p in protected}
    draw_before=sha(Path('scripts/loot/drop_visual.gd').read_text().split('func _draw() -> void:',1)[1].encode())
    old_categories={p.stem:sha(p.read_bytes()) for p in Path('assets/ground_categories').glob('*.png')}
    def run(label,script=None,render=False,stage='after',importing=False):
        env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1',XDG_DATA_HOME=str(out/'user-data'/label),GROUND_STAGE=stage,GROUND_REPORT=str(out/(stage+'-probe.json')),GROUND_ALPHA_REPORT=str(out/'alpha-result.json'),GROUND_CAPTURES=str(out/(stage+'-captures')))
        command=[engine,'--audio-driver','Dummy','--path','.']
        if importing:command+=['--headless','--editor','--import']
        elif render:command=['xvfb-run','-a']+command+['--rendering-method','gl_compatibility','--script','res://tests/'+script+'.gd']
        else:command+=['--headless','--script','res://tests/'+script+'.gd']
        text,code,budget=run_engine(command,env,script=script,importing=importing)
        (out/(label+'.log')).write_text(text,encoding='utf-8')
        ok=code==0 and not re.search(r'SCRIPT ERROR|Parse Error|Failed to load script|ERROR:',text)
        results.append({'test':label,'ok':ok,'exit_code':code,'timeout_seconds':budget,'tested_commit':tested_sha});(out/'test-summary.json').write_text(json.dumps(results,indent=2)+'\n')
        print(label,'PASS' if ok else 'FAIL',flush=True);print('\n'.join(text.splitlines()[-10:]),flush=True)
        return ok
    def sheet(stage):
        paths=sorted(Path('assets/ground_categories').glob('*.png'))
        raw=sorted(list(Path('assets/l1j/verified/ground').glob('*.png'))+list(Path('assets/original_items/ground').glob('*.png')))
        if stage=='after':
            manifest=json.loads(Path('data/ground_alpha.json').read_text())
            paths += [Path(manifest['images']['res://'+str(p)]['path'].removeprefix('res://')) for p in raw]
        else:paths+=raw
        cols=8;cell=112;im=Image.new('RGB',(cols*cell,((len(paths)+cols-1)//cols)*cell),(50,65,70));draw=ImageDraw.Draw(im)
        for i,p in enumerate(paths):
            icon=Image.open(p).convert('RGBA');size=(min(88,icon.width*3),min(88,icon.height*3));icon.thumbnail(size,Image.Resampling.NEAREST)
            x=i%cols*cell;y=i//cols*cell;im.paste(icon,(x+12,y+6),icon);draw.text((x+2,y+94),p.stem[:16],fill='white')
        im.save(out/(stage+'-all-icons.png'))
    subprocess.run([sys.executable,'tools/ground_alpha/test_alpha.py'],check=True)
    if args.install:
        sheet('before')
        if not run('before-import',importing=True,stage='before'):return 1
        if not run('before-probe','ground_category_probe',stage='before'):return 1
        if not run('before-capture','capture_ground_alpha',render=True,stage='before'):return 1
        subprocess.run([sys.executable,'tools/ground_alpha/install.py'],check=True)
        subprocess.run([sys.executable,'tools/ground_icons/build.py','--write'],check=True)
        subprocess.run([sys.executable,'tools/ground_alpha/bake.py','--write'],check=True)
    subprocess.run([sys.executable,'tools/ground_icons/build.py'],check=True)
    subprocess.run([sys.executable,'tools/ground_alpha/bake.py'],check=True)
    sheet('after')
    if not run('after-import',importing=True):return 1
    run('alpha-pixels-and-Main','ground_alpha_test')
    run('after-probe','ground_category_probe')
    for name in ['inven_inventory_icons_test','item_visual_test','ground_drop_smoke_test','ground_loot_system_test','remake_ui_local_item_icons_test','ui_stage4_item_instance_test','original_skill_warehouse_migration_test']:
        run(name,name)
    for name in ['aden_ground_continuity_test','eight_interactions_test']:
        run(name,name,render=True)
    run('after-capture','capture_ground_alpha',render=True)
    after={p:sha(Path(p).read_bytes()) for p in protected}
    if after!=original:raise RuntimeError('Inventory/identity/name/pickup protected files changed')
    draw_after=sha(Path('scripts/loot/drop_visual.gd').read_text().split('func _draw() -> void:',1)[1].encode())
    if draw_before!=draw_after:raise RuntimeError('Existing grade/drop effect drawing code changed')
    same_rows=None
    if args.install:
        before=json.loads((out/'before-probe.json').read_text());after_probe=json.loads((out/'after-probe.json').read_text())
        if before['inventory_rows']!=after_probe['inventory_rows']:raise RuntimeError('Inventory descriptor/pixel regression')
        same_rows=len(before['inventory_rows'])
    categories=json.loads(Path('data/ground_item_icons.json').read_text())['categories'];cutouts=json.loads(Path('data/ground_alpha.json').read_text())['images']
    proof={'historical_base_main':'91ae30fe0562fc3e652645f3d325ae650914ca4a','tested_commit':tested_sha,'protected_sha256':original,'drop_draw_sha256':draw_after,'drop_draw_unchanged':True,'inventory_rows_identical':same_rows,'category_count':len(categories),'changed_category_pngs':[k for k,v in categories.items() if old_categories.get(k)!=sha(Path(v['path'].removeprefix('res://')).read_bytes())],'dedicated_cutouts':len(cutouts),'removed_dedicated_white_pixels':sum(v['removed_white_pixels'] for v in cutouts.values()),'all_engine_stages_passed':all(r['ok'] for r in results)}
    (out/'preservation.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
    print('GROUND_ALPHA_PRESERVATION',json.dumps(proof,ensure_ascii=False),flush=True)
    return 0 if all(r['ok'] for r in results) else 1

if __name__=='__main__':raise SystemExit(main())
