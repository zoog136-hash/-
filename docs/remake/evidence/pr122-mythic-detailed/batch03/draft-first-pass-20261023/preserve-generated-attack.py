from pathlib import Path
import json,hashlib,sys,re,subprocess
from PIL import Image
import numpy as np
R=Path('/workspace/twilight');sys.path.insert(0,str(R/'tools'));import import_original_based_motion as importer
request_path=Path(sys.argv[1]);generated=Path(sys.argv[2]);q=json.loads(request_path.read_text());key=q['key'];actor_id=key.split(':')[1]
assert subprocess.check_output(['git','branch','--show-current'],cwd=R,text=True).strip()=='feature/twilight-remaining106-20261016'
assert key not in ['transform:267','transform:393','transform:413'];assert generated.is_file() and not generated.is_symlink()
ref=R/q['reference'].removeprefix('res://');ref_sha=hashlib.sha256(ref.read_bytes()).hexdigest();assert ref_sha==q['reference_sha256']
folder=R/'docs/remake/evidence/pr122-mythic-detailed/batch03';dest=folder/f'transform_{actor_id}-S-attack-draft-v01.png';record=dest.with_suffix('.json');out=R/f'assets/actors/eight_direction/native_locomotion_staging/transform_{actor_id}/draft001/SpriteFrames.tres';assert not dest.exists() and not record.exists() and not out.exists()
raw=generated.read_bytes();im=Image.open(generated).convert('RGBA');assert im.width%3==0 and im.height%2==0;w,h=im.width//3,im.height//2;geometry={'frames':[]};checks=[]
for i in range(6):
 box=[(i%3)*w,(i//3)*h,w,h];a=np.array(im.crop((box[0],box[1],box[0]+w,box[1]+h)));alpha=a[:,:,3];checks.append(dict(index=i,rgba_sha256=hashlib.sha256(a.tobytes()).hexdigest(),visible_pixels=int((alpha>16).sum()),border_alpha_pixels=int((alpha[:2]>16).sum()+(alpha[-2:]>16).sum()+(alpha[:,:2]>16).sum()+(alpha[:,-2:]>16).sum())))
 geometry['frames'].append(dict(region=box,margin=[0,0,0,0]))
assert all(c['visible_pixels']>0 for c in checks);assert len({c['rgba_sha256'] for c in checks})==6
# Reuse the existing compiler and retain only the independently authored S track.
roles=[[] for _ in range(8)];roles[2]=list(range(6));compiled=importer.spriteframes('res://'+str(dest.relative_to(R)),geometry,{'attack':roles});prefix=compiled.split('animations = [',1)[0];entries=re.findall(r'\{"frames": \[[\s\S]*?\], "loop": (?:true|false), "name": &"attack_(\d)", "speed": [^}]*\}',compiled);assert len(entries)==8
match=re.search(r'\{"frames": \[[\s\S]*?\], "loop": false, "name": &"attack_2", "speed": [^}]*\}',compiled[compiled.index('"name": &"attack_1"')+len('"name": &"attack_1"'):]);assert match is not None
# Start at its own frames entry, excluding the preceding empty track remainder.
text=match.group(0);assert text.count('SubResource("pose_')==6
resource=prefix+'animations = [\n'+text+'\n]\nmetadata/twilight_canvas_size = Vector2(256, 256)\nmetadata/twilight_detailed_completed = false\nmetadata/twilight_source_visual_status = "HOLD_NOT_REVIEWED"\n'
out.parent.mkdir(parents=True,exist_ok=False)
with dest.open('xb') as f:f.write(raw)
with out.open('x') as f:f.write(resource)
q.update(status='GENERATED_DRAFT_NOT_REVIEWED',source=str(dest.relative_to(R)),source_sha256=hashlib.sha256(raw).hexdigest(),source_bytes=len(raw),generated_original_path=str(generated),output_spriteframes='res://'+str(out.relative_to(R)),direction='S',role='attack',poses=6,cell_size=[w,h],frame_order=list(range(6)),automatic_checks=checks,geometry_review='NOT_RUN',source_visual_status='HOLD_NOT_REVIEWED',actual_Main_Player='NOT_RUN',final_motion_approvals_added=0,actor_approvals_added=0,production_connected=False,compiler_sha256=hashlib.sha256((R/'tools/import_original_based_motion.py').read_bytes()).hexdigest())
with record.open('x') as f:f.write(json.dumps(q,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'key':key,'poses':6,'source_bytes':len(raw),'resource':q['output_spriteframes'],'clipped_cells':sum(c['border_alpha_pixels']>0 for c in checks),'status':'DRAFT_FINAL_APPROVAL_HOLD'}))
