#!/usr/bin/env python3
"""Reflow derived gameplay while reusing byte-verified source shards unchanged.

Writes a NEW pack, retains the previous one, and verifies all new placements
before publishing its index. No ZIP extraction or repeated source recovery.
"""
import argparse
import json
from pathlib import Path
import shutil
from build_remake import ROOT, ARCHIVE_SHA, placements, distances, strict_masks, write, sha
from verify_remake import read_verified_grid, verify


def refresh(source,layouts_path,out):
    if out.exists(): raise ValueError('Output exists; do not overwrite a previous pack')
    layouts=json.loads(layouts_path.read_text())
    index=json.loads((source/'index.json').read_text())
    assert index['source_archive_sha256']==ARCHIVE_SHA
    expected={r['map_id']:r for r in json.loads((ROOT/'docs/map-recovery-20261011/MAP_SOURCE_MAPPING.json').read_text())['source_maps'] if r['navigation_rules']=='A3_STATIC_EDGES'}
    report=json.loads((source/'build_report.json').read_text())
    shutil.copytree(source,out)
    (out/'index.json').unlink()
    for map_id,entry in index['maps'].items():
        path=source/'definitions'/f'{map_id}.json'
        assert sha(path.read_bytes())==entry['sha256']
        data=json.loads(path.read_text())
        grid,raw=read_verified_grid(source,data,expected[data['source_map_id']]);masks=strict_masks(raw)
        start=tuple(a-b for a,b in zip(data['spawn_source'],data['origin']))
        reach=distances(masks,start)
        data['remake_gameplay']=placements(layouts[map_id],grid,masks,data['origin'],start,reach)
        data['layout_revision']=2026101502
        write(out/'definitions'/f'{map_id}.json',data)
        entry['sha256']=sha((out/'definitions'/f'{map_id}.json').read_bytes())
        audit=report['maps'][map_id]
        audit['regions']=[{'id':r['id'],'mode':r.get('mode'),'count':r['max_count'],'respawn_time':r['respawn_time'],
            'spawn_radius':r['spawn_radius'],'cells':len(r['source_cells']),'placement_status':r['placement_status']} for r in data['remake_gameplay']['monster_spawn']]
        audit['gameplay']='NOT_RUN_AFTER_REFLOW'
    report['effective_layouts_sha256']=sha(layouts_path.read_bytes())
    report['source_reuse']='HASH_VERIFIED_EXISTING_SHARDS_NO_RECOVERY'
    write(out/'build_report.json',report);write(out/'index.json',index)
    try: result=verify(out,layouts_path)
    except Exception:
        (out/'index.json').unlink();raise
    print(json.dumps({'result':result['result'],'maps':len(index['maps']),'source_bytes_reused':True}))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,required=True);p.add_argument('--layouts',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();refresh(a.source,a.layouts,a.output)
