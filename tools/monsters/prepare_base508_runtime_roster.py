"""Prepare source-ID/context registry and explicit host-port definitions.

A source context key preserves class ID, view and territory. Multiple levels
create multiple keys; no class-global level is selected for those variants.
"""
import argparse, gzip, json
from pathlib import Path
from collections import defaultdict

def read(p):
    if p.suffix in ('.gz','.bin'):
        with gzip.open(p,'rt',encoding='utf-8-sig') as f:return json.load(f)
    return json.loads(p.read_text(encoding='utf-8-sig'))

def key(c):return f"lineagem_base508:npc:{c['npc_id']}:spawn:{c['spawn_view_id']}:territory:{c['territory_link_id']}"

def run(a):
    data=read(a.contexts);tables=data['tables'];npcs={r['ID']:r for r in read(a.npcs)['rows']}
    territories={r['ID']:r for r in tables['Territories']};lands={r['ID']:r for r in tables['Land']}
    links=defaultdict(list)
    for r in tables['NpcSpawnPackTerritory']:links[r['NpcSpawnPackID']].append(r)
    views=defaultdict(list)
    for r in tables['NpcSpawnPackNpcClassView']:views[r['NpcClassID']].append(r)
    ui_boss=read(a.content/'UIBossNpcClass.json')['rows'];boss_ids={r['NpcClassID'] for r in ui_boss}
    review=read(a.requests);original=read(a.first_bindings)['bindings'];legacy=read(a.legacy)
    selections=[];records=[];all_contexts={};staged=[]
    rows=review['source_review']
    for special in (90,60303):
        npc=npcs[special];vid,lid=(762,558) if special==90 else (3520,1410)
        view=next(v for v in views[special] if v['ID']==vid)
        link=next(v for v in links[view['NpcSpawnPackID']] if v['ID']==lid)
        land=territories[link['TerritoriesID']]['LandID']
        rows.append({'npc_id':special,'sprite_id':npc['Sprite'],'display_name':npc.get('DisplayName_from_DescId',''),
                     'source_internal_name':npc['Name'],'context_issues':[],'motion_issues':[],
                     'selected_context':{'npc_id':special,'sprite_id':npc['Sprite'],'spawn_view_id':vid,'territory_link_id':lid,'land_id':land,'land_asset_path':lands[land]['AssetPath'],'npc_level':view['NpcLevel']}})
    for row in rows:
        nid=row['npc_id'];npc=npcs[nid]
        unsupported=[s for s in row['context_issues'] if s!='multiple_Aden_context_levels']+row['motion_issues']
        if unsupported or not row['selected_context']:
            staged.append({'npc_id':nid,'sprite_id':npc['Sprite'],'reason':unsupported});continue
        selection=row['selected_context'].copy();contexts=[]
        for view in views[nid]:
            if view['IsSpawn']!=1 or view['ServerLimitSetID']!=0 or view['NpcLevel']<=0:continue
            for link in links[view['NpcSpawnPackID']]:
                t=territories[link['TerritoriesID']]
                if t['LandID']!=selection['land_id']:continue
                if nid==60303 and (view['ID'],link['ID'])!=(3520,1410):continue
                c={'npc_id':nid,'sprite_id':npc['Sprite'],'spawn_view_id':view['ID'],'territory_link_id':link['ID'],
                   'land_id':t['LandID'],'land_asset_path':lands[t['LandID']]['AssetPath'],'npc_level':view['NpcLevel']}
                contexts.append(c);all_contexts[key(c)]=c
        if not contexts:raise ValueError(('Source context unexpectedly missing',nid))
        selection['source_contexts']=contexts;selections.append(selection)
        records.append({**{k:selection[k] for k in ('npc_id','sprite_id','spawn_view_id','territory_link_id','land_id','land_asset_path','npc_level')},
                        'key':key(selection),'display_name':npc.get('DisplayName_from_DescId',''),
                        'source_internal_name':npc['Name'],'source_ui_boss':nid in boss_ids,
                        'source_context_keys':[key(c) for c in contexts],'host_maps':['aden_world'],
                        'host_placement_contract':'Explicit host-Aden adaptation only; native geographic placement/quantity/respawn not claimed.'})
    index={r['npc_id']:r for r in records};expanded={r['name']:(i,r) for i,r in enumerate(legacy['expanded'])}
    # Explicit author migrations: guarded old slots, not numeric-ID or name-equality proofs.
    choices={257:'오크',258:'오크 궁수',282:'해골 궁수',287:'킹버그베어',322:'오우거',330:'산적 저격수',404:'에티',418:'하피',90:'슬라임',60303:'커츠'}
    ports=[]
    for nid,name in choices.items():
        if nid not in index or name not in expanded:continue
        pos,old=expanded[name];r=index[nid]
        if nid not in (90,60303) and old.get('catalog_only',False):continue
        # In particular, do not map old boss 흑장로 to NPC358: it has no UIBossNpcClass link.
        if old.get('is_boss',False) and not r['source_ui_boss']:raise ValueError(('Host boss vs source UI-boss mismatch',nid,name))
        signature={k:old.get(k) for k in ('name','hp','lv','type','grade')}
        for k in ('sourceId','source_npc_id','catalog_only'):
            if k in old:signature[k]=old[k]
        base_index=next((i for i,v in enumerate(legacy['base']) if v['name']==name),-1)
        ports.append({**{k:r[k] for k in ('npc_id','sprite_id','spawn_view_id','territory_link_id','land_id','land_asset_path')},
                      'host_map_id':'aden_world','legacy_game_db_index':base_index,'legacy_expanded_index':pos,
                      'legacy_signature':signature,
                      'placement_contract':'Author-selected exact base508 NPC/context replaces this guarded host encounter; old host position/count/respawn and other combat remain compatibility. Not a cross-game identity equality or native M geographic claim.'})
    out={'schema':1,'source_snapshot':'base508','source_id_records':records,'contexts':all_contexts,
         'port_bindings':ports,'staged':staged,
         'source_ui_boss_rows':ui_boss,
         'counts':{'source_npc_classes':len(records),'source_context_records':len(all_contexts),
                   'original_host_ports_preserved':len(original),'additional_guarded_host_ports':len(ports),
                   'staged_source_npcs':len(staged),'native_geographic_spawns':0}}
    a.output.write_text(json.dumps(out,ensure_ascii=False,separators=(',',':'))+'\n')
    a.selections.write_text(json.dumps({'selections':selections},ensure_ascii=False,separators=(',',':'))+'\n')
    print(json.dumps(out['counts']))
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for n in ('contexts','npcs','content','requests','first-bindings','legacy','output','selections'):p.add_argument('--'+n,type=Path,required=True)
    run(p.parse_args())
