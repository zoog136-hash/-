from pathlib import Path
import json,hashlib,numpy as np
from PIL import Image
P=Path(__file__).parent;D=P/'NW-DEATH-exact-editable-source-semantic-map-v01';D.mkdir(exist_ok=False)
R=P/'actual-NW-DEATH6-original-white-fold-raw-v08';F=P/'actual-NW-DEATH6-final-original-fabric-volume-v09';S=P/'actual-NW-DEATH-single-phase0-rest-transverse-final-v10'
contract=F/'NW-DEATH-final-six-exact-native-source-root-and-floor-contract-v09.json';single=S/'NW-DEATH-single-phase0-rest-transverse-final-source-root-and-floor-contract-v10.json'
full=json.loads(contract.read_text());rows=[json.loads(single.read_text())['frames'][0]]+full['frames'][1:]
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
keys={'pelvis_skirt':'actual_pelvis_pleated_skirt','torso_corset':'actual_torso_corset','head_bun_ribbon':'head_bun_original_ribbon','RIGHT_upper_arm':'RIGHT_upper','RIGHT_forearm_full_rigid_staff':'RIGHT_forearm_full_rigid_staff','LEFT_real_proximal_shoulderpad':'LEFT_real_proximal_shoulderpad','RIGHT_real_proximal_shoulderpad':'RIGHT_real_proximal_shoulderpad','LEFT_original_continuous_white_sleeve_goldcuff_and_glove':'LEFT_continuous_original_arm'}
for side in ['LEFT','RIGHT']:
 for surf,key in [('complete_foot','foot'),('thigh','thigh'),('actual_calf_shaft','calf'),('actual_kneecap','kneecap'),('actual_anklecap','anklecap'),('counter_stiletto_foreground','counter_foreground')]:keys[side+'_'+surf]=side+'_'+key
coat=R/'actual-original-NW-actual_far_blue_gold_coat-material.png';ca=np.array(Image.open(coat).convert('RGBA'));yy=np.indices(ca.shape[:2])[0];allrows=[];unique={}
for frame in rows:
 phase=frame['phase'];surfs=frame['actual_material_surfaces'];hanging=next(x for x in surfs if x['name']=='far_blue_gold_coat_hanging');cut=650+max(0.,(hanging['world_anchor'][2]-10)/max(-hanging['V'][2],1e-8));entries=[]
 for sf in surfs:
  name=sf['name'];entry=dict(name=name,kind=sf.get('kind','ACTUAL_RGBA_AFFINE_PLANE'),geometry=sf)
  if name=='LEFT_actual_original_white_fabric_volumetric_inner_elbow':
   src=Path(sf['source_actual_white_donor']['path']);layer=(S if phase==0 else F)/f'phase{phase}-actual-original-fabric-rounded-inner-elbow-surface.png';entry.update(actual_source=pin(src),actual_rendered_RGBA_layer=pin(layer),source_mask='EXACT_EMBEDDED_PNG_ALPHA',source_rectangle_in_original=[545,542,573,555]);ar=np.array(Image.open(src).convert('RGBA'))
  else:
   if name.startswith('far_blue_gold_coat_'):
    mask=yy<=cut if name.endswith('hanging') else yy>cut;ar=ca.copy();ar[~mask,3]=0;ar[ar[:,:,3]==0,:3]=0
    if np.array_equal(ar,ca):src=coat
    else:src=D/f'phase{phase}-{name}-actual-original-RGBA-source.png';Image.fromarray(ar).save(src)
    entry.update(original_whole_coat=pin(coat),source_split_y=cut,split_rule='y <= cut' if name.endswith('hanging') else 'y > cut')
   else:
    assert name in keys,name
    src=R/f'actual-original-NW-{keys[name]}-material.png';ar=np.array(Image.open(src).convert('RGBA'))
   n=int((ar[:,:,3]>0).sum());assert n==sf['source_alpha_nonzero_pixels'],(phase,name,n,sf['source_alpha_nonzero_pixels'])
   entry.update(actual_source=pin(src),source_mask='EXACT_EMBEDDED_PNG_ALPHA',source_alpha_nonzero_pixels=n,source_nonzero_alpha_RGBA_preserved=True)
  unique[str(src)]=pin(src);entries.append(entry)
 allrows.append(dict(phase=phase,actual_rendered_frame={k:frame[k]for k in ['path','sha256','bytes']},surfaces=entries))
manifest=dict(status='EXACT_EDITABLE_ACTUAL_RGBA_SOURCE_INDEX_PENDING_FINAL_SOURCE_QUALITY',actor_id=413,direction='NW',action='death',contract_baseline=pin(contract),phase0_actual_rest_transverse_update=pin(single),common_root=full['common_unpadded_root'],physical_canvas=2048,body_unit=2,storage_translation=[128,128],projection='[worldX+128,1058.3+.45*worldY-worldZ+128]',mask_semantics='Source PNG alpha is the exact semantic ownership mask; RGB/alpha of actual source is preserved; alpha0 RGB zero only on derived cloak split. No preview, source resampling or synthesized material.',curved_original_source_mesh_operator=pin(P/'native-curved-elbow-real-material-rasterizer-v01.py'),current_phase0_rest_basis_renderer=pin(P/'author-NW-DEATH-single-phase0-true-rest-transverse-v10.py'),original_fabric_volume_operator=pin(P/'finish-NW-DEATH-single-phase2-actual-volumetric-inner-white-fold-v07.py'),frames=allrows,unique_actual_source_files=list(unique.values()),new_author_images=0,new_services=0,actor_approval_added=0)
f=D/'NW-DEATH-v09-plus-phase0v10-exact-editable-material-surface-source-map-v01.json';f.write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(dict(manifest=pin(f),unique_source_files=len(unique),frames=6,source_alpha_counts_all_exact=True)))
