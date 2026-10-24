from pathlib import Path
import json,sys
repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');project=root/'Main-project'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
roles={'idle':[0,1],'walk':list(range(2,8)),'attack':[8,9,10],'hit':[11,12],'death':[13,14,15]}
sheets=[];proofs=[]
for direction in core.DIRECTIONS:
    version='_v03' if direction=='SW' else ('_v02' if direction in ['E','SE','S'] else '')
    path=root/('monk-'+direction+version+'.png')
    sample=core.analyze(path,16,[0,1],directions_axis='phase_grid4',directions=[direction],canvas_size=768)
    # One uniform whole-source calibration, never one scale per motion frame.
    canvas=round(sample['neutral_height']*256/106/8)*8
    geometry=core.analyze(path,16,[0,1],directions_axis='phase_grid4',directions=[direction],canvas_size=canvas)
    core.require_complete_pose_regions(path,geometry)
    sheets.append({'output_path':str(path),'rows':16,'roles':roles,'reference_rows':[0,1],
      'directions':[direction],'directions_axis':'phase_grid4','canvas_size':canvas,
      'scale_review_note':'One whole-source resolution canvas calibrated from neutral gorilla bodies; all16 phases retain unchanged raster and one physical scale. Actual Main cross-role core/foot review required.'})
    proofs.append({'direction':direction,'sha256':core.sha(path),'canvas':canvas,'geometry':geometry})
c={'key':'monster:알비노 몽크','prompt_record_kind':'batch_instructions_with_exact_saved_image_generation_requests',
 'prompt':'Batch16:128 newly authored exact original-project albino ape poses; eight independent views with idle2/walk6/attack3/hit2/death3. Source-only authoring, not recovered SPX. Initial4 front layouts were rejected for ownership/stance/SW facing; v02 spacious source and canonical-left SW v03 repair selected. Failed whole sources and two unused standalone idle variants remain preserved, never counted as new completed actors.',
 'review':{'identity_preserved':True,'eight_views':True,'motion_roles':True,'no_clipping':True,
  'notes':'All8 raw full16-pose sources reviewed against original albino ape: connected torso/knuckles/heels, original white-gray fur, genuine front/rear body and true SW idle view. Full whole-source, raw uniqueness, ownership and bounds preflight. Main gait/core/ground and baseline review pending; no production approval from source existence.'},
 'display_height_basis':'max_living_frame','sheets':sheets}
actor='albino_monk_batch16_authored';r=core.import_sheet(project,c,actor,[c['key']],True)
(root/'monk-candidate.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n');(root/'monk-all-sources.json').write_text(json.dumps(proofs,ensure_ascii=False,indent=2)+'\n')
fixture={'cases':[{'name':'알비노 몽크','folder':actor,'slug':'albino-monk'},
 {'name':'알비노 이구아나','folder':'albino_iguana_monster_authored','slug':'preserved-iguana-baseline'}]}
(project/'tests/fixtures/pr122_batch16_monk.json').write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(r,ensure_ascii=False))
