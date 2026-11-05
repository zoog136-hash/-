"""Compile declared source weapon families without editing source art or combat timing."""
import sys,json,pathlib,collections,gzip,zlib,hashlib,time,argparse
import original_spr,original_sp2
from weapon_action_selection import select_family
cli=argparse.ArgumentParser()
for name in ['inputs','base-pack','output']:cli.add_argument('--'+name,type=pathlib.Path,required=True)
cli.add_argument('--actors',default='28439,28514,28519,28524');cli.add_argument('--weapon-types',default='1,2,3,7,10,84')
args=cli.parse_args();inputs=args.inputs;stage=args.output;out=stage/'weapon_banks';(out/'actors').mkdir(parents=True,exist_ok=True);(out/'pixels').mkdir(exist_ok=True)
basepath=args.base_pack;ds=original_spr.read((inputs/'lineagem-category-source-metadata/original-spr').glob('*.spr'))
rows=json.load(open(inputs/'base508_all_content_validated/content/ListSprAction.json',encoding='utf-8-sig'))['rows'];groups=collections.defaultdict(dict)
for r in rows:
 if r['WeaponAlterType']==0 and r['MotionType'] in [1,2,4]:groups[r['WeaponType']].setdefault({1:'walk',2:'attack',4:'idle'}[r['MotionType']],r)
inventory=json.load(gzip.open(inputs/'full_resource_inventory/inventory/id_to_archive.json.gz','rt'));byname=collections.defaultdict(list)
for pattern in ['*/Sprite/*.sp2','halphas_analysis/sp2/*.sp2']:
 for p in inputs.glob(pattern):byname[p.name].append(p)
index={'schema':1,'source_snapshot':'base508','source_ListSprAction_sha256':hashlib.sha256((inputs/'base508_all_content_validated/content/ListSprAction.json').read_bytes()).hexdigest(),'records':{},'pending':[]};sources={};parsed={};images={};start=time.time()
def frame(layer,chunk,bit,f):
 key=(layer,chunk,bit,f)
 if key in images:return images[key]
 name=f'{layer}-{chunk}.sp2';paths=byname.get(name,[])
 if not paths:raise FileNotFoundError(name)
 if name not in parsed:
  raw=paths[0].read_bytes();assert all(p.read_bytes()==raw for p in paths)
  asset=next(a for a in inventory[str(layer)]['assets'] if pathlib.Path(a['name']).name==name)
  assert len(raw)==asset['size'] and f'{zlib.crc32(raw)&0xffffffff:08x}'==asset['crc32']
  parsed[name]=original_sp2.parse(raw);sources[name]={'sha256':hashlib.sha256(raw).hexdigest(),'crc32':f'{zlib.crc32(raw)&0xffffffff:08x}','bytes':len(raw)}
 pal,mask,dirs,_=parsed[name];bits=[b for b in range(8) if mask&(1<<b)]
 if bit not in bits:raise ValueError('stored direction absent '+name)
 fs,blocks=dirs[bits.index(bit)]
 if not 0<=f<len(fs):raise ValueError(f'source frame absent {name}: direction={bit} frame={f} stored_frames={len(fs)}')
 im,offset=original_sp2.render(pal,fs,blocks,f)
 rel=f'weapon_banks/pixels/{layer}-{chunk}-{bit}-{f}.png';
 if not (stage/rel).exists():im.save(stage/rel)
 value={'path':rel,'offset':list(offset),'layer_id':layer,'source_bounds':list(fs[f][0]),'pixel_size':list(im.size),'source_direction_mask':mask};images[key]=value;return value
