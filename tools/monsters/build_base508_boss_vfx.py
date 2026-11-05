"""Compile literal original SP2 boss effects; retain absent slots as explicit gaps.
No generated art, interpolation, nearest direction, or invented native frame rate.
"""
import argparse,gzip,hashlib,json,sys,zipfile,zlib,math
from contextlib import ExitStack
from base508_build_space import reserve_budget,BuildSpaceError,DEFAULT_RESERVE_BYTES
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'lineagem_original'))
import original_spr
from base508_sp2_packet import normalize,geometry

class SourceInputsPending(RuntimeError):
 exit_code=66
 def __init__(self,details):
  self.details={'event':'source_waiting','exit_code':66,**details};super().__init__(json.dumps(self.details))

def estimate_space(inv,sprite_ids,available,*,normalized_multiplier=2.0,metadata_bytes_per_model=256*1024,fixed_metadata_bytes=1024*1024,temporary_peak_bytes=None):
 """Manifest-size planning estimate, NOT a measured normalized-output bound."""
 if not math.isfinite(normalized_multiplier)or normalized_multiplier<=0:raise ValueError('normalized multiplier must be finite and positive')
 for value in (metadata_bytes_per_model,fixed_metadata_bytes):
  if type(value)is not int or value<0:raise ValueError('metadata estimate must be a nonnegative byte count')
 pending=list(sprite_ids);seen=set();assets={}
 while pending:
  sid=pending.pop()
  if sid in seen:continue
  seen.add(sid);row=inv.get(str(sid),{})
  for asset in row.get('assets',[]):
   if type(asset.get('size'))is not int or asset['size']<0:raise ValueError('invalid original manifest size')
   assets[asset['name']]=asset
  for declaration in row.get('declarations',[]):
   if declaration.get('alias_target')is not None:pending.append(declaration['alias_target'])
   for reference in declaration.get('references',[]):pending.extend(reference.get('targets',[]))
 original=sum(row['size']for row in assets.values());largest=max((row['size']for row in assets.values()),default=0);metadata=max(1,len(set(sprite_ids)))*metadata_bytes_per_model+fixed_metadata_bytes
 if temporary_peak_bytes is not None and(type(temporary_peak_bytes)is not int or temporary_peak_bytes<0):raise ValueError('temporary estimate must be a nonnegative byte count')
 return {'estimate_only_not_measured_output':True,'source_manifest_bytes':original,'source_manifest_member_count':len(assets),'materialized_requested_member_count':sum(Path(name).name in available for name in assets),'normalized_multiplier':normalized_multiplier,'metadata_bytes_per_model':metadata_bytes_per_model,'fixed_metadata_bytes':fixed_metadata_bytes,'expected_new_bytes':math.ceil(original*normalized_multiplier)+metadata,'temporary_peak_bytes':temporary_peak_bytes if temporary_peak_bytes is not None else math.ceil(largest*normalized_multiplier)+metadata_bytes_per_model,'basis':'all known requested source dependencies; normalized packets estimated from original manifest sizes plus conservative metadata; no source or output size success inferred'}

def build(a):
 inv=json.load(gzip.open(a.inventory));ds=original_spr.read(a.spr_root.glob('*.spr'));available={}
 with ExitStack()as inputs:
  for source in a.sources:
   if source.is_dir():
    for path in source.rglob('*.sp2'):available[path.name]=('file',path)
   else:
    archive=inputs.enter_context(zipfile.ZipFile(source))
    for name in archive.namelist():
     if name.lower().endswith('.sp2'):available[Path(name).name]=(archive,name)
  estimate=estimate_space(inv,a.sprite_ids,available,normalized_multiplier=getattr(a,'space_normalized_multiplier',2.0),metadata_bytes_per_model=getattr(a,'space_metadata_bytes_per_model',256*1024),fixed_metadata_bytes=getattr(a,'space_fixed_metadata_bytes',1024*1024),temporary_peak_bytes=getattr(a,'space_temporary_peak_bytes',None))
  if not estimate['materialized_requested_member_count']:raise SourceInputsPending({'reason':'no_requested_original_inputs_materialized','known_requested_members':estimate['source_manifest_member_count'],'output_unchanged':True})
  with reserve_budget(a.output,estimate['expected_new_bytes'],estimate['temporary_peak_bytes'],getattr(a,'space_reserve_bytes',DEFAULT_RESERVE_BYTES),state_dir=getattr(a,'space_state_dir',None))as lease:
   print(json.dumps({'event':'boss_vfx_space_plan','estimate':estimate,'reservation':lease.as_dict()}),flush=True)
   return _compile(a,inv,ds,available)

