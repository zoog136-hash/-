#!/usr/bin/env python3
"""Make ONLY visual interpretation data for Giran; never rewrite a nav pack.

S32 IDs are references, not pictures. Material/structure identities below are
explicit TWILIGHT interpretations pending comparison approval, not decoded art.
"""
import argparse
import base64
from collections import Counter, deque
import hashlib
import json
from pathlib import Path
import zipfile
import zlib

import numpy as np
from formats import origin, read_s32, write_s32

RECT = (928, 672, 128, 192)
SOURCE_ORIGIN = (32448, 32064)
A3_SHA = '2d25c6d5408aaf29443167c4c82c30b32d1a83b16039d988471ba0c832eb7d20'


def digest(blob):
    return hashlib.sha256(blob).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def build(root, archive, output, report):
    if output.exists():
        raise ValueError('Refusing to overwrite an existing visual review directory')
    if digest(archive.read_bytes()) != A3_SHA:
        raise ValueError('A3 source identity differs')
    pack = root / 'data/map_remake/private/aden'
    definition_bytes = (pack / 'definitions/aden_world.json').read_bytes()
    definition = json.loads(definition_bytes)
    x0, y0, width, height = RECT
    masks = np.zeros((height, width), dtype='uint8')
    grid = masks.copy()
    for cx, cy, cw, ch, shard, offset, length, sha in definition['navigation']['chunks']:
        if not (x0 <= cx*64 < x0+width or cx*64 <= x0 < cx*64+cw):
            continue
        if not (y0 <= cy*64 < y0+height or cy*64 <= y0 < cy*64+ch):
            continue
        with (pack / f'navigation-{shard:02}.bin').open('rb') as file:
            file.seek(offset)
            blob = zlib.decompress(file.read(length))
        if digest(blob) != sha:
            raise ValueError('Existing immutable navigation hash mismatch')
        for target, start in [(grid, 0), (masks, cw*ch)]:
            source = np.frombuffer(blob[start:start+cw*ch], dtype='uint8').reshape(ch,cw)
            left, top = max(x0,cx*64), max(y0,cy*64)
            right, bottom = min(x0+width,cx*64+cw), min(y0+height,cy*64+ch)
            target[top-y0:bottom-y0,left-x0:right-x0] = source[top-cy*64:bottom-cy*64,left-cx*64:right-cx*64]

    floor_ids = np.zeros((height,width),dtype='uint16')
    observations = []
    object_ids, floor_counts = Counter(), Counter()
    with zipfile.ZipFile(archive) as z:
        for name in sorted(z.namelist()):
            if not name.startswith('data/client_maps/normal/4/') or not name.endswith('.s32'):
                continue
            at = origin(name)
            if at is None:
                continue
            sx, sy = at[0]-SOURCE_ORIGIN[0], at[1]-SOURCE_ORIGIN[1]
            if sx+64 <= x0 or sy+64 <= y0 or sx >= x0+width or sy >= y0+height:
                continue
            blob = z.read(name)
            parsed = read_s32(blob,name)
            if write_s32(parsed) != blob:
                raise ValueError('Giran S32 roundtrip differs: '+name)
            halves = np.frombuffer(base64.b64decode(parsed['floor_bytes']),
                                  dtype=[('index','u1'),('tile','<u2'),('unknown','u1')]).reshape(64,128)
            left, top = max(x0,sx),max(y0,sy)
            right,bottom = min(x0+width,sx+64),min(y0+height,sy+64)
            floor_ids[top-y0:bottom-y0,left-x0:right-x0] = halves['tile'][top-sy:bottom-sy,2*(left-sx):2*(right-sx):2]
            floor_counts.update(map(int,halves['tile'].ravel()))
            object_ids.update(int(tile[4]) & 65535 for group in parsed['objects'] for tile in group['tiles'])
            observations.append({'path':name,'sha256':digest(blob),'origin':at,
                                 'roundtrip':'PASS','counts':parsed['counts'],
                                 'unknown_tail_bytes':len(base64.b64decode(parsed['tail_bytes']))})
        art = [n for n in z.namelist() if n.lower().endswith('.til') or n.rsplit('/',1)[-1].lower() in ['tile.pak','tile.idx']]

    # A visual interpretation, NOT a recovered texture-ID mapping. The plaza
    # families 3988..3990 are spatially observed around the A3 Giran anchor.
    surfaces = np.full((height,width), 2, dtype='uint8')
    safe = (grid & 48) == 16
    surfaces[safe] = 0
    surfaces[np.isin(floor_ids,[1173,1174,89,162,190])] = 1
    surfaces[np.isin(floor_ids,[313,314,315,3918,3919,3920,3921,3922,3988,3989,3990,4335,4336])] = 0
    # Keep the reference plaza continuous rather than inventing isolated grass
    # squares for unknown/occluded S32 tiles underneath the central monument.
    surfaces[736-y0:766-y0,966-x0:1005-x0] = 0
    # Six strips around the plaza are present in the S32 floor ID layout.
    # Their placement is observed; flower species/curb artwork are authored.
    garden = np.isin(floor_ids,[3611,3612,3613,3614])
    surfaces[garden] = 1

    visited = np.zeros_like(masks,dtype=bool)
    components = []
    for y in range(height):
        for x in range(width):
            if masks[y,x] or visited[y,x]:
                continue
            queue = deque([(x,y)]); visited[y,x] = True; cells = []
            while queue:
                px,py = queue.popleft();cells.append((px+x0,py+y0))
                for dx,dy in [(0,-1),(1,0),(0,1),(-1,0)]:
                    nx,ny=px+dx,py+dy
                    if 0<=nx<width and 0<=ny<height and not masks[ny,nx] and not visited[ny,nx]:
                        visited[ny,nx]=True;queue.append((nx,ny))
            xs,ys=zip(*cells);box=[min(xs),min(ys),max(xs)-min(xs)+1,max(ys)-min(ys)+1]
            components.append({'box':box,'cells':cells})

    props=[]; covered=set()
    for item in components:
        bx,by,bw,bh=item['box'];count=len(item['cells'])
        if bx<=x0 or by<=y0 or bx+bw>=x0+width or by+bh>=y0+height:
            continue
        kind=None
        if bx<=982<bx+bw and by<=749<by+bh:
            kind='monument'; slot=8;size=220
        elif count>=23 and 5<=bw<=22 and 5<=bh<=22 and count < bw*bh*.88:
            kind='building';slot=(bx+by)%2;size=24*(bw+bh)*1.02
        elif count>=18 and 8<=bw<=24 and 4<=bh<=18 and by<730:
            kind='hall';slot=3;size=24*(bw+bh)
        elif 3<=count<=30 and bw<=7 and bh<=8:
            kind='planting' if 965<bx<1008 and 731<by<769 else 'tree'
            slot=9 if kind=='planting' else (4 if (bx+by)%3 else 5)
            size=90 if kind=='planting' else 100+count*2
        if kind is None:
            continue
        cells=item['cells'];cx=(bx+bx+bw-1)/2;cy=(by+by+bh-1)/2
        # Sprite feet sit at the forward ground edge of this source footprint.
        foot=[24*(cx+cy+1),12*(cy-cx+2048)+12*(bw+bh)*.42]
        props.append({'id':f'{kind}_{bx}_{by}','kind':kind,'slot':slot,'position':foot,
                      'width':round(size,2),'source_box':item['box'],
                      'source_blocked_cells':len(cells),
                      'identity_status':'TWILIGHT_INTERPRETATION_NOT_IDENTIFIED_S32_OBJECT',
                      'collision':'EXISTING_A3_ONLY'})
        covered.update(cells)

    # A component inside a larger structure's bounding box is part of that
    # compound, not evidence for another house. Avoid overlapping full houses.
    buildings=[p for p in props if p['kind'] in ['building','hall']]
    nested=set()
    for p in buildings:
        b=p['source_box']
        p['height']=12*(b[2]+b[3])+140
        for q in buildings:
            if p is q:
                continue
            a=q['source_box']
            if a[0]<=b[0] and a[1]<=b[1] and a[0]+a[2]>=b[0]+b[2] and a[1]+a[3]>=b[1]+b[3]:
                nested.add(p['id'])
    props=[p for p in props if p['id'] not in nested]

    # Small accents at already blocked source cells; no decorative obstacle is
    # added to an originally open walking cell.
    for item in components:
        cells=item['cells'];bx,by,bw,bh=item['box']
        if not (962<=bx<1010 and 730<=by<772) or any(c in covered for c in cells):
            continue
        if 1<=len(cells)<=6:
            cx=sum(c[0] for c in cells)/len(cells);cy=sum(c[1] for c in cells)/len(cells)
            slot=11 if (bx+by)%2 else 15
            props.append({'id':f'accent_{bx}_{by}','kind':'accent','slot':slot,
                          'position':[24*(cx+cy+1),12*(cy-cx+2048)+8],
                          'width':36 if slot==11 else 48,'source_box':[bx,by,bw,bh],
                          'source_blocked_cells':len(cells),'identity_status':'AUTHORED_ACCENT_AT_A3_BLOCKER',
                          'collision':'EXISTING_A3_ONLY'})
            covered.update(cells)

    # No claim about original doors: this trial gate is a decoration around an
    # existing open approach and never changes source passability.
    for cx,cy in [(1018,711),(1019,711),(1018,710)]:
        if masks[cy-y0,cx-x0]:
            props.append({'id':'north_open_gate','kind':'open_gate','slot':2,
                          'position':[24*(cx+cy+1),12*(cy-cx+2048)+25],
                          'width':260,'source_box':[cx-3,cy-3,7,7],
                          'identity_status':'AUTHORED_OPEN_GATE_ORIGINAL_ID_UNVERIFIED',
                          'collision':'EXISTING_A3_ONLY_NO_DOOR_STATE'})
            break

    output.mkdir(parents=True)
    (output/'surfaces.bin').write_bytes(surfaces.tobytes())
    # The renderer can show all remaining source edges with textured low stone
    # coping; coverage is recorded, never counted as identified original art.
    layout={'schema':1,'map_id':'aden_world','review_status':'AWAITING_USER_REVIEW',
            'source_cell_rect':list(RECT),'source_origin':list(SOURCE_ORIGIN),
            'surface_sha256':digest(surfaces.tobytes()),'surface_bytes':int(surfaces.size),
            'props':props,'covered_blocked_cells':sorted(y*2048+x for x,y in covered),
            'garden_cells':sorted(int((y+y0)*2048+x+x0) for y,x in zip(*np.nonzero(garden))),
            'garden_status':'S32_FLOOR_FAMILY_3611_3614_POSITION_OBSERVED_ART_INTERPRETED',
            'material_status':'REFERENCE_GUIDED_INTERPRETATION_NOT_ORIGINAL_TILE_ART',
            'source_definition_sha256':digest(definition_bytes)}
    write_json(output/'layout.json',layout)
    report.parent.mkdir(parents=True,exist_ok=True)
    write_json(report,{'source_archive_sha256':A3_SHA,'archive_crc':'NOT_RUN_BY_THIS_COMMAND',
                       'selected_s32_crc':'PASS',
                       'scope_source_rect':[x0+32448,y0+32064,width,height],
                       's32':observations,'s32_floor_tile_ids':dict(sorted(floor_counts.items())),
                       's32_object_fragment_tile_ids':dict(sorted(object_ids.items())),
                       'tile_graphic_files_in_a3':art,'object_fragment_count_is_not_building_count':True,
                       'identity_mapping':'UNVERIFIED','props':len(props),
                       'prop_kinds':dict(Counter(p['kind'] for p in props)),
                       'topology_regenerated':False,'original_art_recovered':False})
    print(json.dumps({'props':len(props),'s32_segments':len(observations),'topology_regenerated':False}))


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
    parser.add_argument('--a3',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--report',type=Path,required=True)
    args=parser.parse_args()
    build(args.root,args.a3,args.output,args.report)
