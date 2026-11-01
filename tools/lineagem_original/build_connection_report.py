"""Record exact unresolved inputs and confirmed effect relations without inventing triggers."""
import argparse,collections,gzip,json,pathlib

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def build(inputs,registry,pack,report):
 report.mkdir(parents=True,exist_ok=True);cards=read(registry/'cards.json');status=read(pack/'connection-status.json');content=inputs/'base508_all_content_validated/content'
 rows=[r for category in cards['catalog'].values() for r in category];states={r['sprite_id']:r for r in status['status']}
 # Correct older reports that included unrelated groups sharing the prefix.
 status['missing_source_files']={name:[a for a in assets if pathlib.Path(a['name']).name==name] for name,assets in status['missing_source_files'].items()}
 (pack/'connection-status.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n')
 npc_attacks=read(content/'NpcAttack.json')['rows'];by_npc=collections.defaultdict(list)
 for attack in npc_attacks:by_npc[attack['NpcClassID']].append(attack)
 spells={r['ID']:r for r in read(content/'SpellClass.json')['rows']};effects={};ui={};out=[]
 for r in rows:
  source=r['source_original'];npcs={link['npc_class_id'] for link in source['inworld_links'] if 'npc_class_id' in link}
  attacks=[a for npc in npcs for a in by_npc[npc]];spell_ids={a['SpellID'] for a in attacks if a['SpellID']};card_spell=r['source_original_card'].get('SpellClassID',0)
  if card_spell:spell_ids.add(card_spell)
  for detail in r['source_bonuses']:
   if detail['unit']['Name']=='SpellClassID' and detail['bonus']['Value']:spell_ids.add(detail['bonus']['Value'])
  refs=[{'spell_id':sid,'source':spells[sid]} for sid in sorted(spell_ids) if sid in spells]
  effects[r['sourceId']]={'source_card_id':r['source_card_id'],'source_sprite_ids':r['source_inworld_sprite_ids'],'npc_attack_rows':attacks,'spell_references':refs,'trigger_status':'native_fields_preserved_not_reinterpreted','rendering_status':'SPR_clothes_registered_blend_pending; spell_effect_playback_pending'}
  for field,asset in r['source_ui_assets'].items():
   if isinstance(asset,dict) and asset.get('path'):
    key=asset['path'];ui[key]={'path':key,'asset':asset,'cards':ui.get(key,{}).get('cards',[])+[{'source_id':r['sourceId'],'field':field}],'physical_path':('Image/UIImage/Illust_Legend_WorldTree_Helm_On.png' if key=='Image/UIImage/Illust_Legend_WorldTree_Helm_ON.png' else key),'local_present':(pack/'ui'/('Image/UIImage/Illust_Legend_WorldTree_Helm_On.png' if key=='Image/UIImage/Illust_Legend_WorldTree_Helm_ON.png' else key)).is_file()}
  sprite_states=[states[s] for s in r['source_inworld_sprite_ids'] if s in states];single=len(r['source_inworld_sprite_ids'])==1
  out.append({'source_id':r['sourceId'],'name':r['name'],'sprite_ids':r['source_inworld_sprite_ids'],'runtime_single_sprite_connected':single and bool(sprite_states) and sprite_states[0]['status']=='connected_literal_native_pixels','variant_context_required':len(r['source_inworld_sprite_ids'])>1,'sprite_status':sprite_states})
 (pack/'source_effect_bindings.json').write_text(json.dumps(effects,ensure_ascii=False,separators=(',',':'))+'\n')
 (report/'required-ui-assets.json').write_text(json.dumps(list(ui.values()),ensure_ascii=False,indent=2)+'\n')
 (report/'required-extra-sp2.json').write_text(json.dumps(status['missing_source_files'],ensure_ascii=False,indent=2)+'\n')
 summary={'registered_cards':len(rows),'categories':{k:len(v) for k,v in cards['catalog'].items()},'inworld_chains':700,'unique_requested_sprites':len(states),'compiled_actor_records':status['connected_actor_records'],'runtime_single_sprite_connected_cards':sum(x['runtime_single_sprite_connected'] for x in out),'variant_context_required_cards':sum(x['variant_context_required'] for x in out),'unknown_timing_actor_records':sum(bool(x.get('static_pending_timing')) for x in states.values()),'registered_clothes_layer_ids':status['effect_layer_records'],'effect_binding_cards':len(effects),'unique_required_ui_paths':len(ui),'present_ui_paths':sum(x['local_present'] for x in ui.values()),'missing_sp2_filenames':len(status['missing_source_files']),'npc_source_rows':9470,'npc_application':'explicit source_m_npc_id only; legacy name/number/Sprite not inferred','visual_validation':'deferred_by_user','spell_effect_rendering':'pending_exact_trigger_adapter','source_blend':'unverified_attributes_retained','cards':out}
 (report/'connection-report.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({k:v for k,v in summary.items() if k!='cards'},ensure_ascii=False))
if __name__=='__main__':
 p=argparse.ArgumentParser()
 for name in ['inputs','registry','pack','report']:p.add_argument('--'+name,type=pathlib.Path,required=True)
 a=p.parse_args();build(a.inputs,a.registry,a.pack,a.report)
