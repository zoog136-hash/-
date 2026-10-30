from pathlib import Path
import copy,json,sys
repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');project=root/'Main-project'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
from stage_pr122_tomb269_review import GROUND02
candidate=json.loads((repo/'docs/remake/evidence/pr122-remaining106/batch02/tomb269-local-repair01/candidate-112-resumed-HOLD.json').read_text())
raw={}
for directory in [root/'tomb-authoring',repo/'docs/remake/evidence/pr122-remaining106/batch02/tomb269-local-repair01']:
    for p in directory.rglob('*.png'):raw.setdefault(core.sha(p),p)
for s in candidate['sheets']+candidate['pose_files']:
    assert s['source_sha256'] in raw,(s['id'],s['source_sha256'])
    s['output_path']=str(raw[s['source_sha256']])
    s['scale_review_note']='Preserved whole-source canvas and manually observed semantic foot anchors; actual Main final helmet/core/ground review pending. No raster resizing or pose-specific scaling.'
for s in candidate['pose_files']:
    if s['direction']=='NE' and s['role']=='walk' and s['phase'] in [1,2,3]:
        s['output_path']=str(root/('tomb-NE-walk'+str(s['phase'])+'-palette-v02.png'))
        s['source_sha256']=core.sha(Path(s['output_path']))
for sheet in candidate['sheets']:
    dirs=sheet['directions']
    for role,rows in sheet['roles'].items():
        for phase,row in enumerate(rows):
            for di,direction in enumerate(dirs):
                if (role,direction,phase) in GROUND02:
                    sheet['source_anchors'][row*len(dirs)+di]=GROUND02[(role,direction,phase)]
candidate['prompt']='Batch16: restored immutable51-source/112-pose Tomb269 draft; preserve corrected E weapon proportion, NE rear heels, six neutral-palette replacements,32 prior source-foot observations and12 reviewed hit/collapse foot roots. Three NE walk palette v02 edits were newly authored with exact saved prompts. Whole source bytes unchanged; reference-based drawings, not recovered SPX. No production approval from geometry.'
candidate['review']={'identity_preserved':True,'eight_views':True,'motion_roles':True,'no_clipping':True,
 'notes':'Complete source model/facing/connected-body and retained landmark review, with E weapon/NE color/heel corrections. Final actual Main scale/contact/transition review still pending; isolated QA only.'}
actor='tomb_guardian269_batch16_repaired'
result=core.import_mixed_sources(project,candidate,actor,[candidate['key']],True)
(root/'tomb-repaired-candidate.json').write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
fixture=json.loads((project/'tests/fixtures/pr122_tomb269_ground02.json').read_text())
fixture['scope']='Batch16 repaired reference-based Tomb269112 actual Main, source approval pending'
fixture['cases'][0].update(folder=actor,slug='tomb-guardian269-batch16-repaired')
(project/'tests/fixtures/pr122_tomb269_batch16.json').write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
