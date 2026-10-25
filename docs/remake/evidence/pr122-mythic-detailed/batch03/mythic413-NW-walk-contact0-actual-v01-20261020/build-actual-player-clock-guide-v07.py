"""New exact NW Player-clock scaffold; no source pixels or game files modified."""
from pathlib import Path
import hashlib, importlib.util, json, math
from PIL import Image, ImageDraw

HERE=Path(__file__).parent
BASE=Path('/workspace/scratch/mythic413-NW-walk-prep-20261019-r001/fixedboneguide.py')
s=importlib.util.spec_from_file_location('frozen_recipe',BASE);g=importlib.util.module_from_spec(s);s.loader.exec_module(g)
PIXEL_SCALE=.237068965517
SX=.9*PIXEL_SCALE;SY=PIXEL_SCALE
WORLD_PHASE=210./12.5
ROOT_WORLD=(-WORLD_PHASE/math.sqrt(2),-WORLD_PHASE/math.sqrt(2))
NATIVE_RETRO=(-ROOT_WORLD[0]/SX,-ROOT_WORLD[1]/SY)
RATIO=NATIVE_RETRO[0]*math.sin(g.ELEV)/NATIVE_RETRO[1]
g.F=g.unit((-RATIO,1.,0.));g.A=(-g.F[1],g.F[0],0.)
g.THIGH=g.SHIN=88.;g.UPPER_ARM=50.;g.FOREARM=48.
SCALE=1.7;ROOT_RAW=(256.,419.)
D=NATIVE_RETRO[0]/(SCALE*-g.F[0])
HEEL=-6.*math.cos(math.radians(20.));TOE=18.*math.cos(math.radians(25.))
A0=1.5*D;A1=.5*D+6.+HEEL;A2=-.5*D+6.+HEEL;A3=-1.5*D+24.-TOE+HEEL
HZ=6.+6.*math.sin(math.radians(20.));TZ=6.+18.*math.sin(math.radians(25.))
g.PHASES=(
 ('left_heel_contact_right_toeoff','L',A0,HZ,20.,A3,TZ,-25.),
 ('left_midstance_right_swing','L',A1,6.,0.,-.5*D,27.,-8.),
 ('left_terminal_right_approach','L',A2,6.,0.,.5*D,20.,15.),
 ('right_heel_contact_left_toeoff','R',A3,TZ,-25.,A0,HZ,20.),
 ('right_midstance_left_swing','R',-.5*D,27.,-8.,A1,6.,0.),
 ('right_terminal_left_approach','R',.5*D,20.,15.,A2,6.,0.),
)
BACK=g.mul(g.F,-1.);RIGHT=g.mul(g.A,-1.)
def project(p):return(ROOT_RAW[0]+SCALE*p[0],ROOT_RAW[1]-SCALE*(math.sin(g.ELEV)*p[1]+math.cos(g.ELEV)*p[2]))
def screen_world(v):return((v[0]-ROOT_RAW[0])*SX,(v[1]-ROOT_RAW[1])*SY)
def draw_pose(pose,index):
 p=pose['points_world'];panel=Image.new('RGBA',(512,512),(0,0,0,0));draw=ImageDraw.Draw(panel)
 def line(a,b,col,w):draw.line([project(a),project(b)],fill=col,width=w)
 def capsule(a,b,col,w):
  line(a,b,col,w)
  for q in(a,b):
   x,y=project(q);r=w/2;draw.ellipse((x-r,y-r,x+r,y+r),fill=col)
 line(pose['staff']['bottom_world'],pose['staff']['top_world'],(190,145,35,255),4)
 for side,col in[('R',(140,140,140,255)),('L',(55,55,55,255))]:
  capsule(p[side+'_hip'],p[side+'_knee'],col,16);capsule(p[side+'_knee'],p[side+'_ankle'],col,13);capsule(p[side+'_heel'],p[side+'_toe'],col,10)
 def body(depth):
  return[g.add(g.add(g.mul(g.A,-14),g.mul(BACK,depth)),g.mul(g.UP,pose['pelvis_z'])),g.add(g.add(g.mul(g.A,14),g.mul(BACK,depth)),g.mul(g.UP,pose['pelvis_z'])),g.add(g.add(g.mul(g.A,23),g.mul(BACK,depth)),g.mul(g.UP,pose['pelvis_z']+70)),g.add(g.add(g.mul(g.A,-23),g.mul(BACK,depth)),g.mul(g.UP,pose['pelvis_z']+70))]
 draw.polygon([project(q)for q in body(0)],fill=(130,130,130,255));draw.polygon([project(q)for q in body(9)],fill=(65,65,65,255))
 line(g.add(p['pelvis'],g.mul(BACK,11)),g.add(p['chest'],g.mul(BACK,11)),(230,230,230,255),4)
 for side,col in[('R',(150,150,150,255)),('L',(55,55,55,255))]:
  capsule(p[side+'_shoulder'],p[side+'_elbow'],col,12);capsule(p[side+'_elbow'],p[side+'_wrist'],col,10)
 capsule(p['chest'],p['neck'],(110,110,110,255),12)
 hx,hy=project(p['head']);draw.ellipse((hx-25,hy-29,hx+25,hy+29),fill=(120,120,120,255))
 bx,by=project(g.add(g.add(p['head'],g.mul(BACK,16)),g.mul(g.UP,8)));draw.ellipse((bx-12,by-12,bx+12,by+12),fill=(55,55,55,255))
 # Actual FAR RIGHT wrist meets staff exactly; nearLEFT free wrist is separated.
 wx,wy=project(p['R_wrist']);draw.ellipse((wx-5,wy-5,wx+5,wy+5),fill=(40,175,200,255))
 bb=panel.getchannel('A').getbbox();assert bb and bb[0]>=8 and bb[1]>=8 and bb[2]<=504 and bb[3]<=504,(index,bb)
 padded=Image.new('RGBA',(1024,1024),(0,0,0,0));padded.alpha_composite(panel,(256,256))
 padded.save(HERE/f'NW-contact-clock-guide-pose{index}-v07-padded.png')
 return bb
