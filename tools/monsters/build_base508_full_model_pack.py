"""Build source-ID model pack from verified original ZIP members; no artwork synthesis."""
import argparse,collections,gzip,hashlib,json,zipfile,zlib,gc,resource,math
from pathlib import Path
from base508_sp2_packet import normalize,geometry
import original_spr
from base508_actor_capabilities import profile,source_tables
from base508_build_space import reserve_budget,BuildSpaceError
ROLES={0:'walk',1:'attack',2:'hit',3:'idle',8:'death'}
def literal_reference_ids(model,declarations):
 # A referenced layer can be a literal SP2 bank without its own SPR actions.
 # This is not an alias guess: retain the exact 101/105 target and only allow
 # members already listed for that same numeric identity in the source graph.
 refs=original_spr.resolve_references(declarations,int(model['source_sprite_id']))
 members=model.get('original_members',[])
 return {target for rows in refs.values() for row in rows for target in row['targets']
         if not declarations.get(target) and any(name.startswith(f'Sprite/{target}-') and name.endswith('.sp2') for name in members)}
def supported_reference_issues(model,declarations):
 issues=model.get('reference_issues',[])
 if not issues:return True
 try:literal=literal_reference_ids(model,declarations)
 except (ValueError,KeyError):return False
 return all(issue.get('issue')=='missing_or_duplicate_declaration' and issue.get('count')==0 and issue.get('sprite_id') in literal for issue in issues)
