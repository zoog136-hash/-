"""Trace current523 SPR dependencies and build bounded, explicit candidate VFX.

Original archives and declarations stay private. Commandwise RLE is selected by
the supplied M-native half-open extent evidence, not the older grouped decoder.
RGB565, timing defaults and blending remain labelled host interpretation.
"""
from __future__ import annotations
import argparse, collections, gzip, hashlib, io, json, re, struct, sys, zipfile
from pathlib import Path
import brotli
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lineagem_original'))
import original_spr

SPR_ZIP_SHA = '311b22774e923a48640e677d15c5ebcc0bc4035487debea435806a0747d0dae8'
CATALOG_SHA = '2d43c3da5e26afc917cb73e599181eb0c57d7982cee13e496576cd6d9bda808b'
PART_SHAS = {
 '7dfd47a9cb0f1073437933febee72a26a27159c868220b51b476226d4e9632ae',
 '2280a66e69fca0f4853a6b460a9a2c315f3ebc86d46efaf83582297d6fa1091c',
 '3e47d38afadc8b8c55d7528acaba5148ec4c101151fa16bc7202f66e1b23da71',
 '4d6045fc087a8b2e1794776635ac84a6729423e1182a7627fe6bff17ae5a7770',
}
FIELDS = ('CasterEffectSpriteID','EffectSpriteID','EffectExplosionSpriteID','SuccessEffectSpriteID','FailEffectSpriteID','CriticalEffectSpriteID','HostileEffectSpriteID')
def sha(b): return hashlib.sha256(b).hexdigest()
def write(path, value):
 path.parent.mkdir(parents=True, exist_ok=True)
 path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',',':'))+'\n')

class Reader:
 def __init__(self, data): self.data, self.pos = data, 0
 def take(self, n):
  if not 0 <= n <= len(self.data)-self.pos: raise ValueError('SP2 read exceeds source')
  b=self.data[self.pos:self.pos+n]; self.pos+=n; return b
 def get(self, f): return struct.unpack('<'+f, self.take(struct.calcsize('<'+f)))

def decode(raw):
 if raw[:1] == b'\xfe': body=raw
 else:
  d=brotli.Decompressor(); pieces=[]; size=0
  for offset in range(0,len(raw),512):
   piece=d.process(raw[offset:offset+512]); size+=len(piece)
   if size>64*1024*1024: raise ValueError('SP2 expansion bound')
   pieces.append(piece)
  if not d.is_finished(): raise ValueError('incomplete SP2 Brotli')
  body=b''.join(pieces)
 r=Reader(body)
 if r.get('B')[0]!=254: raise ValueError('SP2 marker')
 pn=r.get('B')[0] or 256; palette=r.get('H'*pn); mask=r.get('B')[0]
 if not mask: raise ValueError('empty SP2 mask')
 groups={}
 for bit in range(8):
  if not mask & (1<<bit): continue
  frames=[]
  for _ in range(r.get('B')[0]):
   extent=r.get('4h'); n=r.get('H')[0]
   aa=r.get('b'*n); bb=r.get('b'*n); types=r.take(n); ids=[]
   if n:
    ids=[r.get('H')[0]]
    for delta in r.get('h'*(n-1)): ids.append(ids[-1]+delta+1)
   frames.append((extent,aa,bb,types,ids))
  nb=r.get('I')[0]
  if nb>1000000: raise ValueError('SP2 block bound')
  blocks=[]
  for _ in range(nb):
   x,y,n=r.get('3B'); commands=r.get('H'*n); blocks.append([x,y,commands,[]])
  if any(i<0 or i>=nb for f in frames for i in f[-1]): raise ValueError('SP2 reference bound')
  groups[bit]=(frames,blocks)
 for frames,blocks in groups.values():
  for x0,y0,commands,pixels in blocks:
   x,y=x0,y0
   for word in commands:
    skip,count,step=word&31,(word>>5)&31,word>>10; x+=skip
    values=r.take(count)
    if any(v>=pn for v in values): raise ValueError('SP2 palette bound')
    pixels.extend((x+i,y,v) for i,v in enumerate(values))
    if step: x=x0; y+=step
    else: x+=count
 if r.pos!=len(body): raise ValueError('SP2 trailing bytes')
 return palette,groups,body

