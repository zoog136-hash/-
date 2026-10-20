from pathlib import Path
from PIL import Image
import numpy as np, json, hashlib

D = Path(__file__).parent
V3 = D / 'actual-NE-HIT6-own-native-articulated-v03'
V4 = D / 'actual-NE-HIT6-own-native-settled-guard-v04'
CP3 = V3 / 'NE-HIT6-actual-own-native-brace-spine-head-guard-source-contract-v03.json'
CP4 = V4 / 'NE-HIT-phase5-actual-regained-guard-settle-variant-v04.json'

def rec(p):
    p = Path(p); b = p.read_bytes()
    return dict(path=str(p), sha256=hashlib.sha256(b).hexdigest(), bytes=len(b))

j = json.loads(CP3.read_text()); p5 = json.loads(CP4.read_text())['frames'][0]
assert p5['phase'] == 5 and p5['original_complete_two_legs_shoes_RGBA_changes'] == 0
assert p5['original_full_RIGHT_staff_grip_fixed_region_RGBA_changes'] == 0
assert p5['C'] == 2432 and p5['common_rig_root_unpadded'] == j['common_rig_root_unpadded']
old0 = j['frames'][0]; old5 = j['frames'][5]
assert old0['source']['sha256'] == old5['source']['sha256']
def diff(a, b):
    ar = np.asarray(Image.open(a).convert('RGBA')); br = np.asarray(Image.open(b).convert('RGBA'))
    d = np.any(ar != br, axis=2); y,x = np.where(d)
    return dict(changed_RGBA_pixels=int(d.sum()), bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)])

body0 = Path(old0['source']['path']).parent / 'actual-head-thorax-clothing-node-native-v01.png'
body5 = Path(p5['source']['path']).parent / 'actual-head-thorax-clothing-node-native-v01.png'
armname = 'LEFT-actual-complete-curved-cuff-white-sleeve-bracer-hand-guard-actual-posed-material.png'
proof = dict(schema='NE_HIT_GENUINE_SETTLED_GUARD_INDEPENDENT_NODE_CHANGE_PROOF_V04', prior_duplicate_guard_sources=[old0['source'],old5['source']], new_phase5=p5['source'], actual_forearm_guard_controls_before=old0['LEFT_actual_guard_knots_unpadded'], actual_forearm_guard_controls_after=p5['LEFT_actual_guard_knots_unpadded'], independent_native_node_changes=dict(body_head_thorax_clothing=diff(body0,body5), actual_LEFT_complete_guard_forearm=diff(Path(old0['source']['path']).parent/armname,Path(p5['source']['path']).parent/armname), final_composite=diff(old0['source']['path'],p5['source']['path'])), actual_own_material_response=dict(head_upper_thorax_before=old0['head_upper_thorax_recoil'],head_upper_thorax_after=p5['head_upper_thorax_recoil'],cranial_degrees_before=old0['cranial_rotation_degrees'],cranial_degrees_after=p5['cranial_rotation_degrees'],cloth_before=old0['native_clothing_lag'],cloth_after=p5['native_clothing_lag'],ribbon_before=old0['native_ribbon_lag'],ribbon_after=p5['native_ribbon_lag']), complete_boots_legs_and_full_RIGHT_staff_RGBA_mismatch=0, C_root_foot_fitting=False, actor_approvals_added=0, scope='Actual independently articulated arm/head/torso and cloth response, not metadata-only change or whole-frame jitter; actual source/cycle quality gate remains independent.')
pp = V4 / 'NE-HIT-phase5-genuine-settle-actual-independent-node-change-proof-v04.json'
with pp.open('x') as f: f.write(json.dumps(proof,indent=2)+'\n')
j['schema'] = 'MYTHIC413_NE_HIT_EXACT_FINAL_SIX_DISTINCT_ACTUAL_SOURCE_ROSTER_V04'
j['status'] = 'SIX_DISTINCT_ACTUAL_NATIVE_POSES_SOURCE_CYCLE_FINAL_SETTLE_QC_PENDING'
j['frames'][5] = p5
for f in j['frames']:
    assert rec(f['source']['path']) == f['source']
assert len({f['source']['sha256'] for f in j['frames']}) == 6
j['prior_immutable_source_contract'] = rec(CP3)
j['genuine_phase5_variant_contract'] = rec(CP4)
j['genuine_phase5_actual_node_change_proof'] = rec(pp)
j['historical_v03_hold'] = 'Phase0 and5 were identical recovered guard; parent genuine-six packer correctly held. Original v03 files retained. Final phase5 now has genuine own forearm re-alignment, head/thorax settling and independent cloth/ribbon residual response.'
j['six_distinct_authored_source_SHA256'] = True
j['original_phase0_through4_changed'] = False
j['actor_approvals_added'] = 0
out = V4 / 'NE-HIT6-exact-final-source-roster-v04.json'
with out.open('x') as f: f.write(json.dumps(j,indent=2)+'\n')
print(json.dumps(dict(final_roster=rec(out), distinct_sources=6, actual_node_proof=rec(pp), changed_nodes=proof['independent_native_node_changes']),separators=(',',':')))
