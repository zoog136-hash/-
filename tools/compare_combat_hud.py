"""Compare identical HP-only combat workloads; timings are diagnostic, not gates."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--before', type=Path, required=True)
parser.add_argument('--after', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()

def read(root):
    return json.loads(next(root.rglob('combat-hud-review/performance.json')).read_text())

before, after = read(args.before), read(args.after)
assert len(before['samples']) == len(after['samples']) == 2
for old, new in zip(before['samples'], after['samples']):
    assert old['panel_open'] == new['panel_open']
    assert old['incoming_strikes'] == new['incoming_strikes'] == 192
    assert old['simulated_frames'] == new['simulated_frames'] == 32
    assert old['hp_after'] == new['hp_after'] == new['hud_hp']
    assert old['hud_max_hp'] == new['hud_max_hp']
    assert old['full_hud_refreshes'] > 0
    assert new['full_hud_refreshes'] == new['equipment_syncs'] == new['character_snapshots'] == 0
    assert new['max_hp_queries'] == new['max_mp_queries'] == 0
report = {'before': before, 'after': after,
          'note': 'Same engine/runner and deterministic input; equal real HP damage and HUD limits. Timings are not GPU FPS guarantees.'}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print('COMBAT_HUD_COMPARISON_OK')
