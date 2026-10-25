from pathlib import Path
import json,hashlib,numpy as np
D=Path(__file__).parent;Q=D/'actual-NE-run-two-proximal-pelvis-finish-v04';MP=D/'actual-NE-run-six-fixed-rig-v02/NE-run-six-actual-causal-rig-shoe-surface-and-source-contract-v02.json';m=json.loads(MP.read_text());P=np.asarray(m['projection']);H0=np.asarray(m['source_HFA_raw'][0]);S=np.asarray(m['source_leg_raw']);S3=np.asarray(m['source_leg_XYZ']);PAD=np.array([128.,128.]);records=[]
def rec(p):
 b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
def affine(a,b,c,d):
 u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);n=np.array([-u[1],u[0]]);t=np.array([-v[1],v[0]]);M=np.outer((d-c)/np.linalg.norm(b-a),u)+np.outer(t,n);return M,c-M@a
def chart(M,o,sa,sb,ta,tb):
 v=sb-sa;zc=(tb[2]-ta[2])*v/float(v@v);zo=ta[2]-zc@sa
 C=np.array([.9*M[0],M[1]+zc,zc]);c=np.array([.9*(o[0]-H0[0]),o[1]-H0[1]+zo,zo]);return C,c
identity=np.eye(2);zero=np.zeros(2);capM,capO=chart(identity,zero,S[0],S[1],S3[0],S3[1])
t=(S[1]-S[0])/np.linalg.norm(S[1]-S[0])+(S[2]-S[1])/np.linalg.norm(S[2]-S[1]);t/=np.linalg.norm(t)
for phase in [2,3]:
 f=m['frames'][phase];leg=f['legs']['R'];T=np.asarray(leg['actual_joint_controls_unpadded']);T3=np.array([leg['hip'],leg['knee'],leg['ankle']]);node=np.asarray(f['body_node_XYZ']);fm,fo=affine(S[0],S[1],T[0],T[1]);cm,co=affine(S[1],S[2],T[1],T[2]);FC,FO=chart(fm,fo,S[0],S[1],T3[0],T3[1]);CC,CO=chart(cm,co,S[1],S[2],T3[1],T3[2]);CAPO=capO+node
 file=Q/f'phase{phase}-actual-pelvis-finish-v04/RIGHT-actual-proximal-skin-pelvis-bound-thigh-calf-actual-forward-mesh.json';mesh=json.loads(file.read_text());zs=[];error=0.
 for cell in mesh['mesh']:
  for s,target in zip(cell['source'],cell['target']):
   s=np.asarray(s);k=np.clip(((s-S[1])@t+18)/36,0,1);k=k*k*(3-2*k);h=np.clip((s[1]-716)/48,0,1);h=h*h*(3-2*h)
   bone=(1-k)*(FC@s+FO)+k*(CC@s+CO);xyz=(1-h)*(capM@s+CAPO)+h*bone
   zs.append(float(xyz[2]));error=max(error,float(np.max(abs(P@xyz+H0+PAD-np.asarray(target)))))
 records.append(dict(phase=phase,source_actual_mesh=rec(file),pelvis_surface_matrix=capM.tolist(),pelvis_surface_offset=CAPO.tolist(),femur_surface_matrix=FC.tolist(),femur_surface_offset=FO.tolist(),calf_surface_matrix=CC.tolist(),calf_surface_offset=CO.tolist(),original_forward_knee_blend_tangent=t.tolist(),pelvis_weight='smoothstep(clip((source_y-716)/48,0,1)); same actual material operator',maximum_actual_mesh_vertex_projection_error=error,minimum_all_actual_Rleg_mesh_vertex_Z=min(zs),minimum_Z_with_8native_hidden_thickness=min(zs)-8,hip_knee_ankle_physical_controls_unchanged=True))
out=Q/'NE-run-two-actual-proximal-pelvis-surface-model-v04.json';j=dict(schema='MYTHIC413_NE_RUN_ACTUAL_TWO_PROXIMAL_FLEXIBLE_SKIN_SURFACE_V04',status='FINITE_AUTHOR_MODEL_PENDING_INDEPENDENT_AUDIT',unchanged_original_rig=rec(MP),projection=P.tolist(),frames=records,scope='Same fixed hip/knee/ankle bones; actual native skin/garter surface at pelvis follows body then same actual femur/calf charts. Explicit compatible authored 2.5D surface, not unique hidden anatomy. No source pixels changed by numeric model.',actor_approvals_added=0)
with out.open('x') as f:f.write(json.dumps(j,indent=2)+'\n')
print(json.dumps(dict(model=rec(out),maximum_mesh_projection_error=max(r['maximum_actual_mesh_vertex_projection_error'] for r in records),guarded_Rleg_surface_minima=[r['minimum_Z_with_8native_hidden_thickness'] for r in records])))
