import os,sys,json,hashlib,math
from pathlib import Path
from copy import deepcopy
from PIL import Image,ImageDraw
import numpy as np
sys.dont_write_bytecode=True
sys.path.insert(0,'/workspace/twilight/tools')
import import_original_based_motion as importer
import pr122_reviewed_source_regions as regions_tool
import pr122_reviewed_runtime_layout as layout_tool
OUT=Path('/workspace/scratch/girtas-NE-run-new-contacts-physical-candidate-v02')
OUT.mkdir(exist_ok=False)
ATLAS=Path('/workspace/scratch/girtas-NE-run-reviewed-composite-v02/girtas-NE-run-reviewed-composite-v02.png')
ASSEMBLY=ATLAS.with_suffix('.assembly.json')
A=json.loads(ASSEMBLY.read_text()); Cs=[1936,2240,1936,1776,2048,1936]
roots=[[730,1049],[779,1215],[720,1254],[717,1023],[758,1128],[805,1259]]
waists=[[715,555],[814,664],[750,525],[745,485],[790,585],[735,535]]
hairYs=[205,336,205,165,207,213]
M=-0.5902918298980975 # camera(5,-7,5) targeted at(0,0,1): forward ground screenY/screenX
K=0.8914611308665146 # lateralYperX - forwardSlope
SCALE=.21910501173173982
# All semantic points are SOURCE-native. Shoe undersides/heel contacts were inspected in native ROIs.
feet=[
 [{'foot':'FAR_LEFT','role':'HEEL_LANDING_SUPPORT','roi':[610,900,780,1025],'contact':[637,1021],'sole_polyline':[[622,1019],[630,1020],[637,1021],[645,1021],[660,1021],[680,1019],[700,1019],[720,1016],[740,1011]],'lateral':[-50,-42,-58]}, {'foot':'NEAR_RIGHT','role':'HIGH_FOLDED_RECOVERY','roi':[720,700,920,1020],'sole_polyline':[[772,850],[779,898],[773,907]],'lateral':[79,71,87]}],
 [{'foot':'FAR_LEFT','role':'FLEXED_LOAD_SUPPORT','roi':[464,1064,734,1294],'contact':[600,1223],'sole_polyline':[[530,1201],[565,1214],[600,1223],[641,1220]],'lateral':[-50,-42,-58]}, {'foot':'NEAR_RIGHT','role':'HIGH_FOLDED_RECOVERY','roi':[714,744,964,1024],'sole_polyline':[[799,921],[808,962],[814,981]],'lateral':[79,71,87]}],
 [{'foot':'NEAR_RIGHT','role':'LEADING_AIR','roi':[720,780,900,1080],'sole_polyline':[[756,892],[767,965],[801,1014],[833,1031]],'lateral':[79,65,87]}, {'foot':'FAR_LEFT','role':'TRAILING_AIR','roi':[220,900,440,1180],'sole_polyline':[[267,982],[275,1053],[302,1122],[312,1145]],'lateral':[-50,-44,-54]}],
 [{'foot':'NEAR_RIGHT','role':'HEEL_LANDING_SUPPORT','roi':[890,875,1100,1025],'contact':[934,1018],'sole_polyline':[[922,1012],[934,1018],[950,1016],[980,1007],[1000,987],[1020,981],[1040,974],[1060,957]],'lateral':[79,71,87]}, {'foot':'FAR_LEFT','role':'HIGH_FOLDED_RECOVERY','roi':[280,760,580,1050],'sole_polyline':[[309,885],[325,939],[327,963]],'lateral':[-50,-42,-58]}],
 [{'foot':'NEAR_RIGHT','role':'FLEXED_LOAD_SUPPORT','roi':[850,1050,1080,1254],'contact':[900,1185],'sole_polyline':[[866,1189],[900,1185],[962,1181],[1002,1167]],'lateral':[79,71,87]}, {'foot':'FAR_LEFT','role':'HIGH_FOLDED_RECOVERY','roi':[270,760,560,1080],'sole_polyline':[[289,946],[307,1009],[309,1029]],'lateral':[-50,-42,-58]}],
 [{'foot':'FAR_LEFT','role':'LEADING_AIR','roi':[610,930,840,1170],'sole_polyline':[[679,1076],[722,1105],[765,1134],[829,1138],[835,1129]],'lateral':[-50,-44,-54]}, {'foot':'NEAR_RIGHT','role':'TRAILING_AIR','roi':[690,690,870,900],'sole_polyline':[[732,796],[745,829],[754,851]],'lateral':[79,65,87]}]
]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def dump(name,x):
 p=OUT/name;p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');return p
