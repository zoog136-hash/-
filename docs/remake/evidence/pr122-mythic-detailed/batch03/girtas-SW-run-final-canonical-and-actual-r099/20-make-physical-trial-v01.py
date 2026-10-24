from pathlib import Path
import json,hashlib,sys,math,numpy as np
p=Path(__file__).parent;sys.path.insert(0,'/workspace/twilight/tools');from pr122_reviewed_runtime_layout import apply_reviewed_layout
sha=lambda x:hashlib.sha256(x.read_bytes()).hexdigest();raw=p/'girtas-SW-run-v03six.png';b=json.loads((p/'geometry-base2048-six.json').read_text());regions=json.loads((p/'source-region-review.v03.json').read_text());o=Path('/workspace/scratch/girtas-private-qc-v02-20261019/SW-native-semantic-boot-ROIs-and-surface-search-observations-v02.json');obs=json.loads(o.read_text());surface=np.asarray(obs['body_surface_registration_search_centers0to5'],float);C=np.full(6,2304.);n=1024/C
F=np.array([5.,-7.,-4.]);F/=np.linalg.norm(F);R=np.cross(F,[0.,0.,1.]);R/=np.linalg.norm(R);U=np.cross(R,F);s=-U[1]/R[1]
idlepoints={'LEFT':[349.15,493.60],'RIGHT':[175.14,484.72]};intercepts={side:640+pt[1]-495-s*(pt[0]-256) for side,pt in idlepoints.items()};I=(intercepts['LEFT']+intercepts['RIGHT'])/2;standing=(intercepts['LEFT']-intercepts['RIGHT'])/2
ax=surface[:,0]-14/n;points={}
for row in obs['source_rows']:
 phase=row['phase'];f=row['boots'][0]['alpha_stats']['100'];points[phase]=[sum(f['lastXrange'])/2,f['lastY']]
def surface_base(i):
 x,y=points[i];return I+(surface[i,1]-y)*n[i]+s*(x-ax[i])*n[i]
L=(surface_base(3)-surface_base(0))/2
ay=np.zeros(6);details=[]
for i in [0,1,3,4]:
 x,y=points[i];side='LEFT' if i in [0,1] else 'RIGHT';offset=L if side=='LEFT' else -L;gy=I+s*(x-ax[i])*n[i]+offset;ay[i]=y-(gy-640)/n[i];details.append({'phase':i,'side':side,'native_boot_point':[x,y],'root_native_draft':[float(ax[i]),float(ay[i])],'contact_canonical_Y':float(gy),'surface_canonical_Y':float(640+(surface[i,1]-ay[i])*n[i])})
contact_surface=np.mean([640+(surface[i,1]-ay[i])*n[i] for i in [0,3]]);K=275.;rise=(U[2]*.11-U[1]*(-.08))*K
# Explicit genericguide body rise, not any airborne minimumsole.
for i in [2,5]:ay[i]=surface[i,1]+(640-(contact_surface-rise))/n[i]
anchors=[[int(round(ax[i]))+141+(i%2)*1536,int(round(ay[i]))+141+(i//2)*1536] for i in range(6)]
model={'status':'DRAFT_CAMERA_AND_NARROW_RUN_LANE_HYPOTHESIS_NOT_INDEPENDENT_PHYSICAL_PROOF','camera_forward_slope_y_per_x':float(s),'standing_actual_two_boot_intercepts':intercepts,'ground_origin_intercept_canonical':float(I),'standing_near_far_lane_halfwidth_canonical':float(standing),'running_near_far_lane_halfwidth_canonical':float(L),'running_lane_fit_basis':'Tentative equal frontwaist surface heights of actualcontact0/3. Frontwaist is not bonyhip; uncertainties±20native. Validate actualhip/knee/ankle/head/pauldron and other4phases; fit alone cannotPASS.','rootX_basis':'Currentidle frontwaist surface canonical offset+14px, mappedatC2304. Marker not COM/hip; ±20pxnative uncertainty.','air_body_rise_canonical_trial':float(rise),'air_rise_basis':'Fixedguide pelvis1.03→1.14 withtorsolean.10→.18, initial275canonical/world only a trial. Air roots frombody surface registration, never minimumfoot.','support_details':details,'native_anchors_draft':[[float(ax[i]),float(ay[i])] for i in range(6)],'surface_observations':{'path':str(o),'sha256':sha(o)},'idle_actual_boot_points':idlepoints,'review_required':True}
(p/'common-groundprojection-hypothesis.v01.DRAFT.json').write_text(json.dumps(model,indent=2)+'\n')
q={'status':'REVIEWED_LAYOUT_PROPOSAL','source_sha256':sha(raw),'canvas_size':2048,'authored_pose_canvas_sizes':[2304]*6,'source_anchors':anchors,'review_basis':'FIRST DRAFT uniform2304body-size trial afternativehead/pauldron inspection; provisional observedstanceboots/body surface plusfixedguide camera/support/flight model. NOT physicalPASS or finalselection. No bbox normalization, no lowestAIRsole root, no standingnear/far invariant; seecommon-groundprojection-hypothesis.v01.DRAFT.json and independentreview required.'}
f=p/'reviewed_runtime_layout.trial-v01.json';assert not f.exists();f.write_text(json.dumps(q,indent=2)+'\n');g,proof=apply_reviewed_layout(raw,b,q,source_region_review=regions);(p/'runtime-geometry.trial-v01.json').write_text(json.dumps(g,indent=2)+'\n');(p/'runtime-layout.trial-v01-proof.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'Cs':[2304]*6,'anchors_local':[[round(float(ax[i])),round(float(ay[i]))] for i in range(6)],'ground_slope':float(s),'running_lane_halfwidth':float(L),'air_body_rise_trial':float(rise),'source_pixels_unchanged':proof.get('source_pixels_unchanged')}))
