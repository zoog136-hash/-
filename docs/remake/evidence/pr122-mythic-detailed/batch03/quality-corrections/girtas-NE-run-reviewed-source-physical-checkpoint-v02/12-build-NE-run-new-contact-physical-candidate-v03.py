from pathlib import Path
import json,hashlib
B=Path('/workspace/scratch');P=B/'girtas-NE-run-reviewed-composite-v02'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:json.loads(Path(p).read_text())
def pin(p):p=Path(p);return {'path':str(p),'sha256':sha(p),'bytes':p.stat().st_size}
newraw=P/'girtas-NE-run-reviewed-composite-v02.png';ap=newraw.with_suffix('.assembly.json');a=read(ap)
m=P/'selected-six-bounded-contacts-PROVISIONAL-v01.json';manifest=read(m)
s0=B/'girtas-final-actual-quality-v04/NE-run-contact0-bounded-v02-independent-source-PASS.json'
s3=B/'girtas-ne-final-source-cycle-independent-fresh-20261020/NE-run-contact3-bounded-v04-independent-source-PASS.json'
assert sha(s0)=='f71977cb04e446a7176b92561b65024e58fa69d2d89776f77c636a97cdd049c8'
assert sha(s3)=='3c327d250d6770064df028f94f4ff29c6f1c3c2e5652777056d7a8769cc80afd'
hist=B/'girtas-private-qc-v02-20261019/NE-run-selected-final-six-independent-source-cycle-bridge-v01.json'
for i in [1,2,4,5]:
 p=a['poses'][i];old=read(B/'girtas-NE-run-reviewed-composite-v01/girtas-NE-run-reviewed-composite-v01.assembly.json')['poses'][i]
 assert p['source_sha256']==old['source_sha256'] and p['rgba_sha256']==old['rgba_sha256']
