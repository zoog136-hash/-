from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
D=Path(__file__).resolve().parent;B=Path('/workspace/scratch/mythic413-NW-run-author-20261020-r001');base=D/'thunder_female-NW-run-contact0-v07-actual-layer-join.png';source=B/'thunder_female-NW-run-contact0-v01-service.png';I=Image.open(base).convert('RGBA');M=np.asarray(Image.open(source).convert('RGBA'));old=np.asarray(I).copy()
poly=[(603,579),(640,578),(680,584),(719,600),(754,623),(782,652),(799,674),(789,686),(771,694),(752,694),(733,692),(716,689),(697,688),(676,688),(656,684),(634,678),(612,675),(590,671),(574,665),(566,655),(575,631)]
S=Image.new('L',(1254*4,1254*4),0);ImageDraw.Draw(S).polygon([(x*4,y*4)for x,y in poly],fill=255);sm=np.asarray(S.resize((1254,1254),Image.Resampling.LANCZOS)).astype(float)/255
rect=(560,570,810,775);yy,xx=np.mgrid[570:775,560:810];u=np.clip((xx-575)/230,0,1);d=55*np.sin(np.pi*u)**1.3;v=np.clip((yy-560)/180,0,1);w=v*v*(3-2*v);sy=yy-d*w;sx=xx.astype(float)
def bilinear(a):
 x0=np.floor(sx).astype(int);y0=np.floor(sy).astype(int);fx=sx-x0;fy=sy-y0
 if a.ndim==3:fx=fx[:,:,None];fy=fy[:,:,None]
 return (1-fx)*(1-fy)*a[y0,x0]+fx*(1-fy)*a[y0,x0+1]+(1-fx)*fy*a[y0+1,x0]+fx*fy*a[y0+1,x0+1]
rgba=bilinear(M.astype(float));a=bilinear(sm);rgba[:,:,3]*=a;layer=Image.fromarray(np.rint(rgba).clip(0,255).astype('uint8'));I.alpha_composite(layer,(560,570));arr=np.asarray(I).copy()
for n in ['contact0-actual-new-arm-foreground-protect-mask-v01.png','contact0-new-nearboot-cuff-protect-mask-v02.png']:
 mask=np.asarray(Image.open(D/n))>0;arr[mask]=old[mask]
out=D/'thunder_female-NW-run-contact0-v08-original-cloth-joint-occlusion.png';assert not out.exists();Image.fromarray(arr).save(out);changed=np.any(arr!=old,axis=2);roi=np.zeros(changed.shape,bool);roi[570:775,560:810]=True;assert not np.any(changed&(~roi));assert np.array_equal(arr[775:],old[775:]);S.resize((1254,1254),Image.Resampling.LANCZOS).save(D/'contact0-original-white-pleat-front-layer-mask-v04.png');layer.save(D/'contact0-original-pleat-cloth-posed-layer-v04.png')
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();proof=dict(status='ACTUAL_ORIGINAL_CLOTH_LAYER_JOINT_OCCLUSION_PENDING_QC',output=dict(path=str(out),sha256=h(out),bytes=out.stat().st_size,canvas=[1254,1254]),base=dict(path=str(base),sha256=h(base)),source_original_skirt=dict(path=str(source),sha256=h(source),semantic_polygon=poly),actual_cloth_projection='native x fixed; source_y=target_y-55*sin(pi*clamp((x-575)/230))^1.3*smoothstep(clamp((target_y-560)/180)); waist/bothsideanchors fixed; original pleat/goldhem material projected once',native_C=2560,whole_source_resampled=False,local_cloth_material_projection=True,new_colour_or_pleat_design=False,changed_pixels=int(changed.sum()),outside_ROI_changed=0,arm_nearboot_foreground_changed=0,lowerbody_y775_down_exact=True,source_or_actor_approved=False,actor_approvals_added=0)
p=D/'contact0-original-cloth-occlusion-provenance-v04.json';p.write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'output':str(out),'sha256':h(out),'changed_pixels':int(changed.sum()),'proof_sha256':h(p)}))
