#!/usr/bin/env python3
"""Prepare per-ID native-motion reuse for an identical pinned project image.

This preserves the existing 8-view articulated motion; it does not author or
count new poses. Width/height/color are explicit presentation adapters, not
permissions to substitute a different body, weapon or attack contract. Final
per-ID Main/visual approval is intentionally outside this tool.
"""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import subprocess


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()


def register_profiles(original, catalog, keys):
    """Change only target rows in the repository's one-profile-per-line file."""
    lines = original.splitlines(keepends=True)
    previous_profiles = json.loads(original)['profiles']
    for key in keys:
        prefix = json.dumps(key,ensure_ascii=False)+':'
        matches = [i for i,line in enumerate(lines) if line.startswith(prefix)]
        if not matches and key not in previous_profiles:
            required(lines[-1].strip()=='}}', 'Preserve unfamiliar profile closing format')
            lines[-2] = lines[-2].rstrip()+',\n'
            lines.insert(len(lines)-1,prefix+canonical(catalog['profiles'][key]).decode()+'\n')
            continue
        required(len(matches)==1, 'Expected one existing target profile row; preserve unfamiliar formatting')
        index = matches[0]
        comma = ',' if lines[index].rstrip().endswith(',') else ''
        lines[index] = prefix+canonical(catalog['profiles'][key]).decode()+comma+'\n'
    result = ''.join(lines)
    required(json.loads(result)==catalog, 'Profile registration must preserve every unrelated value')
    return result


def required(value, message):
    if not value:
        raise ValueError(message)


def comparable(presentation):
    result = deepcopy(presentation)
    result.pop('visual_height')
    for field in ('variant', 'width', 'crest', 'accent'):
        result['visual'].pop(field)
    return result