def build(a):
 c=json.load(gzip.open(a.catalog)); req=json.load(gzip.open(a.requests)); files={r['name']:r for r in req['files']}; ds=original_spr.read(a.spr_root.glob('*.spr'))
 out=a.output;out.mkdir(parents=True,exist_ok=True);(out/'actors').mkdir(exist_ok=True);(out/'sp2').mkdir(exist_ok=True)
 zips={};indices={};packets={};models={};failures={}
 capability=bool(a.source_capabilities)
 if capability:source_npcs,source_attacks,source_actions=source_tables(a.content)
 def raw(name):
  r=files[name];p=a.packages/r['available_library_package']['file_name']
  if str(p) not in zips:
   z=zipfile.ZipFile(p);zips[str(p)]=z;indices[str(p)]={Path(n).name:n for n in z.namelist() if n.lower().endswith('.sp2')}
  b=zips[str(p)].read(indices[str(p)][Path(name).name]);crc=f'{zlib.crc32(b)&0xffffffff:08x}'
  if len(b)!=r['size'] or crc.lower()!=str(r['crc32']).lower().removeprefix('0x'):raise ValueError(('Original CRC/size',name,crc,r['crc32']))
  return b
 wanted={int(value)for value in a.model_ids.split(',')}if a.model_ids else None
 for model_index,(sid,m) in enumerate(c['models'].items()):
  if wanted is not None and int(sid)not in wanted:continue
  if model_index % a.shards != a.shard:continue
  if not m.get('original_members') or (m.get('reference_issues') and not(capability and supported_reference_issues(m,ds))) or (m.get('missing_standard_roles')and not capability) or any('available_library_package'not in files[n] or not (a.packages/files[n]['available_library_package']['file_name']).exists() for n in m['original_members']):continue
  cached_path=out/'actors'/f'{sid}.json'
  if a.resume and cached_path.exists():
   try:
    cached=json.loads(cached_path.read_text());assert cached['source_sprite_id']==int(sid)and (bool(cached['tracks'])and cached.get('source_capability_contract')==1 if capability else all(role in cached['tracks']for role in ROLES.values()))
    for tr in cached['tracks'].values():
     for fs in tr['directions']:
      for f in fs:
       for layer in f['layers']:
        name='Sprite/'+Path(layer['path']).stem+'.sp2'
        if name not in packets:
         assert hashlib.sha256((out/layer['path']).read_bytes()).hexdigest()==layer['sha256']
         packets[name]={k:layer[k]for k in('path','sha256','original_sha256','original_bytes','source_archive','source_crc32')}
    models[sid]={'tracks_ref':f'actors/{sid}.json','tracks_sha256':hashlib.sha256(cached_path.read_bytes()).hexdigest()};print(json.dumps({'model_resumed':sid}),flush=True);continue
   except(ValueError,KeyError,AssertionError):pass
  print(json.dumps({'model_start':sid}),flush=True)
  decoded={};bounds={};literal_layers=literal_reference_ids(m,ds) if capability else set()
  def layer_id(target):
   return target if target in literal_layers else original_spr.resolve(ds,target)[0]
  def layer_frame(layer,group,bit,frame,relation,attrs):
   name=f'Sprite/{layer}-{group}.sp2'
   if name not in decoded:
    original=raw(name);packet,parsed=normalize(original,geometry_only=True);decoded[name]=parsed;bounds[name]={}
    if name not in packets:
     rel=f'sp2/{layer}-{group}.bin';(out/rel).write_bytes(packet);packets[name]={'path':rel,'sha256':hashlib.sha256(packet).hexdigest(),'original_sha256':hashlib.sha256(original).hexdigest(),'original_bytes':len(original),'source_archive':files[name]['archive'],'source_crc32':files[name]['crc32']}
   try:extent=geometry(decoded[name],bit,frame,bounds[name])
   except ValueError as error:raise ValueError((name,bit,frame,str(error)))from error
   return {**packets[name],**extent,'codec':'base508_sp2_v1','source_direction_bit':bit,'source_frame_index':frame,'layer_id':layer,'relation':relation,'source_attributes':attrs}
  def track(source_sid,code,action):
   body,_=original_spr.resolve(ds,source_sid);refs=original_spr.resolve_references(ds,source_sid)
   shadows=[layer_id(x)for r in refs.get('shadow',[])for x in r['targets']];clothes=[layer_id(x)for r in refs.get('clothes',[])for x in r['targets']]
   if capability:shadows=list(dict.fromkeys(shadows));clothes=list(dict.fromkeys(clothes))
   layers=shadows+[body]+clothes;attrs={i:[d['body']for decl in ds.get(i,[])for d in decl.directives if d['code']==104]for i in layers}
   if len(shadows)>1 or [e for e in action['errors']if not(capability and e=='no positive playback duration'and len(action['tokens'])==1)]:raise ValueError(('Source reference/action unresolved',code,action['errors']))
   directions=[];omissions=[];instant=[]
   def source_direction(direction):
    frames=[]
    for token_index,(group,frame,ticks)in enumerate(action['tokens']):
     if capability and ticks==0 and len(action['tokens'])>1:
      if direction==0:instant.append({'token_index':token_index,'source_group':group,'source_frame':frame,'source_ticks':0,'annotations':[v for v in action.get('source_annotations',[])if v['token_index']==token_index]})
      continue
     address,bit=original_spr.frame_address(group,direction,action['declared_flag'])
     ls=[]
     for i in layers:
      relation='SPR105.clothes'if i in clothes else('SPR101.shadow'if i in shadows else'body')
      try:ls.append(layer_frame(i,address,bit,frame,relation,attrs[i]))
      except ValueError as error:
       if not capability or relation=='body'or not any(v in str(error)for v in('Source frame absent','Source direction absent')):raise
       omissions.append({'layer_id':i,'relation':relation,'source_group':address,'source_direction_bit':bit,'source_frame_index':frame,'source_token_index':token_index,'reason':str(error),'policy':'verified_attachment_has_no_slot; no substitute pixel; native sparse draw semantics unverified'})
     frames.append({'source_ticks':ticks,'source_frame':frame,'source_group':group,'layers':ls})
    if not frames:raise ValueError(('Empty source action',code))
    return frames
   unavailable=[]
   for direction in range(8):
    try:directions.append(source_direction(direction))
    except ValueError as error:
     if not(getattr(a,'preserve_source_direction_slots',False) and 'Source direction absent' in str(error)):raise
     directions.append([]);unavailable.append({'slot':direction,'reason':str(error),'policy':'Source SP2 mask has no slot; no mirror, duplicate frame or alternate bank'})
   if not any(directions):raise ValueError(('No authored source direction available',code))
   result={'fps':action['fps'],'source_sprite_id':source_sid,'source_body_id':body,'source_action_id':code,'source_raw_body':action['raw_body'],'source_timing_provenance':action.get('fps_provenance'),'timing_issues':action['errors'],'loop':code in(0,3),'directions':directions}
   if unavailable:result['source_unavailable_direction_slots']=unavailable
   if capability:result.update({'source_omitted_attachment_slots':omissions,'instant_source_tokens':instant,'source_static_zero_duration':len(action['tokens'])==1 and action['tokens'][0][2]==0})
   return result
  try:
   body,actions=original_spr.resolve(ds,int(sid));tracks={};errors={}
   for code,action in actions.items():
    try:tracks[ROLES.get(code,f'source_action_{code}')]=track(int(sid),code,action)
    except (ValueError,KeyError,IndexError)as e:errors[str(code)]=str(e)
   if (not tracks if capability else any(role not in tracks for role in ROLES.values())):raise ValueError(('Core source action unresolved',errors))
   run=m.get('source_run_sprite_id')
   if run is not None:
    try:
     _,ra=original_spr.resolve(ds,run);tracks['run']=track(run,0,ra[0])
    except (ValueError,KeyError,IndexError)as e:errors['run']=str(e)
   model={'source_sprite_id':int(sid),'body_id':body,'tracks':tracks,'source_action_issues':errors,'source_run_sprite_id':run,'source_separated_walk_type':m.get('source_separated_walk_type')}
   if capability:model.update({'source_declared_action_ids':sorted(actions),'source_capability_contract':1,'source_available_roles':[role for role in ROLES.values()if role in tracks],'source_entry_role':'idle'if 'idle'in tracks else None,'source_sparse_attachment_policy':'explicit_no_substitution; native draw semantics unverified'})
   if any(not frames for tr in tracks.values() for frames in tr['directions']):model['source_partial_direction_contract']=1
   if literal_layers:model['source_literal_layer_references']={'ids':sorted(literal_layers),'basis':'Exact SPR101/105 numeric target and original indexed SP2 members; no independent layer action declaration required','original_reference_issues':m.get('reference_issues',[])}
   rel=f'actors/{sid}.json';b=(json.dumps(model,ensure_ascii=False,separators=(',',':'))+'\n').encode();(out/rel).write_bytes(b);models[sid]={'tracks_ref':rel,'tracks_sha256':hashlib.sha256(b).hexdigest()}
  except (ValueError,KeyError,IndexError)as e:failures[sid]=str(e)
  except MemoryError:
   failures[sid]='compile_resource_limit; source geometry/metadata requires explicit review';decoded.clear();bounds.clear();tracks={};gc.collect()
  print(json.dumps({'model':sid,'loaded_models':len(models),'failed':len(failures),'packets':len(packets)}),flush=True)
 records={}
 for row in c['rows']:
  nid=str(row['npc_id']);sid=str(row['sprite_id']);contexts=c['world_context_index'].get(nid,[])
  if sid not in models or not contexts or row['source_TestNPC']or row['source_kind']not in('source_ui_boss_npc','source_attackable_monster_actor'):continue
  records[nid]={'npc_id':row['npc_id'],'sprite_id':row['sprite_id'],'source_contexts':[{'spawn_view_id':v,'territory_link_id':l}for v,l in contexts],**models[sid]}
  if capability:
   actor=json.loads((out/models[sid]['tracks_ref']).read_text());records[nid]['source_actor_profile']=profile(row,source_npcs[row['npc_id']],actor,source_attacks,source_actions)
 manifest={'schema':1,'kind':'base508_monster_pack','source_snapshot':'base508','records':records,'models':models,'source_files':packets,'counts':{'npc_records':len(records),'unique_sprite_models':len(models),'original_sp2_files_used':len(packets)},'model_failures':failures,'placement_contract':'Source catalog and exact spawn-view contexts; host map ports are explicit, native geographic placements zero.'}
 (out/('manifest.json'if a.shards==1 else f'manifest-{a.shard}.json')).write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n');print(json.dumps(manifest['counts']),flush=True)
