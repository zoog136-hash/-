"""Build source-ID model pack from verified original ZIP members; no artwork synthesis."""
import argparse,collections,gzip,hashlib,json,zipfile,zlib,gc,resource
from pathlib import Path
from base508_sp2_packet import normalize,geometry
import original_spr
ROLES={0:'walk',1:'attack',2:'hit',3:'idle',8:'death'}
def main(a):
 c=json.load(gzip.open(a.catalog)); req=json.load(gzip.open(a.requests)); files={r['name']:r for r in req['files']}; ds=original_spr.read(a.spr_root.glob('*.spr'))
 out=a.output;out.mkdir(parents=True,exist_ok=True);(out/'actors').mkdir(exist_ok=True);(out/'sp2').mkdir(exist_ok=True)
 zips={};indices={};packets={};models={};failures={}
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
  if not m.get('original_members') or m.get('reference_issues') or m.get('missing_standard_roles') or any('available_library_package'not in files[n] or not (a.packages/files[n]['available_library_package']['file_name']).exists() for n in m['original_members']):continue
  cached_path=out/'actors'/f'{sid}.json'
  if a.resume and cached_path.exists():
   try:
    cached=json.loads(cached_path.read_text());assert cached['source_sprite_id']==int(sid)and all(role in cached['tracks']for role in ROLES.values())
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
  decoded={};bounds={}
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
   shadows=[original_spr.resolve(ds,x)[0]for r in refs.get('shadow',[])for x in r['targets']];clothes=[original_spr.resolve(ds,x)[0]for r in refs.get('clothes',[])for x in r['targets']]
   layers=shadows+[body]+clothes;attrs={i:[d['body']for decl in ds.get(i,[])for d in decl.directives if d['code']==104]for i in layers}
   if len(shadows)>1 or action['errors']:raise ValueError(('Source reference/action unresolved',code,action['errors']))
   directions=[]
   for direction in range(8):
    frames=[]
    for group,frame,ticks in action['tokens']:
     address,bit=original_spr.frame_address(group,direction,action['declared_flag'])
     ls=[layer_frame(i,address,bit,frame,'SPR105.clothes'if i in clothes else('SPR101.shadow'if i in shadows else'body'),attrs[i])for i in layers]
     frames.append({'source_ticks':ticks,'source_frame':frame,'source_group':group,'layers':ls})
    if not frames:raise ValueError(('Empty source action',code))
    directions.append(frames)
   return {'fps':action['fps'],'source_sprite_id':source_sid,'source_body_id':body,'source_action_id':code,'source_raw_body':action['raw_body'],'source_timing_provenance':action.get('fps_provenance'),'timing_issues':action['errors'],'loop':code in(0,3),'directions':directions}
  try:
   body,actions=original_spr.resolve(ds,int(sid));tracks={};errors={}
   for code,action in actions.items():
    try:tracks[ROLES.get(code,f'source_action_{code}')]=track(int(sid),code,action)
    except (ValueError,KeyError,IndexError)as e:errors[str(code)]=str(e)
   if any(role not in tracks for role in ROLES.values()):raise ValueError(('Core source action unresolved',errors))
   run=m.get('source_run_sprite_id')
   if run is not None:
    try:
     _,ra=original_spr.resolve(ds,run);tracks['run']=track(run,0,ra[0])
    except (ValueError,KeyError,IndexError)as e:errors['run']=str(e)
   model={'source_sprite_id':int(sid),'body_id':body,'tracks':tracks,'source_action_issues':errors,'source_run_sprite_id':run,'source_separated_walk_type':m.get('source_separated_walk_type')}
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
 manifest={'schema':1,'kind':'base508_monster_pack','source_snapshot':'base508','records':records,'models':models,'source_files':packets,'counts':{'npc_records':len(records),'unique_sprite_models':len(models),'original_sp2_files_used':len(packets)},'model_failures':failures,'placement_contract':'Source catalog and exact spawn-view contexts; host map ports are explicit, native geographic placements zero.'}
 (out/('manifest.json'if a.shards==1 else f'manifest-{a.shard}.json')).write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n');print(json.dumps(manifest['counts']),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for name in('catalog','requests','spr-root','packages','output'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--shards',type=int,default=1);p.add_argument('--shard',type=int,default=0)
 p.add_argument('--resume',action='store_true',help='Reuse only complete emitted model metadata and hash-verified packets')
 p.add_argument('--model-ids',help='Optional exact source model IDs; avoids rebuilding previously verified models')
 p.add_argument('--memory-limit-mib',type=int,default=3072)
 args=p.parse_args()
 if args.memory_limit_mib:resource.setrlimit(resource.RLIMIT_AS,(args.memory_limit_mib*1024**2,args.memory_limit_mib*1024**2))
 main(args)