bridge={'status':'PASS_INDIVIDUAL_SOURCE_COVERAGE_AND_EXACT_RGBA_TRANSFER_NEW_CYCLE_PHYSICAL_HOLD','key':'transform:267','direction':'NE','role':'run','source_sha256':sha(newraw),'selected_manifest':pin(m),'assembly':pin(ap),'selected_source0_independent_review':pin(s0),'selected_source3_independent_review':pin(s3),'unchanged_sources1_2_4_5_historical_independent_review':pin(hist),'unchanged_source_phases':[1,2,4,5],'all_six_exact_source_RGBA_crops_preserved':True,'scope':'Formal evidence bridge from already independent SOURCE0/3 and byte-identical earlier source1/2/4/5. This is not a new independent whole-cycle/ground/body review.','whole_cycle_status':'HOLD_PENDING_CURRENT_ACTUAL_COMMON_WORLD_REVIEW','physical_status':'HOLD','runtime_status':'HOLD','integration_ready':False,'actor_approval':False,'new_approvals':0}
bp=P/'selected-six-source-only-exact-transfer-bridge-v01.json';assert (not bp.exists()) or read(bp)==bridge
if not bp.exists():bp.write_text(json.dumps(bridge,indent=2,ensure_ascii=False)+'\n')
s=(B/'girtas-NE-run-fresh-physical-author-v01/build_candidate.py').read_text()
s=s.replace("OUT=Path('/workspace/scratch/girtas-NE-run-fresh-physical-author-v01')","OUT=Path('/workspace/scratch/girtas-NE-run-new-contacts-physical-candidate-v02')\nOUT.mkdir(exist_ok=False)")
s=s.replace("ATLAS=Path('/workspace/scratch/girtas-NE-run-reviewed-composite-v01/girtas-NE-run-reviewed-composite-v01.png')","ATLAS=Path('/workspace/scratch/girtas-NE-run-reviewed-composite-v02/girtas-NE-run-reviewed-composite-v02.png')")
s=s.replace('roots=[[730,1200],[779,1215],[720,1254],[717,1125],[758,1128],[805,1259]]','roots=[[730,1049],[779,1215],[720,1254],[717,1023],[758,1128],[805,1259]]')
s=s.replace('M=-0.5902395098824383','M=-0.5902918298980975').replace('K=0.8914722143009328','K=0.8914611308665146')
s=s.replace("'roi':[540,1040,800,1254],'contact':[683,1143],'sole_polyline':[[640,1133],[683,1143],[728,1143],[752,1137]]", "'roi':[610,900,780,1025],'contact':[637,1021],'sole_polyline':[[622,1019],[630,1020],[637,1021],[645,1021],[660,1021],[680,1019],[700,1019],[720,1016],[740,1011]]")
s=s.replace("'roi':[850,1030,1080,1250],'contact':[905,1136],'sole_polyline':[[905,1136],[933,1124],[981,1102],[1034,1079]]", "'roi':[890,875,1100,1025],'contact':[934,1018],'sole_polyline':[[922,1012],[934,1018],[950,1016],[980,1007],[1000,987],[1020,981],[1040,974],[1060,957]]")
start=s.index('  # snap each inspected sole sample')
end=s.index("  foot['sole_polyline']=",start)
s=s[:start]+'''  # Observe a true alpha100 outer silhouette edge, not a painted sole interior.
  def snap(q):
   x,y=q;pts=[]
   for radius in [4,8,16,24]:
    for yy in range(max(1,y-radius),min(im.shape[0]-1,y+radius+1)):
     for xx in range(max(1,x-radius),min(im.shape[1]-1,x+radius+1)):
      if im[yy,xx,3]>100 and any(im[yy+dy,xx+dx,3]<=100 for dx,dy in [(0,1),(0,-1),(1,0),(-1,0)]):pts.append(((xx-x)**2+(yy-y)**2,xx,yy))
    if pts:break
   assert pts,(i,q)
   _,xx,yy=min(pts);return [int(xx),int(yy)]
'''+s[end:]
s=s.replace("'source6_QC_path':'/workspace/scratch/girtas-private-qc-v02-20261019/NE-run-selected-final-six-independent-source-cycle-bridge-v01.json','source6_QC_sha256':'8e99326ebfe236e3d47c9106ddf58f645aed095da1325bf77aa8b9a3c466d307'", "'source6_individual_art_transfer_bridge_path':str(Path('/workspace/scratch/girtas-NE-run-reviewed-composite-v02/selected-six-source-only-exact-transfer-bridge-v01.json')),'source6_individual_art_transfer_bridge_sha256':sha('/workspace/scratch/girtas-NE-run-reviewed-composite-v02/selected-six-source-only-exact-transfer-bridge-v01.json'),'current_whole_six_cycle_review_status':'HOLD_PENDING_FRESH_INDEPENDENT_REVIEW'")
s=s.replace("'author':'/root/girtas_ne_run_physical_author_fresh'", "'author':'/root/girtas_se_walk_author adapting original fresh author fixed camera/projection and ROOT-approved actual new sole roots; independent reviewer separate'")
s=s.replace('Accepted exact source6 and accepted fixed rigid Cs.', 'Formal individual SOURCE6 exact-transfer coverage and accepted fixed rigid Cs; current whole-cycle physical still HOLD.')
s=s.replace("'warning_for_independent_decision':'Accepted C and actual painted proportions produce contact uppercore substantially above idle and deep load compression.", "'warning_for_independent_decision':'New bounded contacts replace the old stretched legs; unchanged AIR5-to0 has a large uppercore drop that still requires actual cycle judgment.")
s=s.replace("p_proof=dump(",'''# Conservative whole assigned AIR-boot ROI minima, including every alpha100 pixel (not sparse sole points).
for phase in [2,5]:
 pp=A['poses'][phase];im=np.array(Image.open(pp['source_path']));C=Cs[phase];ratio=1024/C;root=roots[phase]
 for foot in source_data[phase]['feet']:
  x0,y0,x1,y1=foot['roi'];ys,xs=np.where(im[y0:y1,x0:x1,3]>100);xs=xs+x0;ys=ys+y0
  Lmin=foot['lateral_projected_X_canonical_interval'][0];clear=M*(xs-root[0])*ratio+K*Lmin-(ys-root[1])*ratio;j=int(np.argmin(clear))
  foot['whole_assigned_boot_ROI_alpha100_conservative_clearance']={'ROI_xyxy':[x0,y0,x1,y1],'all_strong_pixels':int(len(xs)),'minimum_native_pixel':[int(xs[j]),int(ys[j])],'minimum_canonical':float(clear[j]),'minimum_world':float(clear[j]*SCALE),'after_4native_XY_uncertainty_world':float((clear[j]-4*ratio*(abs(M)+1))*SCALE),'not_a_measured_absolute_floor':True}
proof['current_timing']={'fps':12.5,'frame_duration':1,'seconds_per_frame':.08,'six_cycle_seconds':.48,'basis':'Fresh independent reviewer provided current actual r099 run_7; future compiled target requires ROOT validation.'}
proof['new_contacts_actual_edge_audit']={'path':'/workspace/scratch/girtas-NE-run-fresh-physical-author-v01/new-bounded-source0-source3-actual-edge-audit-and-clearance-correction-v01.json','sha256':'1fb54d6b695cba7e13360f2454837d4bfe9a786165dc0e68389685ae5ab9ef8b','m_K_exact_transferred':True,'native_roots_are_frozen_integer_authored_values':True}
proof['source_rgba_unchanged_in_this_operation']=True
p_proof=dump(''')
s=s.replace('<=150000','<=130000')
# Save generated program first so its exact executed code is reviewable; execute once in fresh output folder.
script=B/'build-NE-run-new-contact-physical-candidate-executed-v02.py';assert not script.exists();script.write_text(s)
exec(compile(s,str(script),'exec'))
print(json.dumps({'status':'NEW_PHYSICAL_CANDIDATE_GEOMETRY_ONLY_READY_NO_APPROVAL','output_folder':'/workspace/scratch/girtas-NE-run-new-contacts-physical-candidate-v02','source_sha256':sha(newraw),'source3_independent_source_PASS':sha(s3),'whole_cycle_physical_status':'HOLD','actor_approval':False}))
