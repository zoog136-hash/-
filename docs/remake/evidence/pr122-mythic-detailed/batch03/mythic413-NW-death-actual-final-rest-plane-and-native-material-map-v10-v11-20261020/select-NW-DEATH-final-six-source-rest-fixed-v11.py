from pathlib import Path
import json,hashlib
P=Path(__file__).parent
F=P/'actual-NW-DEATH6-final-original-fabric-volume-v09/NW-DEATH-final-six-exact-native-source-root-and-floor-contract-v09.json'
S=P/'actual-NW-DEATH-single-phase0-rest-transverse-final-v10/NW-DEATH-single-phase0-rest-transverse-final-source-root-and-floor-contract-v10.json'
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
d=json.loads(F.read_text());d['frames'][0]=json.loads(S.read_text())['frames'][0]
for f in d['frames']:
 p=Path(f['path']);assert pin(p)['sha256']==f['sha256'];assert len(f['strong_components_alpha100_4conn_gte200'])==1
 f['quality']='INDEPENDENT_ACTUAL_SOURCE_VISIBLE_FALL_AND_TERMINAL_REVIEW_CLOSED_RECEIPT_PENDING'
d.update(status='ACTUAL_FINAL_SIX_SOURCE_VISIBLE_CYCLE_CLOSED_FINITEFLOOR_RECEIPT_PENDING',prior_final_six=pin(F),single_phase0_rest_plane_correction=pin(S),source_order=[f['phase'] for f in d['frames']],source_RGBA_resampling_in_selection=0,whole_figure_global_rotation_as_animation=False,perpose_root_or_canvas_fitting=False,private_author_image_context_bytes_unchanged=5538937,actor_approval_added=0)
f=P/'NW-DEATH-final-six-actual-source-constant-root-and-native-registration-v11.json';f.write_text(json.dumps(d,indent=2)+'\n')
print(json.dumps({'final_contract':pin(f),'selected':[{k:r[k]for k in ['phase','sha256','bytes']}for r in d['frames']]}))
