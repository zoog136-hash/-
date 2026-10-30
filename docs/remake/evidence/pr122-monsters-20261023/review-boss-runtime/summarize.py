"""Summarize technical playback scope without making boss-quality decisions."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize():
    plan = json.loads((OUT / 'plan.json').read_text())
    result = json.loads((OUT / 'godot-results.json').read_text())
    entries = [entry for group in result['resources'] for entry in group['entries']]
    requests = [request for entry in entries for request in entry['resolved']]
    ids = [entry['key'] for entry in entries]
    assert len(ids) == len(set(ids)) == 60 and set(ids) == set(plan['exact_boss_ids'])
    assert sum(entry['approved_preserved'] for entry in entries) == 43
    assert len(requests) == 2400 and sum(request['required'] for request in requests) == 1980
    sources = {}
    for group in result['resources']:
        for source in group['PNG_sources']:
            if source['path'] in sources:
                continue
            path = ROOT / source['path'].removeprefix('res://')
            sources[source['path']] = dict(source, bytes=path.stat().st_size if path.is_file() else 0,
                                           sha256=sha(path) if path.is_file() else None)
    log = (OUT / 'godot-run.txt').read_text()
    summary = dict(schema='pr122-boss-runtime-playability-summary-v1', engine=result['engine'],
        plan_HEAD=plan['HEAD'], exact_boss_ids=plan['exact_boss_ids'], bosses=60, approved_preserved=43,
        unique_TRES=len(result['resources']), unique_PNG_paths=len(sources),
        required_roles_direction_counts=plan['required_roles_direction_counts'],
        required_role_direction_requests=1980, preserved_death_direction_extra_requests=420,
        total_AnimatedSprite2D_play_requests=len(requests),
        required_resolver_unavailable=sum(not row['role_available'] for row in requests if row['required']),
        total_resolver_unavailable=sum(not row['role_available'] for row in requests),
        AnimatedSprite2D_play_failures=sum(row['AnimatedSprite2D_play'] != 'PASS' for row in requests),
        existing_run_to_walk_fallback_requests=sum(row['existing_run_to_walk_fallback'] for row in requests),
        SpriteFrames_load_failures=sum(not group['SpriteFrames_loaded'] for group in result['resources']),
        PNG_load_failures=sum(not row['file_present'] or row['load_error'] != 0 for row in sources.values()),
        failed_bosses=[entry['key'] for entry in entries if entry['failures']],
        final_Godot_script_error_lines=any(marker in log for marker in ('SCRIPT ERROR:', 'Parse Error:', 'ERROR:')),
        tested_scope='Actual canonical-profile ActorMotion resolver and AnimatedSprite2D.play with real engine-clock frame/progress advancement; loaded selected frame texture is nonnull with positive dimensions.',
        playback_speed_scale=137,
        limitations=['Accelerated headless playability sample, not gameplay cadence or full-phase timing review.',
                     'No default Main/combat scene, collision, damage, platform rendering or boss appearance evaluation.',
                     'Resource loading or playback PASS does not confer mythic-quality approval.'],
        art_quality_review='NOT_PERFORMED; independent boss A/B/C reviewers own appearance decisions',
        approval_changes=0, per_boss=entries, PNG_sources=list(sources.values()),
        input_pins=[dict(path=path.relative_to(ROOT).as_posix(), sha256=sha(path)) for path in
                    [OUT / 'plan.json', OUT / 'audit.gd', OUT / 'godot-results.json',
                     ROOT / 'scripts/animation/actor_motion.gd', ROOT / 'scripts/animation/animation_profile.gd',
                     ROOT / 'data/combat_animation_profiles.json']])
    (OUT / 'results.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    brief = {key: value for key, value in summary.items() if key not in ('per_boss', 'PNG_sources', 'input_pins')}
    (OUT / 'summary.json').write_text(json.dumps(brief, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: summary[key] for key in ['bosses', 'approved_preserved', 'unique_TRES', 'unique_PNG_paths',
        'required_role_direction_requests', 'total_AnimatedSprite2D_play_requests', 'required_resolver_unavailable',
        'AnimatedSprite2D_play_failures', 'SpriteFrames_load_failures', 'PNG_load_failures',
        'existing_run_to_walk_fallback_requests', 'approval_changes']}))


if __name__ == '__main__':
    summarize()
