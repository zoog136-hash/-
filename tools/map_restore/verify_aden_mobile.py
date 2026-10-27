"""Validate every shipped mobile art payload and its export/receipt contract."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
def verify():
 base=ROOT/'assets/maps/aden_world_mobile';manifest=base/'manifest.json'
 m=json.loads(manifest.read_text());receipt=json.loads((ROOT/'data/maps/aden_mobile_pack.json').read_text())
 assert hashlib.sha256(manifest.read_bytes()).hexdigest()==receipt['manifest_sha256']
 total=0
 for row in m['ground']+list(m['assets'].values())+[m['overview']]:
  p=base/row['file'];assert p.is_relative_to(base) and p.name.endswith('.webp.bin')
  assert p.stat().st_size==row['bytes'] and hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256'],p
  with Image.open(p) as im:assert list(im.size)==row['size'];im.verify()
  assert max(row['size'])<=2048
  total+=row['bytes']
 assert total==m['encoded_asset_bytes']==receipt['encoded_asset_bytes']
 assert not receipt['navigation_changed'] and not m['navigation_modified']
 for r in m['placements']:assert r['asset'] in m['assets']
 assert 'assets/maps/aden_world_mobile/manifest.json -text' in (ROOT/'.gitattributes').read_text()
 assert '*.bin' in (ROOT/'export_presets.cfg').read_text()
 print(json.dumps({'payload_count':len(m['ground'])+len(m['assets'])+1,'encoded_bytes':total,'ground_chunks':len(m['ground']),'placements':len(m['placements']),'sha_and_dimensions':'PASS'}))
if __name__=='__main__':verify()
