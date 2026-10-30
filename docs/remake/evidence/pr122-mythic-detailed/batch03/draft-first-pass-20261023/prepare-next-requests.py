from pathlib import Path
import json,hashlib
R=Path('/workspace/twilight');T=Path(__file__).parent;q=json.loads((R/'docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json').read_text());template=json.loads((T/'request-411.json').read_text());next_two=[]
for a in q[3:]:
 id=a['id'].split(':')[1];p=T/f'request-{id}.json';dest=R/f'docs/remake/evidence/pr122-mythic-detailed/batch03/transform_{id}-S-attack-draft-v01.json'
 if dest.exists():continue
 if not p.exists():
  d={k:a[k] for k in ['name','grade','reference']};d['key']=a['id'];d['reference_sha256']=hashlib.sha256((R/a['reference'].removeprefix('res://')).read_bytes()).hexdigest();d['policy']=template['policy'];g=dict(template['generation_request']);g['prompt']=g['prompt'].replace('transform:411, 신화-투사(여)',a['id']+', '+a['name']);g['referenced_image_paths']=[str(R/a['reference'].removeprefix('res://'))];d['generation_request']=g;p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 next_two.append(dict(key=a['id'],request=str(p),name=a['name']))
 if len(next_two)==2:break
print(json.dumps(next_two,ensure_ascii=False))
