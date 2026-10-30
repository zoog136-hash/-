"""Batch-check current mythic texture/profile pins and exact authored pose identity."""
import argparse,hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
from import_original_based_motion import _visible_pose_fingerprint

def audit(root):
    register=json.loads((root/'data/pr122_native_locomotion_staging.json').read_text())
    rows=[];pins={};errors=[]
    for key,a in register['actors'].items():
        if a.get('grade')!='신화':continue
        for field in ['frames','native_profile']:
            if field not in a:continue
            p=root/a[field].removeprefix('res://');digest=hashlib.sha256(p.read_bytes()).hexdigest();pins[a[field]]=digest
            if digest!=a[field+'_sha256']:errors.append(dict(id=key,field=field,error='PIN_MISMATCH'))
        for t in a['tracks']:
            if t['role'] not in ['idle','run','attack','hit'] and not(t['role']=='death' and t['direction']=='S'):continue
            p=root/t['texture'];digest=hashlib.sha256(p.read_bytes()).hexdigest();pins[t['texture']]=digest
            failures=[]
            if digest!=t['source_sha256']:failures.append('SOURCE_TEXTURE_PIN_MISMATCH')
            g=t['geometry'];fingerprints=[];bounds=[]
            with Image.open(p) as im:
                rgba=np.asarray(im.convert('RGBA'))
                for f in g['frames']:
                    x,y,w,h=f['region']
                    if min(x,y)<0 or min(w,h)<=0 or x+w>im.width or y+h>im.height:failures.append('REGION_BOUNDS');continue
                    pose=rgba[y:y+h,x:x+w];fingerprints.append(_visible_pose_fingerprint(pose))
                    mask=Image.fromarray(pose[:,:,3]).point(lambda a:255 if a>16 else 0);bounds.append(mask.getbbox())
                    if bounds[-1] is None:failures.append('EMPTY_VISIBLE_POSE')
            if len(set(fingerprints))!=6:failures.append('NOT_SIX_DISTINCT_VISIBLE_POSES')
            row=dict(id=key,clip=t['animation'],texture=t['texture'],source_sha256=digest,poses=len(fingerprints),distinct_visible_poses=len(set(fingerprints)),visible_bounds=bounds,technical_failures=failures,quality_approval=False)
            rows.append(row)
            for e in failures:errors.append(dict(id=key,clip=t['animation'],error=e))
    return dict(scope='All selected mythic clips, excluding unique and retained extra WALK/death directions',clips=len(rows),source_pins=pins,errors=errors,rows=rows,new_quality_approvals=0)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=audit(a.root);a.output.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print('mythic_selected_sources',r['clips'],'errors',len(r['errors']));raise SystemExit(bool(r['errors']))
