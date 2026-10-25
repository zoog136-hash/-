from pathlib import Path
b=Path(__file__).parent;s=(b/'author-N-death-dedicated-native-six-v08.py').read_text().replace("D=B/'actual-N-death-six-native-v08'","D=B/'actual-N-death-six-native-v09'").replace('actual-native-v08.png','actual-native-v09.png').replace('source-contract-v08.json','source-contract-v09.json').replace('source-board-v08.jpg','source-board-v09.jpg')
pos=s.index("materials={'head-bun-outside-ribbon'")
addition="""# Correct semantic articulation: original rigid backshoe input included the
# old calf shaft y880..926. That real material belongs to the moving shin,
# not to a rigid foot. Preserve all original boot art across these subparts.
back_ankle_source=1032-90*(math.cos(-math.pi/6)-CAM*math.sin(-math.pi/6))
backca=np.array(right);backca[:787]=0;backca[942:]=0;backcalf=native(Image.fromarray(backca))
original_back=sources['complete-original-native-RIGHT-calf-ankle-and-full-shoe-material.png']
backa=np.array(original_back);backa[:927]=0;backshoe=native(Image.fromarray(backa));feet['back']=backshoe
backfg=np.array(original_back);backfg[:950]=0;backforeground=native(Image.fromarray(backfg))
am=Image.new('L',right.size);ImageDraw.Draw(am).ellipse((655,back_ankle_source-22,701,back_ankle_source+22),fill=255)
aa=np.array(right);aa[:,:,3]=np.minimum(aa[:,:,3],np.array(am));aa[aa[:,:,3]==0,:3]=0;anklecap=native(Image.fromarray(aa))
Image.fromarray(backca).save(D/'native-original-back-boot-calf-shaft-reassigned-to-shin.png')
Image.fromarray(backa).save(D/'native-complete-original-back-shoe-below-actual-ankle.png')
Image.fromarray(backfg).save(D/'native-protected-original-complete-back-counter-and-stiletto.png')
Image.fromarray(aa).save(D/'native-actual-rounded-back-ankle-leather-joint.png')
original_back.save(D/'native-original-complete-back-boot-input-preserved.png')
"""
s=s[:pos]+addition+s[pos:]
start=s.index('leg=blank();leg.alpha_composite(affine_bone(thigh,')
end=s.index(';parts[side]=leg;leg.save',start)
new="""leg=blank();sh=[616.5,850]if profile=='front'else[680,1032];mirror=side=='R'if profile=='front'else side=='L';fU=Uf*(-1 if mirror else 1)
  # True original shaft is assigned to the actual calf; no old horizontal
  # source crop can remain floating above the new anatomical knee/ankle.
  if profile=='back':leg.alpha_composite(affine_plane(feet['back'],sh,heel,fU,Vf))
  leg.alpha_composite(affine_bone(thigh,[687,631],[679,787],p0,p1,par))
  if profile=='back':
   calfposed=affine_bone(backcalf,[679,787],[678,back_ankle_source],p1,p2,par);leg.alpha_composite(calfposed);calfposed.save(D/f'N-death-phase{ph}-{side}-actual-articulated-original-boot-shaft.png')
  else:leg.alpha_composite(affine_bone(calf,[679,787],[678,895],p1,p2,par/.8))
  ka=p2-p1;ka=ka/np.linalg.norm(ka);leg.alpha_composite(affine_bone(kcap,[679,787],[679,809],p1,p1+22*ka,par))
  if profile=='back':
   aj=proj(heel)-p2;aj=aj/np.linalg.norm(aj);leg.alpha_composite(affine_bone(anklecap,[678,back_ankle_source],[678,back_ankle_source+22],p2,p2+22*aj,par));leg.alpha_composite(affine_plane(backforeground,sh,heel,fU,Vf))
  else:leg.alpha_composite(affine_plane(feet['front'],sh,heel,fU,Vf))"""
s=s[:start]+new+s[end:]
s=s.replace(';parts[side]=leg;leg.save',"\n  parts[side]=leg;leg.save")
s=s.replace("bone_lengths=[BONE,BONE],", "back_boot_semantic_articulation=dict(original_rigid_calflimit=880,reassigned_real_shaft_y=[880,927],complete_foot_retained_from_y=927,original_goldcounter_stiletto_foreground_from_y=950,fixed_back_ankle_source_y=back_ankle_source,real_native_rounded_joint_surface=True),bone_lengths=[BONE,BONE],")
p=b/'author-N-death-dedicated-native-six-v09.py';assert not p.exists();p.write_text(s);print('v09 original calf material rearticulated; full goldcounter/stiletto preserved')
