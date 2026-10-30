from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent
ORIGINAL = Path('/workspace/scratch/girtas-NE-run-RIGHT-landing3-key-v01/girtas-NE-run-RIGHT-landing3-key-v01.png')
SERVICE = OUT / 'generated-lowerbody-contact3-original-service.png'
MASK = OUT / 'semantic-complete-lowerbody-edit-mask-v04.png'
CANDIDATE = OUT / 'girtas-NE-run-contact3-lowerbody-bounded-v04.png'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

assert sha(ORIGINAL) == '513b5c852b9a907e58e9a12f99df5e8c7856b719f39f3a721a9cd9fed2f7292a'
assert sha(SERVICE) == 'ce8b26e7440b41b293d1f2b8e92c78c72c6233bf117c11db931f192b3237a8fc'
assert sha(MASK) == 'fc3c51ac70bfdde5ea88335b0316427335bc99d7dd49caad38c66298f0e32ac5'
assert not CANDIDATE.exists(), 'Never overwrite a prior candidate'
original = Image.open(ORIGINAL).convert('RGBA')
service = Image.open(SERVICE).convert('RGBA')
mask_image = Image.open(MASK).convert('L')
assert original.size == service.size == mask_image.size == (1254, 1254)
assert set(np.unique(np.asarray(mask_image))).issubset({0, 255})
candidate = Image.composite(service, original, mask_image)
candidate.save(CANDIDATE)
a, b, g = [np.asarray(v) for v in (original, candidate, service)]
m = np.asarray(mask_image) > 0
diff = np.any(a != b, axis=2)
assert int((diff & ~m).sum()) == 0
assert np.array_equal(a[:586], b[:586]), 'Rigid upperbody/cuirass/arms must stay exact'
assert np.array_equal(a[730:1080, 250:620], b[730:1080, 250:620]), 'Far LEFT recovering leg must stay exact'
# Separate semantic protected arm/hand/weapon corridor. Its left boundary runs
# through the transparent gap, never through the new near RIGHT leg or tasset.
weapon_left_xy = [(586,820),(600,850),(620,865),(640,885),(650,891),
    (660,898),(670,925),(680,933),(690,936),(700,940),(710,947),
    (720,956),(740,982),(760,998),(780,1002),(800,1005),(820,1012),
    (840,1025),(860,1046),(880,1084),(900,1113),(905,1118),
    (920,1124),(940,1128),(960,1133),(980,1142),(1000,1156),
    (1040,1190),(1100,1254)]
weapon = np.zeros(m.shape, dtype=bool)
for y in range(586, 1101):
    x = int(np.ceil(np.interp(y, [p[0] for p in weapon_left_xy], [p[1] for p in weapon_left_xy])))
    weapon[y, x:] = True
assert int((diff & weapon).sum()) == 0, 'Protected arm/hand/weapon RGBA corridor must stay exact'
assert not np.any(b[1040:1160, 880:1090, 3] > 16), 'No old lower boot remnants'
ys, xs = np.where(diff)
clip_roi = np.zeros(m.shape, dtype=bool)
clip_roi[680:780, 850:1005] = True
# Ignore the separately immutable weapon; all genuinely new opaque upperthigh
# silhouette in the area identified by independent QC must now be selected.
new_upperthigh = clip_roi & (g[:,:,3] > 100) & (a[:,:,3] <= 16) & ~weapon
remaining_new_upperthigh_cut = int((new_upperthigh & ~m).sum())
assert remaining_new_upperthigh_cut == 0, 'Complete the new upperthigh silhouette'
proof = {
    'status': 'EXACT_RGBA_SCOPE_PASS_INDEPENDENT_SOURCE_AND_RUNTIME_PENDING',
    'original_path': str(ORIGINAL), 'original_sha256': sha(ORIGINAL),
    'generated_service_path': str(SERVICE), 'generated_service_sha256': sha(SERVICE),
    'candidate_path': str(CANDIDATE), 'candidate_sha256': sha(CANDIDATE),
    'mask_path': str(MASK), 'mask_sha256': sha(MASK),
    'source_canvas_pixels': [1254,1254], 'fixed_runtime_C': 1776,
    'generation_count': 1, 'changed_pixels': int(diff.sum()),
    'changed_bbox_inclusive': [int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())],
    'outside_mask_changed_pixels': int((diff & ~m).sum()),
    'outside_mask_RGBA_byteidentical': True,
    'entire_upperbody_before_row586_RGBA_byteidentical': True,
    'protected_arm_hand_weapon_corridor_changed_pixels': int((diff & weapon).sum()),
    'protected_arm_hand_weapon_corridor_pixels': int(weapon.sum()),
    'protected_corridor_left_yx': weapon_left_xy,
    'farLEFT_recovery_ROI_RGBA_byteidentical': True,
    'farLEFT_recovery_ROI_xyxy': [250,730,620,1080],
    'independent_QC_upperthigh_original_cut_ROI_xyxy': [850,680,1005,780],
    'new_opaque_upperthigh_pixels_selected': int(new_upperthigh.sum()),
    'remaining_new_opaque_upperthigh_cut_pixels': remaining_new_upperthigh_cut,
    'vacated_old_nearRIGHT_boot_ROI_xyxy': [880,1040,1090,1160],
    'vacated_old_nearRIGHT_boot_pixels_above16': 0,
    'earlier_v01_and_v03_HOLD_candidates_preserved': True,
    'claim_limit': 'Scope proof only. Source anatomy, projected sole/root, physical six-phase transitions, actual game binding and actor approval require independent checks.'
}
proof_path = OUT / 'outside-semantic-ROI-exact-RGBA-proof-v04.json'
assert not proof_path.exists()
proof_path.write_text(json.dumps(proof, indent=2) + '\n')
print(json.dumps({'candidate_path':str(CANDIDATE),'candidate_sha256':sha(CANDIDATE),
                  'scope_proof_path':str(proof_path),'scope_proof_sha256':sha(proof_path),
                  'outside_RGBA_changes':0,'remaining_upperthigh_cut':remaining_new_upperthigh_cut}))