# Check source pins before writing any review metadata.
assert sha(ATLAS)==A['output_sha256']
for p in A['poses']:assert sha(p['source_path'])==p['source_sha256']
canonical=importer.analyze(ATLAS,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid2',canvas_size=2048,directions=['NE'])
assert canonical==A['geometry']
anchors=[[r[0]+p['translation'][0],r[1]+p['translation'][1]] for r,p in zip(roots,A['poses'])]
# Minimal outward-only transparent room for authored virtual ground; no source pixels touched.
rs=[]
for f,anchor in zip(canonical['frames'],anchors):
 x,y,w,h=f['region'];right=max(x+w,anchor[0]+1);bottom=max(y+h,anchor[1]+1);rs.append([x,y,right-x,bottom-y])
alpha=np.array(Image.open(ATLAS))[:,:,3]
owners,ownerproof=regions_tool._foreground_owners(alpha,canonical['frames'])
region_review={'status':'REVIEWED_SOURCE_REGIONS_PROPOSAL','source_sha256':sha(ATLAS),'base_geometry_sha256':regions_tool._digest(canonical),'direction':'NE','review_basis':'Metadata-only minimal outward transparent room for explicit native-local projected ground roots. Every original automatic rectangle and all exact alpha>16 pixels retained; six ownership, nearest-body margin, disjointness, fringe and complete-pose guards unchanged. No PNG/source-body edits and no art/runtime approval.','regions':rs,'nearest_owner_sha256':ownerproof['nearest_owner_sha256']}
expanded,region_validation=regions_tool.apply_reviewed_regions(ATLAS,canonical,region_review)
source_data=[]
for i,(p,C,root,waist,ff) in enumerate(zip(A['poses'],Cs,roots,waists,feet)):
 im=np.array(Image.open(p['source_path']));ratio=1024/C
 for foot in ff:
  # Observe a true alpha100 outer silhouette edge, not a painted sole interior.
  def snap(q):
   x,y=q;pts=[]
   for radius in [4,8,16,24]:
    for yy in range(max(1,y-radius),min(im.shape[0]-1,y+radius+1)):
     for xx in range(max(1,x-radius),min(im.shape[1]-1,x+radius+1)):
      if im[yy,xx,3]>100 and any(im[yy+dy,xx+dx,3]<=100 for dx,dy in [(0,1),(0,-1),(1,0),(-1,0)]):pts.append(((xx-x)**2+(yy-y)**2,xx,yy))
    if pts:break
   assert pts,(i,q)
   _,xx,yy=min(pts);return [int(xx),int(yy)]
  foot['sole_polyline']=[snap(q) for q in foot['sole_polyline']]
  if 'contact'in foot:foot['contact']=snap(foot['contact'])
  L,Llo,Lhi=foot['lateral'];Lmin,Lmax=min(Llo,Lhi),max(Llo,Lhi)
  observations=[]
  for q in foot['sole_polyline']:
   X=(q[0]-root[0])*ratio;Y=(q[1]-root[1])*ratio
   ground=M*X+K*L;gmin=M*X+K*Lmin;gmax=M*X+K*Lmax
   observations.append({'source_native':q,'atlas':[q[0]+p['translation'][0],q[1]+p['translation'][1]],'root_relative_canonical':[X,Y],'projected_ground_Y_canonical':ground,'projected_ground_interval_Y_canonical':[gmin,gmax],'projected_vertical_clearance_canonical':ground-Y,'minimum_interval_clearance_canonical':gmin-Y,'minimum_interval_clearance_world':(gmin-Y)*SCALE})
  foot['samples']=observations
  foot['lateral_projected_X_canonical_interval']=[Lmin,Lmax]
  foot['lateral_nominal_X_canonical']=L
  if 'contact'in foot:
   q=foot['contact'];X=(q[0]-root[0])*ratio;Y=(q[1]-root[1])*ratio
   foot['contact_projection']={'root_relative_canonical':[X,Y],'forward_projected_X_canonical':X-L,'ground_Y_prediction_canonical':M*X+K*L,'contact_residual_canonical':Y-(M*X+K*L),'heel_roll_and_shoe_shape_not_flattened':True}
  foot['minimum_interval_clearance_canonical']=min(q['minimum_interval_clearance_canonical'] for q in observations)
  foot['source_pixel_alpha_threshold']=100
  del foot['lateral']
 source_data.append({'phase':i,'C':C,'source_path':p['source_path'],'source_sha256':p['source_sha256'],'source_actual_size':[im.shape[1],im.shape[0]],'source_to_atlas_translation':p['translation'],'source_native_ground_root':root,'atlas_ground_root':anchors[i],'visible_posterior_cuirass_to_robe_junction_native':waist,'waist_observation_uncertainty_native_xy':[20,24],'hidden_pelvis_is_not_measured':True,'native_root_X_relation_to_visible_waist':root[0]-waist[0],'waist_to_ground_canonical':(root[1]-waist[1])*ratio,'pale_hairroot_Y_canonical_relative_ground':(hairYs[i]-root[1])*ratio,'uppercore_Y_world_preview':(hairYs[i]-root[1])*ratio*SCALE,'feet':ff})
proof={'schema':'PR122_NE_RUN_SOURCE_NATIVE_PHYSICAL_ROOT_AUTHOR_CANDIDATE_V1','status':'AUTHOR_CANDIDATE_PENDING_INDEPENDENT_ACTUAL_PHYSICAL_QC','author':'/root/girtas_se_walk_author adapting original fresh author fixed camera/projection and ROOT-approved actual new sole roots; independent reviewer separate','source_atlas_path':str(ATLAS),'source_atlas_sha256':sha(ATLAS),'assembly_path':str(ASSEMBLY),'assembly_sha256':sha(ASSEMBLY),'source6_individual_art_transfer_bridge_path':str(Path('/workspace/scratch/girtas-NE-run-reviewed-composite-v02/selected-six-source-only-exact-transfer-bridge-v01.json')),'source6_individual_art_transfer_bridge_sha256':sha('/workspace/scratch/girtas-NE-run-reviewed-composite-v02/selected-six-source-only-exact-transfer-bridge-v01.json'),'current_whole_six_cycle_review_status':'HOLD_PENDING_FRESH_INDEPENDENT_REVIEW','accepted_C_stage_path':'/workspace/scratch/girtas-final-actual-quality-v04/NE-run-rigid-Cstage-independent-PASS.json','accepted_C_stage_sha256':'98d5a94893dc0cc343c12a14db0f413213d5d31dc204f541fab75f0588719edc','poseCs':Cs,'poses':source_data,'projection':{'camera':[5,-7,5],'target':[0,0,1],'anatomical_forward':'+Y UPRIGHT','anatomical_near_RIGHT':'+X','far_LEFT':'-X; imageLEFT is not ownership','method':'At each foot, project groundY=m*root_relative_screenX+K*lateral_screenX. Ground has separate lateral slices; groundY is not one flat imageY and forward stride changes groundY. Actual painted sole points are observed; world floor, lateral coordinate and root are authored with explicit intervals.','m_forward_ground_Y_per_screenX':M,'K_lateral_coefficient':K,'ground_lateral_intervals':'far support -50 +/-8 canonical; near support +79 +/-8. AIR far[-54,-44], near[65,87]. More compact far/near stride placement than neutral resting shoe spread is allowed.','projection_camera_pitch_uncertainty':'Camera targetZ in [0,1] would change slopes. This candidate uses the existing guide targetZ1 consistently; guide generic .57 bones never establish source anatomy.','sole_sample_uncertainty_native':4,'foot_orientation':'heel/toe rolls and shoe thickness retained; load support samples need not have identical groundY'},'root_authorship':{'method':'Ground contact0/1 FAR_LEFT and3/4 NEAR_RIGHT pinned from actual selected sole. RootX authored using visible waist and actual thigh-chain intervals, with finite fore/aft and lateral stance; contact rootY follows projected ground equation. AIR2/5 use transparent virtualground and true positive per-foot sole clearances. Horizontal torso motion is retained, including phase5 root anterior of visible waist; hidden hip is an interval, not a clothV point.','source_native_roots':roots,'atlas_roots':anchors,'no_neutral_footdepth_invariant':True,'no_flat_two_feet_Y':True,'no_PNGbbox_floor':True,'no_hidden_hip_exact_measurement':True,'no_C_search_or_reauthoring':True},'reference_idle':{'source_path':'/workspace/scratch/girtas-NE-idle-repair-v03/girtas-NE-idle-v03.png','source_sha256':'a53a5c9a8ad6af62ac51d070ab4231e08cec4e69591f774d0206368cb543f91f','C':832,'root':[337,407],'visible_waist':[350,225],'waist_height_canonical':224,'pale_hairroot_Y_world_preview':(77-407)*1024/832*SCALE},'cycle_observations':{'waist_heights_canonical':[x['waist_to_ground_canonical'] for x in source_data],'load1_below_contact0_canonical':source_data[0]['waist_to_ground_canonical']-source_data[1]['waist_to_ground_canonical'],'load4_below_contact3_canonical':source_data[3]['waist_to_ground_canonical']-source_data[4]['waist_to_ground_canonical'],'AIR2_minimum_nominal_interval_clearance_canonical':min(f['minimum_interval_clearance_canonical'] for f in source_data[2]['feet']),'AIR5_minimum_nominal_interval_clearance_canonical':min(f['minimum_interval_clearance_canonical'] for f in source_data[5]['feet']),'five_to_zero_uppercore_world_Y_delta':source_data[0]['uppercore_Y_world_preview']-source_data[5]['uppercore_Y_world_preview'],'idle_to_contact0_uppercore_world_Y_delta':source_data[0]['uppercore_Y_world_preview']-(77-407)*1024/832*SCALE,'warning_for_independent_decision':'New bounded contacts replace the old stretched legs; unchanged AIR5-to0 has a large uppercore drop that still requires actual cycle judgment. The candidate exposes this rather than resizing accepted C or flattening soles. Independent actual-body/entry/cycle judgment must decide plausibility; author does not grant PASS.'},'region_operation':'Only outward disjoint metadata room, no PNG edits; original alpha16 ownership and strict guards remain unchanged.','source_pixels_unchanged':True,'actor_approval':False,'pixel_scale_preview':SCALE,'runtime_status':'NOT_COMPILED_BY_THIS_AUTHOR','repository_mutations':False}
# Conservative whole assigned AIR-boot ROI minima, including every alpha100 pixel (not sparse sole points).
for phase in [2,5]:
 pp=A['poses'][phase];im=np.array(Image.open(pp['source_path']));C=Cs[phase];ratio=1024/C;root=roots[phase]
 for foot in source_data[phase]['feet']:
  x0,y0,x1,y1=foot['roi'];ys,xs=np.where(im[y0:y1,x0:x1,3]>100);xs=xs+x0;ys=ys+y0
  Lmin=foot['lateral_projected_X_canonical_interval'][0];clear=M*(xs-root[0])*ratio+K*Lmin-(ys-root[1])*ratio;j=int(np.argmin(clear))
  foot['whole_assigned_boot_ROI_alpha100_conservative_clearance']={'ROI_xyxy':[x0,y0,x1,y1],'all_strong_pixels':int(len(xs)),'minimum_native_pixel':[int(xs[j]),int(ys[j])],'minimum_canonical':float(clear[j]),'minimum_world':float(clear[j]*SCALE),'after_4native_XY_uncertainty_world':float((clear[j]-4*ratio*(abs(M)+1))*SCALE),'not_a_measured_absolute_floor':True}
proof['current_timing']={'fps':12.5,'frame_duration':1,'seconds_per_frame':.08,'six_cycle_seconds':.48,'basis':'Fresh independent reviewer provided current actual r099 run_7; future compiled target requires ROOT validation.'}
proof['new_contacts_actual_edge_audit']={'path':'/workspace/scratch/girtas-NE-run-fresh-physical-author-v01/new-bounded-source0-source3-actual-edge-audit-and-clearance-correction-v01.json','sha256':'1fb54d6b695cba7e13360f2454837d4bfe9a786165dc0e68389685ae5ab9ef8b','m_K_exact_transferred':True,'native_roots_are_frozen_integer_authored_values':True}
proof['source_rgba_unchanged_in_this_operation']=True
p_proof=dump('authored-native-sole-projected-ground-root-candidate-v01.json',proof)
layout={'status':'REVIEWED_LAYOUT_PROPOSAL','key':'transform:267','direction':'NE','role':'run','source_sha256':sha(ATLAS),'canvas_size':2048,'authored_pose_canvas_sizes':Cs,'source_anchors':anchors,'review_basis':'Formal individual SOURCE6 exact-transfer coverage and accepted fixed rigid Cs; current whole-cycle physical still HOLD. One explicit actual-sole projected-floor root candidate: FAR_LEFT0/1 support, NEAR_RIGHT3/4 support, AIR2/5 actual sole clearances, bounded lateral/foreaft projection and uncertain hidden pelvis. Deep loads and idle/contact uppercore difference exposed for independent QC; author grants no approval.','anchor_measurement_evidence':str(p_proof),'anchor_measurement_evidence_sha256':sha(p_proof),'runtime_validation':'HOLD_PENDING_INDEPENDENT_PHYSICAL_CANDIDATE_AND_ACTUAL_PLAYER','actor_approval':False}
p_layout=dump('reviewed_runtime_layout.candidate-v01.json',layout)
dump('reviewed_source_regions.candidate-v01.json',region_review)
dump('geometry-base2048.json',canonical);dump('geometry-with-outward-ground-room-v01.json',expanded);dump('reviewed_source_regions.candidate-v01.validation.json',region_validation)
derived,validation=layout_tool.apply_reviewed_layout(ATLAS,expanded,layout,source_region_review=region_review)
dump('geometry-with-authored-root-candidate-v01.json',derived);dump('reviewed_runtime_layout.candidate-v01.validation.json',validation)
# One actual common-world panel. 2.1x display magnification, same source-native pixel->canonical->world conversion for all seven.
B=Image.new('RGB',(1440,840),(25,28,32));D=ImageDraw.Draw(B)
items=[('IDLE C832','/workspace/scratch/girtas-NE-idle-repair-v03/girtas-NE-idle-v03.png',832,[337,407],[161,5,447,417],None)]
for i,p in enumerate(A['poses']):items.append((f'RUN{i} C{Cs[i]}',p['source_path'],Cs[i],roots[i],p['source_region'],i))
for n,(label,path,C,root,roi,phase) in enumerate(items):
 ox=n%4*360;oy=n//4*420;origin=(ox+178,oy+370);s=1024/C*SCALE*2.1
 # lateral slices show physical ground projection, not horizontal image floor
 for L,col in [(-50,(55,72,84)),(79,(70,88,70))]:
  line=[]
  for X in [-300,300]:line.append((origin[0]+X*SCALE*2.1,origin[1]+(M*X+K*L)*SCALE*2.1))
  D.line(line,fill=col,width=1)
 im=Image.open(path).convert('RGBA');x,y,w,h=roi;crop=im.crop((x,y,x+w,y+h));crop=crop.resize((round(w*s),round(h*s)),Image.Resampling.LANCZOS)
 B.paste(crop,(round(origin[0]+(x-root[0])*s),round(origin[1]+(y-root[1])*s)),crop)
 D.text((ox+5,oy+4),label+' actual common-world ground',fill='white');D.line((origin[0]-6,origin[1],origin[0]+6,origin[1]),fill=(80,180,255));D.line((origin[0],origin[1]-6,origin[0],origin[1]+6),fill=(80,180,255))
 if phase is not None:
  for foot in feet[phase]:
   pts=[(origin[0]+(q[0]-root[0])*s,origin[1]+(q[1]-root[1])*s) for q in foot['sole_polyline']]
   D.line(pts,fill=(70,240,170) if 'contact'in foot else (255,165,70),width=2)
  D.text((ox+5,oy+22),f'waistH {source_data[phase]["waist_to_ground_canonical"]:.1f} canonical',fill=(190,195,200))
D.text((1085,425),'Same 1024/C * .219105 * 2.1',fill='white');D.text((1085,443),'Blue=root; green=supportsole',fill='white');D.text((1085,461),'Orange=AIR/recovery sole',fill='white');D.text((1085,479),'Lines=near/far ground slices',fill='white');D.text((1085,505),'AUTHOR CANDIDATE; NO PASS',fill=(255,190,90));D.text((1085,527),'Deep load + idle rise exposed',fill=(255,190,90))
p_board=OUT/'private-actual-seven-common-world-root-candidate-v01.jpg'
for q in [83,76,68,58,48]:
 B.save(p_board,quality=q,optimize=True)
 if p_board.stat().st_size<=130000:break
assert p_board.stat().st_size<=130000
receipt={'status':'AUTHOR_CANDIDATE_READY_FOR_INDEPENDENT_QC','paths':{name:{'path':str(p),'sha256':sha(p),'bytes':p.stat().st_size} for name,p in [('physical_proof',p_proof),('runtime_layout',p_layout),('source_regions',OUT/'reviewed_source_regions.candidate-v01.json'),('derived_geometry',OUT/'geometry-with-authored-root-candidate-v01.json'),('numeric_layout_validation',OUT/'reviewed_runtime_layout.candidate-v01.validation.json'),('region_validation',OUT/'reviewed_source_regions.candidate-v01.validation.json'),('private_common_world_board',p_board)]},'actor_approval':False}
dump('candidate-receipt-v01.json',receipt)
print(json.dumps(receipt,indent=2))
