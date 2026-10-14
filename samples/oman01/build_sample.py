#!/usr/bin/env python3
"""Build an isolated copy of the existing TWILIGHT game using the supplied A3 101 grid.
Never modifies the source checkout or the user's normal Godot save directory.
No downloaded map substitutes, no fabricated original NPC/boss coordinates.
"""
from __future__ import annotations
import argparse
import collections
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import zipfile
import zlib

GRID_SHA = '5e0ea64c017c6d09a8df12d4e7aa267f48a4eb150f10cd6429a199d6625e1aca'
CACHE_SHA = 'a81f5a7a178033be490f717638a36e0b139f53a9f23ba4ea0efdbbfe8c14f207'
SIZE = 192
ORIGIN = (32704, 32704)
DIRECTIONS = ((0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1))

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def load_grid(a3: Path | None, attributes: Path | None) -> bytes:
    if attributes:
        raw = attributes.read_bytes()
    else:
        if a3 is None:
            raise ValueError('Supply --a3 with the uploaded a3.zip, or --attributes with its verified 101 row-major grid.')
        with zipfile.ZipFile(a3) as archive:
            names = [n for n in archive.namelist() if n == 'data/mapcache/101.map' or n.endswith('/data/mapcache/101.map')]
            if len(names) != 1:
                raise ValueError('Expected exactly one A3 data/mapcache/101.map member.')
            cache = archive.read(names[0])
        if len(cache) != 20 + SIZE * SIZE or struct.unpack('>5i', cache[:20]) != (101, *ORIGIN, SIZE, SIZE):
            raise ValueError('A3 map header or dimensions differ from the reviewed source.')
        if digest(cache) != CACHE_SHA:
            raise ValueError('Source cache SHA differs. Do not silently substitute another edition.')
        payload = cache[20:]
        raw = bytes(payload[x*SIZE+y] for y in range(SIZE) for x in range(SIZE))
    if len(raw) != SIZE*SIZE or digest(raw) != GRID_SHA:
        raise ValueError('The exact reviewed A3 101 row-major grid is required.')
    return raw

