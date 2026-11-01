"""Authored E cutout binding; never modifies the preserved production sheet."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops,ImageFilter
import hashlib,json,sys
CHECK="--check" in sys.argv
def write_image(part,path):
 if CHECK:
  assert path.is_file() and Image.open(path).convert("RGBA").tobytes()==part.tobytes(), str(path)
 else: part.save(path)
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'assets/actors/eight_direction/native_locomotion_staging/girtas_267/r049/E-idle.png'
im=Image.open(source).convert('RGBA').crop((46,4,473,499))
folder=ROOT/'assets/actors/shared_skin_pilot/girtas_267';folder.mkdir(parents=True,exist_ok=True)
def mask(poly):
 m=Image.new('L',im.size);ImageDraw.Draw(m).polygon(poly,fill=255);return m
entry={'source':str(source.relative_to(ROOT)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_cell':[46,4,427,495],'hip':[303,277],'articulated_direction':'E','torso_turn_pack':'res://data/animation/girtas_torso_occlusion.json','body_scale':0.219105011732,'rig':{'waist':[304,235],'neck':[298,120],'shoulder_offset':[-17.1,-12.5],'arm_lengths':[10.5,10.25]},'retarget':{'hip_y':-46,'waist_offset':[0.219,-9.203],'hip_offsets':[[6.1,-0.44],[-5.26,0]],'foot_bias':[7,-10],'ground_y':[-4,0],'ankle_height':8,'weapon_downward_gain':0.45,'lengths':[[18,20],[19.5,22.5]]},'parts':{},'authorship':'Visible source polygons rebound to shared motion. Fixed limb lengths and new guard pose are TWILIGHT authoring, not recovered original joints or original-game animation.'}
masks={}
def save(key,poly,pivot,end=None,exclude=None):
 m=mask(poly)
 if key == 'weapon_hand':
  m=m.filter(ImageFilter.MaxFilter(17))
  ImageDraw.Draw(m).rectangle((0,0,181,287),fill=0)
 if exclude is not None:m=ImageChops.subtract(m,exclude)
 masks[key]=m
 part=im.copy();part.putalpha(ImageChops.multiply(im.getchannel('A'),m));path=folder/(key+'.png');write_image(part,path)
 entry['parts'][key]={'texture':'res://'+str(path.relative_to(ROOT)),'pivot':pivot,'end':end,'polygon':poly,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 if key.startswith('foot_'):entry['parts'][key]['sole_y']=part.getbbox()[3]-1
save('upper_arm',[(203,176),(235,175),(245,192),(235,212),(226,238),(204,236),(193,220),(194,195)],[226,178],[218,225])
save('forearm',[(199,220),(230,220),(229,240),(221,260),(221,282),(207,291),(190,278),(189,254)],[218,225],[207,270])
save('weapon_hand',[(193,245),(220,248),(229,266),(219,288),(206,306),(197,345),(179,365),(155,381),(135,405),(118,430),(98,450),(69,471),(26,491),(0,495),(12,481),(49,451),(76,414),(100,390),(125,366),(151,342),(165,313),(168,292),(179,276),(188,262)],[207,270],[12,487])
save('far_arm',[(341,187),(363,187),(373,218),(378,245),(388,273),(378,286),(358,282),(347,261),(340,231)],[351,195])
legs=[{'hip':[331,275],'knee':[349,350],'ankle':[351,430],'thigh':[(317,268),(345,269),(360,303),(367,342),(356,369),(331,362),(321,321)],'shin':[(335,346),(360,343),(365,379),(369,421),(360,443),(337,440),(331,400)],'foot':[(338,421),(361,421),(374,444),(393,449),(396,464),(381,469),(342,465),(333,448)]}, {'hip':[279,277],'knee':[251,355],'ankle':[229,450],'thigh':[(266,267),(299,274),(287,311),(281,343),(263,368),(237,366),(227,341),(241,304)],'shin':[(239,347),(269,350),(259,384),(249,419),(246,453),(221,461),(216,435),(223,393)],'foot':[(219,441),(243,443),(251,468),(247,491),(222,493),(206,484),(208,465)]}]
leg_union=Image.new('L',im.size)
for i,l in enumerate(legs):
 for key,pivot,end in [('thigh',l['hip'],l['knee']),('shin',l['knee'],l['ankle']),('foot',l['ankle'],None)]:
  save(f'{key}_{i}',l[key],pivot,end);leg_union=ImageChops.lighter(leg_union,masks[f'{key}_{i}'])
save('cape',[(250,263),(271,275),(240,311),(220,348),(201,385),(182,414),(153,426),(163,396),(193,350),(212,310)],[250,263],exclude=leg_union)
save('head',[(269,0),(330,0),(337,34),(335,66),(326,82),(327,103),(321,118),(303,133),(278,133),(268,119),(265,101),(275,80),(268,62)],[298,120])
# Remove detached visible pieces exactly; fill only small opaque armor joint overlaps.
removed=Image.new('L',im.size)
for m in masks.values():removed=ImageChops.lighter(removed,m)
body=im.copy();body.putalpha(ImageChops.subtract(im.getchannel('A'),removed))
# The entire old blade domain is excluded from the torso, including antialiased edges.
body_alpha=body.getchannel('A');ImageDraw.Draw(body_alpha).polygon([(0,290),(176,290),(205,325),(194,373),(157,428),(105,472),(0,495)],fill=0);body.putalpha(body_alpha)
# Below the belt only the central hanging armor belongs to the pelvis.
keep=Image.new('L',im.size);kd=ImageDraw.Draw(keep);kd.rectangle((0,0,427,277),fill=255);kd.polygon([(294,270),(332,270),(336,315),(334,370),(315,411),(279,423),(278,396),(296,347)],fill=255)
body.putalpha(ImageChops.multiply(body.getchannel('A'),keep))
entry['pelvis_keep']='belt above y277 and central hanging armor polygon; detached source boot remnants excluded'
entry['body_blade_exclusion']=[[0,290],[176,290],[205,325],[194,373],[157,428],[105,472],[0,495]]
# Small joint caps use existing armor pixels copied from immediately adjacent armor.
# No inferred hidden limb is represented as an original source fragment.
underlays=[([202,176,233,190],[240,176,271,190]),([341,190,354,211],[327,190,340,211])]
for dest,src in underlays:
 patch=im.crop(src);body.alpha_composite(patch,(dest[0],dest[1]))
entry['authored_joint_caps']=underlays
# Authored near pauldron grouping: visible shoulder armor and its lateral spikes.
# Cut from the already separated body, so no arm or weapon pixels are duplicated.
shoulder_poly=[(61,169),(180,153),(195,142),(214,134),(246,145),(247,163),(236,182),(221,193),(202,192),(184,214),(143,247),(164,216),(181,190),(85,232),(155,188),(65,191)]
shoulder_mask=mask(shoulder_poly)
shoulder=body.copy();shoulder.putalpha(ImageChops.multiply(body.getchannel('A'),shoulder_mask))
shoulder_path=folder/'shoulder_armor.png';write_image(shoulder,shoulder_path)
entry['parts']['shoulder_armor']={'texture':'res://'+str(shoulder_path.relative_to(ROOT)),'pivot':[226,178],'polygon':shoulder_poly,'derived_from':'separated body before torso partition','sha256':hashlib.sha256(shoulder_path.read_bytes()).hexdigest()}
body.putalpha(ImageChops.subtract(body.getchannel('A'),shoulder_mask))
# Small explicitly authored joint backing behind the movable pauldron.
backing=im.crop((290,190,306,210));backing.putalpha(ImageChops.multiply(backing.getchannel('A'),shoulder_mask.crop((229,161,245,181))));body.alpha_composite(backing,(229,161))
entry['shoulder_joint_backing']={'source_rect':[290,190,306,210],'destination':[229,161],'authorship':'copied visible armor backing, not recovered hidden anatomy'}
for key,pivot,rect in [('torso',[304,235],(0,0,427,246)),('pelvis',[303,277],(0,239,427,495))]:
 m=Image.new('L',im.size);ImageDraw.Draw(m).rectangle(rect,fill=255)
 part=body.copy();part.putalpha(ImageChops.multiply(body.getchannel('A'),m));path=folder/(key+'.png');write_image(part,path)
 entry['parts'][key]={'texture':'res://'+str(path.relative_to(ROOT)),'pivot':pivot,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'partition_rect':rect}
manifest_path=ROOT/'data/animation/girtas_shared_skin.json'
serialized=json.dumps({'schema':1,'direction':'E','skin':entry},indent=2)+'\n'
if CHECK: assert manifest_path.read_text()==serialized
else: manifest_path.write_text(serialized)
print('Girtas source preserved; authored parts:',len(entry['parts']))
