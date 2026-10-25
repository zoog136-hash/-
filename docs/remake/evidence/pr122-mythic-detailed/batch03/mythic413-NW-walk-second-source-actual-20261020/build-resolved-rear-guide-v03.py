import hashlib, importlib.util, json, math
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).parent
BASE = Path('/workspace/scratch/mythic413-NW-walk-prep-20261019-r001/fixedboneguide.py')
spec = importlib.util.spec_from_file_location('preserved_motion_recipe', BASE)
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
# New physically chronological contract; frozen preparation remains untouched.
g.PHASES = (
 ('left_heel_contact_right_toeoff', 'L', 24., 8.05212086, 20., -30., 13.60712871, -25.),
 ('left_midstance_right_swing_passage', 'L', 6., 6., 0., -12., 27., -8.),
 ('left_terminal_stance_right_approach', 'L', -12., 6., 0., 6., 20., 15.),
 ('right_heel_contact_left_toeoff', 'R', -30., 13.60712871, -25., 24., 8.05212086, 20.),
 ('right_midstance_left_swing_passage', 'R', -12., 27., -8., 6., 6., 0.),
 ('right_terminal_stance_left_approach', 'R', 6., 20., 15., -12., 6., 0.),
)
SCALE = 2.1
BACK = g.mul(g.F, -1.)
RIGHT = g.mul(g.A, -1.)
def project(p):
 return (256 + SCALE*p[0], 480 - SCALE*(math.sin(g.ELEV)*p[1]+math.cos(g.ELEV)*p[2]))

def main():
 atlas = Image.new('RGBA',(1024,1536),(0,0,0,0)); poses=[]
 for i in range(6):
  bob = -2. if i in (1,4) else 0.
  g.PELVIS_Z = 110. + bob
  pose = g.make_pose(i); points = pose['points_world']
  left_advance, right_advance = g.PHASES[i][2],g.PHASES[i][5]
  points['L_wrist'] = g.add(g.add(points['L_shoulder'],g.mul(g.UP,-62.)),g.mul(g.F,-left_advance*.5))
  points['L_elbow'] = g.solve_joint(points['L_shoulder'],points['L_wrist'],40.,38.,g.mul(g.F,-1.))
  points['R_wrist'] = g.add(g.add(g.mul(RIGHT,25.),g.mul(g.F,8.-right_advance*.15)),g.mul(g.UP,127.+bob))
  points['R_elbow'] = g.solve_joint(points['R_shoulder'],points['R_wrist'],40.,38.,g.F)
  panel=Image.new('RGBA',(512,512),(0,0,0,0)); draw=ImageDraw.Draw(panel)
  def line(a,b,color,width): draw.line([project(a),project(b)],fill=color,width=width)
  def capsule(a,b,color,width):
   line(a,b,color,width)
   for q in (a,b):
    x,y=project(q); r=width/2;draw.ellipse((x-r,y-r,x+r,y+r),fill=color)
  grip=points['R_wrist']; bottom=g.add(grip,g.mul(g.UP,-132.)); top=g.add(grip,g.mul(g.UP,123.))
  line(bottom,top,(180,145,40,255),5)
  for side,color in [('R',(135,135,135,255)),('L',(60,60,60,255))]:
   capsule(points[side+'_hip'],points[side+'_knee'],color,16)
   capsule(points[side+'_knee'],points[side+'_ankle'],color,13)
   capsule(points[side+'_heel'],points[side+'_toe'],color,12)
  def body(depth):
   return [g.add(g.add(g.mul(g.A,-14),g.mul(BACK,depth)),g.mul(g.UP,110+bob)),
           g.add(g.add(g.mul(g.A,14),g.mul(BACK,depth)),g.mul(g.UP,110+bob)),
           g.add(g.add(g.mul(g.A,23),g.mul(BACK,depth)),g.mul(g.UP,180+bob)),
           g.add(g.add(g.mul(g.A,-23),g.mul(BACK,depth)),g.mul(g.UP,180+bob))]
  draw.polygon([project(q) for q in body(0)],fill=(130,130,130,255))
  draw.polygon([project(q) for q in body(9)],fill=(70,70,70,255))
  line(g.add(points['pelvis'],g.mul(BACK,11)),g.add(points['chest'],g.mul(BACK,11)),(225,225,225,255),4)
  for side,color in [('R',(145,145,145,255)),('L',(60,60,60,255))]:
   capsule(points[side+'_shoulder'],points[side+'_elbow'],color,12)
   capsule(points[side+'_elbow'],points[side+'_wrist'],color,10)
  capsule(points['chest'],points['neck'],(100,100,100,255),14)
  hx,hy=project(points['head']);draw.ellipse((hx-30,hy-34,hx+30,hy+34),fill=(115,115,115,255))
  bx,by=project(g.add(g.add(points['head'],g.mul(BACK,16)),g.mul(g.UP,8)))
  draw.ellipse((bx-14,by-14,bx+14,by+14),fill=(60,60,60,255))
  atlas.alpha_composite(panel,((i%2)*512,(i//2)*512))
  pose.update({'points_world':points,'points_cell':{k:project(v) for k,v in points.items()},
   'staff_motion_only':{'hand':'R_far','bottom':bottom,'top':top,'constant_length':255.},
   'world_root_forward_offset':18.*i,'small_body_bob':bob,'guide_scale':SCALE})
  for side in ('L','R'):
   assert abs(g.norm(g.sub(points[side+'_hip'],points[side+'_knee']))-61.)<1e-6
   assert abs(g.norm(g.sub(points[side+'_knee'],points[side+'_ankle']))-61.)<1e-6
   assert all(math.isfinite(v) for k,p in points.items() for v in p)
  poses.append(pose)
 # Stance feet move backward 18 local units per frame as body advances 18.
 # For each 4-frame contact/midstance/terminal/toeoff sequence, world XY plant is fixed.
 for side,seq in [('L',[0,1,2,3]),('R',[3,4,5,0])]:
  values=[]
  for j,index in enumerate(seq):
   p=poses[index]['points_world'][side+'_ankle']
   values.append(g.dot(p,g.F)+18.*j)
  assert max(values)-min(values)<1e-6
 checks={'finite_points':True,'all_thigh_shin_lengths_constant':True,
  'L_and_R_four_frame_stance_world_XY_constant':True,
  'chronology':'contactL,midL/swingR,terminalL/Rapproach,contactR,midR/swingL,terminalR/Lapproach',
  'not_game_art_or_approval':True}
 target=OUT/'NW-walk-resolved-rear-guide-v03.png';atlas.save(target)
 (OUT/'NW-walk-resolved-rear-guide-v03.json').write_text(json.dumps({'status':'RESOLVED_MOTION_GUIDE_ONLY',
  'checks':checks,'virtual_C':1024,'raw_cell':512,'requested_alpha16_whole_height':[440,464],
  'anatomical_near':'LEFT','anatomical_far':'RIGHT','heading':'literal NW rear three-quarter',
  'preserved_preparation_sha256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'poses':poses},indent=2)+'\n')
 bg=Image.new('RGB',atlas.size,(205,205,205));bg.paste(atlas,mask=atlas.getchannel('A'))
 bg.thumbnail((600,750));bg.save(OUT/'NW-resolved-rear-guide-v03-private.jpg','JPEG',quality=88,optimize=True)
 print('RESOLVED_FINITE_STANCE_AND_FIXED_BONE_PASS guide_only',str(target))

if __name__=='__main__':main()
