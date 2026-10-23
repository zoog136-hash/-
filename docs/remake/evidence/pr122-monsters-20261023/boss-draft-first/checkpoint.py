#!/usr/bin/env python3
"""Commit only finished, hash-matched art receipts in short batches."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser();p.add_argument('--label',required=True);p.add_argument('--corrections',action='store_true');a=p.parse_args()
    plan=json.loads((HERE/'plan.json').read_text())
    paths={v for v in HERE.glob('*.py')}|{HERE/'plan.json'}
    paths.update(HERE.glob('*.json'))
    rows=[]
    for actor in plan['actors']:
        folder=HERE/actor['slug']
        paths.update(folder.glob('requests/*.json'))
        paths.update(folder.glob('*hold*.json'))
        if (folder/'draft-queue.json').exists():paths.add(folder/'draft-queue.json')
        records=[]
        for receipt in folder.glob('*-receipt.json'):
            d=json.loads(receipt.read_text());source=ROOT/d['source']
            assert sha(source)==d['sha256'] and source.stat().st_size==d['bytes']
            records.append(receipt.stem.removesuffix('-receipt'))
            paths.update([source,receipt])
        rows.append(dict(id=actor['id'],canonical_saved='canonical-v01' in records,draft_clips_saved=sum(v!='canonical-v01' for v in records),required_clips=33))
    if a.corrections:
        folder=HERE.parent/'boss-production-r003/kurtz-motion'
        paths.update(v for v in folder.rglob('*') if v.is_file() and '__pycache__' not in v.parts and v.suffix not in ('.pyc','.import'))
    assert paths
    checkpoints=HERE/'checkpoints';checkpoints.mkdir(exist_ok=True)
    manifest=checkpoints/(a.label+'.json');assert not manifest.exists(),'Use a new checkpoint label'
    manifest.write_text(json.dumps(dict(label=a.label,actors=rows,normal_art_changes=0,new_approvals=0,full_review='DEFERRED_UNTIL_ALL_DRAFTS',files=[dict(path=v.relative_to(ROOT).as_posix(),sha256=sha(v),bytes=v.stat().st_size) for v in sorted(paths)]),ensure_ascii=False,indent=2)+'\n')
    paths.add(manifest)
    subprocess.run(['git','add','--sparse','-f','--',*(v.relative_to(ROOT).as_posix() for v in sorted(paths))],cwd=ROOT,check=True)
    subprocess.run(['git','diff','--cached','--check'],cwd=ROOT,check=True)
    subprocess.run(['git','commit','--quiet','-m','[skip ci] Save dedicated boss draft sources '+a.label],cwd=ROOT,check=True)
    print(json.dumps(dict(commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),canonical_saved=sum(v['canonical_saved'] for v in rows),draft_clips_saved=sum(v['draft_clips_saved'] for v in rows))))

if __name__=='__main__':main()
