"""Join exact NPC attacks, spells, unconditional typed bonuses and source VFX IDs.
Raw Prob/range/delay stay raw: this client table supplies no probability denominator
or coordinate/time unit contract for NpcAttack. No names select spell/status/VFX.
"""
import argparse,collections,gzip,hashlib,io,json
from pathlib import Path

def build(content):
 hashes={}
 def rows(name):
  p=content/(name+'.json');data=p.read_bytes();hashes[name]=hashlib.sha256(data).hexdigest();return json.loads(data.decode('utf-8-sig'))['rows']
 npcs={r['ID']:r for r in rows('NpcClass')};attacks=rows('NpcAttack');spells={r['ID']:r for r in rows('SpellClass')};bonus={r['ID']:r for r in rows('Bonus')};types={r['ID']:r for r in rows('BonusType')};units={r['ID']:r for r in rows('Unit')};buffs={r['ID']:r for r in rows('BuffClass')};spell_bonus=collections.defaultdict(list);buff_bonus=collections.defaultdict(list)
 for r in rows('SpellBonus'):spell_bonus[r['SpellClassID']].append(r)
 for r in rows('BuffBonus'):buff_bonus[r['BuffClassID']].append(r)
 motions=rows('ListSprAction');target_types={r['ID']:r for r in rows('TargettingType')};target_kinds={r['ID']:r for r in rows('TargetKind')};element_types={r['ID']:r for r in rows('ElementalType')};boss_ids={r['NpcClassID']for r in rows('UIBossNpcClass')}
 def typed_bonuses(links,kind):
  result=[]
  for link in links:
   b=bonus.get(link['BonusID']);assert b is not None,('Unresolved source bonus',link)
   t=types[b['BonusTypeID']];u=units[t['UnitID']]
   unconditional=b['BonusApplicationTypeID']==0 and b['BonusApplicationTargetID']==0 and link.get('MinSpellLevel',0)==0 and link.get('CharacterLevel',0)==0 and link.get('CharacterClass',0)==0
   result.append({'link':link,'bonus':b,'type':t['Name'],'unit':u['Name'],'unconditional':unconditional})
  return result
 def exact_values(typed):
  grouped=collections.defaultdict(list)
  for b in typed:
   if b['unconditional']:grouped[b['type']].append((b['bonus']['Value'],b['unit']))
  # Duplicated equal source values are the same assertion; conflicts stay unresolved.
  return {k:{'value':v[0][0],'unit':v[0][1]}for k,v in grouped.items()if len(set(v))==1}
 selected_spells={};npc_attacks=collections.defaultdict(list);missing=[]
 for attack in attacks:
  nid=attack['NpcClassID'];assert nid in npcs
  npc_attacks[str(nid)].append(attack)
  sid=attack['SpellID']
  if sid<=0 or sid in selected_spells:continue
  if sid not in spells:missing.append({'attack_id':attack['ID'],'spell_id':sid});continue
  spell=spells[sid];typed=typed_bonuses(spell_bonus[sid],'spell');values=exact_values(typed);states=[]
  buff_ids=sorted({int(b['bonus']['Value'])for b in typed if b['unconditional']and b['type']=='BuffClassID'and b['unit']=='BuffClassID'})
  for bid in buff_ids:
   if bid not in buffs:continue
   btyped=typed_bonuses(buff_bonus[bid],'buff');bvalues=exact_values(btyped)
   state={'source_buff_id':bid,'buff_class':buffs[bid],'bonuses':btyped,'values':bvalues,'supported_status':None}
   if bvalues.get('Stunned',{}).get('value')==1 and bvalues.get('Stunned',{}).get('unit')=='Value':state['supported_status']='stun'
   states.append(state)
  damage={}
  for source,key in [('SpellDamageBase','base'),('SpellDamageDiceNumber','dice_count'),('SpellDamageDiceSpotCount','dice_spots')]:
   if values.get(source,{}).get('unit')=='Value':damage[key]=values[source]['value']
  duration={}
  for source,key in [('SpellBuffDuration','fixed'),('SpellDebuffMinDuration','min'),('SpellDebuffMaxDuration','max')]:
   if values.get(source,{}).get('unit')=='Seconds':duration[key]=values[source]['value']
  selected_spells[str(sid)]={'source_spell':spell,'typed_bonuses':typed,'unconditional_values':values,'damage_dice':damage,'status_duration_seconds':duration,'buffs':states,'targetting_type':target_types.get(spell['TargettingTypeID'],{}),'target_kind':target_kinds.get(spell['TargetKindID'],{}),'element':element_types.get(spell['ElementalTypeID'],{}),'effect_fields':{k:v for k,v in spell.items()if 'Sprite'in k and k!='IconID'}}
 result={'schema':1,'source_snapshot':'base508','kind':'base508_npc_combat_catalog','source_sha256':hashes,'npc_attacks':dict(npc_attacks),'spells':selected_spells,'source_npcs':{k:{'npc_id':int(k),'sprite_id':npcs[int(k)]['Sprite'],'source_ui_boss':int(k)in boss_ids,'category_id':npcs[int(k)]['Category'],'source_ai_id':npcs[int(k)]['AI']}for k in npc_attacks},'source_actions':motions,'unresolved_spell_references':missing,'contract':{'probability':'NpcAttack.Prob preserved. No documented denominator; no invented original probability. Explicit attack ID or one supported candidate; host weighted selection requires explicit opt-in.','timing':'Source Seconds bonuses applied as seconds. NpcAttack.FixedDelayTime and SpellClass.CastDelay remain unscaled raw pending unit proof. Existing host windup/cooldown are explicitly compatibility timing.','range':'Original range/radius preserved; host pixel range used until explicit source-cell mapping is provided.','damage':'Source unconditional Value dice/base reused with existing host hit/critical/reduction calculation, not claimed native M formula.','status':'Only typed BuffBonus.Stunned=1 is presently dispatched; other status types remain visible in typed metadata. Native status chance absent: existing host resistance policy is compatibility.','vfx':'Exact SpellClass effect sprite IDs. Render only installed source overlay records; no icon/name fallback.'}}
 return result
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--content',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=build(a.content);a.output.parent.mkdir(parents=True,exist_ok=True)
 raw=(json.dumps(r,ensure_ascii=False,separators=(',',':'))+'\n').encode();out=io.BytesIO()
 with gzip.GzipFile(fileobj=out,mode='wb',filename='',mtime=0)as z:z.write(raw)
 a.output.write_bytes(out.getvalue());print(json.dumps({'npc_classes':len(r['npc_attacks']),'attack_rows':sum(map(len,r['npc_attacks'].values())),'spells':len(r['spells']),'unresolved_spell_references':len(r['unresolved_spell_references']),'bytes':a.output.stat().st_size,'sha256':hashlib.sha256(a.output.read_bytes()).hexdigest()}))
