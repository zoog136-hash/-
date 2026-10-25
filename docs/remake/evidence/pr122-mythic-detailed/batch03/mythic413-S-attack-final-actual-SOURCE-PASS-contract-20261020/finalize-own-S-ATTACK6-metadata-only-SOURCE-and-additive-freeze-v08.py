from pathlib import Path
import argparse
import copy
import hashlib
import json

B = Path('/workspace/scratch/mythic413-S-attack-author-20261020-v01')
D = B / 'actual-S-ATTACK6-own-native-articulated-rig-v07'
CANDIDATE = D / 'S-ATTACK6-own-actual-native-front-six-rig-and-local-cape-HOLD-contract-v07.json'
MATERIAL = B / 'actual-own-S-final-authoritative-native-material-provenance-v11/S-own-final-authoritative-native-materials-cloth703-and-original-gear-source-provenance-v11.json'
MATERIAL_PROOF = MATERIAL.parent / 'S-v11-authoritative-native-material-metadata-only-exact-part-binding-proof.json'
NUMERIC = D / 'S-ATTACK6-v07-actual36nodes-protected-body-boots-and-equipment-occlusion-proof-v02.json'
UV = B / 'S-v07-residual-LEFT-trace-original-RAW-versus-body-UV-direct-proof-v02.json'
CAPE = Path('/workspace/scratch/mythic413-W-actual-quality-independent-20261020-v01/S-shared-genuine-703-cloak-and-original-point-only-SOURCE-PASS-v01.json')
PRIOR_FREEZE = B / 'S-ATTACK-genuine703-fin-puff-skin-material-v06-v10r1-and-actual-six-v04-v07-additive-frozen-allowlist-v03.json'
OUT = D / 'S-ATTACK6-final-actual-native-SOURCE-ONE-SHOT-PASS-contract-v08.json'
PROOF = D / 'S-ATTACK6-final-v08-metadata-only-exact-six-PNG-controls-and-native-parts-repin-proof-v01.json'
FREEZE = B / 'S-ATTACK-final-actual-SOURCE-PASS-metadata-and-immutable-additive-frozen-allowlist-v04.json'

def read(p):
    return json.loads(Path(p).read_text())

def pin(p):
    p = Path(p)
    return {'path': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'bytes': p.stat().st_size}

def write_new(p, obj):
    assert not p.exists(), f'Immutable destination already exists: {p}'
    with p.open('x') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write('\n')

def verify_refs(obj, found):
    if isinstance(obj, dict):
        if isinstance(obj.get('path'), str) and isinstance(obj.get('sha256'), str):
            p = Path(obj['path'])
            if p.is_file():
                assert pin(p)['sha256'] == obj['sha256'], f'Changed input: {p}'
                found.add(str(p))
        for v in obj.values():
            verify_refs(v, found)
    elif isinstance(obj, list):
        for v in obj:
            verify_refs(v, found)

def prior_files(p, result):
    d = read(p)
    result[str(p)] = pin(p)
    for item in d['files']:
        assert pin(item['path'])['sha256'] == item['sha256'], f'Prior frozen file changed: {item["path"]}'
        result[item['path']] = item
    previous = d.get('prior_frozen_allowlist')
    if previous:
        assert pin(previous['path'])['sha256'] == previous['sha256']
        prior_files(Path(previous['path']), result)

ap = argparse.ArgumentParser()
ap.add_argument('--source-pass', required=True)
args = ap.parse_args()
receipt = Path(args.source_pass)
candidate = read(CANDIDATE)
assert pin(CANDIDATE)['sha256'] == 'f153e1410a0c35e72b98a2857d0202ade8c6a7932a5ffd95ce60a1e57bc6edb6'
assert pin(MATERIAL)['sha256'] == '9863582c181fae14328204d3e71e8fde7079867f40d82b9250e301284877eae5'
receipt_data = read(receipt)
assert 'PASS' in receipt_data.get('status', ''), 'Independent formal PASS is required'
assert pin(CANDIDATE)['sha256'] in json.dumps(receipt_data), 'PASS must bind exact original six candidate'
current_material = read(MATERIAL)
old_material = read(candidate['shared_materials']['path'])
same_keys = ['source', 'once_registration', 'C', 'bodyunit', 'common_rig_root_in_unpadded_frame', 'production_storage_translation', 'native_size', 'actual_native_controls', 'parts', 'semantic_mattes', 'fullCORE', 'complete_old_erasure_mask']
for key in same_keys:
    assert old_material[key] == current_material[key], f'Actual native material changed at {key}'
checked = set()
verify_refs(candidate, checked)
verify_refs(current_material, checked)
for p in [NUMERIC, UV, CAPE, MATERIAL_PROOF, receipt]:
    assert p.is_file()
numeric = read(NUMERIC)
assert numeric['actual_36nodes_recomposition_RGBA_difference'] == 0
assert numeric['actual_BODY_lowerbody_and_complete_boot_RGBA_changes'] == 0

