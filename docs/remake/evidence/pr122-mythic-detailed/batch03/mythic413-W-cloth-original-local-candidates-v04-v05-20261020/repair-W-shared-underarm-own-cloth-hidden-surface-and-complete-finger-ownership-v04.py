from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import map_coordinates,label
import numpy as np,json,hashlib
D=Path(__file__).parent;OLD=D/'common-own-W-native-LEFT-materials-v03';O=D/'common-own-W-native-LEFT-materials-v04';O.mkdir(exist_ok=False)
HND=OLD/'W-own-native-complete-LEFT-and-old-erased-BODY-readonly-handoff-v03.json';h=json.loads(HND.read_text());src=np.asarray(Image.open(h['source']['path']).convert('RGBA'));H,W=src.shape[:2];yy,xx=np.indices((H,W))
def rec(p):
 p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
def pmask(poly):
 a=Image.new('L',(W,H));ImageDraw.Draw(a).polygon(poly,fill=255);return np.asarray(a)>0
oldmask=np.asarray(Image.open(h['semantic_mattes']['LEFT-far-complete-curved-cuff-forearm-free-hand']['path']))>0
# Complete native fingertip ownership, preserving every material/AA sample.
# The short southwest arc below the pinky was not owned by the older matte.
finger_poly=[(702,640),(750,640),(758,658),(759,678),(754,694),(744,705),(730,718),(721,722),(714,718),(709,714),(705,715),(701,709),(701,701),(698,694),(700,680),(698,669),(699,654)]
mask=(oldmask|pmask(finger_poly))&(src[:,:,3]>0)
part=np.zeros_like(src);part[mask]=src[mask];body=src.copy();body[mask]=0
# Genuine blue W coat material from its own uninterrupted visible panel.
# The patch is a cloth surface behind the former forearm/hand, not a new arm,
# wholebody fit, service art or flat-color fill. Source and target charts are
# pinned in native coordinates; all original visible BODY pixels remain above.
quad=[[770.,690.],[820.,690.],[820.,790.],[770.,790.]]
# UV map into the existing actual blue cloth, with a gentle diagonal drape.
u=np.clip((xx-670.)/112.,0,1);v=np.clip((yy-510.)/225.,0,1)
sx=770.+50.*u;sy=690.+100.*v
coords=[sy,sx];pm=src.astype(float)/255.;pm[:,:,:3]*=pm[:,:,3,None]
z=np.stack([map_coordinates(pm[:,:,i],coords,order=1,mode='constant',cval=0,prefilter=False)for i in range(4)],axis=2);alpha=z[:,:,3];rgb=np.divide(z[:,:,:3],alpha[:,:,None],out=np.zeros_like(z[:,:,:3]),where=alpha[:,:,None]>1e-9);z=np.rint(np.dstack([rgb,alpha]).clip(0,1)*255).astype('uint8')
clothpoly=[(682,514),(704,533),(726,555),(747,579),(765,606),(778,641),(778,726),(728,736),(702,722),(684,680),(672,621),(668,571)]
cm=pmask(clothpoly);z[~cm]=0
assert np.min(z[cm,3])>=250,'Donor cloth chart must be a genuine continuous opaque surface'
under=Image.fromarray(z);under.alpha_composite(Image.fromarray(body));fixed=np.asarray(under)
# The opaque original clothing is above the new hidden layer, bit-exact.
good=(body[:,:,3]==255);assert np.array_equal(fixed[good],body[good])
protect=np.asarray(Image.open(h['fixed_original_RIGHTgear_conservative_native_support']['path']))>0
assert np.array_equal(fixed[protect],src[protect]);assert not np.any(cm&protect)
ap=O/'original-actual-W-LEFT-complete-curved-cuff-forearm-all-fingers-material-v04.png';bp=O/'actual-W-LEFT-erased-BODY-with-own-hidden-blue-coat-surface-v04.png';mp=O/'original-W-LEFT-complete-cuff-all-fingers-native-ownership-mask-v04.png';cp=O/'actual-own-W-hidden-blue-coat-surface-native-material-v04.png';cmask=O/'actual-own-W-hidden-blue-coat-surface-native-support-mask-v04.png'
for p,a in [(ap,part),(bp,fixed),(cp,z)]:Image.fromarray(a).save(p)
Image.fromarray(mask.astype('uint8')*255).save(mp);Image.fromarray(cm.astype('uint8')*255).save(cmask)
recipe=dict(source=rec(h['source']['path']),previous_BODY=rec(h['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots']['body']['path']),new_BODY=rec(bp),actual_cloth_layer=rec(cp),actual_cloth_support=rec(cmask),donor_native_quad=quad,target_support_polygon_native=clothpoly,inverse_UV_formula=dict(u='clip((native_x-670)/112,0,1)',v='clip((native_y-510)/225,0,1)',source_x='770+50*u',source_y='690+100*v'),source_pixels_flat_painted=False,sampling='Premultiplied bilinear original W actual cloth only',composition='Actual new hidden cloth behind original opaque BODY, true source-over; old moving LEFT source is separately complete',new_fingertip_ownership_poly=finger_poly,new_moving_original_RGBA_source_mismatch=int(np.any(part[mask]!=src[mask],axis=1).sum()),original_opaque_BODY_RGBA_mismatch=int(np.any(fixed[good]!=body[good],axis=1).sum()),original_RIGHTgear_RGBA_mismatch=int(np.any(fixed[protect]!=src[protect],axis=1).sum()),changed_bbox_native=None,C_root_unit_changed=False,actor_approvals_added=0)
y,x=np.where(np.any(fixed!=np.asarray(Image.open(recipe['previous_BODY']['path'])),axis=2));recipe['changed_bbox_native']=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)];rp=O/'W-native-underarm-cloth-material-ownership-retouch-recipe-and-preservation-proof-v04.json';rp.write_text(json.dumps(recipe,indent=2)+'\n')
h.update(schema='MYTHIC413_W_COMPLETE_LEFT_AND_GENUINE_HIDDEN_COAT_READONLY_HANDOFF_V04',status='ACTUAL_SOURCE_MATERIAL_REPAIR_PENDING_INDEPENDENT_UNDERARM_QC',parts={'LEFT-far-complete-curved-cuff-forearm-free-hand':rec(ap)},semantic_mattes={'LEFT-far-complete-curved-cuff-forearm-free-hand':rec(mp)},body_inputs={'LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots':dict(body=rec(bp),old_forearm_erasure_support=rec(mp))},genuine_hidden_coat_material_repair=rec(rp),previous_handoff_preserved=rec(HND),source_ownership_recipe=recipe)
p=O/'W-own-native-complete-LEFT-and-repaired-hidden-coat-BODY-readonly-handoff-v04.json';p.write_text(json.dumps(h,indent=2)+'\n')
b=(650,470,840,860);board=Image.new('RGB',(570,410),(82,85,89));dd=ImageDraw.Draw(board)
for i,a in enumerate([src,np.asarray(Image.open(recipe['previous_BODY']['path'])),fixed]):
 im=Image.fromarray(a).crop(b);bg=Image.new('RGBA',im.size,(82,85,89,255));bg.alpha_composite(im);board.paste(bg.convert('RGB'),(190*i,20));dd.text((190*i+2,1),['original','old BODY','own-cloth BODY'][i],fill='white')
board.save(O/'private-W-native-shared-hidden-coat-repair-comparison-v04.jpg',quality=86,optimize=True)
print(json.dumps(dict(handoff=rec(p),recipe=rec(rp),changed_bbox=recipe['changed_bbox_native'],original_opaque0=recipe['original_opaque_BODY_RGBA_mismatch'])))
