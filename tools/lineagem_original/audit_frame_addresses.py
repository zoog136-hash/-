"""Audit exact SPR frame-slot addresses against physical source catalog, without rendering."""
import argparse,collections,gzip,json,pathlib
import original_spr

def audit(inputs,registry,output):
 cards=json.loads((registry/'cards.json').read_text());ds=original_spr.read((inputs/'lineagem-category-source-metadata/original-spr').glob('*.spr'));inventory=json.load(gzip.open(inputs/'full_resource_inventory/inventory/id_to_archive.json.gz','rt'))
 physical={pathlib.Path(a['name']).name for row in inventory.values() for a in row.get('assets',[])};local={p.name for pattern in ['transformation-*/Sprite/*.sp2','magic_doll-*/Sprite/*.sp2','holy_relic-*/Sprite/*.sp2','base508-identity-extra-sp2-*/Sprite/*.sp2'] for p in inputs.glob(pattern)}
 selected={sid for category in cards['catalog'].values() for r in category for sid in r['source_inworld_sprite_ids']};run={r['WalkSpriteID']:r['RunSpriteID'] for r in cards['run_sprite_relationships']};needed=collections.defaultdict(list);errors=[]
 for sid in selected:
  try:owner,actions=original_spr.resolve(ds,sid)
  except ValueError as e:errors.append({'sprite_id':sid,'reason':str(e)});continue
  tracks=[(sid,owner,actions.get(k)) for k in [0,1,3]]
  if sid in run:
   try:ro,ra=original_spr.resolve(ds,run[sid]);tracks.append((run[sid],ro,ra.get(0)))
   except ValueError as e:errors.append({'sprite_id':sid,'reason':str(e)})
  for action_sprite,body,action in tracks:
   if action is None:continue
   refs=original_spr.resolve_references(ds,action_sprite);shadows=[x for ref in refs.get('shadow',[]) for x in ref['targets']];layers=[body]+(shadows if len(shadows)==1 else [])
   for group,frame,ticks in action['tokens']:
    for direction in range(8):
     try:chunk,bit=original_spr.frame_address(group,direction,action['declared_flag'])
     except ValueError as e:errors.append({'sprite_id':sid,'reason':str(e)});continue
     for layer in layers:
      name=f'{layer}-{chunk}.sp2'
      if not needed[name]:needed[name].append({'source_sprite_id':sid,'action_sprite_id':action_sprite,'source_group':group,'direction':direction,'physical_chunk':chunk,'stored_bit':bit})
 absent={n:why for n,why in needed.items() if n not in physical};missing_local={n:why for n,why in needed.items() if n in physical and n not in local}
 result={'needed_unique_files':len(needed),'not_in_physical_catalog':absent,'physical_but_not_local':missing_local,'declaration_errors':errors,'rule':'slot=SPR_group+(direction if flag1 else0); chunk=slot&~7; stored_bit=slot&7; alias layer overrides preserved per action'}
 output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v if not isinstance(v,dict) else len(v) for k,v in result.items() if k!='declaration_errors'}));print('declaration_errors',len(errors))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--inputs',type=pathlib.Path,required=True);p.add_argument('--registry',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();audit(a.inputs,a.registry,a.output)