final = copy.deepcopy(candidate)
final['status'] = 'ACTUAL_NATIVE_SIX_SOURCE_AND_ONE_SHOT_PASS_GAME_CONNECTION_PENDING'
final['prior_actual_candidate_exact_same_six_artwork'] = pin(CANDIDATE)
final['historical_renderer_material_contract'] = candidate['shared_materials']
final['shared_materials'] = pin(MATERIAL)
final['metadata_only_native_material_equivalence'] = pin(MATERIAL_PROOF)
final['independent_final_SOURCE_and_one_shot_PASS'] = pin(receipt)
final['independent_bounded_native_cape_SOURCE_PASS'] = pin(CAPE)
final['exact_current36nodes_BODY_boots_and_foreground_proof'] = pin(NUMERIC)
final['preserved_original_skin_mark_direct_RAW_UV_proof'] = pin(UV)
final['local_cape_status'] = 'SOURCE_PASS_GENUINE5165_PLUS_AUTHORIZED703_AND_ORIGINAL387_CLOAK_POINT'
final['final_png_artwork_or_node_affines_C_root_unit_storage_changes'] = 0
final['actor_game_approvals_added'] = 0
for frame in final['frames']:
    frame['SOURCE_status'] = 'ACTUAL_NATIVE_SOURCE_AND_ONE_SHOT_PASS_GAME_CONNECTION_PENDING'
write_new(OUT, final)
unchanged_frame_keys = ['path', 'sha256', 'native_size', 'physical_C', 'bodyunit', 'common_rig_root_in_unpadded_frame', 'storage_translation', 'actual_rig_nodes_unpadded_native', 'actual_composition_nodes', 'RIGHT_exact_foregrip_affine_grip_target', 'RIGHT_rigid_staff_matrix']
for old, new in zip(candidate['frames'], final['frames']):
    assert all(old[k] == new[k] for k in unchanged_frame_keys)
    assert pin(new['path'])['sha256'] == new['sha256']
write_new(PROOF, {
    'schema': 'PR122-S-final-SOURCE-metadata-only-exact-artwork-and-native-material-repin-v1',
    'prior_actual_six': pin(CANDIDATE), 'final_contract': pin(OUT),
    'prior_native_material': candidate['shared_materials'], 'authoritative_native_material': pin(MATERIAL),
    'actual_native_keys_verified_exact': same_keys, 'six_artwork_and_pose_controls_verified_exact': unchanged_frame_keys,
    'actual_input_references_SHA_verified': len(checked), 'six_png_pixel_file_changes': 0,
    'native_parts_CORE_mattes_controls_changes': 0, 'C_root_unit_storage_fit_or_resampling': False,
    'original_skin_mark_preserved': True, 'SOURCE_PASS': pin(receipt), 'current_numeric36': pin(NUMERIC),
    'game_actor_approvals_added': 0, 'author_actual_image_bytes': 6017817, 'new_image_service_view_returns': 0,
})

old_files = {}
prior_files(PRIOR_FREEZE, old_files)
new_files = {}
for p in B.rglob('*'):
    if not p.is_file() or str(p) in old_files or p == FREEZE:
        continue
    if '__pycache__' in p.parts or p.name.startswith('private-') or 'preview' in p.name.lower() or 'ledger' in p.name.lower():
        continue
    if p.suffix.lower() not in {'.json', '.py', '.log', '.png', '.npz', '.txt'}:
        continue
    if p.name == 'S-final-SOURCE-metadata-and-freeze-v08.log':
        continue
    new_files[str(p)] = pin(p)
for p in [receipt, CAPE]:
    if str(p) not in old_files:
        new_files[str(p)] = pin(p)
write_new(FREEZE, {
    'schema': 'PR122-immutable-additive-real-production-v1',
    'prior_frozen_allowlist': pin(PRIOR_FREEZE), 'prior_files_verified_unchanged': len(old_files),
    'files': [new_files[k] for k in sorted(new_files)], 'file_count': len(new_files),
    'total_bytes': sum(v['bytes'] for v in new_files.values()),
    'files_over10MiB': [v for v in new_files.values() if v['bytes'] > 10 * 1024**2],
    'current_actual6_contract': pin(OUT), 'final_SOURCE_PASS': pin(receipt),
    'authoritative_native_material': pin(MATERIAL),
    'status': 'FINAL_ACTUAL_SIX_SOURCE_AND_ONE_SHOT_PASS_GAME_CONNECTION_PENDING',
    'original_source_or_C_root_unit_game_changed': False,
    'actual_author_image_cumulative_bytes': 6017817, 'new_image_service_view_returns_by_author': 0,
    'actor_game_approvals_added': 0,
})
print(json.dumps({'final': pin(OUT), 'metadata_equivalence_proof': pin(PROOF), 'freeze': pin(FREEZE),
                  'file_count': len(new_files), 'total_bytes': sum(v['bytes'] for v in new_files.values()),
                  'over10MiB_count': sum(v['bytes'] > 10 * 1024**2 for v in new_files.values()),
                  'actual_PNG_changes': 0, 'actual_author_image_bytes': 6017817}, ensure_ascii=False))
