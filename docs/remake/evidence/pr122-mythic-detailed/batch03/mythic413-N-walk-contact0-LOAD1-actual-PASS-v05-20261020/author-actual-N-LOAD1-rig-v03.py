from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,hashlib,json,math
B=Path(__file__).parent;D=B/'actual-LOAD1-rig-v03';D.mkdir();P=Path('/workspace/scratch/mythic413-N-walk-author-20261020-r001/contact0-r002-fixedC1920/N-contact0-r002-left-forward-bounded-v02.png');raw=P.read_bytes();assert hashlib.sha256(raw).hexdigest()=='332ef97f0a973aa5329a25f02cf0139b29c92c38e4c2aaca6424379d741466cb';src=Image.open(P).convert('RGBA');W,H=src.size
V=B/'localized-LOAD1-v03';master=Image.open(V/'original-upperbody-native1254-bobbed-master.png').convert('RGBA');mask=Image.open(V/'allowed-real-lowerbody-edit-mask.png').convert('L');ma=np.asarray(mask)>0;clear=np.asarray(master).copy();clear[ma]=0;base=Image.fromarray(clear)
polys={'right':[(663,640),(720,640),(721,681),(704,740),(707,790),(695,850),(694,929),(658,939),(656,902),(652,844),(647,791),(649,745),(650,701),(653,670)],'left':[(588,640),(655,640),(652,695),(647,750),(648,790),(644,827),(644,865),(585,865),(584,822),(598,777),(593,733),(583,695)]}
parts={}
for side,poly in polys.items():
 m=Image.new('L',src.size);ImageDraw.Draw(m).polygon(poly,fill=255);a=np.asarray(src).copy();a[:,:,3]=np.minimum(a[:,:,3],np.asarray(m));parts[side]=Image.fromarray(a);parts[side].save(D/f'original-native-{side}-leg-material-isolated.png')
# Piecewise articulated orthographic projection: x parity handles the paired boot.
# These transforms affect individual character parts only; no perpose frame/C/alpha-height scaling.
def warp_segment(im,sy0,sy1,scx0,scx1,ty0,ty1,tcx0,tcx1,mirror=False):
 ky=(sy1-sy0)/(ty1-ty0);by=sy0-ky*ty0
 # sx = scx(sy) + parity*(tx-tcx(ty))
 p=-1.0 if mirror else 1.0;ss=(scx1-scx0)/(sy1-sy0);ts=(tcx1-tcx0)/(ty1-ty0)
 a=p;b=ss*ky-p*ts;c=scx0+ss*(by-sy0)-p*(tcx0-ts*ty0)
 warped=im.transform(im.size,Image.Transform.AFFINE,(a,b,c,0,ky,by),resample=Image.Resampling.BICUBIC)
 ar=np.asarray(warped).copy();ar[:max(0,int(math.floor(ty0))-2)]=0;ar[min(H,int(math.ceil(ty1))+3):]=0
 return Image.fromarray(ar)
L=Image.new('RGBA',src.size);R=Image.new('RGBA',src.size)
L.alpha_composite(warp_segment(parts['right'],646,787,687,679,635,753,612,609,True))
L.alpha_composite(warp_segment(parts['right'],787,923,679,678,753,925,609,625,True))
R.alpha_composite(warp_segment(parts['left'],646,703,619,623,635,700,680,698,True))
R.alpha_composite(warp_segment(parts['left'],703,792,623,625,700,787,698,704,True))
# Keep original complete foot material/pixel geometry; heel support point is explicitly translated.
foot=parts['left'].copy();fa=np.asarray(foot).copy();fa[:730]=0
# Complete native foot alpha; a premultiplied articulation join handles the transition.
foot=Image.fromarray(fa);foot.save(D/'original-complete-left-shoe-foot-layer.png')
def attach_complete_native_foot(calf,footcanvas,start,end):
    ca=np.asarray(calf).copy();fo=np.asarray(footcanvas);out=ca.copy();out[end:]=fo[end:]
    xx=np.arange(W,dtype=float)
    for y in range(start,end):
        cids=np.flatnonzero(ca[y,:,3]>128);fids=np.flatnonzero(fo[y,:,3]>128)
        if not len(cids) or not len(fids):
            out[y]=fo[y]if len(fids)else ca[y];continue
        t=(y-start)/(end-start);t=t*t*(3.-2.*t)
        cl,ch=float(cids[0]),float(cids[-1]);fl,fh=float(fids[0]),float(fids[-1]);lo=cl*(1-t)+fl*t;hi=ch*(1-t)+fh*t
        u=np.clip((xx-lo)/max(hi-lo,1),0,1);cx=cl+u*(ch-cl);fx=fl+u*(fh-fl)
        rgb=np.stack([np.interp(cx,xx,ca[y,:,k])*(1-t)+np.interp(fx,xx,fo[y,:,k])*t for k in range(3)],axis=1)
        alpha=np.clip(np.minimum(xx-lo+1.,hi-xx+1.),0,1)*255.
        out[y,:,:3]=np.rint(rgb).astype(np.uint8);out[y,:,3]=np.rint(alpha).astype(np.uint8);out[y,alpha==0,:3]=0
    return Image.fromarray(out)
