from pathlib import Path
from PIL import Image, ImageDraw
import hashlib, json, numpy as np

D = Path(__file__).parent
B = Path('/workspace/scratch/mythic413-NE-walk-author-20261020-v01')
Q = D / 'contact0-actual-NE-run-v01'
Q.mkdir(exist_ok=False)
SIZE, PAD = 1536, np.array([128., 128.])
ROOT = [716.2291666666666, 1054.2766007046484]
S = B / 'NE-contact0-actual-native-background-AA-clean-r002.png'
RP = B / 'actual-NE-LOAD1-semantic-speck-finish-v03/original-native-RIGHT-complete-shoe-and-leg-material-staff-speck-excluded.png'
LP = B / 'actual-NE-LOAD1-rig-v02/original-native-complete-LEFT-visible-boot-material.png'
BP = B / 'actual-NE-LOAD1-semantic-and-RIGHTstaff-finish-v04/original-native-body-coat-complete-RIGHTstaff-oldboots-removed-INPUT-v04.png'
AP = B / 'actual-NE-LOAD1-rig-v02/original-native-LEFT-free-forearm-and-hand-material.png'
src = Image.open(S).convert('RGBA')
right, left = Image.open(RP).convert('RGBA'), Image.open(LP).convert('RGBA')
body, arm = Image.open(BP).convert('RGBA'), Image.open(AP).convert('RGBA')
W, H = src.size

def rec(p):
    raw = p.read_bytes()
    return dict(path=str(p), sha256=hashlib.sha256(raw).hexdigest(), bytes=len(raw))

def semantic(im, poly, name):
    m = Image.new('L', im.size)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    a = np.array(im)
    a[np.array(m) == 0] = 0
    ans = Image.fromarray(a)
    ans.save(Q / (name + '-native-RGBA.png'))
    m.save(Q / (name + '-semantic-matte.png'))
    return ans

# Native actual complete structural shoes: preserve each counter, outsole,
# pointed toe and gold stiletto, and never import the original staff speck.
rshoe = semantic(right, [(803,930),(817,932),(826,949),(834,959),(860,960),(881,975),(881,1003),(855,1016),(825,1014),(809,1035),(780,1035),(777,1001),(776,976),(784,951)], 'RIGHT-complete-shoe')
lshoe = semantic(left, [(552,1063),(567,1067),(574,1094),(573,1126),(592,1130),(610,1145),(610,1163),(599,1175),(583,1187),(555,1185),(543,1170),(538,1188),(517,1196),(514,1187),(514,1148),(509,1120),(512,1099),(531,1082)], 'LEFT-complete-shoe')
shaft = np.array(right)
shaft[940:] = 0
shaft = Image.fromarray(shaft)
shaft.save(Q / 'original-complete-RIGHT-upperthigh-calf-source-native.png')

def affine(im, matrix, offset):
    inv = np.linalg.inv(matrix)
    off = -inv @ np.asarray(offset)
    coeff = (inv[0,0], inv[0,1], off[0], inv[1,0], inv[1,1], off[1])
    return im.transform((SIZE, SIZE), Image.Transform.AFFINE, coeff, resample=Image.Resampling.BICUBIC)

def translate(im, delta):
    delta = np.asarray(delta, float) + PAD
    if np.max(abs(delta - np.rint(delta))) < 1e-10:
        out = Image.new('RGBA', (SIZE, SIZE))
        out.alpha_composite(im, tuple(np.rint(delta).astype(int)))
        return out
    return affine(im, np.eye(2), delta)

def bone_affine(a,b,c,d):
    a,b,c,d = (np.asarray(x,float) for x in (a,b,c,d))
    u=(b-a)/np.linalg.norm(b-a); v=(d-c)/np.linalg.norm(d-c)
    n=np.array([-u[1],u[0]]); t=np.array([-v[1],v[0]])
    M=np.outer((d-c)/np.linalg.norm(b-a),u)+np.outer(t,n)
    return M,c-M@a

