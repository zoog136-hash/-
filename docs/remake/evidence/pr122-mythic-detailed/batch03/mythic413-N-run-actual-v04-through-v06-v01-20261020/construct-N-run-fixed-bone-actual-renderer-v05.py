from pathlib import Path
import hashlib,json

B=Path(__file__).parent
p=B/'author-N-run-six-actual-native-v04.py';s=p.read_text()
s=s.replace('actual-six-native-articulation-v04','actual-six-native-articulation-v05').replace('actual-native-rig-v04.png','actual-native-rig-v05.png').replace('actual-N-run-six-source-contract-v04.json','actual-N-run-six-source-contract-v05.json').replace('private-six-actual-source-board-v04.jpg','private-six-actual-source-board-v05.jpg')
s=s.replace('calf=ypart(right,780,934)','calf=ypart(right,780,896)')
needle='rows=[]\nfor st in states:'
replacement='''
# One explicit constructive N camera/rig, chosen before fitting. All six poses
# consume these constants and exact closed-form knees. No inverse depth search,
# no old WALK knee controls, no varying body units or perpose foot registration.
CAM=.45;ROOTY=917.6920531878804;BONE=187.5;FOOT=90.;ANKLE_RISE=90.
CONTACT_PITCH=math.acos((1/1.035)/math.sqrt(1+CAM*CAM))-math.atan(CAM)
def exact_knee(hip,ankle,knee_x,kind):
 r1=math.sqrt(BONE*BONE-(knee_x-hip[0])**2)
 r2=math.sqrt(BONE*BONE-(ankle[0]-knee_x)**2)
 a=np.array(hip[1:],float);b=np.array(ankle[1:],float);dv=b-a;distance=np.linalg.norm(dv)
 assert abs(r1-r2)<distance<r1+r2
 unit=dv/distance;along=(r1*r1-r2*r2+distance*distance)/(2*distance)
 height=math.sqrt(max(0.,r1*r1-along*along));normal=np.array([-unit[1],unit[0]])
 choices=[a+along*unit+sign*height*normal for sign in (-1,1)]
 point=min(choices,key=lambda t:t[1] if kind=='back' else t[0])
 result=np.array([knee_x,*point],float)
 residuals=[abs(float(np.linalg.norm(result-np.array(hip)))-BONE),abs(float(np.linalg.norm(np.array(ankle)-result))-BONE)]
 assert max(residuals)<1.e-8
 return result.tolist(),residuals
def projected(v):return [float(v[0]),float(ROOTY+CAM*v[1]-v[2])]
rows=[];bone_models=[]
for st in states:'''
assert s.count(needle)==1;s=s.replace(needle,replacement)
start=s.index("  ankle=[heel[0]+parity*(sa[0]-sh[0])")
end=s.index("  # Paired native thigh pattern",start)
s=s[:start]+'''  hidden=torso_point([619 if side=='L' else 687,620],lean)
  hip=[hidden[0]+bx,hidden[1]+by]
  hipdepth=40. if phase in (1,4) else 0.
  hip3=[hip[0],hipdepth,ROOTY+CAM*hipdepth-hip[1]]
  support=(phase in (0,1) and side=='L') or (phase in (3,4) and side=='R')
  if support:
   heeldepth=(heel[1]-ROOTY)/CAM;heelheight=0.
  else:
   heeldepth=180. if x['shoe']=='back' else (20. if phase in (1,4) else -100.)
   heelheight=ROOTY+CAM*heeldepth-heel[1]
  angle=(-math.pi/6) if x['shoe']=='back' else (0. if pitch>1. else CONTACT_PITCH)
  heel3=[heel[0],heeldepth,heelheight]
  toe3=[heel[0],heeldepth-FOOT*math.cos(angle),heelheight+FOOT*math.sin(angle)]
  ankle3=[heel[0],heeldepth+ANKLE_RISE*math.sin(angle),heelheight+ANKLE_RISE*math.cos(angle)]
  ankle=projected(ankle3)
  knee3,res=exact_knee(hip3,ankle3,x['k'][0],x['shoe']);kne=projected(knee3)
  assert abs(projected(heel3)[1]-heel[1])<1e-8
  assert not support or (abs(heelheight)<1.e-8 and toe3[2]>=-1.e-8)
  assert support or min(heel3[2],toe3[2],ankle3[2])>0
  model=dict(phase=phase,side=side,hip=hip3,knee=knee3,ankle=ankle3,heel=heel3,toe=toe3,bone_length_residuals=res,foot_length_residual=abs(float(np.linalg.norm(np.array(toe3)-np.array(heel3)))-FOOT),sole_state='heel-contact' if support and pitch==1. else ('full-support' if support else 'AIR'),foot_pitch_degrees=math.degrees(angle))
  bone_models.append(model)
  joints[side]=dict(hidden_hip_chosen_rig_anchor=hip,knee_from_fixed_187p5_bones=kne,ankle_chosen_rig_anchor=ankle,structural_heel=heel,complete_shoe_material=x['shoe'],paired_part_mirror=mirror,foot_planar_pitch_projection=pitch,model=model)
'''+s[end:]
s=s.replace("affine_bone(thigh,[687,646],[679,787],hip,kne", "affine_bone(thigh,[687,631],[679,787],hip,kne")
s=s.replace("affine_bone(calf,[679,787],[678,923],kne,ankle", "affine_bone(calf,[679,787],[678,895],kne,ankle")
s=s.replace("physical_limitations=['Hip/knee controls are a chosen constructive rig, not uniquely measured hidden 3D joints.','Toe occlusion/true sole support and AIR need independent finite model/art verification.','Projected part lengths alone are not fixed-bone or actual gait approval.']", "physical_limitations=['One chosen camera/hip-depth/foot rig is constructively fixed, not a unique recovery of hidden source anatomy.','Original complete front/back shoe RGBA are actual source-view materials; back-shell planar pitch is used for the visible CONTACT to LOAD material change. Hidden toe controls are not measured bitmap pixels.','Full painted sole depth/occlusion and all6 real source quality/Player closure require independent review.']")
s=s.replace("(D/'actual-N-run-six-source-contract-v05.json').write_text", "contract['constructive_fixed_bone_rig']=dict(camera_depth_factor=CAM,projection='x=X; y=ROOTY+.45*depth-height',bone_lengths_native=[BONE,BONE],foot_length_native=FOOT,heel_to_ankle_native=ANKLE_RISE,hips_depth_contact_flight=0,hips_depth_load=40,hidden_hip_source_y=620,back_foot_material_pitch_degrees=-30,front_contact_pitch_degrees=math.degrees(CONTACT_PITCH),models=bone_models,max_bone_length_residual=max(max(m['bone_length_residuals'])for m in bone_models),articulation_surface='Actual native thigh and continuous black/gold calf leather UV surface is articulated under complete original shoe/counter/stiletto RGBA; painted shaft points are not claimed uniquely measured anatomical joints.')\n(D/'actual-N-run-six-source-contract-v05.json').write_text")
out=B/'author-N-run-six-actual-native-v05.py'
with out.open('x')as f:f.write(s)
print(json.dumps(dict(renderer=str(out),sha256=hashlib.sha256(out.read_bytes()).hexdigest())))
