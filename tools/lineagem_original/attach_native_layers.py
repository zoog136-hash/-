"""Attach literal clothes pixels to native parent token timelines; blending stays pending."""
import argparse,collections,json,pathlib,time
import original_sp2,original_spr

def build(inputs,pack,only=None):
 registry=json.loads((pack/'registered_effect_layers.json').read_text());started=time.time();counts=collections.Counter();issues=[]
 ds=original_spr.read((inputs/'lineagem-category-source-metadata/original-spr').glob('*.spr'))
 import gzip
 inventory=json.load(gzip.open(inputs/'full_resource_inventory/inventory/id_to_archive.json.gz','rt'));byname=collections.defaultdict(list)
 for pattern in ['transformation-*/Sprite/*.sp2','magic_doll-*/Sprite/*.sp2','holy_relic-*/Sprite/*.sp2','base508-identity-extra-sp2-*/Sprite/*.sp2','base508-original-effect-attachments-*/Sprite/*.sp2']:
  for path in inputs.glob(pattern):byname[path.name].append(str(path))
 def layer_info(layer):
  physical=original_spr.resolve(ds,layer)[0] if layer in ds else layer
  declarations=ds.get(layer,[]);attrs=[x['body'] for d in declarations for x in d.directives if x['code']==104]
  if not attrs and physical!=layer:attrs=[x['body'] for d in ds.get(physical,[]) for x in d.directives if x['code']==104]
  assets=inventory.get(str(physical),{}).get('assets',[])
  info={'sprite_id':layer,'physical_sprite_id':physical,'source_attributes':attrs,'blend_status':'unverified','assets':[{**a,'local_paths':byname[pathlib.Path(a['name']).name]} for a in assets],'relation':'SPR105.clothes','timeline':'parent_native_token_address','rendered':False}
  registry[str(layer)]=info
  return info
 for actor_file in sorted((pack/'actors').glob('*.json')):
  if only is not None and int(actor_file.stem) not in only:continue
  actor=json.loads(actor_file.read_text());cache={};images={}
  for track in actor['tracks'].values():
   refs=original_spr.resolve_references(ds,track['source_sprite_id']);layers=[layer_info(layer) for ref in refs.get('clothes',[]) for layer in ref['targets']];track['source_effect_layers']=layers
   annotations=original_spr.source_annotations(track['source_raw_body']);track['source_annotations']=annotations
   for frames in track['directions']:
    for token_index,frame in enumerate(frames):
     frame['source_annotations']=[x for x in annotations if x['token_index']==token_index];frame['effect_layers']=[]
     chunk=frame['physical_group'];bit=frame['stored_direction_bit'];source_frame=frame['source_frame']
     for effect in layers:
      source_layer=effect['sprite_id'];layer=effect['physical_sprite_id'];name=f'{layer}-{chunk}.sp2';key=(layer,chunk,bit,source_frame)
      assets=[a for a in effect['assets'] if pathlib.Path(a['name']).name==name]
      paths=assets[0]['local_paths'] if assets else []
      if not paths:
       issues.append({'actor':actor['source_sprite_id'],'layer':layer,'file':name,'reason':'exact_attachment_file_unavailable'});continue
      try:
       if name not in cache:cache[name]=original_sp2.parse(pathlib.Path(paths[0]).read_bytes())
       pal,mask,dirs,_=cache[name];bits=[b for b in range(8) if mask&(1<<b)]
       if bit not in bits:raise ValueError('exact_stored_direction_absent')
       fs,blocks=dirs[bits.index(bit)]
       if source_frame>=len(fs):raise ValueError('source_frame_out_of_range')
       if key not in images:
        image,offset=original_sp2.render(pal,fs,blocks,source_frame);rel=f'pixels/{layer}-{chunk}-{bit}-{source_frame}.png';dest=pack/rel
        if not dest.exists():image.save(dest)
        images[key]={'path':rel,'offset':list(offset),'layer_id':source_layer,'physical_layer_id':layer,'source_attributes':effect['source_attributes'],'blend_status':'unverified','render_enabled':False,'pixel_size':list(image.size),'source_bounds':list(fs[source_frame][0])}
       frame['effect_layers'].append(images[key]);counts['attached_frame_samples']+=1
      except Exception as e:issues.append({'actor':actor['source_sprite_id'],'layer':layer,'file':name,'reason':str(e)})
  actor_file.write_text(json.dumps(actor,ensure_ascii=False,separators=(',',':'))+'\n');counts['actor_records']+=1
  if counts['actor_records']%50==0:print(json.dumps(dict(counts),ensure_ascii=False),flush=True)
 if only is not None and (pack/'attachment-status.json').exists():
  previous=json.loads((pack/'attachment-status.json').read_text());issues.extend(x for x in previous['issues'] if x['actor'] not in only)
 unique={json.dumps(x,sort_keys=True):x for x in issues};result={'counts':dict(counts),'issues':list(unique.values()),'seconds':round(time.time()-started,1),'blend':'pending; original attributes retained; no guessed shader','trigger_semantics':'raw source annotations retained; gameplay hit clock unchanged'}
 (pack/'registered_effect_layers.json').write_text(json.dumps(registry,ensure_ascii=False,separators=(',',':'))+'\n')
 (pack/'attachment-status.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='issues'},ensure_ascii=False))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--inputs',type=pathlib.Path,required=True);p.add_argument('--pack',type=pathlib.Path,required=True);p.add_argument('--only-sprites');a=p.parse_args();build(a.inputs,a.pack,set(map(int,a.only_sprites.split(','))) if a.only_sprites else None)
