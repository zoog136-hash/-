"""Create synthetic installer safety fixtures, never original-art evidence."""
import json,hashlib,zipfile,sys
from pathlib import Path
root=Path(sys.argv[1]); root.mkdir(parents=True,exist_ok=True)
enc=lambda x:json.dumps(x,separators=(',',':')).encode()
sha=lambda x:hashlib.sha256(x).hexdigest()
for kind in ['valid','corrupt','traversal','missing','duplicate']:
 manifest={'schema':1,'source_snapshot':'base508','records':{'sprite:'+str(i):{'manifest':'actors/test.json'} for i in range(743)}}
 manifest['card_bindings']={str(i):{} for i in range(701)}
 files={'zero-byte-source.dat':b'', 'manifest.json':enc(manifest),'actors/test.json':enc({'fixture':True}), 'source_effect_bindings.json':b'{}','registered_effect_layers.json':b'{}'}
 if kind=='missing':files.pop('registered_effect_layers.json')
 if kind=='traversal':files['../save.dat']=b'unsafe'
 payload=bytearray();rows=[]
 for name,data in files.items():
  rows.append({'path':name,'offset':len(payload),'bytes':len(data),'sha256':sha(data)});payload.extend(data)
 if kind=='duplicate': rows.append(rows[-1])
 data=enc(rows)
 header={'schema':2,'kind':'twilight-lineagem-offline-runtime','source_snapshot':'base508','files':len(rows),'bytes':len(payload),'sprite_records':743,'card_definitions':701,'release_id':'TEST_FIXTURE_ONLY','chunks':[{'path':'inventory/0000.json','bytes':len(data),'sha256':sha(data),'count':len(rows),'payload':'payload/0000.bin','payload_bytes':len(payload),'payload_sha256':sha(payload)}]}
 if kind=='corrupt':payload[-1]^=1
 with zipfile.ZipFile(root/(kind+'.zip'),'w',compression=zipfile.ZIP_DEFLATED) as z:
  z.writestr('pack.json',enc(header));z.writestr('inventory/0000.json',data);z.writestr('payload/0000.bin',payload)

# Addons keep existing base files, replacing only verified small resources.
# Reconstruct the valid baseline definition exactly as the valid fixture above.
base_definition={'schema':1,'source_snapshot':'base508','records':{'sprite:'+str(i):{'manifest':'actors/test.json'} for i in range(743)},'card_bindings':{str(i):{} for i in range(701)}}
for kind in ['addon','addon_wrong_base']:
 definition=json.loads(json.dumps(base_definition));definition['records']['overlay:1']={'manifest':'overlays/new.json'}
 entries={'manifest.json':enc(definition),'source_effect_bindings.json':b'{}','registered_effect_layers.json':b'{}','overlays/new.json':b'{"new":true}'}
 payload=bytearray();rows=[]
 for name,data in entries.items():
  rows.append({'path':name,'offset':len(payload),'bytes':len(data),'sha256':sha(data)});payload.extend(data)
 data=enc(rows)
 header={'schema':2,'kind':'twilight-lineagem-offline-runtime-addon','source_snapshot':'base508','files':len(rows),'bytes':len(payload),'sprite_records':743,'card_definitions':701,'release_id':'TEST_ADDON_ONLY','base_manifest_sha256':sha(enc(base_definition)) if kind=='addon' else '0'*64,'chunks':[{'path':'inventory/0000.json','bytes':len(data),'sha256':sha(data),'count':len(rows),'payload':'payload/0000.bin','payload_bytes':len(payload),'payload_sha256':sha(payload)}]}
 with zipfile.ZipFile(root/(kind+'.zip'),'w',compression=zipfile.ZIP_DEFLATED) as z:
  z.writestr('pack.json',enc(header));z.writestr('inventory/0000.json',data);z.writestr('payload/0000.bin',payload)
