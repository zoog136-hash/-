from pathlib import Path
import json,sys

repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch17');project=root/'Main-project'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
checks={x['name']:x for x in json.loads((root/'source-checks.json').read_text())}

def sheet(name,direction,roles,reference_rows,kind):
    check=checks[name];assert check['status']=='GEOMETRY_PASS_ONLY',name
    path=Path(check['path']);assert core.sha(path)==check['sha256']
    sample=core.analyze(path,check['rows'],reference_rows,directions_axis=check['axis'],directions=[direction],canvas_size=2048)
    equivalent=sample['neutral_height']*(1.25 if kind=='death' else 1.0)
    # A common larger virtual canvas for ALL eight gnoll views accommodates
    # the long connected poleaxe. The final max-living normalization restores
    # physical target height; this is not per-phase/per-direction rescaling.
    canvas=round(equivalent*256/(140 if name.startswith('queen') else 64)/8)*8
    core.require_complete_pose_regions(path,core.analyze(path,check['rows'],reference_rows,directions_axis=check['axis'],directions=[direction],canvas_size=canvas))
    return {'output_path':str(path),'rows':check['rows'],'roles':roles,'reference_rows':reference_rows,
      'directions':[direction],'directions_axis':check['axis'],'canvas_size':canvas,
      'scale_review_note':'Provisional ONE whole-source canvas; no per-phase scaling or PNG edits. All gnoll views use common neutral64 before max-living display normalization, leaving room for the poleaxe. Queen neutral/recovery calibration, kneeling death source uses a whole-sheet standing equivalent. Actual Main anatomy/gait/contact review required; not production approval.'}

queen=[]
for d in core.DIRECTIONS:
    if d=='E':
        queen.append(sheet('queen-E-idle2-v04',d,{'idle':[0,1]},[0,1],'idle'))
        queen.append(sheet('queen-E-hit2-v03',d,{'hit':[0,1]},[0,1],'hit'))
    elif d in ['S','NE']:
        for role in ['idle','hit']:queen.append(sheet(f'queen-{d}-{role}2-v05',d,{role:[0,1]},[0,1],role))
    else:queen.append(sheet(f'queen-{d}-idlehit4-v04',d,{'idle':[0,1],'hit':[2,3]},[0,1],'idle'))
    queen.append(sheet(f'queen-{d}-walk6-'+('v06' if d=='E' else 'v04'),d,{'walk':list(range(6))},[0,3],'walk'))
    attack='v03' if d=='E' else ('v06' if d=='NE' else ('v05' if d in ['SE','NW'] else 'v04'))
    death='v03' if d=='E' else ('v05' if d in ['SE','S','W','NE'] else 'v04')
    queen.append(sheet(f'queen-{d}-attack3-{attack}',d,{'attack':[0,1,2]},[2],'attack'))
    queen.append(sheet(f'queen-{d}-death3-{death}',d,{'death':[0,1,2]},[0],'death'))
gnoll=[]
roles={'idle':[0,1],'walk':list(range(2,8)),'attack':[8,9,10],'hit':[11,12],'death':[13,14,15]}
for d in core.DIRECTIONS:
    version='v03' if d=='E' else ('v05' if d in ['SE','W','NW'] else 'v01')
    gnoll.append(sheet(f'gnoll-{d}-complete16-{version}',d,roles,[0,1],'idle'))
fixtures={'cases':[]}
for label,key,actor,sheets in [('queen','monster:얼음 여왕','ice_queen_batch17_candidate',queen),('gnoll','monster:놀','gnoll_batch17_candidate',gnoll)]:
    candidate={'key':key,'prompt_record_kind':'batch_instructions_with_exact_saved_image_generation_requests',
      'prompt':'Batch17 isolated source candidate. Exact generation requests, all rejected variants and SHA checks preserved. All source bodies accounted; no raw PNG changes, exclusions, mirrored or duplicate frames. Newly authored reference-based source, not recovered SPX. Native QA staging does NOT grant approval.',
      'review':{'identity_preserved':True,'eight_views':True,'motion_roles':True,'no_clipping':True,
                'notes':'Provisional stage inputs: reference model, explicitly authored eight directions and all five nominal motion roles, strict full-source geometry/uniqueness/clipping pass. Actual gait exchange, contact timing and cross-role anatomy remain separate SOURCE_HOLD visual gates. Positive stage flags never substitute for completion approval.'},
      'display_height_basis':'max_living_frame','sheets':sheets}
    if label=='queen':
        candidate['action_aliases']={'cast':'attack'};candidate['review']['cast_uses_authored_attack']=True
    result=core.import_sheet(project,candidate,actor,[key],True)
    (root/(label+'-candidate.json')).write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
    print(label,json.dumps(result,ensure_ascii=False),flush=True)
    fixtures['cases'].append({'name':key.removeprefix('monster:'),'folder':actor,'slug':label+'-candidate'})
fixtures['cases'].append({'name':'알비노 이구아나','folder':'albino_iguana_monster_authored','slug':'preserved-iguana-baseline'})
(project/'tests/fixtures/pr122_batch17_candidates.json').write_text(json.dumps(fixtures,ensure_ascii=False,indent=2)+'\n')
