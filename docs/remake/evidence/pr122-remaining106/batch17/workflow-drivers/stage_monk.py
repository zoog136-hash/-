from pathlib import Path
import json,sys

repo=Path('/workspace/twilight'); root=Path('/workspace/runtime/batch17'); project=root/'Main-project'
sys.path.insert(0,str(repo/'tools')); import import_original_based_motion as core
old=repo/'docs/remake/evidence/pr122-remaining106/batch16/authoring-stop-20261019/monk'
roles={'idle':[0,1],'walk':list(range(2,8)),'attack':[8,9,10],'hit':[11,12],'death':[13,14,15]}
sheets=[]; proofs=[]
def add(path,count,direction,axis,role_rows,refs):
    first=core.analyze(path,count,refs,directions_axis=axis,directions=[direction],canvas_size=2048)
    canvas=round(first['neutral_height']*256/106/8)*8
    geometry=core.analyze(path,count,refs,directions_axis=axis,directions=[direction],canvas_size=canvas)
    core.require_complete_pose_regions(path,geometry)
    spec={'output_path':str(path),'rows':count,'roles':role_rows,'reference_rows':refs,
          'directions':[direction],'directions_axis':axis,'canvas_size':canvas,
          'scale_review_note':'One whole-source scale calibrated from upright neutral or attack recovery, never per-phase scaling. Source bytes unchanged; Main body/gait/root review pending.'}
    sheets.append(spec);proofs.append({'file':str(path),'sha256':core.sha(path),'geometry':geometry})
for direction in core.DIRECTIONS:
    if direction=='SW':continue
    suffix='_v02' if direction in ['E','SE','S'] else ''
    add(old/('monk-'+direction+suffix+'.png'),16,direction,'phase_grid4',roles,[0,1])
def source(name):return Path(json.loads((root/'requests'/(name+'.json')).read_text())['image_path'])
add(source('monk-SW-idle2-v02'),2,'SW','phase_grid2',{'idle':[0,1]},[0,1])
add(source('monk-SW-walk6-v06'),6,'SW','phase_grid3',{'walk':list(range(6))},[0,3])
add(source('monk-SW-combat8-v06'),8,'SW','phase_grid4',{'attack':[0,1,2],'hit':[3,4],'death':[5,6,7]},[2])
candidate={'key':'monster:알비노 몽크','prompt_record_kind':'batch_instructions_with_exact_saved_image_generation_requests',
 'prompt':'Resume batch17: retain112 prior source poses, redraw16 Southwest poses in idle2/walk6/combat8 whole-source sheets. Exact saved generation requests accompany every new source. Rejected full SW v05 and prior raw18 remain unchanged. Newly authored reference-based motion, not recovered SPX.',
 'review':{'identity_preserved':True,'eight_views':True,'motion_roles':True,'no_clipping':True,
  'notes':'Provisional source-stage input: original white gorilla and eight heading sources, all mandatory roles present, strict complete-source/uniqueness/clipping guards. Southwest muzzles point left. This does not approve gait/support, actual Main or production connection; those require separate recorded review.'},
 'display_height_basis':'max_living_frame','sheets':sheets}
result=core.import_sheet(project,candidate,'albino_monk_batch17_authored',[candidate['key']],True)
(root/'monk-candidate.json').write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
(root/'monk-all-sources.json').write_text(json.dumps(proofs,ensure_ascii=False,indent=2)+'\n')
fixture={'cases':[{'name':'알비노 몽크','folder':'albino_monk_batch17_authored','slug':'albino-monk'},
 {'name':'알비노 이구아나','folder':'albino_iguana_monster_authored','slug':'preserved-iguana-baseline'}]}
(project/'tests/fixtures/pr122_batch17_monk.json').write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
