#!/usr/bin/env python3
"""Pin actual source-plane observations, failed trials and immutable repair artifacts."""
from pathlib import Path
import hashlib
import json
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import preserve, json_bytes

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/boss-fix02-zombie-lord')
BASE = ROOT / BATCH
KEY = 'monster:죽음의 좀비 로드'


def pin(path):
    p = ROOT / path
    return {'path': str(path), 'bytes': p.stat().st_size, 'sha256': core.sha(p)}


def finish():
    first = json.loads((BASE / 'candidate.json').read_text())['actors'][KEY]
    second = json.loads((BASE / 'candidate-r002.json').read_text())['actors'][KEY]
    # New revisions cannot alter their old reference, r001 source planes or resources.
    for a in (first, second):
        for key, digest in [('frames', 'frames_sha256'), ('native_profile', 'native_profile_sha256')]:
            assert core.sha(ROOT / a[key].removeprefix('res://')) == a[digest]
        for t in a['tracks']:
            assert core.sha(ROOT / t['source']) == t['source_sha256'] == core.sha(ROOT / t['texture'])
    reference = json.loads((BASE / 'reference-pin.json').read_text())
    assert core.sha(ROOT / reference['path']) == reference['sha256']
    support_trials = []
    for p in sorted((BASE / 'requests').glob('*support-columns*.json')):
        q = json.loads(p.read_text()); raw = BATCH / 'raw' / (q['name'] + '.png')
        rec = {'request': pin(p.relative_to(ROOT)), 'source': pin(raw), 'direction': q['direction'],
               'playback_source_rows': q['playback_source_rows'], 'new_approval': False}
        try:
            g = core.analyze(ROOT / raw, 6, [0, 1], directions_axis='phase_grid2', canvas_size=2048, directions=[q['direction']])
            core.require_complete_pose_regions(ROOT / raw, g)
            rec['strict_geometry'] = 'PASS'
        except ValueError as error:
            rec.update(strict_geometry='SOURCE_HOLD', geometry_reason=str(error))
        if q['direction'] == 'E':
            rec.update(status='HOLD', actual_visual_finding='Both top cells still read as near/right-leg plant. Large belly/skirt occlude ownership; opposite support cannot be asserted. No frame selected for r002.')
        elif q['name'].endswith('v01'):
            rec.update(status='SOURCE_HOLD', actual_visual_finding='Opposite screen-side support visible, but strict foreign-component/bbox ownership guard failed. Keep all source pixels; no import and no noise cleanup.')
        else:
            rec.update(status='SELECTED_SOURCE_PLANE_CANDIDATE_MAIN_HOLD', actual_visual_finding='Left column screenLEFT/anatomicalRIGHT sole grounded; right column screenRIGHT/anatomicalLEFT sole grounded. Opposite foot clearly airborne. Selected as r002 S RUN with order [0,2,4,1,3,5].')
        support_trials.append(rec)
    preserve(BASE / 'support-trials.json', json_bytes(support_trials))
    common = {
        'actor': KEY, 'kind': 'boss', 'quality_tier': 'mythic_transform', 'status': 'HOLD',
        'approval_preserved': True, 'new_approval': False, 'approval_mutated': False,
        'reference_pin': reference, 'reference_scope': 'Exact existing-project atlas crop; external original-game authenticity not established',
        'actual_examined_views': core.DIRECTIONS, 'actual_examined_roles': ['idle', 'run', 'attack', 'hit', 'death_S'],
        'identity_observations': ['Great exposed distended belly and broad torso/oversized bare feet restored versus thin legacy proxy.',
            'Heavy attached chains, rusted shoulder/back spikes, ragged skirt and gold waist plate persist across the viewed poses.',
            'Exact project reference has empty fists; DB fallback weapon=axe is not visibly supported, so no axe was invented.'],
        'role_observations': ['Idle breathing/shoulder settle differs from run.',
            'Four attack keyframes show windup, extended-fist candidate contact, lowered follow-through and elbow recovery.',
            'Hit torso/head/belly recoil differs from idle and recovers over a second source frame.',
            'S death progresses buckle/drop/side-fall to an inert horizontal corpse, retaining attached complete limbs/chains.'],
        'strict_source_geometry': 'PASS for selected 116 poses: true RGBA, nonempty, complete connected-body ownership, bounding regions, no clipped image boundary, no repeated visible pose hashes.',
        'math_anchor_vs_actual_support': 'Godot virtual bottom-anchor/region invariants passed. Those invariants do not prove anatomical support, source-plane stability, real weight or target contact.',
        'unseen_not_reviewed': ['Actual default Main scene and gameplay target/ground contact.',
            'Frame-interpolated belly/chain dynamics and authored impact weight in game.',
            'External original-game design authenticity and human mythic-tier approval.'],
        'source_pixel_edits': 0, 'horizontal_mirror_operations': 0, 'duplicated_source_poses': 0,
        'new_walk_sources': 0, 'existing_multidirection_death_and_walk_preserved': True,
    }
    r001 = dict(common, revision='r001', candidate=pin(BATCH/'candidate.json'),
        actual_examined_pose_count=116, actual_examined_frame_indices='All source poses: idle2/run6/attack4/hit2 each of 8 headings; S death4.',
        source_plane_evidence=[pin(BATCH/('qa-final-'+x+'-private.png')) for x in ['run-0','run-1','core-0','core-1','death-0']],
        camera_before_after=['E RUN v01 front-quarter pull improved in v02 to stronger side-facing nose/belly contour; old v01 preserved.',
            'SW RUN/core v01 frontal pull improved in v02 to leftward nose/feet and leftward punch.',
            'N RUN v01 strict bbox failure resolved by new spaced 3x2 v02 art; failed original untouched.'],
        major_holds=['RUN E0/E3 still show the near foot forward/planted; source sequence resembles two shorter same-leg cycles.',
            'RUN S0/S3 retain the same screenLEFT stance; other visible phases do not establish the required consistent six-phase right/left halves.',
            'SE/SW/W front/side sequences show similarly repeated dominant stance at nominal half-cycle boundaries.',
            'NW/NE lower-leg ownership is partly obscured by skirt/belly/angle; full anatomical support trace cannot be certified from current source.',
            'No final target contact or default Main mythic approval.'],
        runtime_switch_recommendation='HOLD: preserve approved runtime; do not replace it based only on geometry/playback.',
        godot_playback=pin(BATCH/'godot-playback.json'))
    preserve(BASE / 'visual-review-r001.json', json_bytes(r001))
    r002 = dict(common, revision='r002', candidate=pin(BATCH/'candidate-r002.json'),
        actual_examined_pose_count=116, new_examined_source_poses=6, reused_previously_examined_source_poses=110,
        source_plane_evidence=[pin(BATCH/'qa-r002-S-run6-private.png')],
        observed_S_support_sequence=['RIGHT','RIGHT','RIGHT','LEFT','LEFT','LEFT'],
        source_phase_order=[0,2,4,1,3,5],
        S_support_before_after='r001 phases0/3 same screenLEFT plant -> r002 phases0/3 opposite screenLEFT/RIGHT full-sole plant, with opposite bare foot visibly airborne.',
        major_holds=['Only S RUN support exchange is corrected in source plane; E support-column trials remain semantically invalid.',
            'Other r001 RUN stance repetition/occluded anatomical ownership remains unresolved.',
            'Full in-game weight, source-plane pivot stability and target contact remain unreviewed.'],
        runtime_switch_recommendation='HOLD: dedicated comparison candidate; root review required for any runtime change, no new approval.',
        godot_playback=pin(BATCH/'godot-playback-r002.json'))
    preserve(BASE / 'visual-review-r002.json', json_bytes(r002))
    names = {
      'E-run6-v01':'7754bdd4-d19a-42a1-b858-215803b2b549','SE-run6-v01':'4c5d7cbd-cd94-442a-bc07-bb568cef6192',
      'S-run6-v01':'1b2f8812-1269-4a6f-88df-dc70d3462bf8','SW-run6-v01':'b1a9326a-202d-4c4e-8cbc-490adcf2d18c',
      'W-run6-v01':'cdd353be-ed2c-4196-a582-c839ecf2733c','NW-run6-v01':'ad3239ea-9611-43de-b5c9-0c5280f6247a',
      'N-run6-v01':'4032d6f6-074f-4e13-bcdb-ef9808a05869','NE-run6-v01':'4e1efdab-8f7b-44c7-87b0-7add3c33e927',
      'E-core8-v01':'48524dbc-d4a7-42a5-af30-243497d99bc2','SE-core8-v01':'dda1c3e8-f9c2-46d5-b8a3-a253fbae3855',
      'S-core8-v01':'6cc689fa-cb86-4da4-9bce-278acf2ee4f1','SW-core8-v01':'cc6b1abf-f511-4780-b4ff-9e977f63f721',
      'W-core8-v01':'63728107-2e86-4eb2-b2bf-33012547648e','NW-core8-v01':'8414e5b1-ff30-457e-969f-9c13bdaedf84',
      'N-core8-v01':'323ca927-eef2-4c90-9526-d4d0f26db41e','NE-core8-v01':'6876c6bb-68ba-43b5-8fbc-008ab190724c',
      'E-run6-v02':'cee25f97-f2bd-4dc7-97df-b73a453115d2','SW-run6-v02':'893a629f-b110-4f99-a8a0-172cb5f29e75',
      'N-run6-v02':'cb414a6a-086e-4aa8-a7fc-9f7ba77c0324','SW-core8-v02':'ce2132db-8e9e-447d-bd0d-3d7b3a32fe0b',
      'S-death4-v01':'65f0d32e-20d1-40dd-b97f-247e564d4fd3',
      'E-run6-support-columns-v01':'2fbae6b2-36ec-4127-a4cd-6e66b3a98821','S-run6-support-columns-v01':'1e18b8c5-fbfe-4f78-9e19-7da563d360b9',
      'E-run6-support-columns-v02':'8c9980bb-6e73-4938-a25f-dbfa87ee0d38','S-run6-support-columns-v02':'72fe6501-d019-40f7-adec-43a95b31e1e4'}
    provenance = []
    for suffix, uuid in names.items():
        raw = BATCH/'raw'/('zombie-lord-'+suffix+'.png')
        original = Path('/workspace/generated_images')/('exec-'+uuid+'.png')
        assert original.read_bytes() == (ROOT/raw).read_bytes()
        provenance.append({'preserved_source': pin(raw), 'original_generated_path': str(original),
            'original_output_mtime_utc': datetime.fromtimestamp(original.stat().st_mtime, timezone.utc).isoformat(),
            'exact_request': pin(BATCH/'requests'/('zombie-lord-'+suffix+'.json'))})
    preserve(BASE / 'generation-provenance.json', json_bytes(provenance))
    files = sorted({p for p in BASE.rglob('*') if p.is_file() and p.name!='file-manifest.json'} |
        {p for p in (ROOT/'assets/actors/eight_direction/monster_boss_repair/zombie_lord').rglob('*') if p.is_file()})
    manifest = {'schema':'pr122-zombie-lord-repair-artifacts-v1','actor':KEY,'new_raw_PNGs':len(provenance),
        'raw_pose_slots_including_failed_trials':166,'r001_clips':33,'r001_unique_poses':116,
        'r002_clips':33,'r002_unique_poses':116,'r002_new_source_poses':6,'r002_reused_r001_poses':110,
        'new_approvals':0,'default_runtime_switches':0,'git_mutations_by_this_agent':0,
        'quality_status':'HOLD: RUN support defects remain; S-only support repair is a source-plane improvement.',
        'files':[pin(p.relative_to(ROOT)) for p in files]}
    preserve(BASE / 'file-manifest.json', json_bytes(manifest))
    print(json.dumps({k:v for k,v in manifest.items() if k!='files'}))


if __name__ == '__main__':
    finish()
