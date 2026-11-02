"""Literal action availability and NpcAttack routing, without inventing missing clips."""
import collections,json
ROLES={0:'walk',1:'attack',2:'hit',3:'idle',8:'death'}
def source_tables(content):
 def rows(name):return json.loads((content/(name+'.json')).read_text(encoding='utf-8-sig'))['rows']
 npcs={r['ID']:r for r in rows('NpcClass')};attacks=collections.defaultdict(list);actions=collections.defaultdict(list)
 for r in rows('NpcAttack'):attacks[r['NpcClassID']].append(r)
 for r in rows('ListSprAction'):actions[(r['MotionType'],r['WeaponType'])].append(r)
 return npcs,attacks,actions

def profile(row,npc,model,attacks,action_rows):
 tracks=model['tracks'];unresolved=model.get('source_action_issues',{});sparse=sum(len(t.get('source_omitted_attachment_slots',[]))for t in tracks.values())
 available={int(t['source_action_id'])for t in tracks.values()};roles={name:code for code,name in ROLES.items()if code in available};routes=[]
 for attack in attacks.get(npc['ID'],[]):
  candidates=[r for r in action_rows[(attack['MotionType'],attack['WeaponType'])]if r['ID']in available]
  routes.append({'npc_attack_id':attack['ID'],'source_motion_type':attack['MotionType'],'source_weapon_type':attack['WeaponType'],'candidate_action_ids':[r['ID']for r in candidates],'resolved_action_id':candidates[0]['ID']if len(candidates)==1 else None,'status':'exact_unique_source_motion_match'if len(candidates)==1 else('ambiguous_source_motion_match'if candidates else'no_authored_action_for_source_attack'),'source_attack':attack})
 directions={str(t['source_action_id']):[i for i,frames in enumerate(t['directions'])if frames]for t in tracks.values()}
 common=sorted(set.intersection(*(set(v)for v in directions.values())))if directions else []
 complete_core=all(name in tracks and len(tracks[name]['directions'])==8 and all(tracks[name]['directions']) for name in ('idle','walk','attack'))
 category=row['source_category'];citizen=category.get('Name')=='Citizen'
 if not category.get('IsAttackable'):family='source_noncombat_category_visual'
 elif citizen:family='source_attackable_citizen'
 elif 'idle'not in roles:family='source_actor_without_default_state'
 elif 'walk'not in roles and 'attack'not in roles:family='source_stationary_target_or_spell_actor'
 elif 'walk'not in roles:family='source_stationary_attack_actor'
 elif 'attack'not in roles:family='source_motion_without_basic_attack'
 else:family='source_mobile_attack_actor'
 return {'contract':'base508_source_action_capabilities_v1','source_category':category,'source_npc_ai_id':npc['AI'],'source_monster_class_id':npc['MonsterClassID'],'source_weapon_type_id':npc['WeaponTypeID'],'source_kind_preserved':row['source_kind'],'source_behavior_family':family,'available_roles':roles,'available_source_action_ids':sorted(available),'missing_roles':[r for r in ROLES.values()if r not in roles],'source_default_role':'idle'if 'idle'in roles else None,'declared_source_action_ids':model.get('source_declared_action_ids',sorted(available)),'unresolved_source_action_ids':sorted(unresolved),'source_sparse_attachment_slot_count':sparse,'native_sparse_attachment_draw_verified':False if sparse else None,'source_direction_slots_by_action':directions,'source_common_direction_slots':common,'host_combat_ready':complete_core and bool(category.get('IsAttackable'))and not citizen and not sparse and not any(str(k)in unresolved for k in ROLES)and all(r in roles for r in('idle','walk','attack')),'native_attack_routes':routes,'contract_notes':'Missing states are unavailable. Exact native attack rows are preserved; ambiguous routes require an explicit attack selection. No state, frames, rate, AI or placement is synthesized.'}
