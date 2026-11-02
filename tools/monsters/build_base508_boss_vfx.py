"""Compile literal original SP2 boss effects; retain absent slots as explicit gaps.
No generated art, interpolation, nearest direction, or invented native frame rate.
"""
import argparse,gzip,hashlib,json,sys,zipfile,zlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'lineagem_original'))
import original_spr
from base508_sp2_packet import normalize,geometry

def build(a):
 inv=json.load(gzip.open(a.inventory));ds=original_spr.read(a.spr_root.glob('*.spr'));available={};archives=[]
 for source in a.sources:
  if source.is_dir():
   for p in source.rglob('*.sp2'):available[p.name]=('file',p)
  else:
   z=zipfile.ZipFile(source);archives.append(z)
   for name in z.namelist():
    if name.lower().endswith('.sp2'):available[Path(name).name]=(z,name)
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
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--inventory',type=Path,required=True);p.add_argument('--spr-root',type=Path,required=True);p.add_argument('--sources',type=Path,nargs='+',required=True);p.add_argument('--sprite-ids',type=lambda s:list(map(int,s.split(','))),required=True);p.add_argument('--output',type=Path,required=True);build(p.parse_args())
