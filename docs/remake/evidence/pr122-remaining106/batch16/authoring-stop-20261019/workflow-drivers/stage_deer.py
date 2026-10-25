from pathlib import Path
import json
import sys

repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');project=root/'Main-project'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
old=repo/'docs/remake/evidence/pr122-remaining106/batch10'
idle=old/'albino-deer-idle-pilot02/albino-deer-idle-pilot02.png'
g=core.analyze(idle,2,[0,1],directions_axis='blocks4x2',canvas_size=640)
core.require_complete_pose_regions(idle,g)
reference=g['neutral_height']*256/640
sheets=[];proofs=[]
def add(path,role,rows,directions,axis,canvas=None):
    refs=[2] if role=='attack' else ([0,1] if role in ['idle','hit'] else [0])
    sample=core.analyze(path,rows,refs,directions_axis=axis,canvas_size=1536,directions=directions)
    if canvas is None:canvas=round(sample['neutral_height']*256/reference/8)*8
    geometry=core.analyze(path,rows,refs,directions_axis=axis,canvas_size=canvas,directions=directions)
    core.require_complete_pose_regions(path,geometry)
    sheets.append({'output_path':str(path),'rows':rows,'directions':directions,'directions_axis':axis,
       'roles':{role:list(range(rows))},'reference_rows':refs,'canvas_size':canvas,
       'scale_review_note':'One whole-sheet resolution canvas, attack calibrated to full-height recovery. No per-frame scaling or raster alteration.'})
    proofs.append({'file':str(path),'sha256':core.sha(path),'geometry':geometry,'role':role})
add(idle,'idle',2,core.DIRECTIONS,'blocks4x2',640)
add(old/'albino-deer-hit-v02/albino-deer-hit-v02.png','hit',2,core.DIRECTIONS,'blocks4x2',640)
add(old/'albino-deer-death-pilot01/albino-deer-death-pilot01.png','death',3,core.DIRECTIONS,'blocks4x2',640)
for key,dirs in [('albino-deer-walk-N-NE',['N','NE']),('albino-deer-walk-S-SW-v02',['S','SW'])]:
    add(old/key/(key+'.png'),'walk',8,dirs,'rows')
for direction in ['E','SE','W','NW']:
    add(root/('deer-walk-'+direction+'-v01.png'),'walk',8,[direction],'phase_grid4')
for direction in core.DIRECTIONS:
    add(root/('deer-attack-'+direction+'-v03.png'),'attack',3,[direction],'columns')
candidate={'key':'monster:알비노 디어','prompt_record_kind':'batch_instructions_with_exact_saved_image_generation_requests',
 'prompt':'Batch16 source-authoring:32 new four-beat walk and24 new three-phase antler attack poses, v02 identity repair of broad original paddle antlers and v03 spacious whole-direction layout. Preserve88 prior actual poses. Newly authored from original project reference, not recovered SPX animation. Reject/preserve v01 attack identity drift and v02 foreign-body rectangle failures.',
 'review':{'identity_preserved':True,'eight_views':True,'motion_roles':True,'no_clipping':True,
 'notes':'Complete raw model/facing/body/antler review and strict whole-source/uniqueness preflight. Main and cross-role scale review pending; no production approval from geometry.'},
 'display_height_basis':'max_living_frame','sheets':sheets}
actor='albino_deer_batch16_authored'
result=core.import_sheet(project,candidate,actor,[candidate['key']],True)
(root/'deer-candidate.json').write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
(root/'deer-all-sources.json').write_text(json.dumps(proofs,ensure_ascii=False,indent=2)+'\n')
fixture={'cases':[{'name':'알비노 디어','folder':actor,'slug':'albino-deer'},
 {'name':'알비노 이구아나','folder':'albino_iguana_monster_authored','slug':'preserved-iguana-baseline'}]}
(project/'tests/fixtures/pr122_batch16_deer.json').write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False));print('COMPLETE_DEER_SOURCE_MATRIX',sum(len(p['geometry']['frames']) for p in proofs))
