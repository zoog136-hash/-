"""One authored front upper-body key; preserve original crown, arms and weapon."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageChops
R=Path(__file__).resolve().parents[2];D=R/'assets/actors/shared_skin_pilot/girtas_267/front_lean';D.mkdir(parents=True,exist_ok=True)
s=json.loads((R/'data/animation/girtas_front_skin.json').read_text())
def read(p):return Image.open(R/p.removeprefix('res://')).convert('RGBA')
def mask(poly):
 m=Image.new('L',(512,512));ImageDraw.Draw(m).polygon(poly,fill=255);return m
def cut(im,poly):
 o=im.copy();o.putalpha(ImageChops.multiply(o.getchannel('A'),mask(poly)));return o
def save(im,name,pivot):
 clean=Image.new('RGBA',im.size);clean.alpha_composite(im);p=D/(name+'.png');clean.save(p);return {'texture':'res://'+str(p.relative_to(R)),'pivot':pivot,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
authored=Image.open(D/'authored_source.png').convert('RGBA');registered=Image.new('RGBA',(512,512));registered.alpha_composite(authored.resize((round(authored.width*.33),round(authored.height*.33)),Image.Resampling.LANCZOS),(60,17))
# Only the face/neck and chest planes are used from the authored key. The
# redesigned crown, shoulders, weapon and lower body are deliberately excluded.
face_poly=[(261,105),(314,105),(329,124),(330,151),(319,171),(269,171),(251,145)]
chest_poly=[(249,144),(328,144),(350,175),(339,209),(320,229),(257,229),(236,205),(232,174)]
head=Image.new('RGBA',(512,512));crown=cut(read(s['parts']['head']['texture']),[(0,0),(511,0),(511,90),(0,90)]);head.alpha_composite(crown,(0,40));face=cut(registered,face_poly);face=face.transform((512,512),Image.Transform.AFFINE,(1/.85,0,288-288/.85,0,1/.85,135-135/.85),Image.Resampling.BICUBIC);head.alpha_composite(face,(0,12))
torso=read(s['parts']['torso']['texture']);hole=mask([(255,132),(323,132),(338,170),(329,213),(263,213),(244,189),(246,160)]);torso.putalpha(ImageChops.subtract(torso.getchannel('A'),hole));torso.alpha_composite(cut(registered,chest_poly),(0,9))
meta={'schema':1,'authorship':'New 2D face/neck/chest lean key, not recovered original motion. Original crown and outer armor retained; no generated arms/weapon/lower body used.','authored_source_sha256':hashlib.sha256((D/'authored_source.png').read_bytes()).hexdigest(),'fixed_registration':{'scale':.33,'offset':[60,17]},'face_polygon':face_poly,'chest_polygon':chest_poly,'original_crown_offset':[0,40],'authored_face_registration':{'scale':.85,'center':[288,135]},'authored_face_offset':[0,12],'authored_chest_offset':[0,9],'head':save(head,'run_head',[288,140]),'torso':save(torso,'run_torso',[288,245])}
(R/'data/animation/girtas_front_lean.json').write_text(json.dumps(meta,indent=2)+'\n')
print('Masked front lean key built; original crown, arms, sword and lower body preserved.')
