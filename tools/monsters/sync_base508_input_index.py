"""Persist distinct receive/verify/compile/connect states; never download a duplicate.
The caller materializes only missing exact references via supported app tools.
"""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path

def digest(path):
 h=hashlib.sha256()
 with path.open('rb')as f:
  for b in iter(lambda:f.read(4*1024**2),b''):h.update(b)
 return h.hexdigest()
def save(path,value):
 temp=path.with_name(path.name+'.tmp');temp.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n');temp.replace(path)
def main(a):
 idx=json.loads(a.index.read_text());assert idx['source_version']=='base508'and idx['source_request_SHA256']=='9d5bba1c5a652a01f8eedd360054dd63517dc38e1f09e4cdd8d2e497c722ee52'
 state=json.loads(a.state.read_text());rows={r['batch']:r for r in state['batches']};missing=[];candidate=set()
 compiled=json.loads(a.compiled_manifest.read_text())if a.compiled_manifest else{'models':{},'records':{},'model_failures':{}}
 runtime=json.loads(a.runtime_verified_manifest.read_text())if a.runtime_verified_manifest else{'models':{},'records':{}}
 for e in idx['files']:
  n=e['batch_number'];r=rows.setdefault(n,{'batch':n,'registered':False});assert e['version']==0
  for key,value in [('library_file_id',e['library_file_id']),('file_id',e['file_id']),('file_name',e['file_name']),('expected_bytes',e['bytes']),('expected_sha256',e['sha256'])]:
   if r.get(key)is not None:assert r[key]==value,('Immutable input changed',n,key)
   r[key]=value
  path=a.packages/e['file_name'];r['received']=path.is_file()
  if not path.is_file():missing.append({'library_file_id':e['library_file_id'],'file_id':e['file_id'],'file_name':e['file_name']});r['verified']=False;continue
  receipt=a.receipts/f'monster-batch{n:03d}-registration.json'
  prior=json.loads(receipt.read_text())if receipt.exists()and r.get('registered')else{}
  reusable=prior.get('verified_package',{}).get('sha256')==e['sha256']and prior.get('verified_package',{}).get('bytes')==e['bytes']
  assert path.stat().st_size==e['bytes'],('Outer size mismatch',n)
  if not reusable:assert digest(path)==e['sha256'],('Outer checksum mismatch',n)
  r['outer_sha256_verified']=True;r['verification_method']='reuse_immutable_v0_source_registration_receipt'if reusable else'fresh_outer_SHA_and_source_inventory_verification'
  if a.register and not r.get('registered'):
   subprocess.run([sys.executable,str(Path(__file__).with_name('register_base508_source_batch.py')),'--batch',str(path),'--data',str(a.data),'--receipt',str(receipt),'--library-file-id',e['library_file_id'],'--expected-bytes',str(e['bytes']),'--expected-sha256',e['sha256']],check=True,stdout=subprocess.DEVNULL);r['registered']=True
  if receipt.exists()and r.get('registered'):
   record=json.loads(receipt.read_text());r['verified']=True;r['verified_sp2_files']=record['verified_sp2_files'];r['verified_sp2_bytes']=record['verified_sp2_bytes'];ids={m['source_model_id']for m in record['requested_set_candidates']};candidate.update(ids)
   r['source_model_candidate_ids']=sorted(ids);r['compiled_model_ids']=sorted(i for i in ids if str(i)in compiled['models']);r['failed_model_ids']=sorted(i for i in ids if str(i)in compiled.get('model_failures',{}));r['emitted_source_npc_ids']=sorted(int(npc)for npc,value in compiled['records'].items()if int(value['sprite_id'])in ids);r['runtime_verified_model_ids']=sorted(i for i in ids if str(i)in runtime['models']);r['runtime_connected_source_npc_ids']=sorted(int(npc)for npc,value in runtime['records'].items()if int(value['sprite_id'])in ids)
  else:r['verified']=False
 state['batches']=[rows[n]for n in sorted(rows)];state['last_consumed_index']={'version':idx['index_Library_version_expected_after_save'],'sha256':digest(a.index),'confirmed_batches':idx['confirmed_batches']};save(a.state,state)
 todo=sorted(i for i in candidate if str(i)not in compiled['models']and str(i)not in compiled.get('model_failures',{}));result={'missing_materializations':missing,'registered_batches':sum(r.get('registered',False)for r in rows.values()),'verified_source_files':sum(r.get('verified_sp2_files',0)for r in rows.values()if r.get('verified')),'compiled_source_models':len(compiled['models']),'emitted_source_classes':len(compiled['records']),'runtime_connected_source_classes':len(runtime['records']),'next_unique_candidate_ids':todo};save(a.plan,result);print(json.dumps({k:(len(v)if isinstance(v,list)else v)for k,v in result.items()}))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in('index','state','packages','receipts','data','plan'):p.add_argument('--'+n,type=Path,required=True)
 p.add_argument('--compiled-manifest',type=Path);p.add_argument('--runtime-verified-manifest',type=Path);p.add_argument('--register',action='store_true');main(p.parse_args())
