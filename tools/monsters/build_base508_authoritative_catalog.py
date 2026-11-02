"""Register all 9,470 source NPC identities and enumerate original input needs.

The catalog preserves NPC/test/event distinctions. Extraction scope is explicit;
registration, installed models and verified geographic spawns are separate counts.
No name match, MonsterBookLevel, synthetic pixels or native timing inference.
"""
import argparse, collections, gzip, hashlib, io, json, re
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'lineagem_original'))
import original_spr

def read(p):
    if p.suffix in ('.gz','.bin'):
        with gzip.open(p,'rt',encoding='utf-8-sig') as f:return json.load(f)
    return json.loads(p.read_text(encoding='utf-8-sig'))
def write_gz(p,data):
    out=io.BytesIO()
    with gzip.GzipFile(fileobj=out,mode='wb',filename='',mtime=0) as z:z.write((json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n').encode())
    p.write_bytes(out.getvalue())
def run(a):
    npcs=read(a.npcs)['rows'];tables=read(a.contexts)['tables'];categories={r['ID']:r for r in tables['NpcCategory']}
    bosses=read(a.content/'UIBossNpcClass.json')['rows'];boss_ids={r['NpcClassID'] for r in bosses}
    views=collections.defaultdict(list)
    for r in tables['NpcSpawnPackNpcClassView']:views[r['NpcClassID']].append(r)
    pack_links=collections.defaultdict(list)
    for r in tables['NpcSpawnPackTerritory']:pack_links[r['NpcSpawnPackID']].append(r)
    inventory=read(a.inventory);supplied={r['name']:r for r in read(a.supplied)['assets']};transfers={r['file_name'].removesuffix('.zip'):r for r in read(a.transfers)['files']}
    added={r['name']:r for r in read(a.additions)['assets']}
    ds=original_spr.read(a.spr_root.glob('*.spr'))
    run_rows=read(a.content/'SpriteRun.json')['rows'];run_map={r['WalkSpriteID']:r['RunSpriteID'] for r in run_rows}
    separated={r['SpriteId']:r['WalkActionType'] for r in read(a.content/'SpriteSeparatedWalk.json')['rows']}
    model_npcs=collections.defaultdict(list)
    for n in npcs:model_npcs[n['Sprite']].append(n['ID'])
    models={};required={};rows=[];monsters=set()
    for sid,nids in sorted(model_npcs.items()):
        seen=set();pending=[sid]+([run_map[sid]] if sid in run_map else []);issues=[]
        while pending:
            dep=pending.pop()
            if dep in seen:continue
            seen.add(dep)
            matches=ds.get(dep,[])
            if len(matches)!=1:issues.append({'sprite_id':dep,'issue':'missing_or_duplicate_declaration','count':len(matches)})
            for d in matches:
                if d.alias_target is not None:pending.append(d.alias_target)
                for ref in d.references:
                    pending.extend(ref['targets'])
                    if not ref.get('count_valid',True):issues.append({'sprite_id':dep,'issue':'reference_count_unresolved','reference':ref})
        files=[]
        for dep in sorted(seen):
            for asset in inventory.get(str(dep),{}).get('assets',[]):
                name=asset['name'];files.append(name)
                if name not in required:
                    r={k:asset[k] for k in ('archive','name','size','crc32')}
                    r.update({'source_model_ids':[],'source_npc_ids':[]})
                    available=supplied.get(name)
                    if available and available['size']==r['size'] and available['crc32']==r['crc32']:
                        package=transfers.get(available['group'])
                        if package:r['available_library_package']={k:package[k] for k in ('library_file_id','file_name','bytes','sha256')}
                    if name in added:
                        original=added[name]
                        if original['bytes']!=r['size'] or original['crc32']!=r['crc32']:raise ValueError(('Additional original conflict',name))
                        r['available_library_package']={'library_file_id':'libfile_2f54ab8f5bc481919ad26dede5e951c6','file_name':'base508-original-monster-additions-001.zip','bytes':3430077,'sha256':'88037e4235514f6e8af34c80d5ac57e34d5c099a97d96dfc41364e5089c39ac8'}
                    required[name]=r
                required[name]['source_model_ids'].append(sid);required[name]['source_npc_ids'].extend(nids)
        try:
            owner,actions=original_spr.resolve(ds,sid)
            types=[]
            # A local type directive takes precedence over alias-base type.
            cursor=sid;checked=set()
            while cursor not in checked:
                checked.add(cursor);decl=ds[cursor][0]
                own=[d['body'] for d in decl.directives if d['code']==102]
                if own:types=own;break
                if decl.alias_target is None:break
                cursor=decl.alias_target
            model={'source_sprite_id':sid,'body_id':owner,'source_declaration_status':'resolved',
                   'source_type_directives':types,'source_run_sprite_id':run_map.get(sid),'source_separated_walk_type':separated.get(sid),'source_action_ids':sorted(actions),
                   'source_action_names':{str(k):v['name'] for k,v in sorted(actions.items())},
                   'missing_standard_roles':[role for role,code in [('walk',0),('attack',1),('hit',2),('idle',3),('death',8)] if code not in actions],
                   'native_fps_unresolved_actions':[k for k,v in actions.items() if v['fps'] is None],
                   'dependency_sprite_ids':sorted(seen),'reference_issues':issues,'original_members':sorted(set(files)),
                   'source_npc_ids':nids}
        except (ValueError,KeyError) as err:
            model={'source_sprite_id':sid,'source_declaration_status':'unresolved','reason':str(err),'dependency_sprite_ids':sorted(seen),'reference_issues':issues,'original_members':sorted(set(files)),'source_npc_ids':nids,'source_type_directives':[]}
        models[str(sid)]=model
    context_index={};view_only={};kinds=collections.Counter()
    for npc in npcs:
        nid=npc['ID'];sid=npc['Sprite'];category=categories.get(npc['Category'],{})
        literal=[token for token in ('테스트','test','dummy','이벤트','event','소환','summon','연출') if token in npc['Name'].lower()]
        typed10=any(x.strip()=='10' for x in models[str(sid)].get('source_type_directives',[]))
        if npc.get('TestNPC'):kind='source_flagged_test_npc'
        elif nid in boss_ids:kind='source_ui_boss_npc'
        elif category.get('IsAttackable') and typed10:kind='source_attackable_monster_actor'
        elif category.get('IsAttackable'):kind='source_attackable_other_actor'
        else:kind='source_noncombat_npc_or_component'
        kinds[kind]+=1
        if kind in ('source_ui_boss_npc','source_attackable_monster_actor'):monsters.add(nid)
        world=[];without=[]
        for view in views[nid]:
            if view['IsSpawn']!=1 or view['ServerLimitSetID']!=0 or view['NpcLevel']<=0:continue
            links=pack_links[view['NpcSpawnPackID']]
            if not links:without.append(view['ID'])
            for link in links:world.append([view['ID'],link['ID']])
        context_index[str(nid)]=world
        if without:view_only[str(nid)]=without
        rows.append({'sourceId':f'lineagem_base508:npc:{nid}','npc_id':nid,'sprite_id':sid,
                     'name':npc.get('DisplayName_from_DescId',''),'source_internal_name':npc['Name'],
                     'source_kind':kind,'source_category_id':npc['Category'],'source_category':category,
                     'source_TestNPC':npc.get('TestNPC',False),'literal_context_evidence':literal,
                     'source_ui_boss':nid in boss_ids,'source_world_context_count':len(world),
                     'source_spawn_view_without_territory_count':len(without),
                     'source_model_key':f'sprite:{sid}','automatic_normal_spawn':False,
                     'source_stats_location':f'npc_classes.json#ID={nid}'})
    files=list(required.values())
    for r in files:
        r['source_model_ids']=sorted(set(r['source_model_ids']));r['source_npc_ids']=sorted(set(r['source_npc_ids']))
        r['needed_for_monster_scope']=any(nid in monsters for nid in r['source_npc_ids'])
    missing=[r for r in files if 'available_library_package' not in r]
    monster_missing=[r for r in missing if r['needed_for_monster_scope']]
    archive_counts=collections.defaultdict(lambda:{'files':0,'bytes':0})
    for r in monster_missing:archive_counts[r['archive']]['files']+=1;archive_counts[r['archive']]['bytes']+=r['size']
    counts={'registered_source_npcs':len(rows),'source_kinds':dict(kinds),'source_models':len(models),
            'monster_scope_source_npc_ids':len(monsters),'required_original_files_all_npc_scope':len(files),
            'required_original_bytes_all_npc_scope':sum(r['size'] for r in files),
            'files_in_existing_library_packages':len(files)-len(missing),
            'missing_original_files_all_npc_scope':len(missing),'missing_original_bytes_all_npc_scope':sum(r['size'] for r in missing),
            'missing_original_files_monster_scope':len(monster_missing),'missing_original_bytes_monster_scope':sum(r['size'] for r in monster_missing),
            'monster_scope_source_dat_archives':len(archive_counts),
            'source_npcs_with_exact_world_context':sum(bool(v) for v in context_index.values()),
            'native_geographic_spawns':0}
    catalog={'schema':1,'source_snapshot':'base508','contract':'All source NPC identities registered; source category, test flag, UI-boss link and literal context evidence remain distinct. No entry automatically enters ordinary world spawns. Raw native stats remain in npc_classes.json; levels remain exact spawn-view contexts.',
             'rows':rows,'models':models,'world_context_index':context_index,'spawn_view_only_index':view_only,'source_ui_boss_rows':bosses,'source_run_rows':run_rows,'counts':counts}
    requests={'schema':1,'source_snapshot':'base508','contract':'Machine extraction request only. Exact original DAT/member/size/CRC; all 51 existing package identities and supplied 35-file delta deduplicated. Not a claim of installed models or approved M-native geography.',
              'files':files,'missing':missing,'monster_scope_missing':monster_missing,'monster_scope_archives':dict(sorted(archive_counts.items())),'counts':counts}
    a.output.mkdir(parents=True,exist_ok=True)
    write_gz(a.output/'authoritative_catalog.bin',catalog)
    write_gz(a.output/'all_source_npc_pixel_requests.json.gz',requests)
    (a.output/'all_source_npc_counts.json').write_text(json.dumps(counts,ensure_ascii=False,indent=2)+'\n')
    (a.output/'monster_missing_members.csv').write_text('archive,name,bytes,crc32\n'+''.join(f"{r['archive']},{r['name']},{r['size']},{r['crc32']}\n" for r in monster_missing))
    print(json.dumps(counts,ensure_ascii=False,sort_keys=True),flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for n in ('npcs','contexts','content','inventory','supplied','transfers','additions','spr-root','output'):p.add_argument('--'+n,type=Path,required=True)
    run(p.parse_args())
