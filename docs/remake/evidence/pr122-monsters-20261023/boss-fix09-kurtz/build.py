#!/usr/bin/env python3
"""Select reviewed new Kurtz source views; quarantine known bad old clips.

No pixels are synthesized, mirrored, retouched or discarded. Source approval
here is limited to static first-pass identity/camera/hand review, never final QA.
"""
import hashlib
import json
import sys
from copy import deepcopy
from pathlib import Path

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[4]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import frames_bytes

OLD = BASE.parent / 'boss-fix04-kurtz'
OUT = ROOT / 'assets/actors/eight_direction/monster_boss_repair/kurtz/r003'
OLD_CANDIDATE_SHA = 'cfa1b7f5137a0474fd2533261f5062c9b4bce02d86894cba1ff6a99bee952f5e'
OLD_MANIFEST_SHA = 'b9afb98477841218279a93b94147d3b4758be33ecec4e0a69dff8939b12b0fa3'
EXCLUDE = {
    'run_3': 'Independent source review finds sword in anatomical LEFT hand; camera/hand not corrected by metadata.',
    'run_4': 'Baked source W camera flips toward E in phases3-5.',
    'run_5': 'Baked source NW camera flips toward opposite view in phases3-5.',
    'idle_4': 'Source camera is E rather than requested W.',
    'idle_5': 'Source camera is NE rather than requested NW.',
    'hit_4': 'Source camera is E rather than requested W.',
    'hit_5': 'Source camera is NE rather than requested NW.',
    'attack_2': 'S overhead sword-hand identity is inconsistent and target contact extends laterally; requires new source.'
}


def rel(p):
    return p.relative_to(ROOT).as_posix()


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def validate_prior():
    manifest = OLD / 'file-manifest.json'
    assert core.sha(manifest) == OLD_MANIFEST_SHA
    records = json.loads(manifest.read_text())['files']
    for item in records:
        p = ROOT / item['path']
        assert p.is_file() and p.stat().st_size == item['bytes'] and core.sha(p) == item['sha256'], str(p)
    candidate = OLD / 'r002/candidate.json'
    assert core.sha(candidate) == OLD_CANDIDATE_SHA
    return json.loads(candidate.read_text())['actors']['monster:커츠'], len(records)


