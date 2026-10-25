"""Actual-costume pose CONTROL only. Never an approved animation resource."""
from pathlib import Path
import math,hashlib,json
from PIL import Image,ImageDraw,ImageChops

HERE=Path(__file__).parent
BASE=HERE/'thunder_female-NW-walk-contact0-v01-service.png'
assert hashlib.sha256(BASE.read_bytes()).hexdigest()=='dc5da66b30171bdff9ab4c25cf5a22327debe8c8b41088693824433cb4e684db'
OUT=HERE/'left-backswing-native-edit-v02';OUT.mkdir(exist_ok=False)
source=Image.open(BASE).convert('RGBA')
old_mask=Image.open(HERE/'left-backswing-native-edit-v01/old-left-arm-erasure-mask.png').convert('L')
allowed=Image.open(HERE/'left-backswing-native-edit-v01/allowed-left-arm-only-mask.png').convert('L')
draw=ImageDraw.Draw(allowed);draw.line([(674,648),(721,704)],fill=255,width=52)
for x,y in[(674,648),(721,704)]:draw.ellipse((x-26,y-26,x+26,y+26),fill=255)
draw.rectangle((0,0,1253,434),fill=0)
for xy in[(628,422),(705,475),(741,526),(804,448),(816,428),(514,944),(748,1117)]:assert allowed.getpixel(xy)==0
allowed.save(OUT/'allowed-actual-LEFT-backarm-mask-v02.png')
derived=source.copy();derived.paste((0,0,0,0),(0,0),old_mask)
old_shoulder=(589.,458.);old_elbow=(550.,558.);old_wrist=(482.,640.)
new_shoulder=(589.,458.);new_elbow=(632.,550.);new_wrist=(674.,648.)
ops=[]
def move_part(name,partmask,a,b,c,d):
 mask=ImageChops.multiply(source.getchannel('A'),partmask)
 rgba=source.copy();rgba.putalpha(mask)
 old=(b[0]-a[0],b[1]-a[1]);new=(d[0]-c[0],d[1]-c[1])
 scale=math.hypot(*new)/math.hypot(*old);angle=math.atan2(new[1],new[0])-math.atan2(old[1],old[0])
 co=math.cos(angle);si=math.sin(angle)
 tx=c[0]-scale*(co*a[0]-si*a[1]);ty=c[1]-scale*(si*a[0]+co*a[1])
 inv=(co/scale,si/scale,-(co*tx+si*ty)/scale,-si/scale,co/scale,(si*tx-co*ty)/scale)
 result=rgba.transform(source.size,Image.Transform.AFFINE,inv,resample=Image.Resampling.BICUBIC)
 derived.alpha_composite(result)
 ops.append({'part':name,'old_joint_start':a,'old_joint_end':b,'target_joint_start':c,'target_joint_end':d,'reference_only_projected_scale':scale,'reference_only_rotation_degrees':math.degrees(angle),'method':'RGBA segment affine for model pose control ONLY, not final game source'})
up=old_mask.copy();ImageDraw.Draw(up).rectangle((0,566,1253,1253),fill=0)
fore=old_mask.copy();ImageDraw.Draw(fore).rectangle((0,0,1253,534),fill=0)
move_part('upperarm_material_scaffold',up,old_shoulder,old_elbow,new_shoulder,new_elbow)
move_part('forearm_gauntlet_emptyglove_material_scaffold',fore,old_elbow,old_wrist,new_elbow,new_wrist)
derived.save(OUT/'DERIVED-PAINTED-native1254-LEFTbackswing-pose-control-only.png')
# Close native arm crop strengthens new visual target; no old-pose material ref.
derived.crop((535,425,760,745)).save(OUT/'DERIVED-new-backswing-arm-close-control-only.png')
meta={'status':'POSE_CONTROL_INPUT_ONLY_NEVER_FINAL_SOURCE_OR_APPROVAL','original_master_sha256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'fixed_virtual_C':2048,'body_unit_factor':2,'generation_target':'LEFTnear arm real backswing preserving allbody/RIGHTstaff/legs','actual_source_resampling':False,'derived_control_reference_arm_resampled':True,'resampling_scope':'Only isolated oldcostume segments in temporary MODEL INPUT, not original, not game resource, not final output. Service must paint/refine genuine arm anew.','ops':ops,'native_size':[1254,1254],'new_allowed_mask_bbox':allowed.getbbox(),'final_output_rule':'Native service art only inside explicit allowed mask; all originalRGBA outside exact; no resize of original or service output.','service_calls_this_variant':0,'actor_approval_added':0}
(OUT/'painted-backswing-control-input-contract-v02.json').write_text(json.dumps(meta,indent=2)+'\n')
for n in['DERIVED-PAINTED-native1254-LEFTbackswing-pose-control-only.png','DERIVED-new-backswing-arm-close-control-only.png']:
 im=Image.open(OUT/n).convert('RGBA');bg=Image.new('RGB',im.size,(84,84,84));bg.paste(im,mask=im.getchannel('A'));bg.thumbnail((750,750));bg.save(OUT/(Path(n).stem+'-private.jpg'),'JPEG',quality=90,optimize=True)
print('PAINTED_BACK_ARM_POSE_CONTROL_ONLY_READY',OUT,'C2048fixed','approval0')
