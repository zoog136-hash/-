from pathlib import Path
import json,sys
repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');project=root/'Main-project'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
sheets=[];observations=[]
roles={'idle':[0,1],'walk':list(range(2,8)),'attack':[8,9,10],'hit':[11,12],'death':[13,14,15]}
for direction in core.DIRECTIONS:
    path=root/('spider-'+direction+'.png')
    geometry=core.analyze(path,16,[0,1],directions_axis='phase_grid4',directions=[direction],canvas_size=768)
    core.require_complete_pose_regions(path,geometry)
    anchors=[frame['source_anchor'][:] for frame in geometry['frames']]
    if direction=='N':
        # Rear abdomen projects below the legs. It is not a planted foot.
        # Observe only outer left/right leg tips, retain the entire abdomen.
        with core.Image.open(path) as image:
            pixels=core.np.asarray(image)
            for phase,frame in enumerate(geometry['frames'][:13]):
                x,y,w,h=frame['region'];mask=pixels[y:y+h,x:x+w,3]>100
                outer=max(1,round(w*.20));foot=mask.copy();foot[:,outer:w-outer]=False
                ys,_=core.np.nonzero(foot);candidate=int(y+ys.max())
                if candidate < anchors[phase][1]:
                    observations.append({'direction':direction,'phase':phase,'old_bbox_based':anchors[phase][:],'observed_outer_leg_contact_y':candidate,'whole_body_region_preserved':frame['region']})
                    anchors[phase][1]=candidate
    spec={'output_path':str(path),'rows':16,'directions':[direction],'directions_axis':'phase_grid4','roles':roles,
        'reference_rows':[0,1],'canvas_size':768,
        'scale_review_note':'One identical768 virtual canvas across all8 complete16-pose sources; no per-direction bbox height normalization or per-frame scale changes. Pixel body proportions are retained.'}
    if direction=='N':spec['source_anchors']=anchors
    sheets.append(spec)
candidate={'key':'monster:스파이더','prompt_record_kind':'batch_instructions_with_exact_saved_image_generation_requests',
 'prompt':'Batch16: original-project spider atlas1 cell0,128 newly articulated poses, actual8 directions.16 per source:idle2/walk6/attack3/hit2/death3. All source pixels preserved. Not recovered SPX. Original unsuccessful E_v02 contains17 components and is excluded/preserved; earlier complete E16 is used.',
 'review':{'identity_preserved':True,'eight_views':True,'motion_roles':True,'no_clipping':True,
 'notes':'All eight raw views reviewed: connected eight-leg roots and mouth appendages, original purple-brown hairy abdomen, genuine front/back eye occlusion, distinct crawl/strike/recoil/collapse. Whole-source ownership/count/uniqueness guard unchanged. Actual Main ground/cadence/scale approval pending.'},
 'display_height_basis':'max_living_frame','sheets':sheets}
actor='spider_project_batch16_authored'
result=core.import_sheet(project,candidate,actor,[candidate['key']],True)
(root/'spider-candidate.json').write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
(root/'spider-foot-observations.json').write_text(json.dumps(observations,ensure_ascii=False,indent=2)+'\n')
fixture={'cases':[{'name':'스파이더','folder':actor,'slug':'spider-project'},
 {'name':'알비노 이구아나','folder':'albino_iguana_monster_authored','slug':'preserved-iguana-baseline'}]}
(project/'tests/fixtures/pr122_batch16_spider.json').write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False));print('NORTH_FOOT_OBSERVATIONS',len(observations))
