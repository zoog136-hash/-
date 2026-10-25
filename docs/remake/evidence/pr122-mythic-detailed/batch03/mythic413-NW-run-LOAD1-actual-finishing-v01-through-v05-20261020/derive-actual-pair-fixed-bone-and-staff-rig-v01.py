from pathlib import Path
import numpy as np,math,json,hashlib
D=Path(__file__).resolve().parent;P=D/'load1-actual-rig-v04/load1-actual-rig-placement-and-source-provenance-v04.json';a=json.loads(P.read_text());h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();C=2560;K=.0948275862068;L=250.0

def rootq(dx,dy,length=L):
 rad=2*length*length-2*dx*dx-dy*dy
 assert rad>0
 return (-dy+math.sqrt(rad))/2

def point(p,z):return [.9*p[0],p[1]+z,z]
def inv_chain(hip,knee,ankle):
 za=100.;zk=za+rootq(.9*(knee[0]-ankle[0]),knee[1]-ankle[1]);zh=zk+rootq(.9*(hip[0]-knee[0]),hip[1]-knee[1]);return point(hip,zh),point(knee,zk),point(ankle,za)
def right_chain(hip,knee,ankle,hip_z):
 kz=hip_z-rootq(.9*(hip[0]-knee[0]),hip[1]-knee[1]);az=kz+rootq(.9*(ankle[0]-knee[0]),ankle[1]-knee[1]);return point(hip,hip_z),point(knee,kz),point(ankle,az)
raw=[dict(Lhip=[610,692],Lknee=[566,900],Lankle=[564,1075],Rhip=[705,705],Rknee=[642,785],Rankle=[750,858],heel=[583.5,1191],forefoot=[535,1164],body_raw=[0,0]),dict(Lhip=[614,762],Lknee=a['genuine_new_support_knee'],Lankle=a['parts'][0]['target_knots'][-1],Rhip=[709,775],Rknee=a['genuine_far_passing_knee'],Rankle=[669,1015],heel=a['target_heel1_marker'],forefoot=(np.array([535,1164])+np.array(a['exact_plant_source_delta'])).tolist(),body_raw=[4,70])]
frames=[];errors=[]
for i,r in enumerate(raw):
 lc=inv_chain(r['Lhip'],r['Lknee'],r['Lankle']);rc=right_chain(r['Rhip'],r['Rknee'],r['Rankle'],lc[0][2]);bones=[]
 for side,ch in [('L',lc),('R',rc)]:
  for n in range(2):
   length=float(np.linalg.norm(np.array(ch[n+1])-np.array(ch[n])));errors.append(abs(length-L));bones.append(dict(side=side,segment=n,length=length,target=L))
 frames.append(dict(phase=i,raw_markers=r,Lchain=lc,Rchain=rc,bones=bones,Lheel=point(r['heel'],0.),Lforefoot=point(r['forefoot'],0.),Rheel_z=rc[2][2]-90.,Rforefoot_z=rc[2][2]-150.))
dz=frames[1]['Lchain'][0][2]-frames[0]['Lchain'][0][2];dY=70.+dz;body_delta=[3.6,dY,dz]
# One rigid staff, translated with the actual body node. Constant material depth plane is an explicit rig choice.
staff0={k:point(p,1200.-p[1])for k,p in {'top':[896,14],'grip':[906,433],'lower_tip':[926,1110]}.items()};staff1={k:(np.array(v)+body_delta).tolist()for k,v in staff0.items()};lengths=[float(np.linalg.norm(np.array(s['top'])-s['lower_tip']))for s in [staff0,staff1]]
for i,s in enumerate([staff0,staff1]):frames[i]['staff']=s;frames[i]['staff_length']=lengths[i];frames[i]['staff_tip_clearance_native']=s['lower_tip'][2];assert s['lower_tip'][2]>20
expected=np.array(a['exact_plant_source_delta']);actual=np.array(raw[1]['heel'])-raw[0]['heel'];assert np.max(np.abs(actual-expected))<1e-9
world=np.array([.9*expected[0],expected[1]])*K;assert abs(float(np.linalg.norm(world))-16.8)<1e-8
assert max(errors)<1e-9 and abs(lengths[0]-lengths[1])<1e-9 and all(f['Rforefoot_z']>0 for f in frames)
report=dict(status='FINITE_CONSISTENT_RIG_CONSTRUCTION_PENDING_INDEPENDENT_NUMERIC_AND_ACTUAL_ART_REVIEW',actual_source0_path=str(D/'thunder_female-NW-run-contact0-v08-original-cloth-joint-occlusion.png'),actual_source0_sha256=h(D/'thunder_female-NW-run-contact0-v08-original-cloth-joint-occlusion.png'),actual_load1_path=a['output']['path'],actual_load1_sha256=a['output']['sha256'],actual_placement_proof_sha256=h(P),projection='source_x=Xnative/.9, source_y=Ynative-Znative; nativeXYZworldunit=.0948275862068; all raw markers are UNPADDED art coords',common_rig_root_raw=[669,1267.95],same_native_C=C,same_3D_bones_all_sides_and_frames=[L,L],body_whole_node_translation_native3D=body_delta,body_projected_translation=[4,70],body_projection_note='70 rawY is actual rig bob+ground-depth recoil, NOT a changed packing/root; this is one consistent construction, not uniquely recovered original anatomy',foot_L_actual_complete_module=dict(path=str(D/'clean-actual-stiletto-modules-v01/LEFT-actual-complete-stiletto-native.png'),sha256=h(D/'clean-actual-stiletto-modules-v01/LEFT-actual-complete-stiletto-native.png')),actual_highheel_ankle_height_native=100.,foot_R_local_heel_and_forefoot_height_from_ankle=[-90,-150],shoe_local_vertex_heights_model_not_unique=True,heel_and_forefoot_both_ground_z=0,marker_uncertainty_native=dict(tarsals=[8,8],forefoot=[4,4],heel=[1.5,1.5],staff_tip=[5,5]),frames=frames,maximum_bone_error=max(errors),maximum_staff_length_error=abs(lengths[0]-lengths[1]),plant_step_world_xy=world.tolist(),plant_step_world_length=float(np.linalg.norm(world)),source_visual_gate=False,physical_pair_approved=False,cycle_approved=False,actor_approvals_added=0)
out=D/'actual-pair-fixed-bone-and-staff-rig-proposal-v01.json';assert not out.exists();out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'model':str(out),'sha256':h(out),'bone_error':max(errors),'body3D':body_delta,'staff_tip_native':[f['staff_tip_clearance_native']for f in frames],'Rsole_native':[f['Rforefoot_z']for f in frames]}))
