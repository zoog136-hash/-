from pathlib import Path
import hashlib,json
from PIL import Image,ImageDraw

HERE=Path(__file__).parent
SOURCE=HERE/'thunder_female-NW-walk-contact0-v01-service.png'
EXPECTED='dc5da66b30171bdff9ab4c25cf5a22327debe8c8b41088693824433cb4e684db'
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==EXPECTED
OUT=HERE/'left-backswing-native-edit-v01';OUT.mkdir(exist_ok=False)
original=Image.open(SOURCE).convert('RGBA');assert original.size==(1254,1254)
old_polygon=[(573,440),(613,451),(628,480),(609,523),(592,553),(573,588),(542,619),(515,646),(508,680),(501,706),(447,709),(444,680),(460,639),(475,602),(497,575),(513,537),(527,500),(538,469),(550,449)]
old_mask=Image.new('L',original.size,0);ImageDraw.Draw(old_mask).polygon(old_polygon,fill=255)
shoulder=(589,458);elbow=(632,550);wrist=(674,648);fingers=(696,696)
mask=old_mask.copy();md=ImageDraw.Draw(mask)
def capsule(draw,a,b,r,fill):
 draw.line([a,b],fill=fill,width=2*r)
 for x,y in(a,b):draw.ellipse((x-r,y-r,x+r,y+r),fill=fill)
capsule(md,shoulder,elbow,48,255);capsule(md,elbow,wrist,36,255);capsule(md,wrist,fingers,24,255)
# The nape/head, actual RIGHT arm/staff and both complete legs remain outside.
for q in[(628,422),(705,475),(741,526),(804,448),(816,428),(514,944),(748,1117)]:assert mask.getpixel(q)==0,q
mask.save(OUT/'allowed-left-arm-only-mask.png');old_mask.save(OUT/'old-left-arm-erasure-mask.png')
derived=original.copy();derived.paste((0,0,0,0),(0,0),old_mask)
guide=ImageDraw.Draw(derived)
capsule(guide,shoulder,elbow,17,(225,40,185,255));capsule(guide,elbow,wrist,13,(225,40,185,255));capsule(guide,wrist,fingers,10,(225,40,185,255))
for x,y in(shoulder,elbow,wrist):guide.ellipse((x-6,y-6,x+6,y+6),fill=(255,255,255,255))
derived.save(OUT/'DERIVED-native1254-oldLEFTremoved-newBACKarm-guide.png')
# Costume samples contain only original cuff/gauntlet and shoulder material.
board=Image.new('RGBA',(300,200),(0,0,0,0));crops=[((475,560,554,636),(10,20)),((542,447,623,521),(130,20))]
for box,xy in crops:board.alpha_composite(original.crop(box),xy)
board.save(OUT/'original-left-gauntlet-puff-material-only.png')
meta={'status':'BOUNDED_NATIVE_ARM_EDIT_INPUT_NOT_SOURCE_APPROVAL','original':str(SOURCE),'original_sha256':EXPECTED,'virtual_C_fixed':2048,'factor_fixed':2,'new_anatomical_LEFT_near_free_chain':{'shoulder':shoulder,'elbow':elbow,'wrist':wrist,'fingers_end':fingers},'right_arm_staff':'UNCHANGED_PROTECTED','both_legs':'UNCHANGED_PROTECTED','nape':'UNCHANGED_PROTECTED','derived_input':'Only original nearLEFTarm alpha cleared, magenta targetscaffold added; original immutable.','old_left_erasure_polygon':old_polygon,'allowed_edit_mask_bbox':mask.getbbox(),'composition_rule':'Only generatedRGBA inside allowed-left-arm-only-mask; every RGBA byte outside must equal original. Do not resample or change C/roots.','costume_crops':crops,'actual_service_calls':0,'approval_added':0}
(OUT/'bounded-edit-input-contract.json').write_text(json.dumps(meta,indent=2)+'\n')
for name in['DERIVED-native1254-oldLEFTremoved-newBACKarm-guide.png','original-left-gauntlet-puff-material-only.png']:
 im=Image.open(OUT/name).convert('RGBA');bg=Image.new('RGB',im.size,(84,84,84));bg.paste(im,mask=im.getchannel('A'));bg.thumbnail((750,750));q=OUT/(Path(name).stem+'-private.jpg');bg.save(q,'JPEG',quality=88,optimize=True);assert q.stat().st_size<150000
print('BOUNDED_BACK_ARM_TARGET_READY',OUT,'mask_bbox',mask.getbbox(),'C2048_fixed','approval0')
