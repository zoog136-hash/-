from pathlib import Path
import json,hashlib,sys,math
import numpy as np
from PIL import Image

cp=Path(sys.argv[1]);c=json.loads(cp.read_text());D=cp.parent
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
frozen=next(D.glob('*frozen-source-and-code-allowlist.json'));a=json.loads(frozen.read_text());bad=[]
for r in a['files']:
 p=Path(r['path'])
 if not p.exists()or p.stat().st_size!=r['bytes']or pin(p)['sha256']!=r['sha256']:bad.append(str(p))
assert not bad,bad
assert len(c['frames'])==6 and c['fixed_C']==2816 and c['bodyunit']==2.75
assert c['authored_cycle_seconds']==.48 and c['authored_fps']==12.5
assert not c['source_RGBA_scaled']and not c['wholeactor_mirror']and not c['perpose_root_or_C_fit']
physics=json.loads(Path(c['source_floor_binding']['path']).read_text());assert physics['all_above_floor']
records={(r['phase'],r['name']):r for r in physics['records']};rows=[]
for f in c['frames']:
 p=Path(f['path']);im=Image.open(p);assert im.format=='PNG'and im.mode=='RGBA'and list(im.size)==c['storage_canvas'];assert pin(p)['sha256']==f['sha256'];im.verify()
 assert f['common_unpadded_root']==c['common_unpadded_root']and f['physical_C']==c['fixed_C']and f['bodyunit']==c['bodyunit']and f['storage_translation']==c['storage_translation']
 assert not f['storage_boundary_alpha_contact'];assert len(f['strong_components'])==1,f['strong_components']
 for side in ['L','R']:
  q=f['bones'][side];H=np.array(q['hip']);K=np.array(q['knee']);A=np.array(q['ankle']);assert max(abs(np.linalg.norm(K-H)-c['fixed_femur_tibia']),abs(np.linalg.norm(A-K)-c['fixed_femur_tibia']))<1e-7
  R=np.array(q['foot_SO3']);assert np.max(abs(R.T@R-np.eye(3)))<1e-10 and abs(np.linalg.det(R)-1)<1e-10
  if q['support']:assert abs(q['structural_heel_support'][2])<1e-9 and q['structural_foreball'][2]>=-1e-9
  else:assert min(q['structural_heel_support'][2],q['structural_foreball'][2])>0
  assert q['support']==((side=='L'and f['phase']in[0,1])or(side=='R'and f['phase']in[3,4]))
 names=[Path(r['path']).name for r in f['actual_node_rasters']];nodes=[Image.open(r['path']).convert('RGBA')for r in f['actual_node_rasters']];assert len(nodes)==18
 # Geometry/art checks elsewhere resolve all ten leg surfaces by actual ray
 # depth. This check binds final RGBA to that saved exact composition and the
 # original independent body/head/arm module rasters, with zero pixel delta.
 out=Image.new('RGBA',tuple(c['storage_canvas']));out.alpha_composite(nodes[10]);out.alpha_composite(Image.open(D/f'phase{f["phase"]}-both-actual-legs-and-boots-exact-depth-composition.png'))
 for i in range(11,18):out.alpha_composite(nodes[i])
 assert np.array_equal(np.array(out),np.array(Image.open(p)))
 for r in physics['records']:
  if r['phase']!=f['phase']:continue
  z=np.load(r['selected_depth_and_raster_floor']['path']);sel=z['alpha_nonzero']>0;minimum=float(z['texel_quad_min_Z'][sel].min());assert abs(minimum-r['raster_texel_quad_min_Z'])<1e-3
 rows.append(dict(phase=f['phase'],PNG_RGBA_CRC=True,fixed_C_root_storage=True,one_strong_body_component=True,actual_native_node_recomposition_pixel_delta=0,fixed_bones_and_foot_SO3=True,full_original_material_floor_quads=True,support_side='L'if f['phase']in[0,1]else'R'if f['phase']in[3,4]else'AIR'))
s=c['runtime_scale_and_fixed_control'];P=np.array(c['projection_matrix']);F=np.array(s['screen_forward']);delta=210*.08
errors=[]
for side,aa,bb in [('L',0,1),('R',3,4)]:
 d=P@(np.array(c['frames'][bb]['bones'][side]['structural_heel_support'])-c['frames'][aa]['bones'][side]['structural_heel_support']);errors.append(float(np.linalg.norm(d*s['native_to_game_world']+F*delta)))
assert max(errors)<1e-8
r=dict(status='PASS_ENGINEERING_BINDING_ONLY_SOURCE_ART_LOOP_AND_GAME_REVIEW_PENDING',contract=pin(cp),frozen_allowlist=pin(frozen),frozen_files_checked=len(a['files']),all_SHA_size_matches=True,actual_six_rows=rows,all_source_and_raster_floor_min=physics['min_guarded_source_raster_Z'],support_player_motion_residual_game=errors,source_quality_approval=False,actor_approvals_added=0,game_clips_adopted=0,verifier=pin(Path(__file__)))
op=D/'actual-RUN-six-engineering-control-and-PNG-binding-v01.json';op.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(dict(receipt=pin(op),all6=True,min_floor=physics['min_guarded_source_raster_Z'],support_lock_errors=errors)))