def prepare(root, cases):
    read = lambda p: json.loads((root / p).read_text())
    targets = {r['key']: r for r in read('data/animation_authoring_sources.json')['targets']}
    catalog = read('data/combat_animation_profiles.json')
    profiles = catalog['profiles']
    coverage = read('docs/remake/evidence/pr100-direction-fix/original-based/coverage/coverage.json')
    approved = {x['key'] for x in coverage['identities'] if x['native_connected']}
    checkpoint = read('docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json')
    if checkpoint.get('individual_approval_registry'):
        approved.update(x['id'] for x in read(checkpoint['individual_approval_registry'])['decisions']
                        if x['status'] == 'APPROVED')
    tracked = set(subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z']).decode().split('\0'))
    outputs, results = {}, []
    seen = set()
    for case in cases:
        target_key, source_key = case['target'], case['source']
        required(target_key not in seen and target_key not in approved, 'Duplicate/already-approved target')
        required(source_key in approved, 'A source binding is not an existing approved species')
        seen.add(target_key)
        target, source = targets[target_key], targets[source_key]
        required(digest(canonical(target)) == case['target_contract_SHA256'], 'Target contract changed')
        required(target['reference'] == source['reference'], 'Different original image/cell; reuse forbidden')
        required(target['reference']['kind'] == 'existing_project_atlas', 'This adapter is limited to exact project-atlas bodies')
        tp, sp = target['presentation_to_preserve'], source['presentation_to_preserve']
        required(comparable(tp) == comparable(sp), 'Different body/weapon/attack/floating contract')
        original = root / target['reference']['path'].removeprefix('res://')
        required(digest(original.read_bytes()) == target['reference']['sha256'], 'Original reference bytes changed')
        source_profile = profiles[source_key]
        frames_path = case['source_frames_path']
        required(source_profile['frames_path'] == 'res://' + frames_path, 'Source ID/path mismatch')
        frames = root / frames_path
        proof_path = frames.parent / 'provenance.json'
        required(digest(frames.read_bytes()) == case['source_frames_SHA256'], 'Source SpriteFrames changed')
        required(digest(proof_path.read_bytes()) == case['source_provenance_SHA256'], 'Source provenance changed')
        proof = json.loads(proof_path.read_text())
        required(source_key in proof['target_keys'] and proof['reference'] == target['reference'], 'Source provenance identity mismatch')
        required(proof['directions'] == ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE'], 'All independent source views required')
        native_count = proof['distinct_pixel_frames']
        required(native_count in (104,112) and len(proof['frames']) == native_count, 'Do not weaken the original104/112 contract')
        texture_pins = []
        for path in sorted(set(re.findall(r'path="(res://[^\"]+\.png)"', frames.read_text()))):
            relative = path.removeprefix('res://')
            required(relative in tracked, 'A source PNG is not committed')
            texture_pins.append({'path':relative,'SHA256':digest((root/relative).read_bytes())})
        required(texture_pins, 'Missing original source PNGs')
        folder = case['folder']
        required(re.fullmatch(r'[a-z0-9_]+', folder) is not None, 'Unsafe target folder')
        destination = Path('assets/actors/eight_direction/original_based') / folder
        required(not (root/destination).exists(), 'Candidate output already exists; preserve it and review separately')
        old_profile = profiles.get(target_key)
        required(not old_profile or not old_profile.get('frames_path'), 'Do not overwrite an existing native animation')
        width_ratio = tp['visual']['width'] / sp['visual']['width']
        height_ratio = tp['visual_height'] / sp['visual_height']
        required(.8 < width_ratio < 1.25 and .5 < height_ratio < 2, 'Presentation needs separate art review outside bounded adapter')
        text = frames.read_text()
        profile = deepcopy(source_profile)
        profile.update(name=target['name'],prior_visual_profile=deepcopy(old_profile),
                       frames_path='res://'+str(destination/'SpriteFrames.tres'),
                       pixel_scale=source_profile['pixel_scale']*height_ratio,
                       native_width_ratio=width_ratio,
                       sprite_offset=[x*height_ratio for x in source_profile['sprite_offset']])
        accent = tp['visual']['accent']
        tint_amount = .055 + tp['visual']['variant']*.002
        factors = [(1-tint_amount)+tint_amount*(int(accent[n:n+2],16)/255)*1.45 for n in (0,2,4)]
        required(all(0 <= f <= 1.5 for f in factors), 'Unexpected target tint outside bounded source shader')
        # Preserve the source shader's slightly >1 multipliers without clipping
        # them to an8-bit HTML color. Existing string profiles are untouched.
        profile['color_tint'] = factors + [1.0]
        profiles[target_key] = profile
        derived = deepcopy(proof)
        derived.update(source='Existing approved native articulated motion reused for an exact same project-atlas body; no new source PNGs or native poses authored',
                       target_keys=[target_key],reference=target['reference'],
                       target_references={target_key:target['reference']},
                       presentation_to_preserve=tp,target_presentations={target_key:tp},
                       sharing_rule='One target adapter per pinned identical reference/body/weapon/attack contract. Height, bounded width and original tint are explicitly adapted. Multi-target importer guards remain unchanged.',
                       actual_Main='NOT_RUN',completed_added=0,
                       independent_target_visual_review='PENDING')
        derived['source_visual_review_preserved'] = deepcopy(proof['visual_review'])
        derived['visual_review'] = {'identity_preserved':True,'eight_views':True,'motion_roles':True,'no_clipping':True,
            'notes':'Source-only reuse: identical authoritative project image/cell/body/weapon and original full104/112 pose contract. Every source SpriteFrames/region/margin/PNG byte is unchanged. Per-target native display width, height and tint preserve its presentation. Actual target Main, unique boss skills, gait/model/contact and independent final visual judgment remain pending.'}
        derived['retargeting'] = {'source_id':source_key,'source_SpriteFrames':frames_path,
            'source_SpriteFrames_SHA256':case['source_frames_SHA256'],
            'source_provenance_SHA256':case['source_provenance_SHA256'],
            'shared_texture_files':texture_pins,'new_PNG_files':0,'new_native_poses':0,
            'original_native_poses_preserved':native_count,'source_presentation':sp,
            'width_ratio':width_ratio,'height_ratio':height_ratio,
            'tint_multipliers':factors,'target_profile':profile,
            'source_actors_changed':False,'transform_global_scale_changed':False,
            'stats_speed_collision_AI_hitmarker_changed':False}
        outputs[destination/'SpriteFrames.tres'] = text
        outputs[destination/'provenance.json'] = json.dumps(derived,ensure_ascii=False,indent=2)+'\n'
        results.append({'id':target_key,'name':target['name'],'folder':folder,'status':'SOURCE_PASS',
                        'source_reuse':True,'native_poses':native_count,'new_artwork_poses':0,
                        'production_profile_prepared':True,'actual_Main':'NOT_RUN','new_approved':0})
    return outputs, catalog, results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--plan',type=Path,required=True)
    parser.add_argument('--apply',action='store_true')
    args = parser.parse_args()
    root = args.root.resolve()
    config = json.loads(args.plan.read_text())
    original_profiles = (root/'data/combat_animation_profiles.json').read_text()
    outputs,catalog,results = prepare(root,config['cases'])
    registered_profiles = register_profiles(original_profiles,catalog,[case['target'] for case in config['cases']])
    if args.apply:
        # Every source/target/body/geometry preflight has completed before writes.
        for relative,content in outputs.items():
            (root/relative).parent.mkdir(parents=True,exist_ok=True)
            (root/relative).write_text(content)
        (root/'data/combat_animation_profiles.json').write_text(registered_profiles)
    print(json.dumps({'applied':args.apply,'cases':results,'APPROVED_added':0},ensure_ascii=False))


if __name__ == '__main__':
    main()
