"""Compile only available, original awakening sprites; preserve all12 raw chains."""
import argparse,collections,gzip,hashlib,json,pathlib,zlib
import original_spr,original_sp2

def build(inputs,extra,stage,registry_path):
 source=inputs/'base508_all_content_validated/content'
 table=lambda n:json.loads((source/(n+'.json')).read_text(encoding='utf-8-sig'))['rows']
 ds=original_spr.read((inputs/'lineagem-category-source-metadata/original-spr').glob('*.spr'))
 inv=json.load(gzip.open(inputs/'full_resource_inventory/inventory/id_to_archive.json.gz','rt'))
 out=stage/'awakening';(out/'actors').mkdir(parents=True,exist_ok=True);(out/'pixels').mkdir(exist_ok=True)
 rules=[];required={};records={};stats=collections.Counter();attrs=table('StatusEffectAttr')
 for row in table('BuffCardAwakenEffect'):
  raw=[a for a in attrs if a['StatusEffectID']==row['StatusEffectID']];sprite_refs=[a for a in raw if a['StatusEffectAttrType']==48]
  if len(sprite_refs)!=1:raise ValueError('ambiguous scoped awakening reference')
  sid=int(sprite_refs[0]['Value']);body,actions=original_spr.resolve(ds,sid);decl=ds[sid][0]
  rule={'effect_row':row,'status_attributes':raw,'sprite_id':sid,'physical_sprite_id':body,'attr48_reference_id':sprite_refs[0]['ID'],'source_declaration':{'file':decl.source_file,'line':decl.source_line},'render_semantics':'exact12chain_allowlist_only_Type48_global_enum_unverified','activation':'explicit_existing_native_card_awakened_state_and_ownership_required','anchor':'native_card_visual_anchor_compatibility_M_placement_unverified'};rules.append(rule)
  actor={'source_sprite_id':sid,'body_id':body,'shadow_ids':[],'source_attributes':[d['body'] for d in decl.directives if d['code']==104],'source_actions':actions,'source_all_declarations':{'file':decl.source_file,'line':decl.source_line,'directives':decl.directives},'tracks':{},'uncompiled_source_roles':{}}
  parsed={}
  for role,code in [('idle',3),('walk',0)]:
   action=actions.get(code)
   if not action or action['fps'] is None or action['errors']:actor['uncompiled_source_roles'][role]='source action/timing unavailable';continue
   needed={original_spr.frame_address(g,d,action['declared_flag'])[0] for d in range(8) for g,f,t in action['tokens']}
   local={};missing=[]
   for chunk in sorted(needed):
    name=f'{body}-{chunk}.sp2';asset=next((a for a in inv.get(str(body),{}).get('assets',[]) if pathlib.Path(a['name']).name==name),None)
    candidates=list(inputs.glob('*/Sprite/'+name))+list(extra.glob('Sprite/'+name))
    if not candidates:
     missing.append(name);required[name]={'file':'Sprite/'+name,'sprite_id':sid,'physical_id':body,'role':role,'source_action_id':code,'inventory':asset,'state':'indexed_input_not_materialized' if asset else 'not_located_in_supplied_index'};continue
    data=candidates[0].read_bytes()
    if any(p.read_bytes()!=data for p in candidates[1:]):raise ValueError('different bytes for '+name)
    if asset and (len(data)!=asset['size'] or f'{zlib.crc32(data)&0xffffffff:08x}'!=asset['crc32']):raise ValueError('source CRC mismatch '+name)
    local[chunk]=data
   if missing:actor['uncompiled_source_roles'][role]={'missing':missing};continue
   directions=[]
   for direction in range(8):
    frames=[]
    for index,(group,frame,ticks) in enumerate(action['tokens']):
     chunk,bit=original_spr.frame_address(group,direction,action['declared_flag']);key=(chunk,bit,frame)
     if chunk not in parsed:parsed[chunk]=original_sp2.parse(local[chunk])
     pal,mask,dirs,_=parsed[chunk];bits=[b for b in range(8) if mask&(1<<b)]
     if bit not in bits:raise ValueError(f'{sid}: source direction absent')
     fs,blocks=dirs[bits.index(bit)];image,offset=original_sp2.render(pal,fs,blocks,frame)
     name=f'pixels/{body}-{chunk}-{bit}-{frame}.png';target=out/name
     if not target.exists():image.save(target);stats['original_decoded_png']+=1
     frames.append({'duration':ticks/action['fps'],'source_ticks':ticks,'source_group':group,'physical_group':chunk,'stored_direction_bit':bit,'source_frame':frame,'source_annotations':[a for a in action['source_annotations'] if a['token_index']==index],'effect_layers':[],'layers':[{'path':name,'offset':list(offset),'layer_id':sid,'source_bounds':list(fs[frame][0]),'pixel_size':list(image.size),'source_tile_types':sorted({r[2] for r in fs[frame][1]})}]})
    directions.append(frames)
   actor['tracks'][role]={'fps':action['fps'],'source_action':action['name'],'source_action_id':code,'source_raw_body':action['raw_body'],'source_sprite_id':sid,'source_body_id':body,'source_timing_provenance':action.get('fps_provenance'),'static_pending_timing':False,'timing_issues':[],'directions':directions,'loop':True}
   stats['compiled_tracks']+=1
  if 'idle' in actor['tracks']:
   (out/'actors'/f'{sid}.json').write_text(json.dumps(actor,ensure_ascii=False,separators=(',',':'))+'\n');records['sprite:'+str(sid)]={'manifest':f'actors/{sid}.json'};stats['compiled_profiles']+=1
 manifest={'schema':1,'mode':'literal_body_shadow_inspection_only','source_snapshot':'base508','records':records,'limits':'Conditional explicit awakening only; raw source timing/pixels preserved; blend, anchor and source activation semantics not original-client-equivalence approved.'}
 (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n')
 registry={'schema':1,'source_snapshot':'base508','source_table_sha256':{n:hashlib.sha256((source/(n+'.json')).read_bytes()).hexdigest() for n in ['BuffCardAwakenEffect','StatusEffectAttr']},'rules':rules,'condition':'No ownership-only or grade-only activation; no generic StatusEffectAttr48 renderer.'}
 registry_path.write_text(json.dumps(registry,ensure_ascii=False,separators=(',',':'))+'\n')
 result={'counts':dict(stats),'required_inputs':list(required.values()),'compiled_sprites':[int(k.split(':')[1]) for k in records],'source_rules':len(rules)};(stage/'awakening-source-status.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ['inputs','extra','stage','registry']:p.add_argument('--'+key,type=pathlib.Path,required=True)
 a=p.parse_args();build(a.inputs,a.extra,a.stage,a.registry)
