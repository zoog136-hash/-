#!/usr/bin/env python3
"""Project the pinned source linkage into explicit source84 spawn candidates.
Godot still verifies the live grid, floor, protected entry/NPC/portal space.
"""
import argparse, collections, hashlib, json, zipfile
from pathlib import Path
EXPECTED = '33e0b552f1cbd75aef1d299886603107185df1e89cd76432268f94c5bd3b5c77'

def build(archive, root):
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == EXPECTED
    policy = json.loads((root/'data/maps/source_map_runtime.json').read_text())['maps']
    maps = {int(v['source_map_id']): k for k,v in policy.items()}
    identities = {int(r['source_npc_id']):r for r in json.loads((root/'data/monsters/reviewed_source_monsters.json').read_text())['records'] if r['import_enabled']}
    with zipfile.ZipFile(archive) as source:
        assert source.testzip() is None
        member = source.read('map_source3_links/spawns.json')
    rows, held = [], collections.Counter()
    for r in json.loads(member):
        if r['npc_id'] not in identities or not r['source_enabled'] or int(r['map_id']) not in maps: continue
        assert r['npc_impl'] == 'L1Monster'
        assert int(r['gfx_id']) == int(identities[r['npc_id']]['source_raw_fields']['gfxid'])
        raw = r['raw']
        low, high = (float(r['respawn'][k] or 0) for k in ('min_seconds','max_seconds'))
        reason = None
        if r['table'] != 'spawnlist': reason = 'conditional_boss_or_other_table'
        elif raw.get('group_id') != '0': reason = 'group_semantics'
        elif low < 0 or high < low: reason = 'invalid_respawn'
        elif r.get('time_window') is not None or raw.get('near_spawn') != '0' or raw.get('rest') != '0': reason = 'conditional_time_or_spawn_type'
        elif r.get('map_monster_amount_multiplier') != '1': reason = 'map_multiplier'
        if reason: held[reason] += 1; continue
        mid = maps[int(r['map_id'])]
        x, y = int(raw['locx']), int(raw['locy'])
        mode = r['position_mode']
        count = int(r['source_count'])
        if count > 1 and int(raw['locx1']) == 0:
            radius = min(count * 6, 30)
            mode = 'server_count_area'
            bounds = [x-radius,y-radius,x+radius-1,y+radius-1]
        elif mode == 'fixed_point': bounds = [x,y,x,y]
        elif mode == 'random_offsets':
            rx, ry = max(0,int(raw['randomx'])-1),max(0,int(raw['randomy'])-1)
            bounds = [x-rx,y-ry,x+rx,y+ry]
        elif mode == 'area_rectangle':
            bounds = list(map(int,r['source_area'])); bounds[2] -= 1; bounds[3] -= 1
        elif mode not in ['fixed_point','server_count_area']: held['unknown_position'] += 1; continue
        identity = identities[r['npc_id']]
        rows.append(dict(key=r['key'],map_id=mid,source_map_id=r['map_id'],grid_sha256=policy[mid]['grid_sha256'],layout_revision=policy[mid]['layout_revision'],source_npc_id=str(r['npc_id']),game_source_id=identity['sourceId'],name=identity['name'],source_bounds=bounds,count=int(r['source_count']),respawn_seconds=[low,high],heading=int(raw['heading']),raw_row_sha256=hashlib.sha256(json.dumps(raw,sort_keys=True,ensure_ascii=False).encode()).hexdigest(),position_mode=mode,sampling_center=[x,y],sampling_offsets=[int(raw['randomx']),int(raw['randomy'])],respawn_on_screen=raw['respawn_screen']=='1'))
    payload = dict(schema=2,spawn_semantics=dict(repository='https://github.com/nonono44/l1j-tw-99nets',commit='8aa24617476a7d8f6a7072687279c77cf9f3d405',crlf_sha256={'L1Spawn': '6cfc79608b5102e1ed8b3a401678e3ee992c1afb29ba9fce7cbd743f46b9c41b', 'SpawnTable': 'a6f7b337883469d1870338298206f7ddb8628d139d0dd88ece36273f445b30dd', 'S_IdentifyDesc': '1f668fec682069170d682484020a2e13ff641c2a36a9c9b66721d8f2a01487e6'},notes='Zero is immediate rescheduling; integer upper delay and rectangle bounds exclusive; difference-of-two-uniform offset sampling; count>1 without area expands min(count*6,30); screen false defers visible respawn. TWILIGHT keeps its own corpse lifecycle and bounded creation queue.'),input_zip_sha256=EXPECTED,input_member='map_source3_links/spawns.json',input_member_sha256=hashlib.sha256(member).hexdigest(),scope='explicit reviewed active identities on verified source84 maps only; physical floor checked at runtime, conditional group/boss semantics held; zero-delay and visibility interpreted from pinned source',held_rows=dict(held),rows=rows)
    (root/'data/monsters/source3_map_spawns.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
    print('SOURCE3_SPAWN_CANDIDATES',len(rows),'slots',sum(r['count'] for r in rows),'held',dict(held))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive',type=Path,required=True)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
    args = parser.parse_args(); build(args.archive,args.root)
