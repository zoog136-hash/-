"""Reconcile connection metadata against pinned published assets; never approve art."""
import argparse, copy, hashlib, json, re
from pathlib import Path

STAGING='data/pr122_monster_boss_repair_staging.json'
CONNECTIONS='data/pr122_monster_boss_runtime_connections.json'
CATALOG='data/combat_animation_profiles.json'

def reconcile(root):
    def read(path): return json.loads((root/path).read_text())
    before=read(STAGING);after=copy.deepcopy(before)
    connections=read(CONNECTIONS);profiles=read(CATALOG)['profiles'];changes=[]
    seen=set()
    for row in connections['connections']:
        key=row['id'];assert key not in seen, f'Duplicate connection: {key}';seen.add(key)
        assert key in before['actors'] and key in profiles, f'Unknown actor: {key}'
        assert profiles[key]['frames_path']==row['frames'], f'Catalog binding mismatch: {key}'
        relative=Path(row['frames'].removeprefix('res://'))
        assert not relative.is_absolute() and '..' not in relative.parts
        path=root/relative;raw=path.read_bytes()
        assert hashlib.sha256(raw).hexdigest()==row['frames_sha256'], f'Published SHA mismatch: {key}'
        text=raw.decode()
        assert re.search(r'^metadata/twilight_production_connected = true$',text,re.M), f'Not published: {key}'
        assert re.search(r'^metadata/twilight_detailed_completed = false$',text,re.M), f'Unexpected approval marker: {key}'
        tracks=set(re.findall(r'"name":\s*&"([^"]+)"',text))
        required={f'{role}_{d}' for role in ('idle','run','attack','hit') for d in range(8)}|{'death_2'}
        assert required<=tracks, f'Missing published tracks: {key}: {sorted(required-tracks)}'
        assert row['required_clips']==len(required)
        a=after['actors'][key]
        updates=dict(production_connected=True,connected_frames=row['frames'])
        for field,value in updates.items():
            if a.get(field)!=value:
                changes.append(dict(id=key,field=field,before=a.get(field),after=value));a[field]=value
        # Selection, source hashes, formal approval and historical counters stay intact.
        assert a.get('detailed_completed')==before['actors'][key].get('detailed_completed')
    return before,after,dict(schema='pr122-connection-reconciliation-v1',verified_connections=len(seen),changed_actors=sorted({r['id'] for r in changes}),changes=changes,new_art_approvals=0,source_pixel_changes=0,runtime_profile_changes=0)

def main():
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--write',action='store_true');p.add_argument('--report',type=Path);args=p.parse_args()
    before,after,report=reconcile(args.root)
    if args.report:args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    if args.write and before!=after:(args.root/STAGING).write_text(json.dumps(after,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False))
    if before!=after and not args.write:raise SystemExit(1)
if __name__=='__main__': main()
