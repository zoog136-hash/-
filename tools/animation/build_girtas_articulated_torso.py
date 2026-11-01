"""Rigid abdomen/chest bindings and far-arm joints, from preserved visible art."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
import json,hashlib
R=Path(__file__).resolve().parents[2];D=R/'assets/actors/shared_skin_pilot/girtas_267/articulated';D.mkdir(parents=True,exist_ok=True)
def read(p):return Image.open(R/p.removeprefix('res://')).convert('RGBA')
def mask(size,poly):
 m=Image.new('L',size);ImageDraw.Draw(m).polygon(poly,fill=255);return m
def save(im,name,pivot):
 p=D/(name+'.png');im.save(p);return {'texture':'res://'+str(p.relative_to(R)),'pivot':pivot,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
result={'schema':1,'authorship':'Visible rigid armor pieces with overlapping joint bands; no whole-body warp or torso-width morph.'}
for direction,manifest,joint,core,cut in [('E','girtas_shared_skin.json',[304,210],[(276,193),(339,193),(352,216),(349,246),(276,246),(265,226)],[(277,213),(349,213),(354,249),(273,249),(265,230)]),('S','girtas_front_skin.json',[288,215],[(248,196),(330,196),(340,249),(243,249)],[(249,219),(333,219),(340,252),(242,252)])]:
 raw=json.loads((R/'data/animation'/manifest).read_text());s=raw.get('skin',raw);idle=read(s['parts']['torso']['texture']);abd=idle.copy();abd.putalpha(ImageChops.multiply(abd.getchannel('A'),mask(abd.size,core)))
 out={'joint':joint,'abdomen':save(abd,direction+'_abdomen',s['parts']['torso']['pivot']),'source_torso_sha256':s['parts']['torso']['sha256'],'abdomen_polygon':core,'chest_cut_polygon':cut}
 run=idle
 if direction=='E':
  # The old backing also included a second lock of hair. Raising the arm
  # exposed that rectangular duplicate; retain only its authored armor face.
  backing=read('res://assets/actors/shared_skin_pilot/girtas_267/torso_occlusion/side_armor_plane.png')
  armor_poly=[(213,156),(237,156),(268,176),(274,210),(251,236),(237,226),(237,203),(221,192),(217,178)]
  backing.putalpha(ImageChops.multiply(backing.getchannel('A'),mask(backing.size,armor_poly)))
  run=Image.new('RGBA',idle.size);run.alpha_composite(backing);run.alpha_composite(idle)
  out['run_backing_armor_polygon']=armor_poly
 sources={'idle':idle,'run':run}
 for state,im in sources.items():
  chest=im.copy();chest.putalpha(ImageChops.subtract(chest.getchannel('A'),mask(chest.size,cut)));out['chest_'+state]=save(chest,direction+'_chest_'+state,joint)
 if direction=='E':
  arm=read(s['parts']['far_arm']['texture']);pieces={}
  for key,poly,pivot,end in [('far_upper',[(338,183),(366,183),(376,217),(370,239),(346,239),(338,218)],[351,195],[362,232]),('far_forearm',[(344,226),(374,223),(385,249),(382,274),(359,278),(346,255)],[362,232],[370,267]),('far_hand',[(355,259),(382,253),(393,276),(381,291),(358,287)],[370,267],None)]:
   im=arm.copy();im.putalpha(ImageChops.multiply(im.getchannel('A'),mask(im.size,poly)));pieces[key]=save(im,'E_'+key,pivot);pieces[key].update({'end':end,'polygon':poly})
  out['far_parts']=pieces
 result[direction]=out
(R/'data/animation/girtas_articulated_torso.json').write_text(json.dumps(result,indent=2)+'\n');print('Rigid spine and far-arm art saved; source pixels and body widths retained.')
