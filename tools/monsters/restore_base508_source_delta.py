"""Rebuild a full offline monster installer from its preserved baseline + delta.
No original files are changed. All archive bytes/rows are verified before use.
"""
import argparse,hashlib,json,zipfile
from pathlib import Path
from merge_base508_source_packs import run as merge
from package_base508_monster_install import build as package

def sha(path):
 h=hashlib.sha256()
 with path.open('rb')as f:
  for b in iter(lambda:f.read(4*1024**2),b''):h.update(b)
 return h.hexdigest()
def unpack(path,output):
 output.mkdir(parents=True,exist_ok=False)
 with zipfile.ZipFile(path)as z:
  header=json.loads(z.read('pack.json'));assert header['kind']=='twilight-lineagem-offline-monsters'and header['source_snapshot']=='base508';seen=set();total=0
  for chunk in header['chunks']:
   inventory=z.read(chunk['path']);payload=z.read(chunk['payload']);assert hashlib.sha256(inventory).hexdigest()==chunk['sha256']and hashlib.sha256(payload).hexdigest()==chunk['payload_sha256']
   rows=json.loads(inventory);assert len(rows)==chunk['count']
   for row in rows:
    name=row['path'];assert not name.startswith('/')and'..'not in name.split('/')and':'not in name and'\\'not in name and name not in seen
    seen.add(name);data=payload[row['offset']:row['offset']+row['bytes']];assert len(data)==row['bytes']and hashlib.sha256(data).hexdigest()==row['sha256'];p=output/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data);total+=len(data)
  assert len(seen)==header['files']and total==header['bytes']
def main(a):
 root=Path(__file__).resolve().parent.parent;receipt=json.loads((root/'RESTORE.json').read_text());work=a.work.resolve();work.mkdir(parents=True,exist_ok=False)
 if a.output.exists():raise ValueError('Output already exists; preserve it or choose a new path')
 if a.base_root:
  base=a.base_root.resolve();assert sha(base/'manifest.json')==receipt['base_manifest_sha256']
 else:
  assert a.base_install_zip.stat().st_size==receipt['base_install_zip_bytes']and sha(a.base_install_zip)==receipt['base_install_zip_sha256'];base=work/'baseline';unpack(a.base_install_zip,base);assert sha(base/'manifest.json')==receipt['base_manifest_sha256']
 combined=work/'combined';merge(base,root/'delta',combined);m=json.loads((combined/'manifest.json').read_text());assert len(m['records'])==receipt['expected_npc_classes']and len(m['models'])==receipt['expected_source_models'];package(combined,a.output,receipt['release_id'])
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);g=p.add_mutually_exclusive_group(required=True);g.add_argument('--base-root',type=Path);g.add_argument('--base-install-zip',type=Path);p.add_argument('--work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);main(p.parse_args())
