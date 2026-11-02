"""Build all verified card actor tracks; no new art, pose repair, guessed blends or FPS."""
import argparse,collections,gzip,hashlib,json,pathlib,re,time
import original_spr,original_sp2

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def build(inputs,registry,output,only=None):
 output.mkdir(parents=True,exist_ok=True);(output/'actors').mkdir(exist_ok=True);(output/'pixels').mkdir(exist_ok=True)
 cards=read(registry/'cards.json');ds=original_spr.read((inputs/'lineagem-category-source-metadata/original-spr').glob('*.spr'))
 location=json.load(gzip.open(inputs/'full_resource_inventory/inventory/id_to_archive.json.gz','rt'))
 byname=collections.defaultdict(list)
 for pattern in ['transformation-*/Sprite/*.sp2','magic_doll-*/Sprite/*.sp2','holy_relic-*/Sprite/*.sp2','base508-identity-extra-sp2-*/Sprite/*.sp2','base508-original-effect-attachments-*/Sprite/*.sp2','girtas_renewal_analysis/sp2/*.sp2','halphas_analysis/sp2/*.sp2']:
  for p in inputs.glob(pattern):byname[p.name].append(p)
 selected={};categories=collections.defaultdict(set)
 for category,rows in cards['catalog'].items():
  for record in rows:
   for b in record['source_sprite_bindings']:selected[b['sprite_id']]=b;categories[b['sprite_id']].add(category)
 runmap={r['WalkSpriteID']:r['RunSpriteID'] for r in cards['run_sprite_relationships']}
 index={'schema':1,'mode':'literal_body_shadow_inspection_only','source_snapshot':'base508','production_ready':False,'records':{},'card_bindings':{},'limits':['Every known source attachment is registered; unverified blend/trigger semantics are not invented.','Unknown FPS tracks retain a static original first pose and exact raw timing metadata.','Not a visual quality approval.']}
 all_selected=dict(selected)
 status=[];missing={};effect_registry={};started=time.time()
 if only is not None:
  previous=read(output/'connection-status.json');status=[x for x in previous['status'] if x['sprite_id'] not in only]
  index=read(output/'manifest.json');effect_registry=read(output/'registered_effect_layers.json');selected={k:v for k,v in selected.items() if k in only}
  for sid in only:index['records'].pop('sprite:'+str(sid),None)
 for n,(sid,binding) in enumerate(sorted(selected.items()),1):
  try:owner,acts=original_spr.resolve(ds,sid)
  except ValueError as e:status.append({'sprite_id':sid,'status':'missing_or_ambiguous_declaration','reason':str(e)});continue
  base=ds[owner][0];references=original_spr.resolve_references(ds,sid);shadow=[x for r in references.get('shadow',[]) for x in r['targets']];clothes=[x for r in references.get('clothes',[]) for x in r['targets']]
  tracks={};decoded={};pixelcache={};failures=[];effects=[];prior_pixels={}
  previous_actor=output/f'actors/{sid}.json'
  if previous_actor.exists():
   old=read(previous_actor)
   prior_pixels={layer['path']:layer for track in old['tracks'].values() for frames in track['directions'] for frame in frames for layer in frame['layers']}
  for layer in clothes:
   declarations=ds.get(layer,[]);attrs=[x['body'] for d in declarations for x in d.directives if x['code']==104]
   assets=location.get(str(layer),{}).get('assets',[])
   info={'sprite_id':layer,'source_attributes':attrs,'blend_status':'unverified','assets':[{**a,'local_paths':[str(p) for p in byname[pathlib.Path(a['name']).name]]} for a in assets],'relation':'SPR105.clothes','timeline':'parent_native_frame_group_index_ticks','rendered':False}
   effect_registry[str(layer)]=info;effects.append(info)
  action_list=[('idle',sid,owner,acts.get(3)),('walk',sid,owner,acts.get(0)),('attack',sid,owner,acts.get(1))]
  if sid in runmap:
   try:r_owner,r_actions=original_spr.resolve(ds,runmap[sid]);action_list.append(('run',runmap[sid],r_owner,r_actions.get(0)))
   except ValueError as e:failures.append({'role':'run','reason':str(e)})
  for role,action_sprite,body,action in action_list:
   if action is None:continue
   track_refs=original_spr.resolve_references(ds,action_sprite);track_shadow=[original_spr.resolve(ds,x)[0] if x in ds else x for r in track_refs.get('shadow',[]) for x in r['targets']]
   try:groups={original_spr.frame_address(t[0],bit,action['declared_flag'])[0] for t in action['tokens'] for bit in range(8)}
   except ValueError as e:failures.append({'role':role,'reason':str(e)});continue
   layer_ids=(track_shadow if len(track_shadow)==1 else [])+[body]
   source_masks={}
   for group in groups:
    for layer in layer_ids:
     name=f'{layer}-{group}.sp2'
     if name in decoded:continue
     paths=byname.get(name,[])
     if not paths:
      missing[name]=[a for a in location.get(str(layer),{}).get('assets',[]) if pathlib.Path(a['name']).name==name]
      failures.append({'role':role,'file':name,'reason':'SP2_not_in_local_inputs','layer':layer});continue
     try:
      raw=paths[0].read_bytes();decoded[name]=original_sp2.parse(raw)
     except Exception as e:failures.append({'role':role,'file':name,'reason':str(e)})
   directions=[];failed=False
   static=action['fps'] is None or bool(action['errors'])
   for bit in range(8):
    frames=[]
    for token_index,(source_group,frame,ticks) in enumerate(action['tokens']):
     group,stored_bit=original_spr.frame_address(source_group,bit,action['declared_flag'])
     layers=[]
     for layer in layer_ids:
      name=f'{layer}-{group}.sp2';parsed=decoded.get(name)
      if parsed is None:
       if layer==body:failed=True
       continue
      pal,mask,dirs,_=parsed;bits=[i for i in range(8) if mask&(1<<i)]
      use_bit=stored_bit if stored_bit in bits else None
      if use_bit is None:
       failed=True;failures.append({'role':role,'file':name,'reason':'stored_direction_mapping_unverified','requested_bit':stored_bit,'mask':mask});continue
      stored=bits.index(use_bit);fs,blocks=dirs[stored]
      if frame>=len(fs):failed=True;failures.append({'role':role,'file':name,'frame':frame,'reason':'frame_out_of_range'});continue
      key=(layer,group,use_bit,frame)
      if key not in pixelcache:
       relative=f'pixels/{layer}-{group}-{use_bit}-{frame}.png';dest=output/relative
       if relative in prior_pixels and dest.exists():pixelcache[key]=prior_pixels[relative]
       else:
        image,offset=original_sp2.render(pal,fs,blocks,frame)
        if not dest.exists():image.save(dest)
        pixelcache[key]={'path':relative,'offset':list(offset),'layer_id':layer,'source_bounds':list(fs[frame][0]),'pixel_size':list(image.size),'source_direction_mask':mask}
      layers.append(pixelcache[key])
     frames.append({'duration':ticks/action['fps'] if action['fps'] else None,'source_ticks':ticks,'source_group':source_group,'physical_group':group,'stored_direction_bit':stored_bit,'source_frame':frame,'layers':layers})
    directions.append(frames)
   if failed:continue
   tracks[role]={'fps':action['fps'],'source_timing_provenance':action.get('fps_provenance'),'source_action':action['name'],'source_action_id':action['code'],'source_raw_body':action['raw_body'],'source_sprite_id':runmap[sid] if role=='run' else sid,'source_body_id':body,'static_pending_timing':static,'timing_issues':action['errors'],'directions':directions,'loop':role!='attack'}
  if not tracks or 'idle' not in tracks:status.append({'sprite_id':sid,'status':'no_decodable_idle','failures':failures});continue
  actor={'source_sprite_id':sid,'body_id':owner,'run_sprite_id':runmap.get(sid),'shadow_ids':shadow,'tracks':tracks,'source_effect_layers':effects,'source_all_declarations':{'file':base.source_file,'line':base.source_line,'directives':base.directives,'references':references},'source_actions':acts,'failures':failures}
  relative=f'actors/{sid}.json';(output/relative).write_text(json.dumps(actor,ensure_ascii=False,separators=(',',':'))+'\n')
  index['records']['sprite:'+str(sid)]={'manifest':relative};status.append({'sprite_id':sid,'status':'connected_literal_native_pixels','tracks':list(tracks),'static_pending_timing':[k for k,v in tracks.items() if v['static_pending_timing']],'failures':failures})
  if n%25==0:print(json.dumps({'processed':n,'total':len(selected),'actor_records':len(index['records']),'seconds':round(time.time()-started,1)}),flush=True)
 for category,rows in cards['catalog'].items():
  kind={'변신':'transform','마법인형':'doll','성물':'relic'}[category]
  for card in rows:index['card_bindings'][kind+':'+card['sourceId']]={'sprite_ids':card['source_inworld_sprite_ids'],'variant_selection':card.get('source_variant_selection')}
 for key,sid in [('transform:267',22258),('transform:393',28439)]:
  if 'sprite:'+str(sid) in index['records']:index['records'][key]=index['records']['sprite:'+str(sid)]
 (output/'manifest.json').write_text(json.dumps(index,ensure_ascii=False,separators=(',',':'))+'\n')
 (output/'registered_effect_layers.json').write_text(json.dumps(effect_registry,ensure_ascii=False,separators=(',',':'))+'\n')
 # Recompute exact unresolved files across retained and refreshed actors.
 missing={}
 for item in status:
  for failure in item.get('failures',[]):
   if failure.get('reason')=='SP2_not_in_local_inputs':
    name=failure['file'];layer=failure['layer'];missing[name]=[a for a in location.get(str(layer),{}).get('assets',[]) if pathlib.Path(a['name']).name==name]
 summary={'unique_requested_sprite_ids':len(all_selected),'connected_actor_records':sum(r['status']=='connected_literal_native_pixels' for r in status),'effect_layer_records':len(effect_registry),'card_definitions':sum(len(rows) for rows in cards['catalog'].values()),'inworld_chains':sum(bool(r['source_inworld_sprite_ids']) for rows in cards['catalog'].values() for r in rows),'status':status,'missing_source_files':missing,'seconds':round(time.time()-started,1),'visual_validation':'DEFERRED_BY_USER','blend_validation':'UNVERIFIED_SOURCE_ATTRIBUTES_PRESERVED'}
 (output/'connection-status.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k not in ['status','missing_source_files']},ensure_ascii=False))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--inputs',type=pathlib.Path,required=True);p.add_argument('--registry',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);p.add_argument('--only-sprites',help='Refresh only these comma-separated source sprite IDs in an existing pack');a=p.parse_args();build(a.inputs,a.registry,a.output,set(map(int,a.only_sprites.split(','))) if a.only_sprites else None)