for sid in map(int,args.actors.split(',')):
 base=json.load(open(basepath/'actors'/f'{sid}.json'));body,actions=original_spr.resolve(ds,sid);refs=original_spr.resolve_references(ds,sid);shadow=[original_spr.resolve(ds,x)[0] for r in refs.get('shadow',[]) for x in r['targets']];clothes=[x for r in refs.get('clothes',[]) for x in r['targets']];run=base.get('run_sprite_id');run_actions=original_spr.resolve(ds,run)[1] if run else {}
 for weapon,roles in groups.items():
  if weapon==0 or weapon not in {int(x) for x in args.weapon_types.split(',')}:continue
  try:
   roles=select_family(rows,sid,weapon,roles)
   chosen={role:(sid,body,actions[int(row['ID'])]) for role,row in roles.items()}
   if set(chosen)!=set(['idle','walk','attack']):raise ValueError('incomplete source action family')
   if run:
    action=run_actions.get(int(roles['walk']['ID']))
    if action and action['name'].lower().startswith('run'):chosen['run']=(run,body,action)
   tracks={}
   for role,(source_sid,physical,a) in chosen.items():
    if a['errors'] or a['fps'] is None:raise ValueError('source action/timing unavailable')
    directions=[]
    for direction in range(8):
     frames=[]
     for token_index,(g,f,ticks) in enumerate(a['tokens']):
      chunk,bit=original_spr.frame_address(g,direction,a['declared_flag']);layers=[frame(l,chunk,bit,f).copy() for l in [*shadow,physical]];effects=[]
      for layer in clothes:
       lp=original_spr.resolve(ds,layer)[0]
       if not byname.get(f'{lp}-{chunk}.sp2'):continue
       value=frame(lp,chunk,bit,f).copy();attrs=[d['body'] for decl in ds.get(layer,[]) for d in decl.directives if d['code']==104]
       value.update(physical_layer_id=lp,source_attributes=attrs,blend_status='unverified');effects.append(value)
      frames.append({'duration':ticks/a['fps'],'source_ticks':ticks,'source_group':g,'source_frame':f,'physical_group':chunk,'stored_direction_bit':bit,'source_annotations':[x for x in a['source_annotations'] if x['token_index']==token_index],'layers':layers,'effect_layers':effects})
     directions.append(frames)
    tracks[role]={'fps':a['fps'],'source_sprite_id':source_sid,'source_body_id':physical,'source_action_id':a['code'],'source_action':a['name'],'source_raw_body':a['raw_body'],'source_annotations':a['source_annotations'],'loop':role!='attack','directions':directions,'timing_issues':[],'static_pending_timing':False,'source_effect_layers':base['tracks']['idle'].get('source_effect_layers',[])}
   patch={'source_snapshot':'base508','source_sprite_id':sid,'body_id':body,'source_weapon_type':weapon,'source_action_rows':roles,'base_actor_raw_sha256':hashlib.sha256(json.dumps(base.get('source_actions'),sort_keys=True,separators=(',',':')).encode()).hexdigest(),'source_action_guards':{str(a['code']):hashlib.sha256(a['raw_body'].encode()).hexdigest() for _,_,a in chosen.values() if a['code'] in actions and a['raw_body']==actions[a['code']]['raw_body']},'tracks':tracks}
   rel=f'weapon_banks/actors/{sid}-{weapon}.json';(stage/rel).write_text(json.dumps(patch,ensure_ascii=False,separators=(',',':'))+'\n');index['records'][f'{sid}:{weapon}']={'path':rel};print('DONE',sid,weapon,len(images),'png',round(time.time()-start,1),flush=True)
  except (ValueError,FileNotFoundError,KeyError) as e:index['pending'].append({'actor':sid,'source_weapon_type':weapon,'reason':str(e)});print('PENDING',sid,weapon,str(e),flush=True)
(out/'manifest.json').write_text(json.dumps(index,ensure_ascii=False,separators=(',',':'))+'\n');(out/'source_inputs.json').write_text(json.dumps(sources,indent=2)+'\n')
print('FINISH',len(index['records']),'banks',len(images),'png',len(sources),'sp2',round(time.time()-start,1),flush=True)
