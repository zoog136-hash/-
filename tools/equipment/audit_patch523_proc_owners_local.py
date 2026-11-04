"""Read-only source/public-owner contract audit. Reports remain LOCAL_ONLY."""
import collections,hashlib,json,zipfile
from pathlib import Path
ROOT=Path('/workspace/source523/current/content')
OUT=Path('/workspace/equipment523-logs/proc-owner-contracts-3948_LOCAL_ONLY.json')
with zipfile.ZipFile('/workspace/source523/lineagem_patch523_all_content_validated_and_508_520_deltas.zip') as archive:
 SOURCE_INDEX={r['path']:r for r in json.loads(archive.read('index.json').decode('utf-8-sig'))}
VERIFIED={}
def rows(n):
 raw=(ROOT/(n+'.json')).read_bytes();expected=SOURCE_INDEX['content/'+n+'.json'];digest=hashlib.sha256(raw).hexdigest()
 if len(raw)!=expected['bytes'] or digest!=expected['sha256']:raise ValueError('held source differs from original ZIP index: '+n)
 VERIFIED[n]={'sha256':digest,'bytes':len(raw),'row_count':expected['row_count']}
 return json.loads(raw.decode('utf-8-sig'))['rows']
def index(n):return {r['ID']:r for r in rows(n)}
report=json.loads(Path('/workspace/equipment523-logs/PR239_followup_913_coverage_LOCAL_ONLY.json').read_text())
en=index('ItemEnchantBonus');bonuses=index('Bonus');options=index('InvokeOption');types=index('InvokeOptionType');spells=index('SpellClass')
ids=report['unconnected_ids_by_type']['InvokeOption'];selected={};counts=collections.Counter();spell_uses=collections.defaultdict(list)
for rid in ids:
 b=bonuses[en[rid]['BonusID']];o=options[b['BonusApplicationTargetID']];t=types[o['InvokeOptionTypeID']]
 counts[t['Name']]+=1;selected[o['ID']]=o
 for i in range(1,7):
  if t.get('Param%dUnit'%i)==12 and o.get('Param%d'%i,0):spell_uses[o['Param%d'%i]].append({'enchant_row_id':rid,'invoke_id':o['ID'],'type':t['Name'],'param':'Param%d'%i,'meaning':t.get('Param%dDescription'%i)})
public=json.loads(Path('/workspace/equipment523-logs/public245-bindings-655355_LOCAL_ONLY.json').read_text())
owner_ids=collections.defaultdict(list)
for key,b in public['skills'].items():owner_ids[int(b['spell_id'])].append(key)
entries=[]
for sid in sorted(spell_uses):
 s=spells.get(sid)
 entries.append({'spell_class_id':sid,'source_exists':s is not None,'test_spell':s.get('TestSpell') if s else None,'source_name':s.get('Name') if s else None,'source_row_sha256':hashlib.sha256(json.dumps(s,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest() if s else None,'source_declared_cast_costs':{k:s[k] for k in ['HPCost','MPCost','MPCostUnit','VPCost','SpellMaterialTypeID','SpellMaterialItemAmount','CastDelay'] if k in (s or {})},'source_target':{k:s[k] for k in ['TargettingTypeID','TargetKindID','SiegeTargetKindID','TargetAreaRadius','CastRange','SpellEffectTypeID','SpellTypeID','CopySpellClassID','SpellCompositionNode'] if k in (s or {})},'published_player_binding_keys':owner_ids.get(sid,[]),'uses':spell_uses[sid]})
attack_spell_ids={sid for sid,uses in spell_uses.items() if any(u['type']=='Attack_Spell' and u['param']=='Param1' for u in uses)}
direct_spell_ids={sid for sid,uses in spell_uses.items() if any(u['type'] in ['Attack_Spell','Defence_Spell','Aura_Spell'] and u['param']=='Param1' for u in uses)}
result={'attack_spell_ids':sorted(attack_spell_ids),'attack_spell_count':len(attack_spell_ids),'direct_spell_count':len(direct_spell_ids),'shared_attack_spell_ids':sorted(attack_spell_ids&set(owner_ids)),'verified_source_tables':VERIFIED,'status':'LOCAL_ONLY','source_zip_sha256':public['source_zip_sha256'],'enchant_rows':len(ids),'unique_invoke_options':len(selected),'invoke_rows_by_type':dict(counts),'all_param_spell_refs':len(entries),'public_owner_checkpoint':'PR245 655355575705f42036c6169341047dd288247819','public_owner_binding_count':len(public['skills']),'shared_exact_spell_ids':sorted(set(spell_uses)&set(owner_ids)),'spells':entries,'owner_contract':{'available':['player_skills523.evidence_for(curated_id)','player_skills523.apply_to(record,job,upgraded)','skill_service.impact(curated_skill,primary,expected_life)','skill_service.deal_damage(curated_skill,target,link_from)'],'missing':['Exact native SpellClassID + InvokeOption dispatch independent of learned/cast cost','Attack/defence/aura target resolution from source TargettingTypeID/TargetKindID/area','Incoming source SpellClassID, debuff duration and proc context for94 Defence_DebuffTimeDecrease options','Native spell/formula/status execution result, cost ownership, recursion and atomic RNG contract'],'note':'A shared native ID is identity evidence only. Existing curated cast/impact APIs are not an equipment-proc execution owner.'}}
OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['spells','owner_contract','attack_spell_ids']},ensure_ascii=False))
