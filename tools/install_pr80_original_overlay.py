#!/usr/bin/env python3
"""Install recovered PR80 original monster/item visuals into an existing TWILIGHT checkout.

Keeps the 723 authored catalog atlases already tracked on main, validates
image bytes/hashes, refuses conflict unless --overwrite, and merges only
monsters/items/item_names into the existing runtime manifest.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import tempfile
import zipfile

ALLOWED = ('assets/external_l1j/items/', 'assets/external_l1j/monsters/',
           'assets/original_items/inventory/', 'assets/original_items/ground/',
           'assets/l1j/verified/items/', 'assets/l1j/verified/monsters/',
           'assets/l1j/verified/ground/')
OVERLAY = 'data/pr80_original_bindings_overlay.json'


def digest(buf: bytes) -> str:
    return hashlib.sha256(buf).hexdigest()


def install(project: Path, archive: Path, dry_run: bool, overwrite: bool) -> dict:
    project=project.resolve()
    if not (project/'project.godot').is_file():
        raise ValueError('Existing TWILIGHT project.godot required')
    manifest_path=project/'data/visuals/runtime_manifest.json'
    if not manifest_path.is_file():
        raise ValueError('Current main runtime_manifest.json required (contains 723 atlas definitions)')
    base=json.loads(manifest_path.read_text(encoding='utf8'))
    if base.get('schema') != 1 or len(base.get('catalog',{})) != 723:
        raise ValueError('Expected schema=1 and 723 existing main catalog records')
    with zipfile.ZipFile(archive) as z:
        overlay=json.loads(z.read(OVERLAY))
        if overlay.get('schema')!=1 or len(overlay.get('monsters',{}))!=132 or len(overlay.get('items',{}))!=467:
            raise ValueError('Invalid recovered manifest counts')
        expected=overlay['asset_sha256']
        if len(expected)!=528:
            raise ValueError(f'Unexpected unique image count: {len(expected)}')
        found=set();same=[];different=[]
        for path,sha in expected.items():
            pure=PurePosixPath(path)
            if pure.is_absolute() or '..' in pure.parts or '\\' in path or not path.endswith('.png') or not path.startswith(ALLOWED):
                raise ValueError('Unsafe overlay member: '+path)
            raw=z.read(path)
            if digest(raw)!=sha:raise ValueError('SHA-256 mismatch: '+path)
            existing=project/path
            if existing.exists():
                (same if digest(existing.read_bytes())==sha else different).append(path)
            found.add(path)
        if different and not overwrite:
            raise FileExistsError(f'{len(different)} conflicting resource files (first {different[0]}): use --overwrite only if intentional')
        for row in list(overlay['monsters'].values())+list(overlay['items'].values()):
            for key in ('path','ground_path'):
                v=row.get(key)
                if v and (not v.startswith('res://') or v[6:] not in expected):
                    raise ValueError(f'Unverified {key} reference: {v}')
        if not dry_run:
            for path in sorted(found):
                existing=project/path
                if path in same:continue
                existing.parent.mkdir(parents=True,exist_ok=True)
                with z.open(path) as source, existing.open('wb') as dest:
                    shutil.copyfileobj(source,dest)
            for key in ('monsters','items','item_names'):
                base[key]=overlay[key]
            updated=json.dumps(base,ensure_ascii=False,separators=(',',':'))+'\n'
            backup=manifest_path.with_suffix('.json.pr80-before-backup')
            if not backup.exists():shutil.copy2(manifest_path,backup)
            temp=manifest_path.with_suffix('.json.pr80-new')
            temp.write_text(updated,encoding='utf8');os.replace(temp,manifest_path)
        return {'mode':'dry-run' if dry_run else 'installed', 'images':len(expected),
                'monsters':len(overlay['monsters']),'items_including_legacy':len(overlay['items']),
                'catalog_preserved':len(base['catalog']),'already_matching':len(same),'conflicts':len(different),
                'new_or_overwritten':len(expected)-len(same) if not dry_run else 0}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--project',type=Path,required=True)
    p.add_argument('--archive',type=Path,required=True)
    p.add_argument('--dry-run',action='store_true')
    p.add_argument('--overwrite',action='store_true')
    args=p.parse_args()
    print(json.dumps(install(args.project,args.archive,args.dry_run,args.overwrite),ensure_ascii=False,indent=2))
