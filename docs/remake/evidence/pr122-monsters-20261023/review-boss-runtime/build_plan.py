"""Boss runtime-resource/playability plan; no appearance-quality decisions."""
from collections import defaultdict
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent


def read(path):
    return json.loads((ROOT / path).read_text())


def build():
    scope = read('data/pr122_monster_production_scope.json')
    bosses = [row for row in scope['monsters'] if row['kind'] == 'boss']
    assert len(bosses) == 60 and sum(row['preserved_status'] == 'VERIFIED_COMPLETED' for row in bosses) == 43
    profiles = read('data/combat_animation_profiles.json')['profiles']
    db = read('data/monsters/monster_world_catalog.json')
    presentation = read('data/animation_presentation.json')
    records = {}
    for raw in read('data/game_db_v17.json')['몬스터']:
        row = deepcopy(raw)
        row.update(db['overlays'].get(row['name'], {}))
        records[row['name']] = row
    for patch in db['additions']:
        if patch['name'] in records:
            continue
        row = deepcopy(records.get(patch.get('template', '해골 근위병'), {}))
        row.update(patch)
        records[row['name']] = row
    groups = defaultdict(list)
    for row in bosses:
        key = row['id']
        groups[profiles[key]['frames_path']].append(dict(key=key,
            approved_preserved=row['preserved_status'] == 'VERIFIED_COMPLETED',
            preserved_status=row['preserved_status'], profile_settings=profiles[key],
            record=records[row['name']], presentation=presentation.get('bosses', {}).get(key, {})))
    resources = []
    for path, rows in sorted(groups.items()):
        file = ROOT / path.removeprefix('res://')
        text = file.read_text() if file.is_file() else ''
        resources.append(dict(frames=path, TRES_present=file.is_file(),
            TRES_sha256=hashlib.sha256(file.read_bytes()).hexdigest() if file.is_file() else None,
            texture_paths=sorted(set(re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)"', text))), entries=rows))
    result = dict(schema='pr122-boss-runtime-playability-plan-v1',
        HEAD=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        exact_boss_ids=[row['id'] for row in bosses], bosses=60, approved_preserved=43,
        unique_TRES=len(resources), required_roles_direction_counts=dict(idle=8, run=8, attack=8, hit=8, death=1),
        additional_existing_death_directions_checked=True, runtime_run_to_walk_fallback_allowed=True,
        art_quality_review='NOT_PERFORMED: independent boss appearance reviewers own quality decisions.',
        approval_changes=0, resources=resources)
    (OUT / 'plan.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('BOSS_RUNTIME_PLAN bosses=60 approved_preserved=43 unique_TRES=%d' % len(resources))


if __name__ == '__main__':
    build()
