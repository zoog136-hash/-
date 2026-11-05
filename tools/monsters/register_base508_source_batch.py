"""Verify an exact extracted source batch and register its package provenance."""
import argparse,collections,gzip,hashlib,json,zipfile,zlib
from pathlib import Path
from build_base508_authoritative_catalog import write_gz

def run(a):
 raw=a.batch.read_bytes();assert len(raw)==a.expected_bytes and hashlib.sha256(raw).hexdigest()==a.expected_sha256
 root=a.data;requests=json.load(gzip.open(root/'all_source_npc_pixel_requests.json.gz'));catalog=json.load(gzip.open(root/'authoritative_catalog.bin'));known={r['name']:r for r in requests['files']}
 with zipfile.ZipFile(a.batch)as z:
  manifest=json.loads(z.read('input_manifest.json'));assert manifest['source']['snapshot']=='base508';assets=manifest['assets'];assert len(assets)==manifest['original_SP2_files'];total=0
  for asset in assets:
   name=asset['name'];data=z.read(name);entry=known[name];assert len(data)==asset['bytes']==entry['size'];assert f'{zlib.crc32(data)&0xffffffff:08x}'==asset['crc32']==entry['crc32'];assert hashlib.sha256(data).hexdigest()==asset['sha256'];assert asset['archive']==entry['archive'];total+=len(data)
  assert total==manifest['original_SP2_bytes']
 package={'library_file_id':a.library_file_id,'file_name':a.batch.name,'bytes':len(raw),'sha256':a.expected_sha256}
 for asset in assets:
  entry=known[asset['name']]
  if 'available_library_package'in entry and entry['available_library_package']!=package:raise ValueError(('Batch conflicts with previously available source provenance',asset['name']))
  entry['available_library_package']=package;entry['verified_original_sha256']=asset['sha256']
 missing=[r for r in requests['files']if 'available_library_package'not in r];monster=[r for r in missing if r['needed_for_monster_scope']];archives=collections.defaultdict(lambda:{'files':0,'bytes':0})
 for r in monster:archives[r['archive']]['files']+=1;archives[r['archive']]['bytes']+=r['size']
 counts=requests['counts'];counts.update({'files_in_existing_library_packages':len(requests['files'])-len(missing),'missing_original_files_all_npc_scope':len(missing),'missing_original_bytes_all_npc_scope':sum(r['size']for r in missing),'missing_original_files_monster_scope':len(monster),'missing_original_bytes_monster_scope':sum(r['size']for r in monster),'monster_scope_source_dat_archives':len(archives)})
 requests.update({'missing':missing,'monster_scope_missing':monster,'monster_scope_archives':dict(sorted(archives.items()))});
 if package not in requests.setdefault('verified_additional_packages',[]):requests['verified_additional_packages'].append(package)
 catalog['counts']=counts.copy();write_gz(root/'all_source_npc_pixel_requests.json.gz',requests);write_gz(root/'authoritative_catalog.bin',catalog);(root/'all_source_npc_counts.json').write_text(json.dumps(counts,ensure_ascii=False,indent=2)+'\n');(root/'monster_missing_members.csv').write_text('archive,name,bytes,crc32\n'+''.join(f"{r['archive']},{r['name']},{r['size']},{r['crc32']}\n"for r in monster))
 fulfilled=[]
 for sid in manifest['newly_completed_requested_member_set_model_ids']:
  model=catalog['models'][str(sid)];fulfilled.append({'source_model_id':sid,'input_set_complete':all('available_library_package'in known[n]for n in model['original_members']),'missing_standard_roles':model.get('missing_standard_roles',[]),'reference_issues':model.get('reference_issues',[]),'source_npc_ids':model['source_npc_ids'],'compilation_status':'not_yet_tested'})
 receipt={'source_snapshot':'base508','verified_package':package,'verified_sp2_files':len(assets),'verified_sp2_bytes':total,'requested_set_candidates':fulfilled,'remaining_monster_members':len(monster),'remaining_monster_bytes':sum(r['size']for r in monster),'remaining_monster_dat_archives':len(archives)}
 a.receipt.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in receipt.items()if k!='requested_set_candidates'},ensure_ascii=False))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in('batch','data','receipt'):p.add_argument('--'+n,type=Path,required=True)
 p.add_argument('--library-file-id',required=True);p.add_argument('--expected-sha256',required=True);p.add_argument('--expected-bytes',type=int,required=True);run(p.parse_args())