LF=Image.new('RGBA',src.size);LF.paste(foot,(0,133));L=attach_complete_native_foot(L,LF,875,895)
# Mirror paired shoe with integer transform x'=1329-x, y'=y-5.
RF=foot.transpose(Image.Transpose.FLIP_LEFT_RIGHT);RFcanvas=Image.new('RGBA',src.size);RFcanvas.paste(RF,(1329-(W-1),-5));R=attach_complete_native_foot(R,RFcanvas,735,755)
# Occlusion: right passing thigh lies behind skirt and left supporting thigh.
legs=Image.new('RGBA',src.size);legs.alpha_composite(R);legs.alpha_composite(L);la=np.asarray(legs).copy();la[~ma]=0;legs=Image.fromarray(la);out=base.copy();out.alpha_composite(legs)
# Retouch only the bare-thigh joint cap, using the actual original skin material.
# No original upperbody pixel, gold trim, complete shoe, or physical heel anchor changes.
ret=np.asarray(out).copy();orig=np.asarray(master)
def is_skin(v):
    r,g,b,a=map(float,v);return a>0 and r>110 and b>85 and r-g>15 and r-g<90 and 5<g-b<65
for x0,x1 in ((570,657),(658,732)):
    samples=[x for x in range(x0,x1)if is_skin(orig[640,x])]
    for y in range(641,659):
        t=(y-640)/18.;t=t*t*(3.-2.*t)
        for x in range(x0,x1):
            if not ma[y,x]:continue
            new=ret[y,x].astype(float);has=is_skin(new);oldskin=is_skin(orig[640,x])
            if not has:continue
            ox=x if oldskin else min(samples,key=lambda z:abs(z-x))
            oldrgb=orig[640,ox,:3].astype(float)
            if has:new[:3]=oldrgb*(1-t)+new[:3]*t
            # Smooth the actual bare-thigh outline through the joint cap.
            # Skin material keeps its original native opaque/silhouette alpha.
            ret[y,x]=np.rint(np.clip(new,0,255)).astype(np.uint8)
out=Image.fromarray(ret);out.save(D/'N-LOAD1-actual-native-part-rig-v03.png')
L.save(D/'new-left-support-native-part-rig.png');R.save(D/'new-right-passing-native-part-rig.png');mask.save(D/'allowed-authored-lowerbody-region.png')
res=np.asarray(out);mast=np.asarray(master);outside=int(np.count_nonzero(np.any(res[~ma]!=mast[~ma],axis=1)));assert outside==0
meta=dict(status='ACTUAL_NEW_ARTICULATED_LOAD1_PENDING_INDEPENDENT_QC',source=str(P),source_sha256=hashlib.sha256(raw).hexdigest(),native_canvas=[W,H],fixed_virtualC=1920,body_unit=1.875,upperbody_author_bob=[-7,-12],source_root_plane_unchanged=True,outside_authored_limb_region_RGBA_changed=outside,whole_frame_resample=False,perpose_C_or_alphaheight_normalization=False,real_unique_costume_parts_articulated=True,not_a_shared_generic_motion=True,original_part_native_density_preserved_except_declared_articulated_projection=True,exact_left_heel_material_translation=[0,133],actual_left_goldheel_core_from_source=[616.5,850],actual_left_goldheel_core_expected=[616.5,983],perphase_existing_ground_delta=[0,132.8727273],sameheel_world_screen_drift_if_grounded=[0,(133-132.8727273)*.237068965517*1024/1920],right_passing_expected_goldheel=[712.5,845],hidden_3D_joint_reconstruction_claim=False,source0_to_load1_bothcontact_quality_pending=True,local_join_retouch=['original-native-skin thigh cap transition only y641..658','complete native shoe silhouette replaces calf at ankle joint, removing old rectangle'],actor_approval_added=0)
(D/'actual-articulation-and-preservation-contract.json').write_text(json.dumps(meta,indent=2)+'\n')
pre=out.copy();pre.thumbnail((560,560));bg=Image.new('RGBA',pre.size,(206,211,215,255));bg.alpha_composite(pre);bg.convert('RGB').save(D/'private-actual-LOAD1-rig-full.jpg',quality=91,optimize=True);assert(D/'private-actual-LOAD1-rig-full.jpg').stat().st_size<150000
print(json.dumps(dict(status=meta['status'],final=str(D/'N-LOAD1-actual-native-part-rig-v03.png'),sha256=hashlib.sha256((D/'N-LOAD1-actual-native-part-rig-v03.png').read_bytes()).hexdigest(),bytes=(D/'N-LOAD1-actual-native-part-rig-v03.png').stat().st_size,preview_bytes=(D/'private-actual-LOAD1-rig-full.jpg').stat().st_size,outside_changed=outside)))
