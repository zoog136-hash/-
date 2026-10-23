"""Frame-availability inventory only; no art quality or approval decisions."""
from pathlib import Path
from collections import defaultdict
from copy import deepcopy
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent


def read(path):
    return json.loads((ROOT / path).read_text())


def build():
    scope = read('data/pr122_monster_production_scope.json')
    normal = {row['id']: row for row in scope['monsters'] if row['kind'] == 'normal'}
    assert len(normal) == 258
    profiles = read('data/combat_animation_profiles.json')['profiles']
    db = read('data/monsters/monster_world_catalog.json')
    records = {}
    for raw in read('data/game_db_v17.json').get('몬스터', []):
        row = deepcopy(raw)
        row.update(db['overlays'].get(row['name'], {}))
        records[row['name']] = row
    for patch in db['additions']:
        if patch['name'] in records:
            continue
        row = deepcopy(records.get(patch.get('template', '해골 근위병'), {}))
        row.update(patch)
        records[row['name']] = row
    entries = []
    for key, row in normal.items():
        entries.append(dict(entry_id='runtime:' + key, key=key, scope='runtime',
            approved_preserved=row['preserved_status'] == 'VERIFIED_COMPLETED',
            preserved_status=row['preserved_status'], frames=profiles[key].get('frames_path', ''),
            record=records[row['name']], profile_settings=profiles[key]))
    for path in sorted((ROOT / 'data').glob('pr122_monster*staging*.json')):
        value = json.loads(path.read_text())
        for group in ('actors', 'family_adapters'):
            for key, actor in value.get(group, {}).items():
                if key not in normal:
                    continue
                native = actor.get('native_profile', '')
                frames = actor.get('frames', actor.get('frames_path', ''))
                if native and (ROOT / native.removeprefix('res://')).is_file():
                    match = re.search(r'^frames_path\s*=\s*"([^"]+)"', (ROOT / native.removeprefix('res://')).read_text(), re.M)
                    if match:
                        frames = match[1]
                entries.append(dict(entry_id=path.name + ':' + group + ':' + key, key=key,
                    scope='staging_family_adapter' if group == 'family_adapters' else 'staging',
                    register=path.relative_to(ROOT).as_posix(), native_profile=native, frames=frames,
                    approved_preserved=normal[key]['preserved_status'] == 'VERIFIED_COMPLETED',
                    preserved_status=normal[key]['preserved_status'], source_actor=actor.get('source_actor')))
    grouped = defaultdict(list)
    for entry in entries:
        grouped[entry['frames']].append(entry)
    resources = []
    for frames, rows in sorted(grouped.items()):
        path = ROOT / frames.removeprefix('res://')
        text = path.read_text() if path.is_file() else ''
        sources = sorted(set(re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)"', text)))
        resources.append(dict(frames=frames, entries=rows, texture_paths=sources, TRES_present=path.is_file()))
    plan = dict(schema='pr122-normal-frame-audit-plan-v1',
        HEAD=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        runtime_species=258, approved_preserved=221,
        unique_runtime_TRES=len({entry['frames'] for entry in entries if entry['scope'] == 'runtime'}),
        staging_entries=sum(entry['scope'] != 'runtime' for entry in entries),
        required_roles_direction_counts=dict(idle=8, run=8, attack=8, hit=8, death=1),
        runtime_run_walk_fallback_permitted=True, required_death='S; preserve and resolve requested existing directions first',
        quality_review='NOT_PERFORMED_PER_USER: no appearance, palette, species, ground-contact, facing-quality or attack-pose review',
        approval_changes=0, resources=resources)
    (OUT / 'plan.json').write_text(json.dumps(plan, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: plan[key] for key in ['runtime_species', 'approved_preserved', 'unique_runtime_TRES', 'staging_entries']}))


if __name__ == '__main__':
    build()