def _compile(a,inv,ds,available):
 out=a.output;out.mkdir(parents=True,exist_ok=True);(out/'sp2').mkdir(exist_ok=True);(out/'effects').mkdir(exist_ok=True);source_files={};models={};failures={};decoded={}
 assets={v['name']:v for value in inv.values()for v in value.get('assets',[])}
 def packet(layer,address,bit,frame,relation,attrs):
  name=f'Sprite/{layer}-{address}.sp2';spec=assets.get(name)
  if spec is None:raise KeyError(('source_inventory_member_unlocated',name))
  item=available.get(Path(name).name)
  if item is None:raise KeyError(('source_member_not_materialized',name))
  relative=f'sp2/{layer}-{address}.bin'
  if name not in decoded:
   raw=item[1].read_bytes()if item[0]=='file'else item[0].read(item[1]);assert len(raw)==spec['size']and f'{zlib.crc32(raw)&0xffffffff:08x}'==str(spec['crc32']).lower().removeprefix('0x'),('Original source CRC/size',name)
   normalized,parsed=normalize(raw,geometry_only=True);decoded[name]=parsed
   (out/relative).write_bytes(normalized);source_files[name]={'path':relative,'sha256':hashlib.sha256(normalized).hexdigest(),'original_sha256':hashlib.sha256(raw).hexdigest(),'original_bytes':len(raw),'source_archive':spec['archive'],'source_crc32':spec['crc32']}
  bounds=geometry(decoded[name],bit,frame)
  return {**source_files[name],**bounds,'codec':'base508_sp2_v1','source_direction_bit':bit,'source_frame_index':frame,'layer_id':layer,'relation':relation,'source_attributes':attrs}
 for sid in a.sprite_ids:
  try:
   body,actions=original_spr.resolve(ds,sid);action=actions.get(0)
   if action is None:raise ValueError('source_action0_absent; no invented effect state')
   if action['errors']:raise ValueError(action['errors'])
   refs=original_spr.resolve_references(ds,sid);shadows=list(dict.fromkeys(original_spr.resolve(ds,x)[0]for ref in refs.get('shadow',[])for x in ref['targets']));clothes=list(dict.fromkeys(original_spr.resolve(ds,x)[0]for ref in refs.get('clothes',[])for x in ref['targets']));layers=shadows+[body]+clothes
   attrs={i:[d['body']for declaration in ds.get(i,[])for d in declaration.directives if d['code']==104]for i in layers};directions=[];gaps=[]
   for direction in range(8):
    frames=[];body_failed=False
    for index,(group,frame,ticks)in enumerate(action['tokens']):
     if ticks==0:continue
     address,bit=original_spr.frame_address(group,direction,action['declared_flag']);visible=[]
     for layer in layers:
      relation='SPR105.clothes'if layer in clothes else('SPR101.shadow'if layer in shadows else'body')
      try:visible.append(packet(layer,address,bit,frame,relation,attrs[layer]))
      except (KeyError,ValueError)as error:
       gaps.append({'source_direction':direction,'source_token_index':index,'layer_id':layer,'relation':relation,'address':address,'direction_bit':bit,'frame_index':frame,'reason':str(error)})
       if relation=='body':body_failed=True;break
     if body_failed:break
     frames.append({'source_ticks':ticks,'source_group':group,'source_frame':frame,'layers':visible})
    directions.append([]if body_failed else frames)
   if not any(directions):raise ValueError(('No exact source body direction complete',gaps))
   track={'source_sprite_id':sid,'source_body_id':body,'source_action_id':0,'fps':action['fps'],'source_timing_provenance':action.get('fps_provenance'),'source_raw_body':action['raw_body'],'source_annotations':action.get('source_annotations',[]),'timing_issues':action['errors'],'loop':False,'directions':directions}
   model={'source_snapshot':'base508','source_sprite_id':sid,'body_id':body,'tracks':{'effect':track},'source_gaps':gaps,'source_pixels_complete':not gaps,'available_directions':[i for i,v in enumerate(directions)if v],'source_rate_status':'source_explicit'if action['fps']is not None else'native_FPS_unknown; strict_static_or_explicit_compat_policy'}
   relative=f'effects/{sid}.json';b=(json.dumps(model,ensure_ascii=False,separators=(',',':'))+'\n').encode();(out/relative).write_bytes(b);models[str(sid)]={'path':relative,'sha256':hashlib.sha256(b).hexdigest(),'source_pixels_complete':not gaps,'available_directions':model['available_directions']}
  except (KeyError,ValueError,IndexError)as error:failures[str(sid)]=str(error)
 result={'schema':1,'source_snapshot':'base508','kind':'base508_boss_literal_sp2_effects','models':models,'source_files':source_files,'failures':failures,'contract':'Exact source action0 and stored slots only. Missing dependencies stay declared source gaps. Runtime may show available original body layers without claiming full source composition. Unknown FPS/blend never claimed native-verified.'};(out/'boss_vfx.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n');print(json.dumps({'models':len(models),'complete_source_compositions':sum(v['source_pixels_complete']for v in models.values()),'source_packets':len(source_files),'failures':failures}));return result
def nonnegative(value):
 result=int(value)
 if result<0:raise argparse.ArgumentTypeError('must be nonnegative')
 return result
def multiplier(value):
 result=float(value)
 if not math.isfinite(result)or result<=0:raise argparse.ArgumentTypeError('must be finite and positive')
 return result
def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--inventory',type=Path,required=True);p.add_argument('--spr-root',type=Path,required=True);p.add_argument('--sources',type=Path,nargs='+',required=True);p.add_argument('--sprite-ids',type=lambda s:list(map(int,s.split(','))),required=True);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--space-normalized-multiplier',type=multiplier,default=2.0,help='Planning estimate only: normalized packet bytes / original manifest bytes')
 p.add_argument('--space-metadata-bytes-per-model',type=nonnegative,default=256*1024)
 p.add_argument('--space-fixed-metadata-bytes',type=nonnegative,default=1024*1024)
 p.add_argument('--space-temporary-peak-bytes',type=nonnegative,help='Override conservative temporary disk estimate')
 p.add_argument('--space-reserve-bytes',type=nonnegative,default=DEFAULT_RESERVE_BYTES)
 p.add_argument('--space-state-dir',type=Path,help='Shared with other builders; otherwise BASE508_SPACE_STATE_DIR or shared task temporary directory')
 try:build(p.parse_args(argv))
 except (BuildSpaceError,SourceInputsPending)as error:
  print(json.dumps(error.details,sort_keys=True),file=sys.stderr,flush=True);return error.exit_code
 return 0
if __name__=='__main__':raise SystemExit(main())
