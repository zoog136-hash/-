from pathlib import Path
import json,sys
repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');project=root/'Main-project';out=repo/'docs/remake/evidence/pr122-remaining106/batch16'
sys.path.insert(0,str(repo/'tools'));import retarget_original_motion as adapter
import retime_reused_motion as cadence
import import_original_based_motion as core
targets={x['key']:x for x in json.loads((repo/'data/animation_authoring_sources.json').read_text())['targets']}
source_key='monster:스파이더';relative='assets/actors/eight_direction/original_based/spider_project_batch16_authored/SpriteFrames.tres'
frames=repo/relative;proof=frames.parent/'provenance.json'
cases=[]
for key,folder in [('monster:검은숲 거미','dark_forest_spider_batch16_project'),('monster:왜곡의 타란툴라','distorted_tarantula_batch16_project')]:
    cases.append({'target':key,'source':source_key,'target_contract_SHA256':adapter.digest(adapter.canonical(targets[key])),
        'source_frames_path':relative,'source_frames_SHA256':core.sha(frames),'source_provenance_SHA256':core.sha(proof),'folder':folder})
plan={'scope':'Two exact atlas1 cell0/body/crawl/melee reference matches; explicit per-ID width/tint/speed adapters; new art0; no DB/gameplay edits','cases':cases}
(out/'spider-family-reuse-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
outputs,catalog,results=adapter.prepare(repo,cases)
before=json.loads((project/'data/combat_animation_profiles.json').read_text())
for path,text in outputs.items():
    dest=project/path;assert not dest.exists();dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text)
for c in cases:before['profiles'][c['target']]=catalog['profiles'][c['target']]
core.expansion.save_profiles(project/'data/combat_animation_profiles.json',before)
retimed,observations=cadence.prepare(project,out/'spider-family-reuse-plan.json')
core.expansion.save_profiles(project/'data/combat_animation_profiles.json',retimed)
(out/'spider-family-cadence.json').write_text(json.dumps({'applied':'ISOLATED_MAIN_ONLY','cases':observations},ensure_ascii=False,indent=2)+'\n')
fixture={'cases':[{'name':targets[c['target']]['name'],'folder':c['folder'],'slug':c['folder'].replace('_','-')} for c in cases]}
(project/'tests/fixtures/pr122_batch16_spider_family.json').write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'cases':results,'cadence':observations},ensure_ascii=False))