def estimate_build_budget(a):
 # Conservative estimates, not a guarantee or a reason to delete existing output.
 # Select only this requested shard; existing original packages are read in place.
 catalog=json.load(gzip.open(a.catalog)); requests=json.load(gzip.open(a.requests))
 files={r['name']:r for r in requests['files']}
 wanted={int(v) for v in a.model_ids.split(',')} if a.model_ids else None
 selected=[]; members=set();declarations=original_spr.read(a.spr_root.glob('*.spr'))
 for index,(sid,model) in enumerate(catalog['models'].items()):
  if wanted is not None and int(sid) not in wanted:continue
  if index % a.shards != a.shard:continue
  if not model.get('original_members') or (model.get('reference_issues') and not(a.source_capabilities and supported_reference_issues(model,declarations))):continue
  if model.get('missing_standard_roles') and not a.source_capabilities:continue
  if any(name not in files or 'available_library_package' not in files[name] or not (a.packages/files[name]['available_library_package']['file_name']).exists() for name in model['original_members']):continue
  selected.append(int(sid));members.update(model['original_members'])
 layer_slots=0
 for sid in selected:
  _,actions=original_spr.resolve(declarations,sid)
  refs=original_spr.resolve_references(declarations,sid)
  layers=1+sum(len(row['targets']) for rows in refs.values() for row in rows)
  layer_slots+=sum(len(action['tokens']) for action in actions.values())*8*layers
 original_bytes=sum(files[name]['size'] for name in members)
 expected=math.ceil(original_bytes*a.space_packet_factor)+layer_slots*1024+len(selected)*65536
 return expected,{'selected_models':len(selected),'unique_original_members':len(members),'original_member_bytes':original_bytes,'estimated_layer_slots':layer_slots,'packet_expansion_factor':a.space_packet_factor,'resume_output_is_preserved':True}

