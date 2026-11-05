"""Compare original visual geometry without treating its pixels as passability proof."""
import json,hashlib,base64,collections,argparse
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--assets',type=Path,required=True);parser.add_argument('--inventory',type=Path,required=True);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
root=args.assets;inventory=json.loads(args.inventory.read_text());groups={};matches=[]
for row in inventory:
 if row['values'] not in [[0,1],[4,5],[0,1,65],[4,5,69]]:continue
 for p in (root/('base508_asset_'+row['asset'])/'geometry').glob('*.json'):
  d=json.loads(p.read_text());raw=base64.b64decode(d['attribute_u16le']);key=hashlib.sha256(json.dumps([d['origin'],d['floor_u32le'],d['covers'],d['objects'],d['opacity_raw']],sort_keys=True).encode()).hexdigest()
  if key in groups:
   old,prior=groups[key]
   if raw!=prior:
    differences=collections.Counter(a^b for a,b in zip(raw,prior));matches.append({'left':old,'right':str(p),'xor_bytes':dict(differences),'identical_original_visual_geometry':True})
  else:groups[key]=(str(p),raw)
args.out.write_text(json.dumps(matches,indent=2));print('matching original geometry with different attributes',len(matches))
