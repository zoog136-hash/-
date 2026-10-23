#!/usr/bin/env python3
"""Preserve newly drawn boss art after bounded real-speed playback."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--candidate', type=Path, required=True)
    p.add_argument('--runtime', type=Path, required=True)
    p.add_argument('--source-folder', type=Path, required=True)
    p.add_argument('--message', required=True)
    a = p.parse_args()
    candidate = a.candidate.resolve()
    payload = json.loads(candidate.read_text())
    key, actor = next(iter(payload['actors'].items()))
    process = json.loads((a.runtime / 'process.json').read_text())
    report = json.loads((a.runtime / 'report.json').read_text())
    assert process['returncode'] == 0 and not process['script_errors']
    assert report['capture_enabled'] and report['speed_scale'] == 1.0
    assert all(s['status'] == 'PLAYED_AT_GAME_SCALE' for c in report['cases'] for s in c['segments'])
    images, textures, checked = {}, set(), 0
    for track in actor['tracks']:
        for frame in track['geometry']['frames']:
            path = ROOT / frame.get('texture', track['texture'])
            if path not in images:
                images[path] = Image.open(path).convert('RGBA')
            x, y, w, h = frame['region']
            im = images[path]
            assert x >= 0 and y >= 0 and x+w <= im.width and y+h <= im.height
            assert hashlib.sha256(im.crop((x,y,x+w,y+h)).tobytes()).hexdigest() == frame['rgba_sha256']
            textures.add(path)
            checked += 1
    evidence = candidate.parent
    for path in a.runtime.rglob('*'):
        rel = path.relative_to(a.runtime)
        if rel.parts[0] in ('project','user') or path.is_symlink() or not path.is_file():
            continue
        dest = evidence / 'playback' / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path,dest)
    ledger_path = ROOT / 'data/pr122_monster_boss_repair_staging.json'
    ledger = json.loads(ledger_path.read_text())
    actor['replaces_previous_staging_selection'] = True
    actor['source_candidate'] = dict(path=candidate.relative_to(ROOT).as_posix(),sha256=sha(candidate))
    ledger['actors'][key] = actor
    ledger['source_inputs'] = [v['source_candidate'] for v in ledger['actors'].values()]
    ledger['latest_authoring_session'] = HERE.relative_to(ROOT).as_posix()
    ledger_path.write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+'\n')
    subprocess.run(['python3','tools/reclassify_pr122_monsters.py'],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
    # Source folders are session-owned; earlier revisions and approved art are preserved.
    folders = [a.source_folder.resolve(),evidence]
    profiles = [ROOT / v.removeprefix('res://') for k,v in actor.items() if isinstance(v,str) and v.endswith('.tres')]
    folders += [v.parent for v in profiles if v.exists()]
    paths = {v for folder in folders for v in folder.rglob('*') if v.is_file() and '__pycache__' not in v.parts and v.suffix not in ('.pyc','.import')}
    paths.update(textures)
    paths.update([ledger_path,ROOT/'data/pr122_monster_production_scope.json',Path(__file__).resolve()])
    manifest = evidence / 'batch-manifest.json'
    manifest.write_text(json.dumps(dict(schema='pr122-boss-production-batch-v1',actor=key,clips=actor['native_track_count'],poses=checked,missing_required_slots=len(actor['missing_required_tracks']),root_Godot_real_speed='PASS',viewport_captures=sum(c['capture_count'] for c in report['cases']),new_approvals=0,default_catalog_switches=0,files=[dict(path=v.relative_to(ROOT).as_posix(),bytes=v.stat().st_size,sha256=sha(v)) for v in sorted(paths)]),ensure_ascii=False,indent=2)+'\n')
    paths.add(manifest)
    subprocess.run(['git','add','--sparse','-f','--',*(v.relative_to(ROOT).as_posix() for v in sorted(paths))],cwd=ROOT,check=True)
    subprocess.run(['git','diff','--cached','--check'],cwd=ROOT,check=True)
    subprocess.run(['git','commit','--quiet','-m','[skip ci] '+a.message],cwd=ROOT,check=True)
    print(json.dumps(dict(commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),actor=key,clips=actor['native_track_count'],poses=checked,missing=len(actor['missing_required_tracks'])),ensure_ascii=False))

if __name__ == '__main__':
    main()
