from pathlib import Path
import ast,copy,hashlib,json
root=Path(__file__).parent;p=root/'pr122_reviewed_runtime_layout_physical_canvas_proposal.py';tree=ast.parse(p.read_text());fns={n.name:n for n in tree.body if isinstance(n,ast.FunctionDef)};ns={};exec(compile(ast.Module(body=[fns['_validated_authored_canvas_sizes'],fns['_apply_actual_pose_layout']],type_ignores=[]),str(p),'exec'),ns)
validate=ns['_validated_authored_canvas_sizes'];apply=ns['_apply_actual_pose_layout'];results=[]
def record(name,fn,reject=False):
 try: fn()
 except (ValueError,AssertionError):
  assert reject,name+' unexpected rejection';results.append({'name':name,'result':'PASS_EXPECTED_REJECTION'})
 else:
  assert not reject,name+' unexpectedly accepted';results.append({'name':name,'result':'PASS_ACCEPTED'})
def geom(region=(300,0,1200,1500),anchor=(1024,1396)):
 return {'frames':[{'row':i,'direction':'NW','region':list(region),'source_anchor':list(anchor),'rgba_sha256':str(i)*64} for i in range(6)]}
record('valid_perpose2560_nominal2048',lambda:validate({'authored_pose_canvas_sizes':[2560]*6},2048))
for name,sizes,canvas in [('non2048_nominal',[2560]*6,1024),('bool_canvas_member',[True]*6,2048),('float_canvas_member',[2560.0]*6,2048),('short_canvas_list',[2560]*5,2048),('oversize_canvas',[4104]*6,2048),('undersize_canvas',[248]*6,2048),('nonmultiple8_canvas',[2561]*6,2048)]:
 record(name,lambda sizes=sizes,canvas=canvas:validate({'authored_pose_canvas_sizes':sizes},canvas),True)
record('nominal2048_false_fit_reject',lambda:apply(geom(),2048,None,None),True)
g=geom();record('actual2560_padded_root_fit',lambda:apply(g,2048,[2560]*6,None));assert g['frames'][0]['margin']==[556,204,1360,1060] and g['frames'][0]['foot']==[1280,1600]
record('actual2560_real_width_overflow_reject',lambda:apply(geom((0,0,3000,1000),(1500,700)),2048,[2560]*6,None),True)
record('actual2560_real_bottom_overflow_reject',lambda:apply(geom((0,0,1000,1800),(500,100)),2048,[2560]*6,None),True)
record('actual2560_anchor_outside_owned_region_reject',lambda:apply(geom(),2048,[2560]*6,[[1500,1396]]*6),True)
record('actual2560_real_top_overflow_reject',lambda:apply(geom((0,0,1000,2000),(500,1700)),2048,[2560]*6,None),True)
normal=geom((100,50,700,900),(450,800));expected=[]
for f in normal['frames']:
 x,y,w,h=f['region'];ax,ay=f['source_anchor'];expected.append([1024-(ax-x),1280-(ay-y),2048-w,2048-h])
apply(normal,2048,None,None);assert [f['margin'] for f in normal['frames']]==expected and all('canvas_size' not in f and 'foot' not in f for f in normal['frames']);results.append({'name':'no_perpose_nominal_layout_literal_equivalence','result':'PASS_ACCEPTED'})
g=geom((300,0,900,800),(700,700));sizes=[1536,2048,2560,1792,2304,2816];apply(g,2048,sizes,None);order=[3,4,5,0,1,2];play=[g['frames'][i] for i in order];assert all(f['canvas_size'][0]==sizes[f['row']] and f['foot']==[sizes[f['row']]//2,sizes[f['row']]*5//8] for f in play);results.append({'name':'physical_sizes_follow_authored_row_through_playback_permutation','result':'PASS_ACCEPTED'})
# Existing source identity, strict complete-region and source-byte checks stay in the proposal.
a=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='apply_reviewed_layout');text=ast.unparse(a)
for token in ['importer.require_complete_pose_regions(path, derived)','_pose_identity(f)','derived[\'distinct_pixel_frames\'] != 6','derived[\'image_size\'] != base_geometry.get(\'image_size\')','hashlib.sha256(path.read_bytes()).hexdigest() != source_sha','reviewed_regions.apply_reviewed_regions(path, canonical, source_region_review)']:
 assert token in text,token
results.append({'name':'original_source_sha_identity_distinctness_complete_region_ownership_calls_retained','result':'PASS_ACCEPTED'})
report={'schema':'pr122-actual-physical-canvas-fit-proposal-fixtures-v1','status':'PASS_PURE_NUMERIC_HELPER_AND_STATIC_GUARD_FIXTURES_ONLY','proposal_path':str(p),'proposal_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'official_layout_sha256_unchanged':hashlib.sha256(Path('/workspace/twilight/tools/pr122_reviewed_runtime_layout.py').read_bytes()).hexdigest(),'checks':len(results),'results':results,'example':{'root_native_y_analytic':1395.95,'nominal2048_foot_y':1280,'actual2560_foot_y':1600,'nominal_margin_y_if_region_top0':round(1280-1395.95,4),'actual_margin_y_if_region_top0':round(1600-1395.95,4),'review_source_anchors_remain_strict_integer_pairs':True},'no_png_or_game_processing':True,'repo_writes':0,'git_commands':0,'godot_or_ci_runs':0}
out=root/'physical-canvas-fit-proposal-fixtures.json'
with out.open('x') as f:json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({'checks':len(results),'report':str(out),'report_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'proposal_sha256':hashlib.sha256(p.read_bytes()).hexdigest()}))
