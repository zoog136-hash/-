"""Deduplicated restoration queue: one visual job per AssetPath, all Land contexts.

Existing successful outputs are preserved. Missing inputs/SEG/large canvases are
reported per job; one failure never hides remaining map jobs. No network access.
"""
import argparse,base64,json,os,subprocess,sys,zlib
from pathlib import Path
from base508 import read_s32,write_s32

def jobs(manifest,requirements):
 members=requirements['all_member_locations'];result=[]
 for group in manifest['asset_groups']:
  prefix='Map/'+group['asset_path'];specs=[s for member,s in members.items() if member.startswith(prefix)]
  reasons=[]
  if not group['land_ids']:reasons.append('UNREFERENCED_RAW_PRESERVE; no fabricated LandID or playable registration')
  if any(not s['member'].endswith('.s32') for s in specs):reasons.append('SEG_RENDERER_NOT_IMPLEMENTED')
  if any(s['local']['state']!='LOCAL_CRC_VERIFIED' for s in specs):reasons.append('MISSING_GEOMETRY')
  tile_ids=set()
  if not reasons:
   for spec in specs:
    data=Path(spec['local']['valid_paths'][0]).read_bytes()
    if len(data)!=spec['bytes'] or f'{zlib.crc32(data):08x}'!=spec['crc32']:raise ValueError('Source changed after manifest: '+spec['member'])
    row=read_s32(data,spec['member'])
    if write_s32(row)!=data:raise ValueError('S32 roundtrip mismatch')
    tile_ids.update(p[0] for p in row['tile_pairs'])
   for tid in tile_ids:
    s=members.get('Tile/'+str(tid)+'.ti2')
    if not s or s['local']['state']!='LOCAL_CRC_VERIFIED':reasons.append('MISSING_EXACT_TI2');break
  result.append({'asset_path':group['asset_path'],'shared_art_key':group['shared_art_key'],'land_ids':group['land_ids'],'representative_land':group['land_ids'][0] if group['land_ids'] else None,'ready':not reasons,'blockers':reasons,'exact_tile_ids':sorted(tile_ids),'visual_status':group['visual']['status'],'visual_checkpoint':group['visual'],'runtime_collision':'UNKNOWN_UNLESS_SEPARATE_REGISTERED_LEGACY_ADAPTER'})
 return result

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for key in ['manifest','requirements','out']:p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--execute',action='store_true');p.add_argument('--max-maps',type=int,default=1)
 for key in ['analysis','structure','tables']:p.add_argument('--'+key,type=Path)
 a=p.parse_args();manifest=json.loads(a.manifest.read_text());req=json.loads(a.requirements.read_text());queue=jobs(manifest,req);a.out.mkdir(parents=True,exist_ok=True)
 (a.out/'jobs.json').write_text(json.dumps(queue,ensure_ascii=False,indent=2)+'\n')
 if a.execute:
  if not all([a.analysis,a.structure,a.tables]):p.error('Execution requires analysis, structure and tables')
  source=a.out/'shared-source';source.mkdir(exist_ok=True)
  for spec in req['all_member_locations'].values():
   if spec['local']['state']!='LOCAL_CRC_VERIFIED':continue
   origin=Path(spec['local']['valid_paths'][0]);target=source/spec['member'];target.parent.mkdir(parents=True,exist_ok=True)
   if not target.exists():os.link(origin,target)
  count=0
  for job in queue:
   if not job['ready']:continue
   target=a.out/'assets'/job['shared_art_key']
   if target.exists() or target.is_symlink():job['execution']='EXISTING_OUTPUT_PRESERVED';continue
   if job['visual_status']=='S32_TI2_RENDERABLE' and Path(job['visual_checkpoint'].get('pack_root','')).is_dir():
    target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to(Path(job['visual_checkpoint']['pack_root']).resolve(),target_is_directory=True);job['execution']='REUSED_RENDERED_ART_CHECKPOINT; NO_DUPLICATE_COMPOSITION';continue
   if count>=a.max_maps:break
   count+=1
   command=[sys.executable,str(Path(__file__).with_name('build_base508_pack.py')),'--analysis',str(a.analysis),'--structure',str(a.structure),'--tables',str(a.tables),'--source',str(source),'--land',str(job['representative_land']),'--out',str(target),'--compose-tiles','--tile-cache',str(a.out/'shared-tile-cache.sqlite')]
   target.parent.mkdir(parents=True,exist_ok=True)
   with (a.out/(job['shared_art_key']+'.log')).open('w') as log:status=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT).returncode
   job['execution']='BUILT_NOT_GPU_VERIFIED' if status==0 else 'FAILED_OUTPUT_PRESERVED_FOR_REVIEW'
   if status==0:
    contexts=[row for row in manifest['land_contexts'] if row['land']['ID'] in job['land_ids']]
    (a.out/(job['shared_art_key']+'-land-contexts.json')).write_text(json.dumps(contexts,ensure_ascii=False,indent=2)+'\n')
  (a.out/'jobs.json').write_text(json.dumps(queue,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'asset_jobs':len(queue),'ready_jobs':sum(j['ready'] for j in queue),'shared_source_members':req['already_present_members'],'network_requests':0}))
