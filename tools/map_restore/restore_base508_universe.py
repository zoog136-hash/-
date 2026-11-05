"""Resume private all-asset composition; isolate failures, never synthesize missing art."""
import argparse,json,subprocess,sys,time
from concurrent.futures import ThreadPoolExecutor,wait,FIRST_COMPLETED
from pathlib import Path
from batch_base508_maps import jobs

def save(path,value):
 temporary=path.with_suffix('.tmp');temporary.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n');temporary.replace(path)

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('manifest','requirements','source','analysis','structure','tables','out'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
 state_path=a.out/'universe-progress.json'
 state=json.loads(state_path.read_text()) if state_path.exists() else {'assets':{},'terrain_collision':'UNKNOWN','runtime_activation':'NO_AUTOMATIC_REGISTRATION','network_requests':0}
 manifest=json.loads(a.manifest.read_text());queue=jobs(manifest,json.loads(a.requirements.read_text()),include_unreferenced=True,exact=False)
 save(a.out/'universe-jobs.json',queue)
 def execute(job):
  key=job['shared_art_key'];target=a.out/'assets'/key;target.parent.mkdir(exist_ok=True)
  row={'asset_path':job['asset_path'],'land_ids':job['land_ids'],'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'pack_root':str(target)}
  if not job['ready']:return dict(row,status='BLOCKED',reason=job['blockers'])
  checkpoint=Path(job['visual_checkpoint'].get('pack_root','/nonexistent'))
  if not target.exists() and checkpoint.is_dir() and job['visual_status']=='S32_TI2_RENDERABLE':target.symlink_to(checkpoint.resolve(),target_is_directory=True)
  reused=target.is_symlink()
  if not target.exists():
   cmd=[sys.executable,str(Path(__file__).with_name('build_base508_pack.py'))]
   for name in ('analysis','structure','tables','source'):cmd+=['--'+name,str(getattr(a,name))]
   cmd+=['--land',str(job['representative_land'])] if job['land_ids'] else ['--asset',job['asset_path']]
   cmd+=['--out',str(target),'--compose-tiles','--stream-tiles','--tile-cache',str(a.out/'shared-tile-cache.sqlite')]
   with (a.out/(key+'.log')).open('w') as log:result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT)
   if result.returncode:return dict(row,status='FAILED',reason=(a.out/(key+'.log')).read_text()[-5000:])
  try:
   from verify_base508_pack import verify
   verification=verify(target,None);row['verification']=verification
   row['status']='REUSED_VERIFIED_VISUAL' if reused else ('VERIFIED_VISUAL' if verification['art_chunks'] else 'VERIFIED_EMPTY')
  except Exception as error:row.update(status='FAILED',reason=repr(error))
  return row
 terminal=('VERIFIED_VISUAL','VERIFIED_EMPTY','REUSED_VERIFIED_VISUAL','FAILED','BLOCKED')
 def retry_storage_check(job):
  old=state['assets'].get(job['shared_art_key'],{})
  return old.get('status')=='FAILED' and old.get('reason')=="ValueError('Raster chunk PNG mode/extent')"
 pending=iter(j for j in sorted(queue,key=lambda j:j['source_bytes_estimate']) if state['assets'].get(j['shared_art_key'],{}).get('status') not in terminal or retry_storage_check(j))
 def checkpoint():
  state['counts']={status:sum(r.get('status')==status for r in state['assets'].values()) for status in sorted({r.get('status','UNKNOWN') for r in state['assets'].values()})};state['total_asset_jobs']=len(queue);save(state_path,state)
 with ThreadPoolExecutor(max_workers=3) as pool:
  active={}
  def submit():
   job=next(pending,None)
   if job is None:return
   state['assets'][job['shared_art_key']]={'status':'BUILDING','land_ids':job['land_ids'],'asset_path':job['asset_path']};checkpoint();active[pool.submit(execute,job)]=job
  for _ in range(3):submit()
  while active:
   done,_=wait(active,return_when=FIRST_COMPLETED)
   for future in done:
    job=active.pop(future);key=job['shared_art_key']
    try:row=future.result()
    except Exception as error:row={'status':'FAILED','reason':repr(error),'asset_path':job['asset_path'],'land_ids':job['land_ids']}
    state['assets'][key]=row;checkpoint();print(json.dumps({'asset':key,'status':row['status'],'counts':state['counts'],'total':len(queue)}),flush=True);submit()
if __name__=='__main__':main()
