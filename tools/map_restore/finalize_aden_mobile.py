from pathlib import Path
import json,hashlib
from PIL import Image
from build_aden_mobile import raw_blocker_sprite,save_webp,OUT,ROOT,REVIEW
m=json.loads((OUT/'manifest.json').read_text());audit=json.loads(Path('/workspace/aden-mobile-evidence/feet.json').read_text());bad={r['id'] for r in audit['risks']};bad.update(f'landmark_surround_3_{i}' for i in range(4))
excluded=[{'id':r['id'],'reason':'foot contact intersects preserved walkable route' if r['id'] in {x['id'] for x in audit['risks']} else 'unsupported rock cluster in source castle courtyard'} for r in m['placements'] if r['id'] in bad]
m['placements']=[r for r in m['placements'] if r['id'] not in bad]
spec=json.loads((ROOT/'data/maps/aden_faith_png_plan.json').read_text())['maps']['aden_world'];byid={r['id']:r for r in m['placements']}
for c in spec['collision']:
 if c['id']=='palace_plaza_fountain':continue
 r=byid['existing_'+c['id']];name='oak' if 'tree' in c['id'] or 'stump' in c['id'] else ('basalt' if 'lava' in c['id'] or 'basalt' in c['id'] else ('hut' if 'hut' in c['id'] else 'cliff'));pts=c.get('points')
 if pts:name='ruin_fort' if 'ruin' in c['id'] else name
 im=raw_blocker_sprite(name);target=min(im.width,round((max(p[0] for p in pts)-min(p[0] for p in pts))*6) if pts else round(c['radius']*12));target=max(60,target);im=im.resize((target,round(im.height*target/im.width)),Image.Resampling.LANCZOS)
 m['assets'][r['asset']]=save_webp(im,OUT/'objects'/(r['asset']+'.webp.bin'),True);r['size']=list(im.size);r['position']=[r['foot'][0]-im.width//2,r['foot'][1]-round(im.height*.85)]
m['status']='READY_WITH_EXISTING_NAVIGATION';m['review_exclusions']=excluded;m['foot_contact_audit']={'samples':audit['contact_samples'],'risks_excluded':len(audit['risks']),'original_navigation_unchanged':True};m['encoded_asset_bytes']=sum(r['bytes'] for r in m['ground'])+sum(r['bytes'] for r in m['assets'].values())+m['overview']['bytes']
(OUT/'manifest.json').write_text(json.dumps(m,separators=(',',':'))+'\n');(REVIEW/'exclusions.json').write_text(json.dumps(excluded,indent=2)+'\n')
receipt={'schema':1,'map_id':'aden_world','manifest_sha256':hashlib.sha256((OUT/'manifest.json').read_bytes()).hexdigest(),'encoded_asset_bytes':m['encoded_asset_bytes'],'navigation_changed':False}
(ROOT/'data/maps/aden_mobile_pack.json').write_text(json.dumps(receipt,indent=2)+'\n');print(receipt,'placements',len(m['placements']))
