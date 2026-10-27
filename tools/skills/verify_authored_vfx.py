#!/usr/bin/env python3
"""Verify delivered files, all roster bindings and atlas frame bounds."""
import argparse, hashlib, json, subprocess
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--require-tracked',action='store_true');args=parser.parse_args()
    manifest=json.loads((ROOT/'data/skills/authored_vfx.json').read_text())
    master=json.loads((ROOT/'data/skills/master.json').read_text())['records']
    profiles=manifest['profiles'];assert set(profiles)=={s['id'] for s in master}
    for sid,preview in manifest.get('preview_profiles',{}).items():
        assert sid not in profiles and preview['preview_only'] is True and preview['runtime_status']=='BLOCKED'
        assert preview['inherits_visual'] in profiles
    tracked=set(subprocess.check_output(['git','-C',str(ROOT),'ls-files','-z']).decode().split('\0'))
    by_path={};frames=0;total=0
    for asset in manifest['assets']:
        path=ROOT/asset['path'];blob=path.read_bytes()
        assert hashlib.sha256(blob).hexdigest()==asset['sha256'],f"SHA mismatch: {asset['path']}"
        assert len(blob)==asset['bytes']
        if args.require_tracked:assert asset['path'] in tracked,f"not tracked: {asset['path']}"
        with Image.open(path) as image:
            image.load();assert image.size==(asset['width'],asset['height']) and image.mode=='RGBA'
            assert image.size==(manifest['cell_size']*manifest['columns'],manifest['cell_size']*manifest['rows'])
            assert image.getchannel('A').getextrema()[0]==0 and image.getchannel('A').getextrema()[1]>=240
        by_path['res://'+asset['path']]=asset
        total+=len(blob);frames+=asset['frames']
    inherited=0;dormant=0
    for row in master:
        profile=profiles[row['id']];seen=set()
        while 'inherits_visual' in profile:
            sid=profile['inherits_visual'];assert sid in profiles and sid not in seen;seen.add(sid);profile=profiles[sid]
        if row['mode']=='upgrade':inherited+=1
        if profile.get('standalone_event'):
            assert profile['atlas'] in by_path
            asset=by_path[profile['atlas']]
            assert profile['atlas_rgba_bytes']==asset['width']*asset['height']*4
            occupied=[]
            for clip in profile['clips'].values():
                occupied.extend(range(clip['first'],clip['first']+len(clip['durations_ms'])))
                assert 0<=clip['first']<manifest['columns']*manifest['rows'] and clip['first']+len(clip['durations_ms'])<=manifest['columns']*manifest['rows']
                assert all(0<ms<=1000 for ms in clip['durations_ms'])
            assert len(set(occupied))==len(occupied)==manifest['columns']*manifest['rows']
        else:
            assert row['mode'] in ('stats','stack_defense','stack_attack','amplify')
            dormant+=1
        assert profiles[row['id']]['reference_status']=='UNVERIFIED'
    print(json.dumps({'status':'PASS','profiles':len(profiles),'atlases':len(by_path),'cells':frames,'bytes':total,
        'inherited':inherited,'no_standalone_event':dormant,'require_tracked':args.require_tracked}))

if __name__=='__main__':main()
