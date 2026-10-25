from pathlib import Path
import hashlib,json
B=Path('/workspace/scratch/mythic413-W-attack-author-fresh-20261020-v01');L=Path('/workspace/scratch/pr122-death-s-only-20261022-v01');src=B/'author-own-W-ATTACK6-native-visible-profile-true-rims-staff-guard-safe-clearance-v03.py';code=src.read_text();original=hashlib.sha256(src.read_bytes()).hexdigest()
insert="""# The complete forearm's original native crop begins at y477.  Retain every
# original upper texel, bind only its overlapping distal cuff rows to that same
# rigid forearm, and leave the native shoulder/upper source and controls intact.
_original_left_upper=parts['LEFT-full-near-upper-arm'].copy()
_left_distal=_original_left_upper.copy();_left_distal[:477,:,:]=0
_left_proximal=_original_left_upper.copy();_left_proximal[477:,:,:]=0
assert np.array_equal(_left_distal.astype(np.uint16)+_left_proximal.astype(np.uint16),_original_left_upper.astype(np.uint16))
assert p['parts']['LEFT-complete-original-curved-cuff-forearm-free-fingers']['native_crop_box'][1]==477
parts['LEFT-full-near-upper-arm']=_left_proximal
parts['LEFT-original-distal-upper-cuff-follows-rigid-forearm']=_left_distal
_prox_path=O/'LEFT-original-upper-proximal-native-RGBA-v04.png';_dist_path=O/'LEFT-original-distal-cuff-native-RGBA-v04.png'
Image.fromarray(_left_proximal).save(_prox_path);Image.fromarray(_left_distal).save(_dist_path)
_binding=dict(status='ACTUAL_SOURCE_TEXEL_PRESERVING_RIG_BIND_CHANGE_PENDING_INDEPENDENT_SOURCE_REVIEW',original_native_parts_contract=pin(P),original_upper=p['parts']['LEFT-full-near-upper-arm'],proximal=pin(_prox_path),distal_cuff=pin(_dist_path),split_native_y=477,distal_nonzero_alpha_texels=int((_left_distal[:,:,3]>0).sum()),proximal_plus_distal_RGBA_inverse_mismatch=0,source_pixels_deleted=0,source_colors_changed=False,source_RGBA_resized=False,body_or_right_gear_or_boots_or_timing_changed=False,bind='Existing source-overlap cuff rows follow the same rigid LEFT forearm/cuff; all proximal upper texels retain the original joint.',source_visual_status='HOLD_NOT_REVIEWED',actor_approvals_added=0,game_clips_adopted=0)
_binding_path=O/'LEFT-distal-native-cuff-articulation-source-ownership-v04.json';_binding_path.write_text(json.dumps(_binding,indent=2)+chr(10))
"""
assert code.count('core=np.zeros((H,W,4),np.uint8)')==1;code=code.replace('core=np.zeros((H,W,4),np.uint8)',insert+'\ncore=np.zeros((H,W,4),np.uint8)')
needle="('LEFT-complete-original-curved-cuff-forearm-free-fingers',aff(parts['LEFT-complete-original-curved-cuff-forearm-free-fingers'],LF,lfo))";assert code.count(needle)==1;code=code.replace(needle,"('LEFT-original-distal-upper-cuff-follows-rigid-forearm',aff(parts['LEFT-original-distal-upper-cuff-follows-rigid-forearm'],LF,lfo)),"+needle)
code=code.replace('actual-W-ATTACK6-native-profile-rig-v03','actual-W-ATTACK6-native-profile-rig-v04-distal-cuff-bind-20261022').replace('actual-native-v03.png','actual-native-v04.png').replace('W-ATTACK6-actual-native-profile-RIGHT-fullstaff-LEFTguard-realcloth-candidate-v03.json','W-ATTACK6-actual-native-profile-RIGHT-fullstaff-LEFTguard-realcloth-candidate-v04.json')
needle="f=O/'W-ATTACK6-actual-native-profile-RIGHT-fullstaff-LEFTguard-realcloth-candidate-v04.json'";assert needle in code;code=code.replace(needle,"j['LEFT_distal_cuff_source_ownership_and_rig_binding']=pin(_binding_path)\n"+needle)
out=B/'author-own-W-ATTACK6-native-visible-profile-distal-cuff-bind-v04-20261022.py'
with out.open('x') as f:f.write(code)
assert hashlib.sha256(src.read_bytes()).hexdigest()==original
print(json.dumps(dict(new_rig=str(out),original_rig_unchanged=True,source_visual_status='HOLD',approvals_added=0)))