def main():
 poses=[]
 for i in range(6):
  g.PELVIS_Z=[154.,170.,166.][i%3]
  q=g.make_pose(i);p=q['points_world'];bob=g.PELVIS_Z-154.
  p['L_wrist']=g.add(g.add(p['L_shoulder'],g.mul(g.UP,-62.)),g.mul(g.F,-g.PHASES[i][2]*.2))
  p['L_elbow']=g.solve_joint(p['L_shoulder'],p['L_wrist'],50.,48.,g.mul(g.F,-1.))
  p['R_wrist']=g.add(g.add(g.mul(RIGHT,25.),g.mul(g.F,8.)),g.mul(g.UP,181.*math.cos(math.radians(20.))+bob))
  p['R_elbow']=g.solve_joint(p['R_shoulder'],p['R_wrist'],50.,48.,RIGHT)
  angle=math.radians([20.,27.,24.][i%3]);axis=g.add(g.mul(g.UP,math.cos(angle)),g.mul(BACK,math.sin(angle)))
  staff={'hand':'anatomical_RIGHT_FAR','rigid_length_world_guide_units':320.,'tilt_backward_degrees':math.degrees(angle),'top_world':g.add(p['R_wrist'],g.mul(axis,139.)),'bottom_world':g.add(p['R_wrist'],g.mul(axis,-181.))}
  assert staff['bottom_world'][2]>=-1e-6
  q.update({'points_world':p,'points_native_cell':{k:project(v)for k,v in p.items()},'pelvis_z':g.PELVIS_Z,'staff':staff,'actual_runtime_phase_index':i,'root_forward_guide_units':i*D,'root_world':tuple(i*x for x in ROOT_WORLD)})
  for side in('L','R'):
   assert abs(g.norm(g.sub(p[side+'_hip'],p[side+'_knee']))-88.)<1e-6
   assert abs(g.norm(g.sub(p[side+'_knee'],p[side+'_ankle']))-88.)<1e-6
   assert abs(g.norm(g.sub(p[side+'_heel'],p[side+'_toe']))-24.)<1e-6
  assert abs(g.norm(g.sub(staff['top_world'],staff['bottom_world']))-320.)<1e-6
  assert all(math.isfinite(v)for pt in p.values()for v in pt)
  q['native_guide_alpha_bbox']=draw_pose(q,i);poses.append(q)
 def world_point(index,side,part,unwrapped):
  p=poses[index]['points_world'][side+'_'+part];xy=screen_world(project(p))
  return(xy[0]+unwrapped*ROOT_WORLD[0],xy[1]+unwrapped*ROOT_WORLD[1])
 residuals=[]
 for side,seq in[('L',[0,1,2,3]),('R',[3,4,5,0])]:
  for part,links in[('heel',[(0,1)]),('toe',[(1,2),(2,3)])]:
   for aa,bb in links:
    pa=world_point(seq[aa],side,part,aa);pb=world_point(seq[bb],side,part,bb)
    r=math.dist(pa,pb);assert r<1e-8,(side,part,aa,bb,r)
    assert abs(poses[seq[aa]]['points_world'][side+'_'+part][2])<1e-6
    assert abs(poses[seq[bb]]['points_world'][side+'_'+part][2])<1e-6
    residuals.append({'side':side,'part':part,'from_phase':seq[aa],'to_phase':seq[bb],'world_drift':r})
 result={'status':'GUIDE_FINITE_ACTUAL_PLAYER_CLOCK_PASS_NOT_SOURCE_APPROVAL','key':'transform:413','direction':'NW','role':'walk','virtual_C':1024,'logical_canvas':1024,'raw_native_cell':512,'actual_generation_canvas':1024,'extract_rectangle':[256,256,768,768],'no_resample':True,'raw_ground_root':ROOT_RAW,'profile_pixel_scale':PIXEL_SCALE,'player_sprite_scale':[SX,SY],'fps':12.5,'reference_speed':210.,'phase_seconds':1/12.5,'world_per_phase':WORLD_PHASE,'root_world_delta':ROOT_WORLD,'required_native_retrograde':NATIVE_RETRO,'camera_elevation_degrees':math.degrees(g.ELEV),'projected_forward_3d':g.F,'fixed_thigh_shin_lengths':[88.,88.],'fixed_foot_length':24.,'forward_guide_units_per_phase':D,'plant_residuals':residuals,'all_bones_finite_rigid':True,'all_staff_rigid_length':320.,'all_staff_bottom_above_ground':True,'source_approval_added':0,'actor_approval_added':0,'poses':poses}
 out=HERE/'NW-sixposes-actual-Player-clock-guide-v07.json';out.write_text(json.dumps(result,indent=2)+'\n')
 print('ACTUAL_PLAYER_CLOCK_GUIDE_PASS',out,'maxworlddrift',max(x['world_drift']for x in residuals),'C1024','all6bounds',[q['native_guide_alpha_bbox']for q in poses])
if __name__=='__main__':main()
