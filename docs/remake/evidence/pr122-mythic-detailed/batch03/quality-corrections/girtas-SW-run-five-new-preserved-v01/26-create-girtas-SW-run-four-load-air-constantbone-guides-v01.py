from pathlib import Path
import bpy,math,json,hashlib
import numpy as np
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
O=Path('/workspace/scratch/girtas-SW-run-four-load-air-solid-guide-v01');O.mkdir(exist_ok=False)
def mat(n,c):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);return m
body=mat('neutral_identity_body',(.46,.49,.53));far=mat('FAR_anatomical_RIGHT_ORANGE',(.96,.30,.07));near=mat('NEAR_anatomical_LEFT_BLUE',(.03,.48,.93));black=mat('nose_forward_PLUS_Y',(.08,.09,.11));weapon=mat('permanent_RIGHT_weapon_guide',(.52,.39,.12))
def ball(n,p,s,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=p);o=bpy.context.object;o.name=n;o.scale=s;o.data.materials.append(m);return o
def limb(n,a,b,r,m):
 d=Vector(b)-Vector(a);mid=(Vector(a)+Vector(b))/2;bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=d.length,location=mid);o=bpy.context.object;o.name=n;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(m)
def foot(side,x,y,angle,clearance,m):
 ext=math.sqrt((.20*math.sin(angle))**2+(.07*math.cos(angle))**2);z=ext+clearance;o=ball(side+'BOOT',(x,y+.08,z),(.095,.20,.07),m);o.rotation_euler.x=angle;return (x,y,z+.08),{'center':[x,y+.08,z],'rotationX':angle,'ground_clearance':clearance,'is_support':clearance==0}
def fixed_knee(hip,ankle,L=.52):
 a=np.asarray(hip,dtype=np.float64);b=np.asarray(ankle,dtype=np.float64);v=b-a;d=float(np.linalg.norm(v));assert 0<d<2*L;u=v/d;p=np.array((0,-u[2],u[1]));p=p/np.linalg.norm(p);k=a+v*.5+p*math.sqrt(L*L-d*d/4);return tuple(float(x) for x in k)
def fixed_elbow(shoulder,wrist,sgn):
 a=np.asarray(shoulder,dtype=np.float64);b=np.asarray(wrist,dtype=np.float64);v=b-a;d=float(np.linalg.norm(v));L1=.32;L2=.27;assert abs(L1-L2)<d<L1+L2;u=v/d;t=(L1*L1-L2*L2+d*d)/(2*d);pref=np.array((sgn,0,-.15));p=pref-u*float(np.dot(pref,u));p=p/np.linalg.norm(p);return tuple(float(x) for x in a+u*t+p*math.sqrt(max(0,L1*L1-t*t)))
