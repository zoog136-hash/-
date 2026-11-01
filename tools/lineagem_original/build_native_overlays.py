"""Compile available original ]SpriteID overlays; compatibility semantics remain explicit."""
import argparse,collections,gzip,json,pathlib,re
import original_spr,original_sp2

def build(inputs,pack):
 ds=original_spr.read((inputs/'lineagem-category-source-metadata/original-spr').glob('*.spr'));inventory=json.load(gzip.open(inputs/'full_resource_inventory/inventory/id_to_archive.json.gz','rt'));index=json.loads((pack/'manifest.json').read_text());targets=collections.defaultdict(list);byname=collections.defaultdict(list)
 for p in (pack/'actors').glob('*.json'):
  actor=json.loads(p.read_text())
  for role,track in actor['tracks'].items():
   for annotation in original_spr.source_annotations(track['source_raw_body']):
    for sid in re.findall(r'\](\d+)',annotation['raw']):targets[int(sid)].append({'actor_sprite_id':actor['source_sprite_id'],'role':role,'annotation':annotation})
 bindings=json.loads((pack/'source_effect_bindings.json').read_text());spell_bindings={}
 for card,binding in bindings.items():
  for ref in binding['spell_references']:
   source=ref['source'];spell_bindings[str(source['ID'])]=source
   for field,sid in source.items():
    if field.endswith('SpriteID') and sid:targets[sid].append({'source_spell_id':source['ID'],'source_field':field,'EffectSpriteActionNo':source['EffectSpriteActionNo']})
 for pattern in ['transformation-*/Sprite/*.sp2','magic_doll-*/Sprite/*.sp2','holy_relic-*/Sprite/*.sp2','base508-identity-extra-sp2-*/Sprite/*.sp2','base508-original-effect-attachments-*/Sprite/*.sp2']:
  for p in inputs.glob(pattern):byname[p.name].append(p)
 (pack/'overlays').mkdir(exist_ok=True);status=[];missing={}
 for sid,usage in sorted(targets.items()):
  try:owner,actions=original_spr.resolve(ds,sid)
  except ValueError as e:status.append({'sprite_id':sid,'state':'unresolved_declaration','reason':str(e),'usage':usage});continue
  if len(actions)!=1:
   status.append({'sprite_id':sid,'state':'ambiguous_effect_action','action_ids':list(actions),'usage':usage});continue
  code,action=next(iter(actions.items()));decoded={};pixels={};directions=[];failed=False;problems=[]
  for bit in range(8):
   frames=[]
   for token_index,(group,frame,ticks) in enumerate(action['tokens']):
    try:
     chunk,stored_bit=original_spr.frame_address(group,bit,action['declared_flag']);name=f'{owner}-{chunk}.sp2'
     if name not in decoded:
      if not byname[name]:
       missing[name]=[a for a in inventory.get(str(owner),{}).get('assets',[]) if pathlib.Path(a['name']).name==name];raise ValueError('exact_source_file_unavailable')
      decoded[name]=original_sp2.parse(byname[name][0].read_bytes())
     pal,mask,dirs,_=decoded[name];bits=[b for b in range(8) if mask&(1<<b)]
     if stored_bit not in bits:raise ValueError('exact_stored_direction_absent')
     fs,blocks=dirs[bits.index(stored_bit)]
     if frame>=len(fs):raise ValueError('source_frame_out_of_range')
     key=(chunk,stored_bit,frame)
     if key not in pixels:
      image,offset=original_sp2.render(pal,fs,blocks,frame);rel=f'pixels/{owner}-{chunk}-{stored_bit}-{frame}.png';dest=pack/rel
      if not dest.exists():image.save(dest)
      pixels[key]={'path':rel,'offset':list(offset),'layer_id':owner,'pixel_size':list(image.size),'source_bounds':fs[frame][0]}
     frames.append({'duration':ticks/action['fps'] if action['fps'] else None,'source_ticks':ticks,'source_group':group,'physical_group':chunk,'stored_direction_bit':stored_bit,'source_frame':frame,'layers':[pixels[key]],'source_annotations':[a for a in action['source_annotations'] if a['token_index']==token_index]})
    except Exception as e:failed=True;problems.append(str(e));break
   directions.append(frames)
  if failed:status.append({'sprite_id':sid,'state':'source_input_or_address_pending','reasons':sorted(set(problems)),'usage':usage});continue
  attrs=[x['body'] for d in ds.get(sid,[]) for x in d.directives if x['code']==104]
  if not attrs and owner!=sid:attrs=[x['body'] for d in ds.get(owner,[]) for x in d.directives if x['code']==104]
  record={'source_sprite_id':sid,'body_id':owner,'source_attributes':attrs,'one_shot_overlay':True,'source_usage':usage,'compatibility_semantics':'PC documented ]SpriteID overlay; single native action used; M client trigger placement/effect action meaning unverified','tracks':{'idle':{'fps':action['fps'],'source_action':action['name'],'source_action_id':code,'source_sprite_id':sid,'source_raw_body':action['raw_body'],'static_pending_timing':action['fps'] is None,'timing_issues':action['errors'],'directions':directions,'loop':False}}}
  relative=f'overlays/{sid}.json';(pack/relative).write_text(json.dumps(record,ensure_ascii=False,separators=(',',':'))+'\n');index['records']['overlay:'+str(sid)]={'manifest':relative};status.append({'sprite_id':sid,'state':'compiled_compat_overlay','usage':usage})
 index['source_spell_bindings']=spell_bindings;index['compatibility_policy']='res://data/lineagem_base508/playback_policy.json';(pack/'manifest.json').write_text(json.dumps(index,ensure_ascii=False,separators=(',',':'))+'\n')
 report={'targets':len(targets),'compiled':sum(x['state']=='compiled_compat_overlay' for x in status),'status':status,'missing_exact_source_files':missing,'M_client_equivalence_verified':False};(pack/'overlay-status.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ['status','missing_exact_source_files']}))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--inputs',type=pathlib.Path,required=True);p.add_argument('--pack',type=pathlib.Path,required=True);a=p.parse_args();build(a.inputs,a.pack)
