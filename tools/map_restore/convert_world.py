"""Resume from PR81's recovered pack; export every grid and supplied S32 variant.
No whole source rescan, guessed origins, unverified edition rules, or combat stats.
"""
import argparse
from collections import defaultdict,Counter
import json
from pathlib import Path
import sys
import struct
import zipfile
import zlib
import numpy as np
from formats import sha,read_s32,write_s32,move_masks
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'l1j'))
from extract_a3 import tables

def compact(value): return json.dumps(value,ensure_ascii=False,separators=(',',':')).encode()
def output(path,value): path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(compact(value)+b'\n')

class Pack:
    """4 MiB shards bound transfers and runtime seeking; chunks never cross shards."""
    def __init__(self,root,prefix): self.root,self.prefix,self.shard,self.position,self.file,self.known=root,prefix,-1,0,None,{}
    def add(self,raw):
        digest=sha(raw)
        if digest in self.known:return self.known[digest]
        data=zlib.compress(raw,9)
        if self.file is None or self.position+len(data)>4*1024*1024:
            if self.file:self.file.close()
            self.shard+=1;self.position=0;self.file=(self.root/f'{self.prefix}-{self.shard:02}.bin').open('wb')
        ref=[self.shard,self.position,len(data),digest]
        self.file.write(data);self.position+=len(data);self.known[digest]=ref;return ref
    def close(self):
        if self.file:
            self.file.close()
            path = self.root/f'{self.prefix}-{self.shard:02}.bin'
            if path.stat().st_size != self.position:
                raise IOError('Incomplete resource shard: '+str(path))