records=[]
for phase,lead in [(1,'LEFT'),(2,'RIGHT'),(4,'RIGHT'),(5,'LEFT')]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);hipZ=.89 if phase in (1,4) else 1.14;lean=.16 if phase in (1,4) else .18;bob=hipZ-1.03;ball('PELVIS',(0,0,hipZ),(.25,.15,.16),body);ball('TORSO',(0,lean,1.37+bob),(.32,.17,.32),body);limb('NECK',(0,lean,1.58+bob),(0,lean+.02,1.72+bob),.08,body);ball('HEAD',(0,lean+.03,1.85+bob),(.15,.14,.21),body);ball('nose_FORWARD_PLUSY',(0,lean+.17,1.85+bob),(.045,.055,.055),black);record={'phase':phase,'name':('LOAD_'+lead+'_FLAT_SOLE_other_AIR' if phase in (1,4) else 'AIR_'+lead+'_FORWARD_both_AIR'),'camera':[-5,7,5],'forward':[0,1,0],'RIGHT_far':[1,0,0],'LEFT_near':[-1,0,0],'fixed_thigh_length':.52,'fixed_shin_length':.52,'legs':{},'arms':{}}
 for side,x,m in [('RIGHT',.18,far),('LEFT',-.18,near)]:
  islead=side==lead;isload=phase in (1,4);y=(.14 if islead else -.27) if isload else (.46 if islead else -.42);angle=(0 if islead else -.65) if isload else (.12 if islead else -.50);clear=(0 if islead else .32) if isload else (.10 if islead else .24);hip=(x,0,hipZ);ankle,fr=foot(side,x,y,angle,clear,m);knee=fixed_knee(hip,ankle);limb(side+'THIGH',hip,knee,.102,m);ball(side+'KNEE',knee,(.10,.10,.10),m);limb(side+'SHIN',knee,ankle,.077,m);ball(side+'ANKLE',ankle,(.07,.07,.085),m);actual=[math.dist(knee,hip),math.dist(ankle,knee)];assert max(abs(v-.52) for v in actual)<1e-9;record['legs'][side]={'hip':list(hip),'knee':list(knee),'ankle':list(ankle),'actual_bone_lengths':actual,**fr}
  sgn=1 if side=='RIGHT' else -1;shoulder=(sgn*.31,lean,1.54+bob)
  if side=='RIGHT':elbow=(sgn*.40,lean-.03,1.24);wrist=(sgn*.43,lean-.01,.99+bob)
  else:
   swing=-.16 if lead=='LEFT' else .25;elbow=(sgn*.40,lean+swing*.6,1.25);wrist=(sgn*.43,lean+swing,1.03+bob)
  elbow=fixed_elbow(shoulder,wrist,sgn);arm_lengths=[math.dist(elbow,shoulder),math.dist(wrist,elbow)];assert abs(arm_lengths[0]-.32)<1e-9 and abs(arm_lengths[1]-.27)<1e-9
  ball(side+'SHOULDER',shoulder,(.10,.10,.10),m);limb(side+'UPPERARM',shoulder,elbow,.075,m);limb(side+'FOREARM',elbow,wrist,.065,m);ball(side+'HAND',wrist,(.07,.06,.085),m);record['arms'][side]={'shoulder':list(shoulder),'elbow':list(elbow),'wrist':list(wrist),'owns_weapon':side=='RIGHT','actual_bone_lengths':arm_lengths}
  if side=='RIGHT':
   points=[wrist]+[(wrist[0]+.03*math.sin(k*2.5),wrist[1]+.12*k,wrist[2]-.035*k) for k in range(1,8)]
   for k in range(len(points)-1):limb('RIGHT_only_permanent_bladeguide_'+str(k),points[k],points[k+1],.022,weapon)
 bpy.ops.object.camera_add(location=(-5,7,5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.75;scene=bpy.context.scene;scene.camera=cam;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.studio_light='paint.sl';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='BOTH';scene.display.shading.background_type='WORLD';scene.world.color=(.12,.13,.15);scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';out=O/f'SW-run-phase{phase}-fixedbone.png';scene.render.filepath=str(out);bpy.ops.render.render(write_still=True);record['render']=str(out);record['render_sha256']=hashlib.sha256(out.read_bytes()).hexdigest()
 for side,leg in record['legs'].items():
  leg['projected_native768']={}
  for k in ['hip','knee','ankle','center']:
   q=world_to_camera_view(scene,cam,Vector(leg[k]));leg['projected_native768'][k]=[float(q.x*768),float((1-q.y)*768)]
 records.append(record)
(O/'constantbone-joint-and-ground-authority.json').write_text(json.dumps({'status':'PRODUCTION_3D_GUIDE_ONLY_NOT_FINAL_ART_OR_APPROVAL','actor':'transform:267','direction':'SW','role':'run','authored_phases':[1,2,4,5],'fixed_leg_bone_lengths':[.52,.52],'fixed_arm_bone_lengths':[.32,.27],'max_bone_length_error':1e-9,'camera':[-5,7,5],'forward_PLUS_Y':'DOWNLEFT','anatomicalRIGHT_PLUS_X':'FAR_ORANGE_permanent_sinuousweapon','anatomicalLEFT_MINUS_X':'NEAR_BLUE_EMPTY_hand','frames':records,'source_imagegen_must_preserve':'Actual LEFTload1/RIGHTload4 with plantedFLATsole+kneecompression and RIGHTleadAIR2/LEFTleadAIR5 bothfeetair; samefixedbones, constant proportions and correctSWface/hips, no alllegs-same or terminalpush mislabeledlanding.'},indent=2)+'\n')
