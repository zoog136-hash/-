import hashlib
import json
from pathlib import Path

from PIL import Image

D = Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01')
V = D / 'actual-NE-run-two-proximal-pelvis-finish-v04'
BASE = D / 'actual-NE-run-six-common-material-finish-v03/NE-run-common-finished-six-actual-source-roster-v03.json'
OUT = V / 'NE-run-exact-final-six-actual-source-roster-v04.json'

def rec(p):
    p = Path(p)
    b = p.read_bytes()
    return dict(path=str(p), sha256=hashlib.sha256(b).hexdigest(), bytes=len(b))

j = json.loads(BASE.read_text())
assert rec(BASE)['sha256'] == '64cfc1d121ad9e63619cfeb0ef07aae2fae194083a7085812e199f8a6fe5d850'
assert rec(j['exact_original_physical_rig']['path']) == j['exact_original_physical_rig']
for f in j['frames']:
    assert rec(f['source']['path']) == f['source']
    i = f['phase']
    if i in [2, 3]:
        q = V / f'phase{i}-actual-pelvis-finish-v04'
        pr = q / 'actual-two-proximal-pelvis-skin-bind-preservation-proof-v04.json'
        p = json.loads(pr.read_text())
        assert p['outside_actual_R_proximal_support_RGBA_mismatch'] == 0
        assert p['original_foreground_whitehem_body_staff_RGBA_mismatch'] == 0
        assert not p['heel_and_all_bone_controls_changed']
        assert p['unchanged_actual_joint_controls'] == f['joint_controls_and_shoes']
        f['prior_actual_common_source_preserved'] = f['source']
        f['source'] = p['output']
        assert rec(f['source']['path']) == f['source']
        f['actual_proximal_skin_finish_provenance'] = rec(pr)
        f['actual_proximal_skin_causal_mesh'] = rec(q / 'RIGHT-actual-proximal-skin-pelvis-bound-thigh-calf-actual-forward-mesh.json')
    assert list(Image.open(f['source']['path']).size) == [1536, 1536]
    assert f['C'] == 2432 and f['bodyunit'] == 2.375
    assert f['storage_translation'] == [128, 128]
    f['static_source_status'] = 'INDEPENDENT_ACTUAL_SOURCE_PASS_FINAL_SIX_WITH_CYCLE_PASS; immutable formal QC receipt separate'

j['schema'] = 'NE_RUN_EXACT_FINAL_SIX_ACTUAL_SOURCE_ROSTER_V04'
j['prior_immutable_common_finish_roster'] = rec(BASE)
j['actual_two_proximal_soft_skin_surface_model'] = rec(V / 'NE-run-two-actual-proximal-pelvis-surface-model-v04.json')
j['actual_six_source_and_cycle_gate'] = 'INDEPENDENT_PASS; 0/1/4/5 retained v03, two changed hips 2/3 v04 independently passed; formal immutable receipt separate'
j['full_source_cycle_and_runtime_gate_pending'] = False
j['actual_game_runtime_gate_pending'] = True
j['physical_scope'] = 'One explicit compatible finite rig and actual shoe/tarsal/soft-skin surfaces with declared uncertainty. Contact full planar-card minima below zero remain disclosed; not a unique hidden 3D reconstruction or strict all-sole contact measurement.'
j['clock']['actual_game_run_speed_world'] = 262.5
j['clock']['effective_actual_phase_Hz'] = 15.625
j['clock']['effective_actual_phase_seconds'] = 0.064
j['clock']['world_per_phase'] = 16.8
j['actor_approvals_added'] = 0
j['completed_detailed_actors_unchanged'] = 2
assert not OUT.exists(), 'Preserve immutable existing roster'
OUT.write_text(json.dumps(j, indent=2) + '\n')
print(json.dumps(dict(roster=rec(OUT), phases=[dict(phase=f['phase'], sha256=f['source']['sha256']) for f in j['frames']]), separators=(',', ':')))
