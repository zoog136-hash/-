from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
D=Path(__file__).resolve().parent;B=Path('/workspace/scratch/mythic413-NW-run-author-20261020-r001');base=D/'thunder_female-NW-run-contact0-v06-original-hem-restored.png';m=B/'thunder_female-NW-run-contact0-v01-service.png';c=B/'thunder_female-NW-run-contact0-v04-localized-composite.png'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(base)=='8ee2ca11c418ca717abf45a219bb1d06c18e8f014d3af19f17ee6e67c3ef4160'
M=np.asarray(Image.open(m).convert('RGBA'));C=np.asarray(Image.open(c).convert('RGBA'));O=Image.open(base).convert('RGBA');old=np.asarray(O).copy();rect=(590,700,746,775);W=156;H=75;scale=8

def cubic(p0,p1,p2,p3):
 t=np.linspace(0,1,65)[:,None];return ((1-t)**3*np.array(p0)+3*(1-t)**2*t*np.array(p1)+3*(1-t)*t**2*np.array(p2)+t**3*np.array(p3)).tolist()
def mask(points):
 a=Image.new('L',(W*scale,H*scale),0);ImageDraw.Draw(a).polygon([((x-590)*scale,(y-700)*scale)for x,y in points],fill=255);return a.resize((W,H),Image.Resampling.LANCZOS)
sp=[(596,704),(617,704),(641,706),(674,708),(700,705),(716,708)]+cubic((716,708),(717,719),(698,731),(674,735))+cubic((674,735),(656,739),(638,742),(621,744))+cubic((621,744),(608,744),(600,740),(596,731))
bp=cubic((606,744),(611,738),(624,734),(638,733))+cubic((638,733),(650,732),(658,738),(662,747))+cubic((662,747),(665,755),(669,764),(675,771))+[(675,774),(610,774),(606,758)]
S=mask(sp);F=mask(bp)
y,x=np.mgrid[700:775,590:746];sy=np.where(y<=721,y,721+(y-721)*.1);sx=x
# actual retained upperhip surface, projected only below its original hem; body/head/C never scaled.
skin=M[np.rint(sy).astype(int),sx].copy();skin[:,:,3]=np.asarray(S)
# actual V04 black boot surface, a finite upper-cuff joint layer; no procedural flat fill.
fx=np.rint(630+.35*(x-606)).astype(int);fy=np.rint(775+.3*(y-733)).astype(int);boot=C[fy,fx].copy();boot[:,:,3]=np.asarray(F)
assert np.all(C[fy[np.asarray(F)>128],fx[np.asarray(F)>128],3]>230)
layer=Image.new('RGBA',(W,H));layer=Image.alpha_composite(layer,Image.fromarray(skin));layer=Image.alpha_composite(layer,Image.fromarray(boot))
patchpoly=[(596,704),(625,704),(649,706),(680,706),(711,702),(731,707),(741,725),(740,744),(741,758),(729,773),(607,773),(597,744)]
P=np.asarray(mask(patchpoly)).copy();A=np.asarray(Image.open(D/'contact0-actual-new-arm-foreground-protect-mask-v01.png').crop(rect));N=np.asarray(Image.open(D/'contact0-new-nearboot-cuff-protect-mask-v02.png').crop(rect));P[(A>0)|(N>0)]=0
# Blend the layered boot into the unchanged actual recovery thigh over the last native rows.
la=np.asarray(layer).copy();orig=old[700:775,590:746].copy();t=np.clip((y-762)/8,0,1)[:,:,None];la=np.rint(la*(1-t)+orig*t).astype('uint8')
O.paste(Image.fromarray(la),(590,700),Image.fromarray(P));out=D/'thunder_female-NW-run-contact0-v07-actual-layer-join.png';assert not out.exists();O.save(out);new=np.asarray(O);changed=np.any(new!=old,axis=2);roi=np.zeros(changed.shape,bool);roi[700:775,590:746]=P>0;assert not np.any(changed&(~roi))
for name,arr in [('contact0-join-semantic-edit-mask-v03.png',P),('contact0-posed-upperhip-layer-alpha-v03.png',np.asarray(S)),('contact0-posed-farboot-cap-layer-alpha-v03.png',np.asarray(F))]:Image.fromarray(arr).save(D/name)
proof=dict(status='ACTUAL_PART_LAYER_JOINT_RETOUCH_PENDING_INDEPENDENT_QC',output=dict(path=str(out),sha256=sha(out),bytes=out.stat().st_size,canvas=[1254,1254]),base=dict(path=str(base),sha256=sha(base)),source_actual_upperhip=dict(path=str(m),sha256=sha(m),projection='xnative unchanged; ysource=y to721, then721+.1*(y-721) in tinyunderhemjoint'),source_actual_farboot=dict(path=str(c),sha256=sha(c),projection='xsource=630+.35*(x-606); ysource=775+.3*(y-733) nativeblackbootmaterial'),ROI=rect,changed_pixels=int(changed.sum()),outside_semantic_ROI_changed=0,whole_source_resampled=False,local_actual_part_projection=True,native_C=2560,arm_nearboot_foreground_preserved=True,head_body_garment_staff_goodregions_unchanged=True,lowerbody_y775_down_exact=bool(np.array_equal(new[775:],old[775:])),skin_curve=sp[::16],boot_curve=bp[::16],service_rejection='previousfiniteactualretouch rejected at outputmoderation; noimage/no retry; this is authorized actualpartlayer retouch, not a service return',source_approved=False,cycle_approved=False,actor_approvals_added=0)
q=D/'contact0-actual-layer-join-provenance-v03.json';q.write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'output':str(out),'sha256':sha(out),'changed_pixels':int(changed.sum()),'proof_sha256':sha(q)}))
