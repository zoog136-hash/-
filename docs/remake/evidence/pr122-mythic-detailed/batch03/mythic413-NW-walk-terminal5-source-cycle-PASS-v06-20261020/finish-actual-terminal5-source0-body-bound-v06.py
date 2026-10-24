"""Two actual native legs, complete shoes, shared body/root; no canvas fitting."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
from scipy.ndimage import map_coordinates
import numpy as np
import hashlib, json

P=Path(__file__).parent
R=P/'thunder_female-NW-walk-terminal5-local-joint-v01-service.png'
A=P/'terminal5-author-actual-contact-annotations-v01.json'
F=P/'thunder_female-NW-walk-terminal5-finished-source0-body-bound-v06.png'
assert not F.exists(), 'Frozen output must never be overwritten'
ann=json.loads(A.read_text())
r=Image.open(R).convert('RGBA'); raw=np.asarray(r); W,H=r.size
y,x=np.indices((H,W),dtype=float)
def polygon(points):
    m=Image.new('L',(W,H)); ImageDraw.Draw(m).polygon(points,fill=255); return m

legs=polygon([(537,729),(737,729),(805,831),(841,940),(870,1036),
              (899,1188),(773,1225),(704,1060),(679,950),(688,1110),
              (528,1110),(520,925),(530,792)])
cape=polygon([(727,690),(743,735),(763,775),(783,825),(813,875),
              (842,915),(914,978),(1138,1005),(1138,650)])
staff=polygon([(800,640),(813,640),(787,850),(780,864),(774,858),(779,829)])
protect=ImageChops.lighter(cape,staff)
legs=ImageChops.subtract(legs,protect)
lm=np.asarray(legs)>0
part=raw.copy(); part[:,:,3][~lm]=0

left=np.asarray(ann['LEFT_actual_heel_source'],float)
right=np.asarray(ann['RIGHT_actual_forefoot_source'],float)
left_target=np.array([610.,1010.])
right_target=np.array([776.8386376044843,1099.757773844036])
dl=left_target-left; dr=right_target-right
# The two complete shoes have disjoint endpoint domains: no transverse shoe warp.
blend=np.clip((x-680.)/60.,0,1); blend=blend*blend*(3-2*blend)
dx=dl[0]*(1-blend)+dr[0]*blend
dy=dl[1]*(1-blend)+dr[1]*blend
v=np.clip((y-760.)/235.,0,1); v=v*v*(3-2*v)
dy=-35.*(1-v)+dy*v
dx=(10.*(1-blend))*(1-v)+dx*v
coords=np.array([y-dy,x-dx])
rgba=part.astype(float)/255.; a=rgba[:,:,3]
wa=map_coordinates(a,coords,order=1,mode='constant',cval=0)
rgb=np.stack([map_coordinates(rgba[:,:,c]*a,coords,order=1,
                 mode='constant',cval=0) for c in range(3)],2)
rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-7)
moved=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255+.5,0,255)),'RGBA')
# Restore approved SOURCE0 actualbody/costume/fullstaff, with its intended rigid bob.
Bpath=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/left-backswing-native-edit-v02/thunder_female-NW-walk-contact0-LEFTbackswing-bounded-v02.png')
B=Image.open(Bpath).convert('RGBA')
from PIL import ImageFilter
protect0=Image.open(P/'terminal5-original-body-equipment-protection-control.png').convert('L')
old=Image.open('/workspace/scratch/mythic413-NW-walk-LOAD1-author-20261020-v01/old-legs-erasure-mask.png').convert('L').filter(ImageFilter.MaxFilter(25))
old=ImageChops.lighter(old,polygon([(520,714),(715,714),(749,835),(788,966),(850,1145),(711,1155),(650,975),(570,954),(440,938),(446,848),(495,786)]))
topskin=polygon([(574,692),(589,698),(617,704),(650,706),(678,705),(698,710),(715,710),(730,746),(548,746),(558,718)])
top_shift=Image.new('L',(W,H));top_shift.paste(topskin,(0,-6));protect0=ImageChops.subtract(protect0,top_shift)
old_shift=Image.new('L',(W,H));old_shift.paste(old,(0,-6));old_shift=ImageChops.lighter(old_shift,top_shift);old_shift=ImageChops.subtract(old_shift,protect0)
body=Image.new('RGBA',(W,H));body.paste(B,(0,-6));body.paste((0,0,0,0),(0,0),old_shift)
out=moved.copy();out.alpha_composite(body)
# Rigged legs remain behind original skirt/coat/staff and empty nearLEFT hand.
out=Image.composite(body,out,protect0)
out.save(F)
legs.save(P/'terminal5-actual-leg-semantic-matte-v06.png')
protect0.save(P/'terminal5-original-gear-protection-v06.png')
top_shift.save(P/'terminal5-original-thigh-skin-join-exception-v06.png')
moved.save(P/'terminal5-actual-articulated-leg-layer-v06.png')
changed=np.any(raw!=np.asarray(out),axis=2)
d={'status':'ACTUAL_TERMINAL5_SOURCE_PAIR_AND_WHOLE6_PENDING_INDEPENDENT_QC',
   'raw':str(R),'raw_sha256':hashlib.sha256(R.read_bytes()).hexdigest(),
   'output':str(F),'output_sha256':hashlib.sha256(F.read_bytes()).hexdigest(),
   'physical_canvas_fixed':2048,'rig_root_in_unpadded_frame':[641,1058.3],
   'storage_translation':[0,0],
   'LEFT_actual_heel_source':left.tolist(),'LEFT_actual_heel_target':left_target.tolist(),
   'RIGHT_actual_forefoot_source':right.tolist(),
   'RIGHT_actual_forefoot_target':right_target.tolist(),
   'LEFT_complete_boot_translation':dl.tolist(),
   'RIGHT_complete_boot_translation':dr.tolist(),
   'actual_4_to5_forefoot_delta':[111.35431880224218,100.21888692201796],
   'body_scope':'ApprovedSOURCE0 actualbody+entirestaff translatedbyintended[0,-6]bob only; newactual5 semanticlegs with hip-to-calf articulation, fixedC/root',
   'anatomy':'Genuine nearLEFT lateAIR/farRIGHT terminal stance; complete shoe rigid domains and smooth actual calf/knee articulation',
   'source_sampling':'Premultiplied actual semantic leg pixels only; transparent outside own matte, no end clamp',
   'changed_RGBA_pixels':int(changed.sum()),
   'protected_gear_RGBA_changes':int((np.any(np.asarray(out)!=np.asarray(body),axis=2)&(np.asarray(protect0)>0)).sum()),
   'upper_body_RGBA_changes':int((np.any(np.asarray(out)!=np.asarray(body),axis=2)&(y<708)).sum()),'upper_body_change_scope':'Only original lowerthighskin removal below actual white/gold skirt; separate exception matte, never hair/torso/arms/gear','actual_body_authority':str(Bpath),'actual_body_sha256':hashlib.sha256(Bpath.read_bytes()).hexdigest(),'body_bob_and_rigid_staff':[0,-6],'approval_added':0}
(P/'terminal5-finished-native-limbs-proof-v06.json').write_text(json.dumps(d,indent=2)+'\n')
for name,img in [('terminal5-finished-v06-whole-private.jpg',out),
                 ('terminal5-finished-v06-legs-private.jpg',out.crop((450,630,940,1200)))]:
    bg=Image.new('RGB',img.size,(80,80,80)); bg.paste(img,mask=img.getchannel('A'))
    bg.thumbnail((750,750)); bg.save(P/name,quality=85,optimize=True)
    assert (P/name).stat().st_size<150000
print(json.dumps({k:d[k] for k in ['output_sha256','LEFT_complete_boot_translation',
       'RIGHT_complete_boot_translation','protected_gear_RGBA_changes','upper_body_RGBA_changes']}))