def main(a):
 if a.shards<1 or not 0<=a.shard<a.shards:raise ValueError('Invalid shard range')
 if getattr(a,'preserve_source_direction_slots',False) and not a.source_capabilities:raise ValueError('Partial source direction preservation requires source capabilities')
 if not math.isfinite(a.space_packet_factor) or a.space_packet_factor<1:raise ValueError('space-packet-factor must be finite and >=1')
 expected,plan=estimate_build_budget(a)
 with reserve_budget(a.output,expected,a.space_temporary_mib*1024**2,a.space_reserve_mib*1024**2) as lease:
  print(json.dumps({**lease.as_dict(),'estimate_plan':plan}),flush=True)
  build(a)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for name in('catalog','requests','spr-root','packages','output'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--shards',type=int,default=1);p.add_argument('--shard',type=int,default=0)
 p.add_argument('--source-capabilities',action='store_true',help='Preserve partial source states; do not require invented five-role actors')
 p.add_argument('--content',type=Path,default=Path('/workspace/base508/content'))
 p.add_argument('--resume',action='store_true',help='Reuse only complete emitted model metadata and hash-verified packets')
 p.add_argument('--model-ids',help='Optional exact source model IDs; avoids rebuilding previously verified models')
 p.add_argument('--preserve-source-direction-slots',action='store_true',help='Keep only physically authored SP2 directions; do not make absent directions')
 p.add_argument('--memory-limit-mib',type=int,default=3072)
 p.add_argument('--space-packet-factor',type=float,default=4.0,help='Conservative normalized-packet expansion estimate; actual output may differ')
 p.add_argument('--space-temporary-mib',type=int,default=128)
 p.add_argument('--space-reserve-mib',type=int,default=512)
 args=p.parse_args()
 if args.memory_limit_mib:resource.setrlimit(resource.RLIMIT_AS,(args.memory_limit_mib*1024**2,args.memory_limit_mib*1024**2))
 try:main(args)
 except BuildSpaceError as error:
  print(json.dumps(error.details),flush=True);raise SystemExit(error.exit_code)