def convert(root,a3,viewer):
    base=root/'data/l1j/recovered_maps'; out=root/'data/original_maps';docs=root/'docs/map-runtime-20261011'
    out.mkdir(parents=True,exist_ok=True);docs.mkdir(parents=True,exist_ok=True)
    rows=json.loads((base/'source_maps.json').read_text())['maps']
    with zipfile.ZipFile(a3) as source:
        db,_=tables(source.read('db/l1remaster.sql').decode('utf-8-sig'),{'mapids','npc','spawnlist','spawnlist_npc','getback','dungeon','spawnlist_door'})
    meta={int(r['mapid']):r for r in db['mapids']};npcs={int(r['npcid']):r for r in db['npc']}
    by_table={t:defaultdict(list) for t in ['spawnlist','spawnlist_npc','getback','dungeon','spawnlist_door']}
    key={'spawnlist':'mapid','spawnlist_npc':'mapid','getback':'area_mapid','dungeon':'src_mapid','spawnlist_door':'mapid'}
    for t,group in by_table.items():
        for r in db.get(t,[]):group[int(r[key[t]])].append(r)
    masks_by_id={};definitions={};grids={};nav=Pack(out,'navigation');terrain=Pack(out,'terrain')
    s32_refs=defaultdict(list);tile_pairs=defaultdict(set);failures=[]
    for archive in [a3,viewer]:
        with zipfile.ZipFile(archive) as z:
            for name in sorted(z.namelist()):
                if not name.lower().endswith('.s32'):continue
                raw=z.read(name)
                try:
                    p=read_s32(raw,name)
                    if write_s32(p)!=raw:raise ValueError('S32 byte round trip mismatch')
                    ref=terrain.add(compact(p));mid=int(Path(name).parent.name)
                    variant=name.split('client_maps/')[1].split('/')[0] if 'client_maps/' in name else 'viewer_fixture'
                    r={'variant':variant,'origin':p['origin'],'pack':ref,'source':archive.name+'!'+name,
                       'source_sha256':sha(raw),'counts':p['counts'],'duplicate_suffix':'_' in Path(name).stem}
                    s32_refs[mid].append(r)
                    for tile,index in p['tile_pairs']:tile_pairs[tile].add(index)
                except (ValueError,struct.error) as exc:failures.append({'source':archive.name+'!'+name,'sha256':sha(raw),'error':str(exc)})
    existing=json.loads((root/'data/game_db_v17.json').read_text())['몬스터']
    extras=json.loads((root/'data/monsters/monster_world_catalog.json').read_text())['additions']
    known={r['name'] for r in existing+extras}
    explicit=json.loads((root/'data/monsters/l1j_id_map.json').read_text())['monster_id_to_twilight']
    unbound=[]
    for row in rows:
        mid=row['map_id'];w,h=row['dimensions'];raw=(base/row['raw_file']).read_bytes()
        if sha(raw)!=row['row_major_sha256'] or len(raw)!=w*h:raise ValueError('Preserved source grid mismatch '+str(mid))
        grid=np.frombuffer(raw,np.uint8).reshape(h,w);verified=row['navigation_rules']=='A3_STATIC_EDGES' and row['source_origin'] is not None
        masks=move_masks(grid) if verified else np.zeros_like(grid)
        refs=[]
        for cy,y in enumerate(range(0,h,64)):
            for cx,x in enumerate(range(0,w,64)):
                a,m=grid[y:y+64,x:x+64],masks[y:y+64,x:x+64]
                if not np.any(a) and not np.any(m):continue
                ch,cw=a.shape;ref=nav.add(a.tobytes()+m.tobytes())
                refs.append([cx,cy,cw,ch,*ref])
        origin=row['source_origin'];rules=meta.get(mid,{}) if verified else {}
        spawn=[];note='NO_VERIFIED_SPAWN'
        def opened(x,y):
            if not verified:return False
            xx,yy=int(x)-origin[0],int(y)-origin[1]
            return 0<=xx<w and 0<=yy<h and masks[yy,xx]!=0
        if verified:
            grids[mid]=grid;masks_by_id[mid]=masks
            returns=[r for rs in by_table['getback'].values() for r in rs if int(r['getback_mapid'])==mid]
            returns.sort(key=lambda r:0 if '기란' in str(r.get('note','')) else 1)
            for r in returns:
                if opened(r['getback_x1'],r['getback_y1']):spawn=[r['getback_x1'],r['getback_y1']];note=str(r.get('note',''));break
            if not spawn:
                positions=np.argwhere(masks!=0)
                if len(positions):
                    yy,xx=positions[len(positions)//2];spawn=[int(xx)+origin[0],int(yy)+origin[1]];note='Verified walkable source cell; town spawn unknown'
        npc_rows=[];mob_rows=[]
        if verified:
            for r in by_table['spawnlist_npc'][mid]:
                if int(r.get('count',0))<=0:continue
                record=npcs.get(int(r['npc_templateid']),{});impl=record.get('impl','')
                npc_rows.append({'id':'source_npc_'+str(r['id']),'name':record.get('desc_kr',r.get('location','')),
                    'source_position':[r['locx'],r['locy']],'role':{'L1Merchant':'shop','L1Dwarf':'warehouse','L1Teleporter':'teleport'}.get(impl,'source_npc'),
                    'coordinate_valid':bool(opened(r['locx'],r['locy'])),'source_row':r,'source_npc_id':r['npc_templateid']})
            for r in by_table['spawnlist'][mid]:
                n=npcs.get(int(r['npc_templateid']),{}).get('desc_kr','');binding=explicit.get(str(r['npc_templateid']),n if n in known else '')
                mob_rows.append({'source_row':r,'source_name':n,'twilight_name':binding,'source_npc_id':r['npc_templateid']})
                if not binding:unbound.append({'map_id':mid,'npc_id':r['npc_templateid'],'name':n})
        layers=s32_refs.get(mid,[])
        d={'schema':2,'map_id':f'l1_{mid}','source_map_id':mid,'map_name':row['source_name'],'origin':origin,'dimensions':[w,h],
           'source_path':row['source'],'source_sha256':row['row_major_sha256'],'navigation':{'chunks':refs,'profile':row['navigation_rules'],'row_sha256':sha(raw),'mask_sha256':sha(masks.tobytes())},
           'spawn_source':spawn,'spawn_note':note,'playable':bool(spawn),'rules':rules,'graphics_status':'MISSING_ORIGINAL_TILE_IMAGES',
           'npc_spawns':npc_rows,'monster_spawns':mob_rows,'portals':by_table['dungeon'][mid] if verified else [],
           'getback':by_table['getback'][mid] if verified else [],'doors':by_table['spawnlist_door'][mid] if verified else [],
           'terrain_chunks':[r for r in layers if r['variant']=='normal' and r['origin'] and not r['duplicate_suffix']],
           'terrain_variants':layers,'layout_revision':2026101102,'actual_play_test':'NOT_RUN'}
        definitions[mid]=d;output(out/'definitions'/f'{mid}.json',d)
    nav.close();terrain.close()
    links=[]
    for mid,rows in by_table['dungeon'].items():
        for r in rows:
            def valid(mapid,x,y):
                if mapid not in grids:return False
                ox,oy=definitions[mapid]['origin'];grid=grids[mapid];xx,yy=int(x)-ox,int(y)-oy
                return 0<=xx<grid.shape[1] and 0<=yy<grid.shape[0] and masks_by_id[mapid][yy,xx]!=0
            links.append({'from_map':mid,'to_map':r['new_mapid'],'source':[r['src_x'],r['src_y']],
                'target':[r['new_x'],r['new_y']],'source_valid':bool(valid(mid,r['src_x'],r['src_y'])),
                'target_valid':bool(valid(int(r['new_mapid']),r['new_x'],r['new_y']))})
    output(out/'catalog.json',{'schema':2,'maps':[{'id':d['map_id'],'source_map_id':mid,'name':d['map_name'],
        'playable':d['playable'],'source_definition':f'res://data/original_maps/definitions/{mid}.json'} for mid,d in sorted(definitions.items())]})
    output(out/'TILE_IMAGE_MAPPING.json',{'schema':1,'tiles':{str(t):{'indexes':sorted(v),'images':{},'status':'MISSING'} for t,v in sorted(tile_pairs.items())}})
    output(docs/'S32_CHUNK_MAPPING.json',dict(s32_refs));output(docs/'CONVERSION_FAILURES.json',failures)
    output(docs/'PORTAL_VALIDATION.json',links);output(docs/'UNMAPPED_SOURCE_MONSTERS.json',unbound)
    summary={'preserved_source_grids':len(definitions),'verified_a3_navigation_maps':len(grids),'playable_source_maps':sum(d['playable'] for d in definitions.values()),
        'source_s32_layers_converted':sum(len(v) for v in s32_refs.values()),'source_s32_failures':len(failures),
        's32_unknown_chunk_origins':sum(r['origin'] is None for v in s32_refs.values() for r in v),'tile_ids':len(tile_pairs),
        'original_graphics_maps':0,'normal_terrain_maps':sum(bool(d['terrain_chunks']) for d in definitions.values()),
        'navigation_chunks':len(nav.known),'terrain_payloads':len(terrain.known),'valid_portals':sum(r['source_valid'] and r['target_valid'] for r in links),
        'invalid_portals':sum(not(r['source_valid'] and r['target_valid']) for r in links),'unmapped_monster_spawns':len(unbound),'actual_play_maps':0}
    output(docs/'conversion_summary.json',summary);print(json.dumps(summary,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--a3',type=Path,required=True);p.add_argument('--viewer',type=Path,required=True)
    a=p.parse_args();convert(a.root,a.a3,a.viewer)
