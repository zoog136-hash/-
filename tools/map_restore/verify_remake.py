#!/usr/bin/env python3
"""Verify an installed private remake without trusting its generated report.

Reconstruct every raw grid and compare it with the previously recovered source
hash, independently recalculate edge rules, and verify all derived reservations
and preserved gameplay fields. No original art / current-M fidelity claim.
"""
import argparse
import json
from pathlib import Path
import zlib
import numpy as np
from formats import move_masks, sha
from build_remake import ARCHIVE_SHA, ROOT, distances, strict_masks, pixel


def read_verified_grid(pack, data, source):
    w,h=data['dimensions'];grid=np.zeros((h,w),np.uint8);masks=grid.copy()
    coverage=np.zeros((h,w),np.uint8)
    for cx,cy,cw,ch,shard,offset,size,digest in data['navigation']['chunks']:
        with (pack/f'navigation-{shard:02}.bin').open('rb') as f:
            f.seek(offset);block=f.read(size)
        assert len(block)==size
        raw=zlib.decompress(block)
        assert len(raw)==cw*ch*2 and sha(raw)==digest, 'source chunk integrity'
        x,y=cx*64,cy*64
        grid[y:y+ch,x:x+cw]=np.frombuffer(raw[:cw*ch],np.uint8).reshape(ch,cw)
        masks[y:y+ch,x:x+cw]=np.frombuffer(raw[cw*ch:],np.uint8).reshape(ch,cw)
        coverage[y:y+ch,x:x+cw]+=1
    assert np.all(coverage==1), 'missing/overlapping source chunks'
    assert sha(grid.tobytes())==source['row_major_sha256']==data['source_sha256']
    assert data['origin']==source['source_origin'] and data['dimensions']==source['dimensions']
    assert np.array_equal(masks,move_masks(grid)), 'original edge bytes changed'
    return grid,masks


def verify(pack: Path, layouts_path: Path):
    layouts = json.loads(layouts_path.read_text())
    index = json.loads((pack/'index.json').read_text())
    old = json.loads((ROOT/'docs/map-recovery-20261011/MAP_SOURCE_MAPPING.json').read_text())
    expected = {r['map_id']: r for r in old['source_maps'] if r['navigation_rules']=='A3_STATIC_EDGES'}
    assert index['source_archive_sha256'] == ARCHIVE_SHA
    assert set(index['maps']) == {f'oman_{n:02}' for n in range(1,11)}
    report = {}
    for map_id, entry in index['maps'].items():
        path = pack/'definitions'/f'{map_id}.json'
        assert entry['path']==f'res://data/map_remake/private/definitions/{map_id}.json'
        assert sha(path.read_bytes())==entry['sha256'], f'{map_id}: definition SHA'
        data = json.loads(path.read_text()); source = expected[data['source_map_id']]
        grid,masks=read_verified_grid(pack,data,source);h,w=grid.shape
        assert data['source_sha256']==entry['grid_sha256']
        strict = strict_masks(masks)
        start = tuple(a-b for a,b in zip(data['spawn_source'],data['origin']))
        reach = distances(strict,start)
        assert np.count_nonzero(reach>=0)==np.count_nonzero(masks), f'{map_id}: unreachable area'
        gameplay = data['remake_gameplay']; legacy=layouts[map_id]
        reserved=[gameplay['entry_exclusion']]
        for kind in ['npc_spawn','portal']:
            assert [r['id'] for r in gameplay[kind]]==[r['id'] for r in legacy[kind]]
            for new,oldrow in zip(gameplay[kind],legacy[kind]):
                x,y=new['source_cell']
                assert reach[y,x]>=0 and new['position']==pixel((x,y),w)
                reserved.append({'center':new['position'],'radius':64})
                if kind=='npc_spawn':
                    for key in set(oldrow)-{'position'}:
                        assert new[key]==oldrow[key], f'{map_id}: NPC service changed {key}'
                else:
                    assert new['target_map']==oldrow['target_map'], f'{map_id}: portal target changed'
        seen=set()
        for new,oldrow in zip(gameplay['monster_spawn'],legacy['monster_spawn']):
            assert float(new.get('spawn_radius',0))==float(oldrow.get('spawn_radius',0)), f'{map_id}: hotspot radius changed'
            for key in gameplay['preserved_gameplay_fields']:
                assert new.get(key)==oldrow.get(key), f'{map_id}: gameplay field changed {key}'
            cells=new['source_cells']
            assert cells==sorted(set(cells)) and not seen.intersection(cells)
            seen.update(cells)
            for flat in cells:
                y,x=divmod(flat,w);px,py=pixel((x,y),w)
                assert 0<=flat<w*h and reach[y,x]>=0 and (grid[y,x]&48)!=16
                if float(new.get('spawn_radius',0))>0:
                    r=new['rect'];cx,cy=r[0]+r[2]/2,r[1]+r[3]/2
                    assert (px-cx)**2+(py-cy)**2<=new['spawn_radius']**2, f'{map_id}: spread outside hotspot'
                for r in reserved:
                    assert (px-r['center'][0])**2+(py-r['center'][1])**2>=r['radius']**2, f'{map_id}: reserved spawn'
        report[map_id]={'grid_sha256':data['source_sha256'],'connected_cells':int((reach>=0).sum()),
            'spawn_cells':len(seen),'regions':len(gameplay['monster_spawn']),
            'placements':'PROVISIONAL','source_edition':'A3_PC','visual_fidelity':'UNVERIFIED'}
    return {'result':'PRIVATE_TOPOLOGY_AND_PLACEMENTS_VERIFIED','maps':report,'failures':[],
            'images':'TWILIGHT_EXISTING_ART_ONLY','android':'NOT_RUN'}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack',type=Path,required=True)
    parser.add_argument('--layouts',type=Path,required=True)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args();result=verify(args.pack,args.layouts)
    if args.report: args.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False))
