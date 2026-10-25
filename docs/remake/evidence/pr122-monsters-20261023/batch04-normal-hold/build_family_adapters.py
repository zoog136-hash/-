"""Reproduce explicit same-source normal-family adapters, with no approvals."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/batch04-normal-hold')
FOLDER = Path('assets/actors/eight_direction/monster_staging/batch04/albino_fishman/r001')
KEYS = ['monster:에바 왕국 심해어인', 'monster:알비노 심해어', 'monster:알비노 피쉬맨']


def identity(row):
    presentation = deepcopy(row['presentation_to_preserve'])
    for field in ('variant', 'width', 'crest', 'accent'):
        presentation['visual'].pop(field, None)
    return dict(reference=row['reference'], presentation=presentation, group=row['group'])


def build():
    targets = {row['key']: row for row in json.loads((ROOT / 'data/animation_authoring_sources.json').read_text())['targets']
               if row['key'] in KEYS}
    assert len(targets) == 3 and all(identity(row) == identity(targets[KEYS[-1]]) for row in targets.values())
    reference = targets[KEYS[-1]]['reference']
    assert hashlib.sha256((ROOT / reference['path'].removeprefix('res://')).read_bytes()).hexdigest() == reference['sha256']
    profile = (ROOT / FOLDER / 'NativeMotionProfile.tres').read_text()
    adapters = {}
    for key, slug in [(KEYS[0], 'eva_deep_fishman'), (KEYS[1], 'albino_deep_fish')]:
        ratio = targets[key]['presentation_to_preserve']['visual']['width'] / targets[KEYS[-1]]['presentation_to_preserve']['visual']['width']
        destination = FOLDER / 'family-adapters' / (slug + '.tres')
        text = profile.replace('profile_id = "monster:알비노 피쉬맨"', f'profile_id = "{key}"')
        text += f'native_width_ratio = {ratio:.12f}\nmetadata/twilight_same_source_family_adapter = true\n'
        path = ROOT / destination
        path.parent.mkdir(exist_ok=True)
        assert not path.exists() or path.read_text() == text
        path.write_text(text)
        adapters[key] = dict(native_profile='res://' + destination.as_posix(),
            native_profile_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), source_actor=KEYS[-1],
            frames='res://' + (FOLDER / 'SpriteFrames.tres').as_posix(), native_width_ratio=ratio,
            new_source_poses=0, new_approval=False, production_connected=False,
            quality_review='HOLD: same-source family adapter identity/contact/default-Main review pending')
    path = ROOT / 'data/pr122_monster_hold_staging.json'
    register = json.loads(path.read_text())
    register['family_adapters'] = adapters
    path.write_text(json.dumps(register, ensure_ascii=False, indent=2) + '\n')
    evidence = dict(schema=1, same_reference_proven=True, same_rendered_body_attack_and_height_proven=True,
        group='normal_monster', targets=list(targets.values()),
        comparison_omissions=['variant', 'width', 'crest', 'accent'],
        comparison_omission_reason='User permits compatible normal-monster same-source family reuse; per-alias width explicitly retained in staged adapter. No palette re-tint added.',
        shared_new_sources={'run_poses': 32, 'S_death_poses': 3, 'counted_once': True},
        preserved_old_sources={'idle': 16, 'attack': 24, 'hit': 16, 'walk': 24},
        adapters=adapters, newly_completed=0, default_catalog_switches=0,
        claim='One same-source fishman family candidate. Adapters are not independently authored species or approvals.')
    (ROOT / BATCH / 'family-sharing-evidence.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n')
    print('FISHMAN_SAME_SOURCE_FAMILY adapters=2 additional_source_poses=0 approvals=0')


if __name__ == '__main__':
    build()
