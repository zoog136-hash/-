"""Audit every legacy slot and build exact source-ID/context candidates.

Name matches are evidence queues, never cross-game identity approval. This batch
separately selects literal source NPC IDs for their own source roster; native
geographic placements and runtime server conditions are not inferred.
"""
import argparse
import collections
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lineagem_original'))
import original_spr

# Literal source IDs reviewed as source-first Aden candidates. These are not
# inferred equivalences to old PC/Taiwan IDs. Context-tagged NPCs remain explicit.
BATCH_IDS = [248,249,257,258,259,267,268,280,281,282,283,284,286,287,322,327,330,
             334,358,391,393,404,418,931,941,951,961,971,1091,1281,1421,50582,53913,92492]
ROLES = {'idle':3, 'walk':0, 'attack':1, 'hit':2, 'death':8}
EXCLUDED_MARKERS = ('dummy', 'test', '테스트', '연출', '[이벤트]', '소환', 'summon')

def read(path):
    if path.suffix in ('.gz','.bin'):
        with gzip.open(path,'rt',encoding='utf-8-sig') as stream:return json.load(stream)
    return json.loads(path.read_text(encoding='utf-8-sig'))

def build(args):
    contexts=read(args.contexts); tables=contexts['tables']
    npcs=read(args.npcs)['rows']; ni={r['ID']:r for r in npcs}
    territories={r['ID']:r for r in tables['Territories']}
    lands={r['ID']:r for r in tables['Land']}
    categories={r['ID']:r for r in tables['NpcCategory']}
    links=collections.defaultdict(list)
    for row in tables['NpcSpawnPackTerritory']:links[row['NpcSpawnPackID']].append(row)
    views_by_npc=collections.defaultdict(list)
    for row in tables['NpcSpawnPackNpcClassView']:views_by_npc[row['NpcClassID']].append(row)
    source_inventory=read(args.inventory)
    all_assets={a['name']:a for row in source_inventory.values() for a in row['assets']}
    supplied={a['name']:a for a in read(args.supplied)['assets']}
    transfers={r['file_name'].removesuffix('.zip'):r for r in read(args.transfers)['files']}
    ds=original_spr.read(args.spr_root.glob('*.spr'))
    source_rows=[]; source_index={}; names=collections.defaultdict(list)
    required_files={}
    for npc in npcs:
        nid=npc['ID']; sid=npc['Sprite']; display=npc.get('DisplayName_from_DescId','')
        candidates=[]
        for view in views_by_npc[nid]:
            if view['IsSpawn']!=1 or view['ServerLimitSetID']!=0 or view['NpcLevel']<=0:continue
            for link in links[view['NpcSpawnPackID']]:
                territory=territories[link['TerritoriesID']]
                if territory['LandID']!=4:continue
                candidates.append((view,link,territory))
        selected=None; issues=[]
        if npc.get('TestNPC'):issues.append('source_TestNPC_true')
        if not categories.get(npc['Category'],{}).get('IsAttackable'):issues.append('source_category_not_attackable')
        markers=[marker for marker in EXCLUDED_MARKERS if marker in npc['Name'].lower()]
        if markers:issues.append('literal_context_markers_require_explicit_selection')
        if not candidates:issues.append('no_active_unrestricted_positive_level_Aden_context')
        levels=sorted({view['NpcLevel'] for view,_,_ in candidates})
        if len(levels)>1:issues.append('multiple_Aden_context_levels')
        if candidates:
            view,link,territory=min(candidates,key=lambda triplet:(triplet[0]['ID'],triplet[1]['ID']))
            selected={'npc_id':nid,'sprite_id':sid,'spawn_view_id':view['ID'],'territory_link_id':link['ID'],
                      'land_id':4,'land_asset_path':lands[4]['AssetPath'],'npc_level':view['NpcLevel'],
                      'selection_contract':'Explicit source-context snapshot for host adaptation; not global class level or verified host geography.'}
        files=[]; motion_issues=[]; body=None; references={}
        if selected and (nid in BATCH_IDS):
            try:
                body,actions=original_spr.resolve(ds,sid);references=original_spr.resolve_references(ds,sid)
                if any(not ref.get('count_valid',True) for refs in references.values() for ref in refs):motion_issues.append('invalid_source_reference_count')
                clothes=[original_spr.resolve(ds,target)[0] for r in references.get('clothes',[]) for target in r['targets']]
                shadows=[original_spr.resolve(ds,target)[0] for r in references.get('shadow',[]) for target in r['targets']]
                if len(shadows)>1:motion_issues.append('multiple_native_shadows_require_compositor')
                needed=set()
                for role,code in ROLES.items():
                    action=actions.get(code)
                    if action is None:motion_issues.append('source_action_missing:'+role);continue
                    if action['errors']:motion_issues.append('source_action_invalid:'+role)
                    for group,frame,ticks in action['tokens']:
                        for direction in range(8):
                            physical,bit=original_spr.frame_address(group,direction,action['declared_flag'])
                            for layer in shadows+[body]+clothes:needed.add(f'Sprite/{layer}-{physical}.sp2')
                for name in sorted(needed):
                    asset=all_assets.get(name)
                    if asset is None:
                        motion_issues.append('original_member_address_unresolved:'+name);continue
                    value={k:asset[k] for k in ('archive','name','size','crc32')}
                    available=supplied.get(name)
                    if available and available['size']==asset['size'] and available['crc32']==asset['crc32']:
                        transfer=transfers.get(available['group'])
                        if transfer:value['available_library_package']={k:transfer[k] for k in ('library_file_id','file_name','bytes','sha256')}
                    value['source_npc_ids']=[nid]
                    if name in required_files:required_files[name]['source_npc_ids'].append(nid)
                    else:required_files[name]=value
                    files.append(name)
            except ValueError as error:motion_issues.append('source_declaration_unresolved:'+str(error))
        record={'key':f'lineagem_base508:npc:{nid}', 'npc_id':nid,'sprite_id':sid,'display_name':display,
                'source_internal_name':npc['Name'],'source_category':npc['Category'],
                'source_TestNPC':npc.get('TestNPC',False),'Aden_levels':levels,
                'selected_context':selected,'context_issues':issues,'literal_context_markers':markers,
                'batch02_selected':nid in BATCH_IDS,'body_id':body,'motion_issues':motion_issues,
                'required_original_members':files,'legacy_identity_approval':False}
        source_rows.append(record);source_index[nid]=record
        if display:names[display].append(nid)
    legacy=read(args.legacy);first=read(args.bindings)['bindings']
    authored={int(row['legacy_game_db_index']):row for row in first}
    classified={}
    for group,records in legacy.items():
        results=[]
        for index,record in enumerate(records):
            candidates=names.get(record['name'],[])
            explicit=authored.get(index) if group=='base' else next((row for row in first if all(record.get(k)==v for k,v in row['legacy_signature'].items())),None)
            status='explicit_authored_source_port' if explicit else ('source_display_name_candidates_unapproved' if candidates else 'no_exact_source_display_name_candidate')
            results.append({'legacy_index':index,'legacy_name':record['name'],
                            'legacy_source_id':record.get('sourceId',record.get('source_npc_id')),
                            'legacy_catalog_only':record.get('catalog_only',False),
                            'identity_status':status,'explicit_source_npc_id':explicit['npc_id'] if explicit else None,
                            'source_name_candidate_ids':candidates,
                            'source_name_candidate_count':len(candidates),
                            'candidate_with_Aden_context':sum(source_index[nid]['selected_context'] is not None for nid in candidates),
                            'candidate_with_multiple_Aden_levels':sum(len(source_index[nid]['Aden_levels'])>1 for nid in candidates)})
        classified[group]=results
    args.output.mkdir(parents=True,exist_ok=True)
    files=list(required_files.values())
    requested=[f for f in files if 'available_library_package' not in f]
    batch=[source_index[nid] for nid in BATCH_IDS]
    count={'source_npc_rows':len(source_rows),'source_npcs_with_Aden_context':sum(row['selected_context'] is not None for row in source_rows),
           'base_registry_rows':len(legacy['base']),'expanded_registry_rows':len(legacy['expanded']),
           'batch02_source_ids':len(batch),'batch02_without_context_issues':sum(not row['context_issues'] for row in batch),
           'batch02_without_motion_issues':sum(not row['motion_issues'] for row in batch),
           'required_original_files':len(files),'required_original_bytes':sum(f['size'] for f in files),
           'files_available_in_existing_library_packages':len(files)-len(requested),
           'files_requiring_original_extraction':len(requested)}
    for group,records in classified.items():count[group+'_identity_counts']=dict(collections.Counter(r['identity_status'] for r in records))
    outputs={'source_roster_review.json':{'schema':1,'source_snapshot':'base508','rows':source_rows,'counts':count},
             'legacy_registry_classification.json':{'schema':1,'source_snapshot':'base508','contract':'Exact localized names are unapproved candidate queues, not an identity/variant/region join. Only earlier explicit authored ports count as bindings.','records':classified,'counts':count},
             'source_batch02_requests.json':{'schema':1,'source_snapshot':'base508','selections':[row['selected_context'] for row in batch if row['selected_context']], 'source_review':batch,'files':files,'missing_from_supplied_packages':requested,'counts':count}}
    for name,value in outputs.items():(args.output/name).write_text(json.dumps(value,ensure_ascii=False,separators=(',',':'))+'\n')
    print(json.dumps(count,ensure_ascii=False,sort_keys=True))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('contexts','npcs','inventory','supplied','transfers','legacy','bindings','spr-root','output'):
        p.add_argument('--'+name,type=Path,required=True)
    build(p.parse_args())