def forward_material(im, source_knots, target_knots, name):
    sp=np.asarray(source_knots,float); tp=np.asarray(target_knots,float)+PAD
    m0,o0=bone_affine(sp[0],sp[1],tp[0],tp[1])
    m1,o1=bone_affine(sp[1],sp[2],tp[1],tp[2])
    t=(sp[1]-sp[0])/np.linalg.norm(sp[1]-sp[0])+(sp[2]-sp[1])/np.linalg.norm(sp[2]-sp[1]);t/=np.linalg.norm(t)
    def posed(p):
        z=np.clip(((p-sp[1])@t+18)/36,0,1);z=z*z*(3-2*z)
        return (1-z)*(m0@p+o0)+z*(m1@p+o1)
    data=np.array(im).astype(float)/255
    data[:,:,:3]*=data[:,:,3,None]
    yy,xx=np.where(data[:,:,3]>0)
    acc=np.zeros((SIZE,SIZE,4),float);vertices=[];triangles=0
    for sy in range(int(yy.min())//8*8,int(yy.max())+8,8):
        for sx in range(int(xx.min())//8*8,int(xx.max())+8,8):
            if not data[max(sy,0):min(sy+9,H),max(sx,0):min(sx+9,W),3].any():continue
            cell=np.array([[sx,sy],[sx+8,sy],[sx+8,sy+8],[sx,sy+8]],float)
            dst=np.array([posed(p) for p in cell]);vertices.append(dict(source=cell.tolist(),target=dst.tolist()))
            for ids in ((0,1,2),(0,2,3)):
                S0=cell[list(ids)];T=dst[list(ids)];A=np.column_stack((T[1]-T[0],T[2]-T[0]))
                if abs(np.linalg.det(A))<1e-8:continue
                x0=max(0,int(np.floor(T[:,0].min())));x1=min(SIZE,int(np.ceil(T[:,0].max()))+1)
                y0=max(0,int(np.floor(T[:,1].min())));y1=min(SIZE,int(np.ceil(T[:,1].max()))+1)
                if x1<=x0 or y1<=y0:continue
                gy,gx=np.mgrid[y0:y1,x0:x1];V=np.stack((gx-T[0,0],gy-T[0,1]),axis=-1);uv=V@np.linalg.inv(A).T
                u,v=uv[:,:,0],uv[:,:,1];inside=(u>=-1e-7)&(v>=-1e-7)&(u+v<=1+1e-7)
                mx=S0[0,0]+u*(S0[1,0]-S0[0,0])+v*(S0[2,0]-S0[0,0]);my=S0[0,1]+u*(S0[1,1]-S0[0,1])+v*(S0[2,1]-S0[0,1])
                ix=np.clip(np.floor(mx).astype(int),0,W-2);iy=np.clip(np.floor(my).astype(int),0,H-2)
                fx=(mx-ix)[:,:,None];fy=(my-iy)[:,:,None]
                val=(1-fx)*(1-fy)*data[iy,ix]+fx*(1-fy)*data[iy,ix+1]+(1-fx)*fy*data[iy+1,ix]+fx*fy*data[iy+1,ix+1]
                val[~inside]=0;dest=acc[y0:y1,x0:x1];dest[:]=val+dest*(1-val[:,:,3,None]);triangles+=1
    alpha=acc[:,:,3];rgb=np.divide(acc[:,:,:3],alpha[:,:,None],out=np.zeros_like(acc[:,:,:3]),where=alpha[:,:,None]>1e-8)
    ans=Image.fromarray(np.rint(np.dstack((rgb,alpha)).clip(0,1)*255).astype('uint8'))
    ans.save(Q/(name+'-actual-posed-material.png'))
    (Q/(name+'-actual-forward-mesh.json')).write_text(json.dumps(dict(source_knots=sp.tolist(),target_knots_unpadded=np.asarray(target_knots).tolist(),storage_translation=PAD.tolist(),mesh=vertices,triangles=triangles,mesh_spacing_native=8,method='forward native semantic RGBA, premultiplied bilinear material, explicit projected bones, bounded true source pixels only'),indent=2)+'\n')
    return ans

# RUN-only contact: RIGHT leads; LEFT femur/calf fold into a genuine rear
# recovery. The fixed whole-body root and native body density are unchanged.
R = np.array([[774.,724.],[790.,815.],[811.,960.]])
L = np.array([[680.,730.],[525.,810.],[585.,865.]])
right_shaft=forward_material(shaft, R, R, 'RIGHT-leading-thigh-calf')
left_shaft=forward_material(shaft, R, L, 'LEFT-folded-recovery-thigh-calf')
right_foot=translate(rshoe,[0,0])
left_foot=translate(lshoe,L[2]-[553.,1095.])
right_foot.save(Q/'RIGHT-original-whole-shoe-posed.png')
left_foot.save(Q/'LEFT-original-whole-shoe-posed.png')

# The original blue tails trail behind the new recovery, while original
# white/gold skirt, torso, head and complete RIGHT staff remain foreground.
ba=np.array(body);am=np.array(arm)[:,:,3]>0;ba[am]=0
hem=[(600,704),(620,714),(650,718),(675,714),(700,710),(725,706),(750,699),(775,689),(798,680)]
hy=np.interp(np.arange(W),[p[0] for p in hem],[p[1] for p in hem])
tail=(np.arange(H)[:,None]>hy[None,:])&(np.arange(W)[None,:]<820)
bg=ba.copy();bg[~tail]=0;front=ba.copy();front[tail]=0
Image.fromarray(bg).save(Q/'original-native-blue-coattails-behind-running-legs.png')
Image.fromarray(front).save(Q/'original-native-body-skirt-RIGHTstaff-foreground-old-free-arm-removed.png')
Image.fromarray(tail.astype('uint8')*255).save(Q/'actual-original-coattail-depth-semantic-matte.png')
M,o=bone_affine([559,550],[481,645],[559,550],[590,615])
newarm=affine(arm,M,o+PAD);newarm.save(Q/'actual-LEFT-free-forearm-complete-hand-forward-counterphase.png')
out=translate(Image.fromarray(bg),[0,0]);out.alpha_composite(left_shaft);out.alpha_composite(left_foot);out.alpha_composite(right_shaft);out.alpha_composite(right_foot);out.alpha_composite(newarm);out.alpha_composite(translate(Image.fromarray(front),[0,0]))
P=Q/'thunder_female-NE-run-contact0-actual-parts-v01.png';out.save(P)
note=dict(status='ACTUAL_NEW_NE_RUN_CONTACT0_SOURCE_PENDING_AUTHOR_AND_INDEPENDENT_QC',output=rec(P),source_inputs=[rec(p) for p in (S,RP,LP,BP,AP)],C=2432,bodyunit=2.375,common_rig_root_unpadded=ROOT,storage_translation=PAD.tolist(),stored_common_root=(np.array(ROOT)+PAD).tolist(),native_canvas=[SIZE,SIZE],source_native_canvas=[W,H],body_node_translation=[0,0],anatomical_RIGHT_staff_preserved=True,RIGHT_controls_unpadded=R.tolist(),LEFT_controls_unpadded=L.tolist(),LEFT_free_forearm_source_control=[[559,550],[481,645]],LEFT_free_forearm_target_control=[[559,550],[590,615]],foot_source_controls={'RIGHT':[811,960],'LEFT':[553,1095]},foot_controls_are_declared_projected_rig_landmarks_not_unique_hidden_anatomy=True,whole_actor_flip=False,whole_source_resized=False,perpose_C_or_root_fit=False,clock=dict(actual_run_speed=262.5,effective_phase_hz=15.625,phase_dt=.064,world_travel_per_phase=16.8),actor_approvals_added=0)
(Q/'NE-run-contact0-actual-part-controls-and-source-provenance-v01.json').write_text(json.dumps(note,indent=2)+'\n')
print(json.dumps(dict(output=rec(P),status=note['status'])))
