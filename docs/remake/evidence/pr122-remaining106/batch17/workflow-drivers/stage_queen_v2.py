from pathlib import Path
import copy,json,sys

root=Path('/workspace/runtime/batch17');repo=Path('/workspace/twilight');project=root/'Main-project'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
key='monster:얼음 여왕'
old=json.loads((root/'queen-candidate.json').read_text())
rejected=json.loads((root/'Queen-Gnoll-QA-v01/gameplay/report-cases/queen-candidate.json').read_text())
assert len(rejected['failures'])==344
assert set(rejected['failures'])=={'existing skeleton attack '+d for d in core.DIRECTIONS}
path=project/'data/combat_animation_profiles.json';staged=json.loads(path.read_text())
production=json.loads((repo/'data/combat_animation_profiles.json').read_text())
assert not production['profiles'][key].get('frames_path')
(root/'queen-rejected-stage-profile-v1.json').write_text(json.dumps({
 'review':'REJECTED isolated cast-alias trial:344 normal-attack route assertions, eight directions. No production approval. Preserve v1 PNG/TRES/provenance and profile.',
 'failures':list(dict.fromkeys(rejected['failures'])),'rejected_profile':staged['profiles'][key],
 'restore_scope':'Only the rejected isolated staging profile; repository production profile is unchanged.',
 'production_baseline':production['profiles'][key]},ensure_ascii=False,indent=2)+'\n')
# Explicit failed-trial review restores only the private staging key. The
# unchanged importer still rejects replacing any declared native profile.
staged['profiles'][key]=copy.deepcopy(production['profiles'][key]);core.expansion.save_profiles(path,staged)
new=copy.deepcopy(old);new.pop('action_aliases');new['review'].pop('cast_uses_authored_attack')
new['prompt']+=' Optional cast-alias v1 failed the unchanged normal-attack route gate and remains preserved. This v2 defers extra cast track names and uses the authored attack through the existing normal magic route. No PNG, combat-data or AI changes.'
new['review']['notes']+=' Optional cast alias deferred; source gait/contact remains HOLD. This is a new isolated metadata version, not an approved replacement.'
result=core.import_sheet(project,new,'ice_queen_batch17_candidate_v2',[key],True)
(root/'queen-candidate-v2.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
queen={'name':'얼음 여왕','folder':'ice_queen_batch17_candidate_v2','slug':'queen-candidate-v2'}
baseline={'name':'알비노 이구아나','folder':'albino_iguana_monster_authored','slug':'preserved-iguana-baseline'}
for name,cases in [('pr122_batch17_queen_v2',[queen,baseline]),('pr122_batch17_candidates_v2',[queen,{'name':'놀','folder':'gnoll_batch17_candidate','slug':'gnoll-candidate'},baseline])]:
 (project/'tests/fixtures'/(name+'.json')).write_text(json.dumps({'cases':cases},ensure_ascii=False,indent=2)+'\n')
assert json.loads((repo/'data/combat_animation_profiles.json').read_text())['profiles'][key]==production['profiles'][key]
print(json.dumps(result,ensure_ascii=False))