def build():
    old, preserved_count = validate_prior()
    excluded = [dict(animation=t['animation'], direction=t['direction'], role=t['role'],
                     source=t['source'], source_sha256=t['source_sha256'], reason=EXCLUDE[t['animation']])
                for t in old['tracks'] if t['animation'] in EXCLUDE]
    assert len(excluded) == 8
    tracks = [deepcopy(t) for t in old['tracks'] if t['animation'] not in EXCLUDE]
    assert len(tracks) == 11 and sum(len(t['geometry']['frames']) for t in tracks) == 46
    reviews = json.loads((BASE / 'source-review.json').read_text())['sources']
    records = []
    for review in reviews:
        source = BASE / 'raw' / (review['name'] + '.png')
        record = dict(name=review['name'], source=rel(source), source_sha256=core.sha(source),
                      bytes=source.stat().st_size, requested_direction=review['requested_direction'],
                      selected_direction=review['selected_direction'], selected=review['select'])
        # Perform every geometric guard even for preserved, rejected generations.
        checked_direction = review['selected_direction'] or review['requested_direction']
        initial = core.analyze(source, 4, [0, 1], directions_axis='phase_grid2',
                               canvas_size=2048, directions=[checked_direction])
        core.require_complete_pose_regions(source, initial)
        record['strict_source_geometry'] = 'PASS_FOUR_COMPLETE_DISTINCT_RGBA_POSES'
        if not review['select']:
            record.update(status='HOLD_NOT_SELECTED', reason=review['observation'], geometry=initial)
            records.append(record)
            continue
        assert review['identity'].startswith('PASS_') and review['direction'].startswith('PASS_')
        assert review['sword_hand'].startswith('PASS_')
        measured = [sole - apex for apex, sole in review['standing_head_to_boot_landmarks']]
        standing_height = sum(measured) / len(measured)
        canvas = max(64, round(standing_height * 256 / 96 / 8) * 8)
        geometry = core.analyze(source, 4, [0, 1], directions_axis='phase_grid2',
                                canvas_size=canvas, source_anchors=review['source_anchors'],
                                directions=[review['selected_direction']])
        core.require_complete_pose_regions(source, geometry)
        geometry.update(reference_body_height=96, standing_head_to_boot_source_height=standing_height,
                        standing_head_to_boot_landmarks=review['standing_head_to_boot_landmarks'],
                        canvas_basis='One source-specific virtual canvas, body-height normalized without changing source RGBA',
                        ground_anchor_basis=review['ground_anchor_basis'], physical_ground_contact_approved=False)
        OUT.mkdir(parents=True, exist_ok=True)
        texture = OUT / source.name
        texture.write_bytes(source.read_bytes())
        assert core.sha(texture) == record['source_sha256']
        direction = review['selected_direction']
        for role, phases in [('idle', [0, 1]), ('hit', [2, 3])]:
            g = deepcopy(geometry)
            g['frames'] = [f for f in g['frames'] if f['row'] in phases]
            assert len(g['frames']) == 2
            tracks.append(dict(direction=direction, role=role, animation=f'{role}_{core.DIRECTIONS.index(direction)}',
                               source=rel(source), source_sha256=record['source_sha256'], texture=rel(texture), geometry=g,
                               source_review=rel(BASE / 'source-review.json'), production_connected=False))
        record.update(status='SELECTED_STATIC_FIRST_PASS_ONLY', geometry=geometry, texture=rel(texture))
        records.append(record)
    assert len(tracks) == 17 and sum(len(t['geometry']['frames']) for t in tracks) == 58
    assert len({t['animation'] for t in tracks}) == len(tracks)
    assert not ({t['animation'] for t in tracks} & EXCLUDE.keys())
    frames = OUT / 'SpriteFrames.tres'
    frames.write_bytes(frames_bytes(tracks))
    profile = OUT / 'NativeMotionProfile.tres'
    profile.write_text((ROOT / old['native_profile'].removeprefix('res://')).read_text().replace(old['frames'], 'res://' + rel(frames)))
    required = {(role, d) for role in ['idle', 'run', 'attack', 'hit'] for d in core.DIRECTIONS} | {('death', 'S')}
    available = {(t['role'], t['direction']) for t in tracks}
    actor = deepcopy(old)
    actor.update(schema='pr122-boss-kurtz-repair-candidate-v2', frames='res://' + rel(frames), frames_sha256=core.sha(frames),
                 native_profile='res://' + rel(profile), native_profile_sha256=core.sha(profile), tracks=tracks,
                 native_track_count=len(tracks), native_pose_count=58, new_source_poses=12,
                 new_source_track_count=6, prior_revision_source_poses_reused=46, prior_revision_tracks_reused=11,
                 excluded_prior_tracks=excluded, missing_required_tracks=sorted(f'{r}_{core.DIRECTIONS.index(d)}' for r, d in required-available),
                 production_connected=False, detailed_completed=False, new_approvals=0, prior_approval_and_assets_changed=False,
                 quality_review='HOLD: 17 native clips / 58 source poses only. Known bad W/NW cameras, SW RUN left sword hand and S attack hand/contact are excluded. New E/SE/S IDLE/HIT improve identity/camera/hand in static source review; 16 required slots, timed support/contact and full mythic QA remain incomplete.')
    actor['prior_quality_findings_preserved'] = actor.pop('quality_findings')
    actor['quality_findings'] = [
        dict(criterion='new_E_SE_S_idle_hit', result='IMPROVED_STATIC_SOURCE_ONLY', observation='Six new two-pose clips preserve unique spiked heavy armor, horned closed helm, greatsword in anatomical right hand and dark-scarlet cape. A failed pure-E request is explicitly selected as actual SE; a second source genuinely corrects pure E.'),
        dict(criterion='known_wrong_sources', result='QUARANTINED_NOT_SELECTED', observation='Eight prior bad clips are absent from this staging library; old files and approval records remain unchanged. No camera flip, sword hand reassignment or proxy role fills a missing track.'),
        dict(criterion='SW_new_source', result='HOLD_NOT_SELECTED', observation='The fourth generation produced S-to-SE instead of SW. Complete source and exact request preserved, zero frames selected.'),
        dict(criterion='world_scale_and_ground', result='FIRST_PASS_METADATA_ONLY', observation='New sources use manually reviewed neutral helmet-apex/armored-sole heights with one 96px reference body height and inherited 112/96 world scale. Manual sole anchors have estimated eight-source-pixel uncertainty. RGBA is byte-identical and no masks/resampling hide bounds. Physical support and runtime visual scale need final QA.'),
        dict(criterion='inherited_RUN_and_SW_attack', result='HOLD_FINAL_MOTION_CONTACT', observation='Remaining five RUN views, rear IDLE/HIT and SW attack retain their original source pixels. Independent SW attack review establishes continuous right-hand grip only. Gait cadence, N/NE cape-obscured support, target contact and release timing remain unsigned.'),
        dict(criterion='required_coverage', result='HOLD_MISSING_16', observation='Missing RUN SW/W/NW; IDLE/HIT SW/W/NW; ATTACK E/SE/S/W/NW/N/NE. No full eight-direction or completed-boss claim.')
    ]
    assert len(actor['missing_required_tracks']) == 16
    dump(BASE / 'candidate.json', dict(schema='pr122-boss-repair-staging-v1', batch=rel(BASE), new_approvals=0,
         default_catalog_switches=0, actors={'monster:커츠':actor}))
    dump(BASE / 'source-checks.json', dict(schema='pr122-kurtz-r003-source-checks-v1', prior_frozen_files_verified=preserved_count,
         prior_manifest_sha256=OLD_MANIFEST_SHA, prior_candidate_sha256=OLD_CANDIDATE_SHA,
         new_imagegen_calls=4, selected_source_PNGs=3, held_source_PNGs=1, sources=records, excluded_prior_tracks=excluded))
    # Recheck frozen inputs after all output is produced.
    validate_prior()
    print(json.dumps(dict(clips=17, poses=58, new_clips=6, new_poses=12, reused_clips=11,reused_poses=46,
                          excluded_prior_clips=8, missing=actor['missing_required_tracks']),ensure_ascii=False))


if __name__ == '__main__':
    build()
