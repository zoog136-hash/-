"""Check only frame existence, loading, source bounds and nonempty alpha."""
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def analyze():
    plan = json.loads((OUT / 'plan.json').read_text())
    godot = json.loads((OUT / 'godot-results.json').read_text())
    sources, resources, entries = {}, [], []
    for group in godot['resources']:
        images = {}
        resource_failures = list(group['failures'])
        for source in group['source_files']:
            value = dict(source)
            path = ROOT / source['path'].removeprefix('res://')
            try:
                with Image.open(path) as image:
                    image.load()
                    assert image.format == 'PNG', 'Non-PNG texture in PNG frame inventory'
                    alpha = image.convert('RGBA').getchannel('A')
                    images[source['path']] = alpha
                    value.update(PIL_load='PASS', size=list(image.size))
                if source['path'] not in sources:
                    value.update(bytes=path.stat().st_size, sha256=sha(path))
            except Exception as error:
                value.update(PIL_load='FAIL', error=str(error))
                resource_failures.append('PNG_PIXEL_LOAD_FAILED:' + source['path'])
            if source['path'] not in sources:
                sources[source['path']] = value
        invalid_frames = []
        zero_count = []
        for name, clip in group['clips'].items():
            if clip['count'] == 0:
                zero_count.append(name)
            for frame in clip['frames']:
                failures = list(frame['failures'])
                source_path = frame.get('source_path', '')
                alpha = images.get(source_path)
                levels = frame.get('atlas_levels', [])
                if alpha is None:
                    failures.append('SOURCE_ALPHA_UNAVAILABLE')
                elif not failures:
                    if len(levels) == 0:
                        empty = alpha.getbbox() is None
                    elif len(levels) == 1:
                        x, y, width, height = levels[0]['region']
                        if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > alpha.width or y + height > alpha.height:
                            failures.append('PNG_SOURCE_REGION_OUT_OF_BOUNDS')
                            empty = False
                        else:
                            region = (math.floor(x), math.floor(y), math.ceil(x + width), math.ceil(y + height))
                            empty = alpha.crop(region).getbbox() is None
                    else:
                        empty = bool(frame.get('nested_render_alpha_empty', False))
                    if empty:
                        failures.append('ALPHA_ZERO_FRAME')
                if failures:
                    invalid_frames.append(dict(clip=name, index=frame['index'], source_path=source_path,
                                               failures=sorted(set(failures))))
        tres = ROOT / group['frames'].removeprefix('res://')
        resources.append(dict(frames=group['frames'], TRES_sha256=sha(tres) if tres.is_file() else None,
            SpriteFrames_loaded=group['SpriteFrames_loaded'], PNG_source_paths=[row['path'] for row in group['source_files']],
            clip_counts={name: value['count'] for name, value in group['clips'].items()},
            zero_count_optional_clips=zero_count, invalid_frames=invalid_frames, failures=resource_failures))
        for old in group['entries']:
            row = dict(old)
            required = [q for q in row['resolved'] if q['required']]
            missing = [q for q in required if not q['role_available']]
            if old['scope'] == 'runtime':
                failures = list(old['failures']) + resource_failures
            else:
                # Unauthored partial candidates stay partial; do not call an
                # absent new clip a corrupt existing frame or a quality HOLD.
                failures = [failure for failure in old['failures'] if not failure.endswith(':MISSING_ROLE_CLIP')] + resource_failures
            if invalid_frames:
                failures.append('INVALID_REFERENCED_FRAME_DATA')
            row['missing_frames'] = [dict(requested_role=q['requested_role'], requested_direction=q['requested_direction'],
                resolved_clip=q['resolved_clip'], frame_count=q['frame_count'],
                category='MISSING_REQUIRED_RUNTIME_CLIP' if old['scope'] == 'runtime' else 'NOT_AUTHORED_IN_THIS_STAGING_CANDIDATE')
                for q in missing]
            row['failures'] = sorted(set(failures))
            row['required_roles_direction_counts'] = dict(idle=8, run=8, attack=8, hit=8, death=1)
            row['required_requests'] = len(required)
            row['existing_runtime_walk_fallback_requests'] = sum(q['existing_runtime_walk_fallback'] for q in required)
            row['preserved_existing_death_clips'] = [name for name in group['clips'] if name.startswith('death_')]
            row['frame_availability_status'] = 'FAIL_FRAME_DATA' if failures else ('PARTIAL_NOT_AUTHORED' if missing else 'PASS_FRAME_AVAILABILITY')
            row['art_quality_review'] = 'NOT_PERFORMED_PER_USER'
            entries.append(row)
        images.clear()
    runtime = [row for row in entries if row['scope'] == 'runtime']
    staging = [row for row in entries if row['scope'] != 'runtime']
    runtime_frames = {row['frames'] for row in runtime}
    runtime_resources = [row for row in resources if row['frames'] in runtime_frames]
    runtime_sources = {path for row in runtime_resources for path in row['PNG_source_paths']}
    def summary(rows):
        return dict(entries=len(rows), approved_preserved=sum(row['approved_preserved'] for row in rows),
            required_role_direction_requests=sum(row['required_requests'] for row in rows),
            missing_required_direction_clips=sum(len(row['missing_frames']) for row in rows),
            frame_data_failed_entries=sum(bool(row['failures']) for row in rows),
            complete_frame_availability_entries=sum(row['frame_availability_status'] == 'PASS_FRAME_AVAILABILITY' for row in rows),
            partial_not_authored_entries=sum(row['frame_availability_status'] == 'PARTIAL_NOT_AUTHORED' for row in rows),
            existing_run_to_walk_fallback_requests=sum(row['existing_runtime_walk_fallback_requests'] for row in rows))
    result = dict(schema='pr122-normal-frame-review-v1', audit_plan_HEAD=plan['HEAD'], engine=godot['engine'],
        review_scope='Frame absence/loading/reference-bounds/empty-alpha only; all 258 normal monsters, including preserved approved entries.',
        art_quality_review='NOT_PERFORMED_PER_USER: no appearance, color, species, contact, facing quality or attack-pose evaluation',
        approval_changes=0, required_roles_direction_counts=dict(idle=8, run=8, attack=8, hit=8, death=1),
        existing_run_walk_fallback_allowed=True,
        runtime_summary=summary(runtime), staging_summary=summary(staging),
        unique_runtime_TRES=len(runtime_frames), unique_all_TRES=len(resources),
        unique_runtime_PNG_paths=len(runtime_sources), unique_all_PNG_paths=len(sources),
        unique_PNG_content_hashes=len({row.get('sha256') for row in sources.values() if row.get('sha256')}),
        PNG_failed_sources=[row for row in sources.values() if row['PIL_load'] != 'PASS' or row['load_error'] != 0],
        invalid_frame_occurrences=sum(len(row['invalid_frames']) for row in resources),
        runtime=runtime, staging=staging, resources=resources, PNG_sources=list(sources.values()),
        input_pins=[dict(path=path.relative_to(ROOT).as_posix(), sha256=sha(path)) for path in
                    [OUT / 'plan.json', OUT / 'audit.gd', OUT / 'godot-results.json', ROOT / 'scripts/animation/actor_motion.gd',
                     ROOT / 'scripts/animation/animation_profile.gd', ROOT / 'data/combat_animation_profiles.json']])
    assert len(runtime) == 258 and len(runtime_frames) == 93 and sum(row['approved_preserved'] for row in runtime) == 221
    assert len(staging) == 12
    (OUT / 'results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    brief = {key: result[key] for key in ['engine', 'runtime_summary', 'staging_summary', 'unique_runtime_TRES',
        'unique_all_TRES', 'unique_runtime_PNG_paths', 'unique_all_PNG_paths', 'invalid_frame_occurrences']}
    brief['PNG_failed_sources'] = len(result['PNG_failed_sources'])
    (OUT / 'summary.json').write_text(json.dumps(brief, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(brief, ensure_ascii=False))


if __name__ == '__main__':
    analyze()
