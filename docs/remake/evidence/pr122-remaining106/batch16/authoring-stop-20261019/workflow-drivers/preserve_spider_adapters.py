from pathlib import Path
import json,shutil,sys
repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');out=repo/'docs/remake/evidence/pr122-remaining106/batch16'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
plan=json.loads((out/'spider-family-reuse-plan.json').read_text())
for case in plan['cases']:
    folder=case['folder'];src=root/'Main-project/assets/actors/eight_direction/original_based'/folder;dst=repo/'assets/actors/eight_direction/original_based'/folder
    assert not dst.exists();dst.mkdir()
    for name in ['SpriteFrames.tres','provenance.json']:shutil.copyfile(src/name,dst/name);assert core.sha(src/name)==core.sha(dst/name)
    key=case['target'];label='dark-forest-spider' if key=='monster:검은숲 거미' else 'distorted-tarantula'
    config={'key':key,'actor':folder,'slug':folder.replace('_','-'),'label':label,'poses':128,
      'main':'Spider-Family-Main-QA-v01','temporal':'Spider-Family-Temporal-QA-v01','main_label':'spider-family','temporal_label':'spider-family',
      'candidate':'spider-family-reuse-plan.json','completion_reason':'Exact pinned project atlas1 cell0/crawl/melee source128 reused with original per-ID width/tint/speed cadence; actual Main3686 and continuous87873 all-PASS, new source art0, shared PNG paths retained',
      'next_active':'monster:알비노 몽크','next_state':'SIX_NEW_NATIVE_BINDINGS_LOCALLY_VERIFIED; MONK128_SOURCE_REPAIR_CONTINUES',
      'visual_decision':{'species_gates':dict.fromkeys(['source_review','static_image_gate','temporal_gate','game_function_gate','actual_Main_visual_gate','baseline_comparison'],'PASS'),
        'independent_visual_review':'Resuming agent reviewed source base128 plus actual per-ID Main E/N gait, real poison strike and S terminal collapse. Preserved original per-ID width/tint and actual56/94 movement speeds with distinct cadence. No independent human or no-slip measurement claim.',
        'directions':core.DIRECTIONS,'motion_contract':{'idle':2,'walk':6,'attack':3,'hit':2,'death':3,'unique_poses':128,'run':'No separate source run defined; none invented'},
        'newly_drawn_poses':0,'preserved_prior_poses':128,'new_raw_PNG':0,'total_pack_PNG':0,'shared_source_PNG':8,'source_reuse':True,'source_id':'monster:스파이더',
        'visual_notes':'Verified exact same project atlas bytes/region/body/crawl/melee contract before reuse; no external ID inference. Shared source texture paths prevent duplicate PNG loading. Only original display width/tint and animation cadence are adapted; all gameplay DB, AI, poison/damage/hit count, collision and save logic unchanged. Each actor renders all128 phases in its own actual Main case.'}}
    (root/(label+'-visual-decision.json')).write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n')
print('TWO_EXACT_SOURCE_ADAPTER_PACKS_PRESERVED_NO_PNG_DUPLICATES')