def raster(palette, group, index):
 frames,blocks=group; extent,aa,bb,types,ids=frames[index]; points=[]
 for a,b,i in zip(aa,bb,ids):
  dx,dy=24*(b+a-a//2),12*(b-a//2)
  points.extend((x+dx,y+dy,v) for x,y,v in blocks[i][3])
 if not points: return Image.new('RGBA',(1,1)),[0,0],list(extent)
 box=[min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points)+1,max(p[1] for p in points)+1]
 if box!=list(extent): raise ValueError(('native half-open extent mismatch',box,extent))
 w,h=box[2]-box[0],box[3]-box[1]
 if not 0<w<=2048 or not 0<h<=2048: raise ValueError('SP2 raster bound')
 image=Image.new('RGBA',(w,h)); px=image.load()
 for x,y,v in points:
  c=palette[v]; px[x-box[0],y-box[1]]=((c>>11)*255//31,((c>>5)&63)*255//63,(c&31)*255//31,255)
 return image,box[:2],list(extent)

def run(a):
 if sha(a.spr_zip.read_bytes())!=SPR_ZIP_SHA: raise ValueError('SPR archive pin')
 if sha(a.catalog.read_bytes())!=CATALOG_SHA: raise ValueError('catalog pin')
 out=a.output; out.mkdir(parents=True,exist_ok=True)
 spr_root=out/'private-source-declarations'; spr_root.mkdir(exist_ok=True)
 with zipfile.ZipFile(a.spr_zip) as z:
  if z.testzip(): raise ValueError('SPR archive CRC')
  proofs=json.loads(z.read('SPR_reference_closure/results/all_current_text_integrity.json'))
  for p in proofs:
   b=z.read('SPR_reference_closure/originals/'+p['path'])
   if len(b)!=p['bytes'] or sha(b)!=p['sha256'] or not p['fresh_current_manifest_match']: raise ValueError('current SPR proof')
   (spr_root/Path(p['path']).name).write_bytes(b)
 ds=original_spr.read(spr_root.glob('*.spr'))
 catalog=json.loads(a.catalog.read_bytes()); refs=collections.defaultdict(list)
 for kind,table,fields in [('Spell','SpellClass',FIELDS),('Invoke','InvokeOption',('AttackerEffectSpriteID','TargetEffectSpriteID'))]:
  for entry in catalog['tables'][table].values():
   row=entry['row']
   for f in fields:
    if row.get(f): refs[int(row[f])].append({'kind':kind,'id':row['ID'],'field':f})
 cross=json.loads(a.crosscheck.read_bytes()); roots=set(refs)|set(map(int,cross['sprite_catalog_records']))
 todo=list(roots); closure={}; failures=[]
 while todo:
  sid=todo.pop()
  if sid in closure: continue
  matches=ds.get(sid,[])
  if len(matches)!=1: closure[sid]={'pending':'missing_or_duplicate','count':len(matches)};continue
  d=matches[0]; links=[]
  if d.alias_target is not None: links.append({'kind':'alias','target':d.alias_target})
  for ref in d.references:
   if not ref['count_valid']: failures.append({'id':sid,'reference':ref});continue
   links.extend({'kind':ref['kind'],'target':target} for target in ref['targets'])
  # Preserve all action/directive bodies; no annotation/109 dispatch inference.
  closure[sid]={'file':d.source_file,'line':d.source_line,'alias':d.alias_target,'links':links,'actions':d.actions,'directives':d.directives}
  todo.extend(link['target'] for link in links)
 members={}; containers=[]; part_hashes=set()
 for path in sorted(a.originals.glob('*checkpoint*.zip')):
  digest=sha(path.read_bytes())
  if digest not in PART_SHAS: continue
  part_hashes.add(digest)
  with zipfile.ZipFile(path) as outer:
   if outer.testzip(): raise ValueError('original checkpoint CRC')
   for n in outer.namelist():
    if not n.endswith('.dat'): continue
    name=Path(n).name; data=outer.read(n); proof=json.loads(outer.read('source_proofs/'+name+'_proof.json'))
    if len(data)!=proof['bytes'] or sha(data)!=proof['sha256'] or not proof['whole_current523_manifest_match']: raise ValueError('current DAT proof')
    containers.append({'container':proof['container'],'sha256':sha(data),'bytes':len(data)})
    with zipfile.ZipFile(io.BytesIO(data)) as dat:
     if dat.testzip(): raise ValueError('current DAT member CRC')
     for member in dat.namelist():
      mt=re.fullmatch(r'Sprite/(\d+)-(\d+)\.sp2',member)
      if mt and int(mt[1]) in closure:
       raw=dat.read(member)
       if member in members and members[member]['sha256']!=sha(raw): raise ValueError('conflicting exact member')
       members[member]={'bytes':len(raw),'sha256':sha(raw),'container':proof['container'],'raw':raw}
 if part_hashes!=PART_SHAS or len(containers)!=69: raise ValueError('expected all 69 exact current DATs')
 records={}; issues=[]; raw_dir=out/'originals'; raw_dir.mkdir(exist_ok=True)
 for member,rec in members.items(): (raw_dir/Path(member).name).write_bytes(rec['raw'])
 def compile_layer(sid, parent_action=None, visited=()):
   if sid in visited or len(visited)>=8: raise ValueError('layer cycle/depth bound')
   owner,actions=original_spr.resolve(ds,sid); links=original_spr.resolve_references(ds,sid)
   # Keep a sole nonzero source action under its real ID. Runtime auto-selection
   # is a separate opt-in host policy; explicit source action0 is never replaced.
   inherited=not actions
   if inherited and parent_action is None: raise ValueError('no source action')
   if not inherited and 0 not in actions and len(actions)!=1: raise ValueError('ambiguous action selection')
   action=parent_action if inherited else actions[0] if 0 in actions else next(iter(actions.values()))
   flag=action['declared_flag']
   if action['errors'] or flag not in (0,1): raise ValueError('unsupported source action/flag')
   directions=range(8) if flag==1 else range(1)
   addresses={original_spr.frame_address(g,d,flag) for d in directions for g,f,t in action['tokens']}
   parsed={}
   for chunk,bit in addresses:
    member=f'Sprite/{owner}-{chunk}.sp2'
    if member not in members: raise ValueError('missing exact '+member)
    pal,groups,body=decode(members[member]['raw']); parsed[chunk]=(pal,groups)
   direction_frames={}
   for direction in directions:
    frames=[]
    for i,(g,f,ticks) in enumerate(action['tokens']):
     chunk,bit=original_spr.frame_address(g,direction,flag);pal,groups=parsed[chunk]
     image,offset,extent=raster(pal,groups[bit],f); context=sha(action['raw_body'].encode())[:16]
     rel=f'frames/{sid}_{context}/'+(f'd{direction}/' if flag else '')+f'{i}.png'; target=out/rel;target.parent.mkdir(parents=True,exist_ok=True);image.save(target)
     frames.append({'path':rel,'bytes':target.stat().st_size,'sha256':sha(target.read_bytes()),'offset':offset,'size':list(image.size),'source_ticks':ticks,'source_frame':f,'source_group_bit':bit,'source_chunk':chunk,'source_extent_halfopen':extent})
    direction_frames[str(direction)]=frames
   children=[]
   for kind,entries in links.items():
    for ref in entries:
     if not ref['count_valid']: raise ValueError('unresolved layer reference')
     for target in ref['targets']:
      child=compile_layer(target,action,visited+(sid,));child['host_layer_kind']=kind;children.append(child)
   if len(children)>8: raise ValueError('layer count bound')
   budget=max(sum(f['size'][0]*f['size'][1]*4 for f in frames) for frames in direction_frames.values())+sum(c['runtime_rgba_bytes'] for c in children)
   if budget>64*1024*1024: raise ValueError('complete effect exceeds host64MiB decoded texture budget')
   return {'source_sprite_id':sid,'source_owner_id':owner,'source_action_id':action['code'],'source_action_ids':sorted(actions),'source_direction_flag':flag,'source_fps':action['fps'],'frames':direction_frames['0'],'directions':direction_frames if flag else {},'source_raw_body':action['raw_body'],'source_attributes':[d['body'] for d in ds[sid][0].directives if d['code']==104],'references':refs.get(sid,[]),'children':children,'runtime_rgba_bytes':budget,'action_origin':'host_estimated_parent_frame_indices' if inherited else 'own_SPR_action'+str(action['code']),'composition_origin':'host_independent_same_start_once; source_layer_sync_blend_not_verified','facing_origin':'literal stored group chosen by configurable host direction; native physical facing map not verified'}
 for sid in sorted(refs):
  try:
   records[str(sid)]=compile_layer(sid)
  except (ValueError,KeyError,IndexError) as e: issues.append({'sprite_id':sid,'pending':str(e)})
 audit={'kind':'patch523_complete_selected_SPR_trace','SPR_source_zip_sha256':SPR_ZIP_SHA,'text_files':len(proofs),'effect_roots':len(refs),'all_roots_including_declared11':len(roots),'reached_declarations':closure,'alias_edges':[{'from':s,**l} for s,d in closure.items() for l in d.get('links',[]) if l['kind']=='alias'],'reference_syntax_boundaries':failures,'current69_containers':containers,'selected_actual_members':{m:{k:v for k,v in r.items() if k!='raw'} for m,r in members.items()},'compiled_action0_effects':list(records),'pending':issues,'limits':'Complete explicit alias/shadow/clothes selected-root closure. No annotation/109 dispatch inference. Child frame inheritance/same-start-once composition is explicit host policy, disabled unless selected. Native pixel order/RGB/alpha/FPS/runtime remains interpretation.'}
 write(out/'SPR_AUDIT.json',audit)
 manifest={'schema':1,'kind':'patch523_source_effect_frames','source_snapshot':'patch523','catalog_sha256':CATALOG_SHA,'mode':'M_commandwise_RGB565_candidate','native_runtime_verified':False,'records':records}
 write(out/'manifest.json',manifest)
 print(json.dumps({'effects':list(records),'members':len(members),'closure':len(closure),'aliases':len(audit['alias_edges']),'manifest_sha256':sha((out/'manifest.json').read_bytes()),'pending':issues},ensure_ascii=False))

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in ['spr-zip','originals','catalog','crosscheck','output']:p.add_argument('--'+n,type=Path,required=True)
 run(p.parse_args())
