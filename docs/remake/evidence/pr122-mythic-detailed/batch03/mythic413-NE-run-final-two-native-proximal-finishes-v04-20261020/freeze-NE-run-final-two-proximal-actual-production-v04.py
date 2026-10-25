import hashlib
import json
from pathlib import Path

D = Path(__file__).parent
V = D / 'actual-NE-run-two-proximal-pelvis-finish-v04'
F = Path('/workspace/scratch/mythic413-NE-run-independent-qc-20261020-v01')
OUT = D / 'NE-run-final-two-proximal-actual-production-frozen-allowlist-v04.json'

def rec(p):
    p = Path(p)
    b = p.read_bytes()
    return dict(path=str(p), sha256=hashlib.sha256(b).hexdigest(), bytes=len(b))

prior = [
    D / 'NE-run-first-actual-six-v01-v02-production-frozen-allowlist-v01.json',
    D / 'NE-run-common-material-repair-attempts-and-contact0-v03-frozen-allowlist-v01.json',
    D / 'NE-run-common-finished-six-actual-production-and-source0-PASS-frozen-allowlist-v01.json',
]
files = [
    D / 'finish-NE-run-phase2-3-proximal-real-skin-pelvis-bind-v04.py',
    D / 'derive-NE-run-two-proximal-soft-skin-causal-surface-model-v04.py',
    D / 'freeze-NE-run-exact-final-six-source-roster-v04.py',
    Path(__file__),
    F / 'NE-run-v03-independent-phase2-3-proximal-thigh-source-HOLD-v01.json',
]
# This scope is only the author's two new phase folders and their exact models;
# no global resource scan, previews, or mutable live ledgers enter the archive.
for phase in [2, 3]:
    files += sorted((V / f'phase{phase}-actual-pelvis-finish-v04').iterdir())
files += [
    V / 'NE-run-two-actual-proximal-pelvis-surface-model-v04.json',
    V / 'NE-run-exact-final-six-actual-source-roster-v04.json',
]
records = [rec(p) for p in sorted(set(files))]
j = dict(
    schema='MYTHIC413_NE_RUN_FINAL_TWO_PROXIMAL_ACTUAL_PRODUCTION_FREEZE_V04',
    files=records,
    prior_exact_production_dependencies=[rec(p) for p in prior],
    final_source_roster=rec(V / 'NE-run-exact-final-six-actual-source-roster-v04.json'),
    status='INDEPENDENT_ACTUAL_TWO_HIP_ROI_PASS_AND_FINAL_SIX_SOURCE_CYCLE_PASS_REPORTED; formal immutable QC receipt archived separately',
    old_source_variant_states='v03 phase2/3 preserved with exact formal proximal source HOLD. v04 source2/3 selected; v03 source0/1/4/5 selected unchanged. All prior failed and partial actual PNGs preserved by prior production freezes.',
    unchanged_1c1717_bone_heel_shoe_clock_root_C=True,
    new_local_actual_skin_surface_only=True,
    game_gate_pending_root_owned=True,
    actor_approvals_added=0,
    global_completed_detailed_actors_unchanged=2,
    original_sources_deleted_or_overwritten=False,
    private_previews_and_live_ledgers_excluded=True,
)
assert not OUT.exists(), 'Do not overwrite immutable freezes'
OUT.write_text(json.dumps(j, indent=2) + '\n')
print(json.dumps(dict(freeze=rec(OUT), files=len(records), bytes=sum(r['bytes'] for r in records)), separators=(',', ':')))
