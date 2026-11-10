#!/usr/bin/env python3
"""Materialize only the exact committed current Aden inputs for the core gate."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
from ci_core import ensure_objects, git

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('.'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root, output = args.root.resolve(), args.output.resolve()
    prefix = 'external_map_packs/source84_v3/'
    # The pre-November source84 map pack was removed (user decision
    # 2026-11-10): only the installed original 523 pack is shown. Without it
    # the gate stages an empty folder and map tests report its absence.
    if not git(root, 'ls-tree', '-r', '--name-only', 'HEAD', '--', prefix).strip():
        output.mkdir(parents=True, exist_ok=True)
        print('CORE_CURRENT_MAP_INPUTS 0 0 old_map_pack_removed')
        return
    record = json.loads(git(root, 'show', 'HEAD:'+prefix+'maps/aden_world.json'))
    names = {'index.json','runtime_safety.json','local-interpretation-v1/index.json',
             'equal-collision-v1/index.json','maps/aden_world.json',record['collision']['file']}
    names.update(row['file'] for row in record['chunks'])
    if any(PurePosixPath(p).is_absolute() or '..' in PurePosixPath(p).parts or '\\' in p for p in names):
        raise ValueError('unsafe committed map path')
    objects = {}
    for raw in git(root, 'ls-tree', '-rz', 'HEAD', '--', prefix).split(b'\0'):
        if raw:
            meta, path = raw.split(b'\t',1)
            name = path.decode().removeprefix(prefix)
            if name in names:
                objects[name] = meta.decode().split()[2]
    if set(objects) != names:
        raise RuntimeError('current map input is not fully committed')
    ensure_objects(root, sorted(set(objects.values())))
    total = 0
    for name, oid in objects.items():
        path = output / name
        if path.is_file():
            data = path.read_bytes()
            if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest() == oid:
                total += len(data)
                continue
        data = git(root, 'cat-file', 'blob', oid)
        if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest() != oid:
            raise RuntimeError('map object mismatch: '+name)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        total += len(data)
    print('CORE_CURRENT_MAP_INPUTS',len(objects),total)

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('::error title=Current map input::'+str(error).replace('%','%25').replace('\r','%0D').replace('\n','%0A'), flush=True)
        raise
