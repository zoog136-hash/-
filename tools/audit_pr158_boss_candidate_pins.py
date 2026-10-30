"""Whole unpublished boss selection integrity, preserving source and quality holds."""
import hashlib,json
from pathlib import Path
from PIL import Image

def audit(root):
    register=json.loads((root/'data/pr122_monster_boss_repair_staging.json').read_text());rows=[];pins={};errors=[]
    for key,a in register['actors'].items():
        if a.get('kind')!='boss' or a.get('production_connected'):continue
        for field in ['frames','native_profile']:
            path=root/a[field].removeprefix('res://');digest=hashlib.sha256(path.read_bytes()).hexdigest();pins[a[field]]=digest
            if digest!=a[field+'_sha256']:errors.append({'key':key,'error':'RESOURCE_PIN','path':str(path)})
        for t in a['tracks']:
            path=root/t['texture'];raw=path.read_bytes();sha=hashlib.sha256(raw).hexdigest();pins[t['texture']]=sha
            proof=t.get('lossless_source_ownership_proof');expected=t['source_sha256']
            if proof:
                pr=root/proof;proof_data=json.loads(pr.read_text());pins[proof]=hashlib.sha256(pr.read_bytes()).hexdigest();expected=proof_data['texture_sha256']
                if proof_data['source_sha256']!=t['source_sha256']:errors.append({'key':key,'clip':t['animation'],'error':'PROOF_SOURCE_PIN'})
            failures=[]
            if sha!=expected:failures.append('TEXTURE_PIN')
            with Image.open(path) as source:
                rgba=source.convert('RGBA');n=0
                for frame in t['geometry']['frames']:
                    x,y,w,h=frame['region']
                    if min(x,y)<0 or min(w,h)<=0 or x+w>rgba.width or y+h>rgba.height:failures.append('REGION_BOUNDS');continue
                    crop=rgba.crop((x,y,x+w,y+h))
                    if hashlib.sha256(crop.tobytes()).hexdigest()!=frame['rgba_sha256']:failures.append('SELECTED_RGBA_PIN')
                    if crop.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox() is None:failures.append('EMPTY_ALPHA')
                    n+=1
            row={'key':key,'clip':t['animation'],'texture':t['texture'],'poses':n,'required_quality_poses':6,'quality_pose_gate_pass':n>=6,'reviewed_frame_adjustment':t.get('reviewed_frame_adjustment'),'technical_errors':failures,'final_approved':False};rows.append(row)
            for failure in failures:errors.append({'key':key,'clip':t['animation'],'error':failure})
    return {'actors':13,'selected_clips':len(rows),'required_clips':429,'missing_or_held_requests':429-len(rows),'source_pins':pins,'technical_errors':errors,'quality_pose_holds':[{'key':r['key'],'clip':r['clip'],'poses':r['poses']} for r in rows if not r['quality_pose_gate_pass']],'rows':rows,'new_quality_approvals':0}
if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=audit(a.root);a.output.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print('clips',r['selected_clips'],'technical_errors',len(r['technical_errors']),'quality_holds',r['quality_pose_holds']);raise SystemExit(bool(r['technical_errors']))
