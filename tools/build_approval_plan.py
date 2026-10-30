"""Inventory current runtime and selected staging without granting art approval."""
import argparse, collections, hashlib, json, re, subprocess
from pathlib import Path

def build(root):
    def read(p): return json.loads((root / p).read_text())
    profiles = read('data/combat_animation_profiles.json')['profiles']
    transforms = {'transform:'+str(r['sourceId']):r for r in read('data/catalog_v19.json')['변신']}
    queue = {r['id'] for r in read('docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json')}
    scope = read('data/pr122_monster_production_scope.json')
    monsters = {r['id']:r for r in scope['monsters']}
    db=read('data/monsters/monster_world_catalog.json')
    records={r['name']:{**r,**db['overlays'].get(r['name'],{})} for r in read('data/game_db_v17.json')['몬스터']}
    for r in db['additions']:
        if r['name'] not in records: records[r['name']]={**records.get(r.get('template','해골 근위병'),{}),**r}
    entries=[]
    for key,p in profiles.items():
        if key in transforms:
            grade=transforms[key]['grade']
            if grade not in ['신화','전설','영웅'] or (grade=='신화' and key not in queue): continue
        elif key in monsters: grade='보스' if monsters[key]['kind']=='boss' else '일반 몬스터'
        else: continue
        record=transforms[key] if key in transforms else records[monsters[key]['name']]
        effective={**p,**record.get('animation_profile',{})}
        entries.append(dict(id=key,category=grade,scope='runtime',frames=effective.get('frames_path',''),profile_settings=p,record=record))
    category={e['id']:e['category'] for e in entries}
    for path in sorted((root/'data').glob('pr122_*staging.json')):
        if path.name not in ['pr122_native_locomotion_staging.json'] and not path.name.startswith('pr122_monster'): continue
        j=json.loads(path.read_text())
        for group in ['actors','family_adapters']:
            for key,a in j.get(group,{}).items():
                if key not in category: continue
                frames=a.get('frames',a.get('frames_path',''))
                native=a.get('native_profile','')
                if native and (root/native.removeprefix('res://')).is_file():
                    m=re.search(r'^frames_path\s*=\s*"([^"]+)"',(root/native.removeprefix('res://')).read_text(),re.M)
                    if m:frames=m[1]
                if frames:entries.append(dict(id=key,category=category[key],scope='staging',register=path.relative_to(root).as_posix(),frames=frames,native_profile=native,recorded_frames_sha256=a.get('frames_sha256'),recorded_frames=a.get('frames'),production_connected=a.get('production_connected',False),detailed_completed=a.get('detailed_completed',False)))
    grouped=collections.defaultdict(list)
    for e in entries:grouped[e['frames']].append(e)
    resources=[];missing=[]
    for path,rows in sorted(grouped.items()):
        file=root/path.removeprefix('res://');text=file.read_text() if file.is_file() else ''
        textures=sorted(set(re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)"',text)))
        for texture in textures:
            if not (root/texture.removeprefix('res://')).is_file():missing.append(texture.removeprefix('res://'))
        resources.append(dict(frames=path,entries=rows,texture_paths=textures,sha256=hashlib.sha256(file.read_bytes()).hexdigest() if file.is_file() else None))
    return dict(schema='pr122-approval-plan-v1',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),runtime_counts=dict(collections.Counter(e['category'] for e in entries if e['scope']=='runtime')),staging_counts=dict(collections.Counter(e['category'] for e in entries if e['scope']=='staging')),resources=resources,missing_checkout_textures=sorted(set(missing)),new_quality_approvals=0,scope_note='Current PR122 selections only. Unmerged parallel branch results are separate integration dependencies; no approval inference from load or CI.')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();j=build(a.root);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in j.items() if k not in ['resources','missing_checkout_textures']},ensure_ascii=False));print('resources',len(j['resources']),'missing checkout textures',len(j['missing_checkout_textures']))
