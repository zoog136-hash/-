"""Compare bounded geometry with original RGBA parser on supplied source files."""
import argparse,gzip,json,zipfile,brotli
from pathlib import Path
from base508_sp2_packet import normalize,geometry
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--requests',type=Path,required=True);p.add_argument('--packages',type=Path,required=True);p.add_argument('--samples',type=int,default=40);a=p.parse_args()
files=json.load(gzip.open(a.requests))['files'];checked=0;frames=0
for r in sorted(files,key=lambda x:x['size']):
 if 'available_library_package'not in r:continue
 package=a.packages/r['available_library_package']['file_name']
 if not package.exists():continue
 with zipfile.ZipFile(package)as z:
  names=[n for n in z.namelist()if Path(n).name==Path(r['name']).name]
  if len(names)!=1:continue
  raw=z.read(names[0])
 try:left,original=normalize(raw);right,bounded=normalize(raw,geometry_only=True)
 except(ValueError,IndexError):continue
 assert left==right,(r['name'],'packet changed')
 mask=original[1];directions=[i for i in range(8)if mask&(1<<i)]
 for bit,(fs,_)in zip(directions,original[2]):
  for index in set((0,len(fs)-1)):
   if index<0:continue
   assert geometry(original,bit,index,{})==geometry(bounded,bit,index,{}),(r['name'],bit,index)
   frames+=1
 for malformed in (raw[:-1],raw+b"\0"):
  try:normalize(malformed,geometry_only=True)
  except (ValueError,IndexError,brotli.error):pass
  else:raise AssertionError((r["name"],"malformed payload accepted"))
 checked+=1
 if checked==a.samples:break
assert checked==a.samples
print(json.dumps({'original_files':checked,'frame_geometry_comparisons':frames,'normalized_packet_bytes_identical':True,'malformed_payloads_rejected':checked*2}))
