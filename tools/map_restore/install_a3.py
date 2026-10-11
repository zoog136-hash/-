"""Build a private playable pack from exact PR81-proven A3 members, not a rescan.

Original art is not included. Existing recovered packs are reused when verified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'l1j'))
from convert_maps import read_cache
from convert_world import convert

def sha(data): return hashlib.sha256(data).hexdigest()
def install(root, a3, viewer):
    inventory = json.loads((root/'docs/map-recovery-20261011/MAP_SOURCE_MAPPING.json').read_text())
    expected = '2d25c6d5408aaf29443167c4c82c30b32d1a83b16039d988471ba0c832eb7d20'
    if sha(a3.read_bytes()) != expected:
        raise ValueError('A3 archive does not match verified PR81 input; will not guess its format')
    if sha(viewer.read_bytes()) != 'af04061b375d99cd94cfd95b18686bab358e01cac6d46d7cd9b57358f31794fa':
        raise ValueError('MapViewer archive does not match verified PR81 input')
    base = root/'data/l1j/recovered_maps'
    rows = [r.copy() for r in inventory['source_maps'] if r['navigation_rules']=='A3_STATIC_EDGES']
    catalog = base/'source_maps.json'
    if catalog.exists():
        old = json.loads(catalog.read_text())['maps']
        for r in old:
            raw = base/r['raw_file']
            if not raw.exists() or sha(raw.read_bytes()) != r['row_major_sha256']:
                raise ValueError('Existing pack is incomplete or changed; preserve it and restore separately')
        print('REUSE_VERIFIED_RECOVERED_PACK',len(old))
    else:
        (base/'raw').mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(a3) as archive:
            for r in rows:
                member = r['source'].split('!',1)[1]
                blob = archive.read(member)
                if sha(blob)!=r['source_sha256']: raise ValueError('Source member changed: '+member)
                meta, grid = read_cache(blob,r['map_id'])
                raw=grid.tobytes()
                if meta['source_origin']!=r['source_origin'] or sha(raw)!=r['row_major_sha256']:
                    raise ValueError('Recovered geometry mismatch: '+member)
                r['raw_file']='raw/%s.bin'%r['map_id']
                (base/r['raw_file']).write_bytes(raw)
        catalog.write_text(json.dumps({'schema':1,'maps':rows},ensure_ascii=False,indent=2)+'\n')
        print('RECOVERED_EXACT_A3_MEMBERS',len(rows))
    target=root/'data/original_maps/catalog.json'
    if target.exists():
        print('EXISTING_RUNTIME_PACK_PRESERVED; run verify_delivery.py to verify it')
        return
    convert(root,a3,viewer)
    print('PRIVATE_PACK_INSTALLED; original graphics still missing; gameplay tests required')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
    p.add_argument('--a3',type=Path,required=True);p.add_argument('--viewer',type=Path,required=True)
    a=p.parse_args();install(a.root.resolve(),a.a3.resolve(),a.viewer.resolve())
