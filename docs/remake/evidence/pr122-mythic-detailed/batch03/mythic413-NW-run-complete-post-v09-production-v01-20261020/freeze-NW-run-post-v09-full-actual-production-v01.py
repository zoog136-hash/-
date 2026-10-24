from pathlib import Path
import hashlib
import json

D = Path('/workspace/scratch/mythic413-NW-run-load-fresh-20261020-v01')
Q = Path('/workspace/scratch/mythic413-nw-run-contact-independent-qc-20261020')
F = Path('/workspace/scratch/mythic413-nw-run-cycle-qc-fresh-v02-20261020')
N = Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020')
OUT = D / 'NW-run-post-v09-complete-actual-production-frozen-allowlist-v01.json'
assert not OUT.exists(), 'Immutable freeze already exists; do not overwrite.'

def record(p):
    assert p.is_file(), f'Missing required file: {p}'
    raw = p.read_bytes()
    return {'path': str(p), 'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)}

folders = (
    ['load1-actual-rig-v10']
    + [f'flight2-actual-rig-v{i:02d}' for i in range(1, 5)]
    + [f'contact3-actual-rig-v{i:02d}' for i in range(1, 7)]
    + [f'load4-actual-rig-v{i:02d}' for i in range(1, 5)]
    + [f'flight5-actual-rig-v{i:02d}' for i in (1, 2, 4)]
    + ['original915-complete-near-leg-native-v01',
       'actual-approved-recovery-ankle-surface-native-v01',
       'actual-short-blackleather-recovery-joint-native-v01',
       'actual-short-blackleather-recovery-joint-native-v02']
)
files = set()
for name in folders:
    folder = D / name
    assert folder.is_dir(), f'Missing actual production directory: {folder}'
    files.update(p for p in folder.iterdir() if p.is_file() and p.suffix in ('.png', '.json'))

scripts = [
    'author-real-NW-run-load1-rig-v10-genuine-rigid3D-footroll-and-ankle.py',
    'author-real-NW-run-flight2-rig-v01-actual-parts.py',
    'author-real-NW-run-flight2-rig-v02-lossless-storage-padding.py',
    'author-real-NW-run-flight2-rig-v03-complete-original-thigh-and-boots.py',
    'author-real-NW-run-flight2-rig-v04-remove-exact-old-boot-edge-remnant.py',
    'extract-original915-complete-near-leg-material-v01.py',
    'author-real-NW-run-contact3-rig-v01-complete-actual-contralateral-parts.py',
    'author-real-NW-run-contact3-rig-v02-coherent-original-shaft-and-whole-shoe.py',
    'author-real-NW-run-contact3-rig-v03-exact-fixedbone-model-knee-control.py',
    'author-real-NW-run-contact3-rig-v04-common-actual-recovery-ankle.py',
    'author-real-NW-run-load4-rig-v01-genuine-opposite-rigid3D-footroll.py',
    'author-real-NW-run-load4-rig-v02-common-actual-recovery-ankle.py',
    'author-real-NW-run-flight5-rig-v01-complete-opposite-actual-parts.py',
    'author-real-NW-run-flight5-rig-v02-common-actual-recovery-ankle.py',
    'extract-approved-actual-recovery-ankle-surface-v01.py',
    'rig-actual-approved-recovery-ankle-surface-helper-v01.py',
    'finish-three-actual-recovery-ankles-short-blackleather-v01.py',
    'finish-three-actual-recovery-ankles-short-blackleather-v02-exact-outsideRGBA.py',
    'derive-actual-load1-footroll-rigid3D-v01.py',
    'derive-original915-matched-fixed-boot-contact3-load4-footroll-v01.py',
    'derive-final-six-actual-causal-rig-and-foot-surface-bounds-v01.py',
    'freeze-actual-six-NW-run-source-roster-v01.py',
    'freeze-NW-run-post-v09-full-actual-production-v01.py',
]
files.update(D / name for name in scripts)
files.update(D / name for name in [
    'actual-load1-rigid3D-heel-pinned-footroll-contract-v01.json',
    'original915-matched-fixed-boot-contact3-load4-footroll-contract-v01.json',
    'final-six-actual-causal-rig-and-full-foot-surface-AIR-bounds-v01.json',
    'Mythic413-NW-run-final-six-actual-source-roster-v01.json',
    'NW-run-final-six-static-PASS-source-quick-frozen-allowlist-v01.json',
])
proofs = [
    Q / 'NW-run-load1-v10-independent-source-and-partial-physical-PASS-v01.json',
    Q / 'NW-run-flight2-v04-independent-static-source-PASS-v01.json',
    F / 'CONTACT3-v01-independent-actual-ankle-material-HOLD-v01.json',
    F / 'CONTACT3-v03-independent-model-control-PASS-left-ankle-HOLD-v01.json',
    F / 'LOAD4-FLIGHT5-v01-independent-shared-ankle-HOLD-v01.json',
    F / 'opposite3-4-5-shared-surface-v01-independent-alpha-fade-HOLD-v01.json',
    F / 'opposite3-4-5-final-short-joints-independent-static-source-PASS-v01.json',
    F / 'CONTACT3-LOAD4-ea6969-independent-constructive-numeric-v01.json',
    N / 'RUN-dae173-new-footroll-independent-constructive-numeric-PASS-v01.json',
    N / 'RUN-AIR5-v01-independent-finite-bones-marker-construction-PASS-v01.json',
]
files.update(proofs)

dependencies = [D / name for name in [
    'contact0-v08-static-PASS-original-cloth-layer-frozen-allowlist-v02.json',
    'contact0-original-garment-and-actual-layer-join-frozen-allowlist-v01.json',
    'NW-run-load1-v01-through-v05-actual-production-frozen-allowlist-v01.json',
    'NW-run-load1-v06-through-v09-actual-production-static-PASS-frozen-allowlist-v01.json',
]]
input_refs = [
    Path('/workspace/scratch/mythic413-NW-run-author-20261020-r001/thunder_female-NW-run-contact0-v01-service.png'),
    D / 'thunder_female-NW-run-contact0-v08-original-cloth-joint-occlusion.png',
    D / 'actual-pair-fixed-bone-and-staff-rig-proposal-v01.json',
]

roster = json.loads((D / 'Mythic413-NW-run-final-six-actual-source-roster-v01.json').read_text())
records = [record(p) for p in sorted(files)]
output = {
    'schema': 'TWILIGHT_PR122_ACTUAL_NW_RUN_POST_V09_IMMUTABLE_PRODUCTION_FREEZE_V01',
    'scope': 'Actual native-density source production after prior remote v01-v09 archives; all finished and historical actual attempts are preserved.',
    'files': records,
    'file_count': len(records),
    'total_bytes_before_sha_deduplication': sum(r['bytes'] for r in records),
    'prior_remote_dependency_archives': [record(p) for p in dependencies],
    'existing_input_sha256_reference': [record(p) for p in input_refs],
    'selected_final_roster': record(D / 'Mythic413-NW-run-final-six-actual-source-roster-v01.json'),
    'source_status': {
        'load1_v10': 'SELECTED independent actual source and observed heelclock/rigid3D-footroll PARTIAL PHYSICAL PASS',
        'flight2_v01': 'PRESERVED HOLD clipped top before invertible larger storage padding',
        'flight2_v02': 'PRESERVED HOLD hip/thigh missing material and old-body edge sliver',
        'flight2_v03': 'PRESERVED HOLD only old-body nearleg edge sliver',
        'flight2_v04': 'SELECTED independent actual static source PASS',
        'contact3_v01': 'PRESERVED HOLD mismatched shaft-to-shoe ankle gap',
        'contact3_v02': 'PRESERVED historical scoped RIGHT ankle PASS; later LEFT recovery gap found, not final whole-source PASS',
        'contact3_v03': 'PRESERVED exact model RIGHT-knee control and good stance; LEFT recovery ankle gap; final short-joint base',
        'load4_v01_flight5_v01': 'PRESERVED good base body/shafts/true shoes; shared LEFT recovery gap; final short-joint bases',
        'contact3_v04_load4_v02_flight5_v02': 'PRESERVED HOLD broad-surface compositor caused opacity fade and unwanted broad material; only geometry reused',
        'contact3_v05': 'PRESERVED first short source-over actual result; superseded immutable v06 exact-outside-RGBA operator',
        'load4_v03': 'PRESERVED unselected partial production output; old visible opaque pixels retained but 128 transparent-RGB outside-envelope differences failed strict provenance assertion before proof write',
        'flight5_v03': 'NOT GENERATED; prior operator stopped before this output; no fabricated file',
        'contact3_v06_load4_v04_flight5_v04': 'SELECTED independent actual static source/genuine short joint PASS; original opaque RGBA changed0, opaque alpha loss0, outside-envelope RGBA changed0',
    },
    'final_six_visible_cycle_status': 'Independent reviewer has reported visible six-source cycle including5-to0 PASS; formal immutable proof is to be frozen separately when issued.',
    'full_foot_surface_rig_status': '153dff actual-causal all-six model bound to final roster, independently being audited; declared compatible authored 3D surface/depth/thickness model, not unique hidden anatomy recovery.',
    'clock_clarification': {
        'frozen_roster_clock_is_reference': True,
        'reference_actor_speed_world': 210,
        'reference_phase_hz': 12.5,
        'actual_runtime_run_speed_world': 262.5,
        'actual_effective_phase_hz': 15.625,
        'actual_effective_phase_dt_seconds': 0.064,
        'phase_ground_travel_world_both_clocks': 16.8,
        'existing_runtime_rule': '12.5 * actual_actor_speed / 210',
        'frozen_roster_pngs_and_game_profiles_changed': False,
    },
    'native_C': 2560,
    'source_density_factor': 2.5,
    'common_unpadded_rig_root': [669, 1267.95],
    'storage_translation': {'phase0': [0, 0], 'phase1': [0, 0], 'phases2to5': [128, 128]},
    'whole_source_resized_or_perpose_C_root_fit': False,
    'historical_originals_deleted_or_overwritten': False,
    'private_previews_live_ledgers_and_binary_message_outputs_excluded': True,
    'actor_approvals_added': 0,
    'global_completed_detailed_actors_unchanged': '2/31',
    'runtime_connection_and_exact_atlas_request_gate': 'Owned by root; pending when this immutable production freeze was made.',
}
OUT.write_text(json.dumps(output, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({'freeze': record(OUT), 'files': len(records), 'bytes_before_dedup': output['total_bytes_before_sha_deduplication']}))