def move_masks(raw: bytes) -> bytes:
    def v(x: int, y: int) -> int:
        return raw[y*SIZE+x] if 0 <= x < SIZE and 0 <= y < SIZE else 0
    result = bytearray(SIZE*SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            first = v(x,y)
            for d,(dx,dy) in enumerate(DIRECTIONS):
                nx,ny=x+dx,y+dy
                if not (0 <= nx < SIZE and 0 <= ny < SIZE):
                    continue
                second=v(nx,ny)
                allowed=(bool(first&2),
                    bool((first&2 and v(x,y-1)&1) or (first&1 and v(x+1,y)&2)),
                    bool(first&1), bool((v(x,y+1)&3)==3 or (first&1 and second&2)),
                    bool(second&2), bool((second&1 and v(x,y+1)&2) or (second&2 and v(x-1,y)&1)),
                    bool(second&1), bool((v(x-1,y)&3)==3 or (first&2 and second&1)))[d]
                if allowed:
                    result[y*SIZE+x] |= 1 << d
    return bytes(result)

def connected_components(masks: bytes) -> list[int]:
    seen: set[tuple[int,int]] = set()
    counts: list[int] = []
    for y in range(SIZE):
        for x in range(SIZE):
            if not masks[y*SIZE+x] or (x,y) in seen:
                continue
            queue=collections.deque([(x,y)]); seen.add((x,y)); count=0
            while queue:
                cx,cy=queue.popleft(); count+=1
                for d,(dx,dy) in enumerate(DIRECTIONS):
                    target=(cx+dx,cy+dy)
                    if masks[cy*SIZE+cx] & (1<<d) and target not in seen:
                        seen.add(target); queue.append(target)
            counts.append(count)
    return sorted(counts,reverse=True)

def nearest(masks: bytes, source: tuple[int,int]) -> list[int]:
    cx,cy=source[0]-ORIGIN[0],source[1]-ORIGIN[1]
    candidates=[]
    for y in range(max(0,cy-16),min(SIZE,cy+17)):
        for x in range(max(0,cx-16),min(SIZE,cx+17)):
            if masks[y*SIZE+x]:
                candidates.append(((x-cx)**2+(y-cy)**2,y,x))
    if not candidates:
        raise ValueError(f'No connected landing near {source}; manual edition review required.')
    _,y,x=min(candidates)
    return [x+ORIGIN[0],y+ORIGIN[1]]

def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def prepare(root: Path, destination: Path, raw: bytes, a3: Path | None = None) -> dict:
    if destination.exists():
        raise ValueError('Destination must not exist. Existing samples and saves are never overwritten.')
    if destination == root or root in destination.parents:
        raise ValueError('Choose a sibling directory outside the source checkout.')
    if not (root/'Main.tscn').is_file() or not (root/'scripts/world.gd').is_file():
        raise ValueError('--root must point to the existing TWILIGHT checkout.')
    masks=move_masks(raw)
    components=connected_components(masks)
    if components != [16868]:
        raise ValueError(f'Unexpected source connectivity: {components}')
    destination.mkdir(parents=True)
    # Copy, not symlink/hardlink: editor imports cannot modify source-checkout resources.
    for name in ['project.godot','Main.tscn','assets','scripts','scenes','data','addons','samples']:
        p=root/name
        if not p.exists():
            continue
        if p.is_dir():
            shutil.copytree(p,destination/name,ignore=shutil.ignore_patterns('.godot','__pycache__','evidence','original_maps','recovered_maps'))
        else:
            shutil.copy2(p,destination/name)
    config=destination/'project.godot'
    text=config.read_text(encoding='utf-8')
    text=text.replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="TWILIGHT_OMAN01_SAMPLE"',1)
    config.write_text(text,encoding='utf-8')
    world=destination/'scripts/world.gd'
    text=world.read_text(encoding='utf-8')
    old='const SOURCE_RENDERER = preload("res://scripts/maps/source_renderer.gd")'
    if text.count(old)!=1:
        raise ValueError('World renderer integration changed. Refusing an unreviewed replacement.')
    text=text.replace(old,'const SOURCE_RENDERER = preload("res://samples/oman01/renderer.gd")',1)
    world.write_text(text,encoding='utf-8')
    # The art is wholly new and deterministic. No proprietary Lineage artwork is copied.
    import runpy
    atlas_path=destination/'samples/oman01/assets/oman01_flagstones.png'
    runpy.run_path(str(root/'samples/oman01/make_floor.py'))['generate'](atlas_path)
    if not atlas_path.is_file(): raise ValueError('Dungeon flagstone art generation failed')
    output=destination/'data/original_maps'; output.mkdir(parents=True,exist_ok=True)
    pack=bytearray(); chunks=[]
    for cy in range(3):
        for cx in range(3):
            values=b''.join(raw[(cy*64+y)*SIZE+cx*64:(cy*64+y)*SIZE+cx*64+64] for y in range(64))
            edges=b''.join(masks[(cy*64+y)*SIZE+cx*64:(cy*64+y)*SIZE+cx*64+64] for y in range(64))
            block=values+edges; compressed=zlib.compress(block,9)
            chunks.append([cx,cy,64,64,0,len(pack),len(compressed),digest(block)])
            pack.extend(compressed)
    (output/'navigation-00.bin').write_bytes(pack)
    write_json(output/'TILE_IMAGE_MAPPING.json',{'schema':1,'tiles':{}})
    entrance=nearest(masks,(32728,32799))
    guide=nearest(masks,(32800,32800))
    encounter=nearest(masks,(32796,32800))
    # A3 SQL provides actual PC-series spawn rows; never call temporary M positions original.
    original_rows=[]
    orphan_rows=[]
    source_npc=[]
    if a3 is not None:
        sys.path.insert(0,str(root/'tools/l1j'))
        from extract_a3 import tables
        with zipfile.ZipFile(a3) as zip_file:
            db,_=tables(zip_file.read('db/l1remaster.sql').decode('utf-8-sig'),{'spawnlist','spawnlist_npc'})
        original_rows=[r for r in db['spawnlist'] if int(r['mapid'])==101]
        source_npc=[r for r in db['spawnlist_npc'] if int(r['mapid'])==101]
    known_names={row.get('name','') for row in json.loads((root/'data/game_db_v17.json').read_text())['몬스터']}
    known_names.update(row.get('name','') for row in json.loads((root/'data/monsters/monster_world_catalog.json').read_text())['additions'])
    name_alias={'왜곡의 옹골리언트':'왜곡의 웅골리언트'}
    adapted=[]
    for row in original_rows:
        original_name=str(row['location'])
        match=name_alias.get(original_name,original_name)
        if original_name.startswith('구슬(') or match not in known_names:
            orphan_rows.append({'source_name':original_name,'source_id':row['id'],
                 'reason':'orb-not-combat-monster' if original_name.startswith('구슬(') else 'game-record-not-matched'})
            continue
        limited=dict(row)
        limited['count']=min(8,int(row['count']))
        adapted.append({'twilight_name':match,'source_name':original_name,'source_row':limited,
             'provenance':'A3_ROW_WITH_LOCAL_RUNTIME_COUNT_CAP_8'})
    definition={'schema':2,'map_id':'l1_101','map_name':'오만의 탑 1층 · A3 리메이크 샘플','source_map_id':101,
        'source_sha256':GRID_SHA,'playable':True,'layout_revision':2,'origin':list(ORIGIN),'dimensions':[SIZE,SIZE],
        'navigation':{'profile':'A3_STATIC_EDGES','chunks':chunks},'spawn_source':entrance,
        'rules':{'escapable':0,'teleportable':0},'getback':[],'doors':[],'portals':[],'terrain_chunks':[],
        'npc_spawns':[], 'monster_spawns':adapted, 'sample_encounter_source':encounter,
        'visuals_provenance':'Original A3 topology and sampled M-style authored 2D art; exact M prop positions unverified.'}
    # Source NPC (32800,32800) is blocked on this A3 grid. Do not spawn a fake guide.
    original_reference={'source_spawnlist':original_rows,'source_npc':source_npc,'unmatched':orphan_rows}
    write_json(destination/'samples/oman01/evidence/a3_101_spawn_reference.json',original_reference)
    write_json(output/'definitions/101.json',definition)
    write_json(output/'catalog.json',{'schema':2,'maps':[{'id':'l1_101','source_map_id':101,'name':definition['map_name'],
        'playable':True,'source_definition':'res://data/original_maps/definitions/101.json'}]})
    report={'status':'SOURCE_VALIDATED_GAMEPLAY_NOT_YET_RUN','grid_sha256':GRID_SHA,'cache_sha256':CACHE_SHA,
        'grid':[SIZE,SIZE],'origin':list(ORIGIN),'connected_components':components,'navigation_chunks':9,
        'source_coordinate_issues':{'original_exit_32724_32799_walkable':bool(masks[95*SIZE+20]),
          'original_npc_32800_32800_walkable':bool(masks[96*SIZE+96])},
        'sample_entry':entrance,'sample_guide':None,'sample_encounter':encounter,
        'source_npc_rows':len(source_npc),'a3_spawn_rows':len(original_rows),
        'matched_combat_spawn_rows':len(adapted),'unmatched_a3_rows':orphan_rows,
        'visuals':'New deterministic dark flagstone tiles; grouped stone masonry and oxidized gothic iron. Not restored NC tile art.',
        'spawn_policy':'Source A3 combat rows with runtime cap 8 where existing TWILIGHT DB identity matches. Unmatched source rows excluded. Zenith Queen in the sample run is a separate test-only override; not a verified M respawn zone/schedule.',
        'edition_status':'A3 PC source topology. Current Lineage M per-object coordinates remain unverified.',
        'source_checkout_unchanged':True,'normal_user_save_untouched':True}
    write_json(destination/'samples/oman01/evidence/source_validation.json',report)
    return report

def self_test() -> None:
    # These are utility tests only, not substitute evidence for the source grid/game.
    assert len(DIRECTIONS)==8 and len(set(DIRECTIONS))==8
    for x,y in [(0.5,0.5),(18.5,95.5),(96.5,96.5),(191.5,191.5)]:
        px,py=24*(x+y),12*(y-x+SIZE)
        assert abs((px/24-py/12+SIZE)/2-x)<1e-9
        assert abs((px/24+py/12-SIZE)/2-y)<1e-9
    assert move_masks(bytes(SIZE*SIZE))==bytes(SIZE*SIZE)
    try:
        load_grid(None,None)
    except ValueError:
        pass
    else:
        raise AssertionError('Missing sources must fail, not create a fabricated map.')
    print('UTILITY_CHECKS_OK; ORIGINAL_GRID_AND_GAMEPLAY_NOT_TESTED')

def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--a3',type=Path)
    parser.add_argument('--attributes',type=Path)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--self-test',action='store_true')
    args=parser.parse_args()
    if args.self_test:
        self_test(); return
    if args.output is None:
        parser.error('--output is required and must be a new sibling directory')
    report=prepare(args.root.resolve(),args.output.resolve(),load_grid(args.a3,args.attributes),args.a3)
    print(json.dumps(report,ensure_ascii=False,indent=2))
    print('NEXT: godot --path "'+str(args.output.resolve())+'" --editor --headless --quit')
    print('THEN: godot --path "'+str(args.output.resolve())+'" --script res://samples/oman01/run.gd')

if __name__=='__main__':
    try:
        main()
    except (ValueError,OSError,zipfile.BadZipFile) as error:
        print('OMAN_SAMPLE_BLOCKED:',error,file=sys.stderr)
        raise SystemExit(2)
