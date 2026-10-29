#!/usr/bin/env python3
"""Install only byte-identical archive candidates; never infer a 3.80 baseline.
The immutable map84 art/review index stays unchanged. Runtime promotion is a
separate map-by-map policy, not an installer side effect.
"""
import argparse,gzip,hashlib,json,os,tempfile,zipfile
from pathlib import Path
from source_map_pack import LINKAGE_SHA,digest,encoded,require
AUDIT_SHA='4c0e3e9be4ea0e37805942679cc4c80783ae888cce7c79f443202be11c1b4cb3'
EXPECTED={42,58,64,65,67,69,70,75,76,101,102,103,104,105,107,108,109,110,200,440,490,491,492,493,494,496,522,523,524,602,603,608,780,781,782}
def verified_rows(linkage,audit):
 require(digest(linkage)==LINKAGE_SHA,'Unknown linkage ZIP')
 require(digest(audit)==AUDIT_SHA,'Unknown archive equality audit')
 proof=json.loads(Path(audit).read_text())
 rows=[r for r in proof['numeric'] if r['category']=='multiple_candidates_byte_identical']
 require({r['map_id'] for r in rows}==EXPECTED,'Wrong identical set')
 result={}
 with zipfile.ZipFile(linkage) as z:
  for row in rows:
   require(row['raw_byte_equality_verified'] is True and len(row['candidates'])>=2,'No cross-archive proof')
   samples=[]
   for c in row['candidates']:
    name=c['grid_path'].split('map_source3_links/',1)[1]
    packed=z.read('map_source3_links/'+name);raw=gzip.decompress(packed)
    require(hashlib.sha256(packed).hexdigest()==c['grid_sha256'] and hashlib.sha256(raw).hexdigest()==c['raw_u8_sha256'],'Candidate bytes changed')
    require(len(raw)==c['width']*c['height'],'Bad grid dimensions')
    samples.append((c,packed,raw))
   require(all(s[2]==samples[0][2] and s[0]['world_bounds_candidate']==samples[0][0]['world_bounds_candidate'] for s in samples),'Not byte-identical in the same frame')
   representative=next(s for s in samples if s[0]['archive_version_label']=='351')
   c,packed,raw=representative
   result[str(row['map_id'])]=({'file':'grids/'+str(row['map_id'])+'.u8.gz','sha256':c['grid_sha256'],'raw_sha256':c['raw_u8_sha256'],'width':c['width'],'height':c['height'],'bounds':c['world_bounds_candidate'],'archive_version_label':'351','basis':'byte-identical archive representative; not authenticated 3.80 and not current-main A3 equality','equivalent_archive_labels':[s[0]['archive_version_label'] for s in samples]},packed)
 return result
def install(linkage,audit,output,receipt):
 rows=verified_rows(linkage,audit);out=Path(output)
 require(not out.exists(),'Refuse to overwrite an existing install')
 out.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(dir=out.parent) as tmp:
  stage=Path(tmp)/'install';(stage/'grids').mkdir(parents=True)
  index={'schema':1,'linkage_sha256':LINKAGE_SHA,'audit_sha256':AUDIT_SHA,'maps':{}}
  for sid,(spec,packed) in rows.items():(stage/spec['file']).write_bytes(packed);index['maps'][sid]=spec
  payload=encoded(index);(stage/'index.json').write_bytes(payload)
  os.replace(stage,out)
 proof={'schema':1,'library_file_id':'libfile_5f66f03ee4a48191821a467f880f72b3','library_version':0,'audit_sha256':AUDIT_SHA,'index_sha256':hashlib.sha256(payload).hexdigest(),'maps':35,'basis':'351 representative of identical archive raw bytes; no 3.80 or main-A3 equivalence asserted'}
 Path(receipt).write_bytes(encoded(proof));return proof
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--linkage-zip',required=True);p.add_argument('--audit',required=True);p.add_argument('--output',required=True);p.add_argument('--receipt',required=True);a=p.parse_args();print(json.dumps(install(a.linkage_zip,a.audit,a.output,a.receipt)))
