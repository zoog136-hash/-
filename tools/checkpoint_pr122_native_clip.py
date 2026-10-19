#!/usr/bin/env python3
"""Save one verified PR122 clip with normal push; preserve unrelated changes."""
import argparse
import json
from pathlib import Path
import subprocess

import stage_pr122_native_locomotion as staging

BRANCH = 'feature/twilight-remaining106-20261016'


def update_authoring_queue(register, manifest):
    """Update missing-source pointers, including actors not registered yet.

    A saved raw HOLD never creates a fake actor. A run or core-action request
    requires the selected same-heading native walk used by its authoring prompt.
    """
    selected = manifest.get('selected_locomotion_sheets', {})
    actions = manifest.get('selected_detailed_action_sheets', {})
    holds = {(r.get('key'), r.get('direction'), r.get('role')) for r in manifest.get('raw_images', [])
             if r.get('geometry', {}).get('status') == 'HOLD'}
    holds.update((r.get('key'), r.get('direction'), r.get('role'))
                 for r in manifest.get('authoring_holds', []) if r.get('status') == 'HOLD')
    next_movement = None
    missing_movement = 0
    next_action = None
    missing_actions = 0
    for key in staging.ACTORS:
        for direction in staging.importer.DIRECTIONS:
            has_walk = f'{key}:{direction}:walk' in selected
            for role in ('walk', 'run'):
                if f'{key}:{direction}:{role}' in selected:
                    continue
                missing_movement += 1
                if (next_movement is None and (key, direction, role) not in holds
                        and (role == 'walk' or has_walk)):
                    next_movement = dict(key=key, direction=direction, role=role)
        for role in ('attack', 'hit', 'death', 'idle'):
            for direction in staging.importer.DIRECTIONS:
                if f'{key}:{direction}:{role}' in actions:
                    continue
                missing_actions += 1
                if (next_action is None and (key, direction, role) not in holds
                        and f'{key}:{direction}:walk' in selected):
                    next_action = dict(key=key, direction=direction, role=role)
    register['next_locomotion_source'] = next_movement
    register['next_detailed_source'] = next_action
    register['missing_locomotion_blocks'] = missing_movement
    register['missing_detailed_action_blocks'] = missing_actions
    return missing_movement, missing_actions, next_movement or next_action


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--request', type=Path, required=True)
    parser.add_argument('--local-only', action='store_true',
                        help='Preserve a verified local commit when remote authentication is unavailable')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    def read_git(*parts):
        return subprocess.check_output(['git', *parts], cwd=root, text=True).strip()
    assert read_git('branch', '--show-current') == BRANCH
    request_path = root / args.request
    request = json.loads(request_path.read_text())
    register = json.loads((root / staging.REGISTER).read_text())
    manifest = json.loads((root / staging.SOURCE_MANIFEST).read_text())
    assert register['approved_history_preserved'] == 405 and register['detailed_complete'] == 0
    passed = request['status'] == 'GENERATED_GEOMETRY_PASS_NOT_APPROVED'
    assert passed or request['status'] == 'GENERATED_HOLD_NOT_APPROVED'
    source = root / request['output_source']
    assert staging.digest(source) == request['output_sha256']
    actor = register['actors'].get(request['key'])
    names = [request['output_source'], str(args.request), str(staging.SOURCE_MANIFEST),
             str(staging.REGISTER), 'docs/remake/TWILIGHT_PR122_RESUME_20261019.md',
             'tools/checkpoint_pr122_native_clip.py']
    for reference in request.get('preserved_reference_files', []):
        relative = Path(reference['source'])
        allowed = root / 'docs/remake/evidence/pr122-mythic-detailed' / request.get('source_batch', 'batch03') / 'authoring-references'
        path = root / relative
        assert not relative.is_absolute() and '..' not in relative.parts and not path.is_symlink()
        assert path.resolve().is_relative_to(allowed.resolve()) and path.is_file()
        assert staging.digest(path) == reference['sha256'] and path.stat().st_size == reference['bytes']
        names.append(relative.as_posix())
    if passed:
        assert actor is not None, 'A passed clip requires a real staged and verified actor'
        assert actor['verification']['actual_Player_scene_form_api'] == 'PASS'
        assert actor['verification']['required_engine_4_7_2'] == 'PASS'
        assert any(t['source'] == request['output_source'] for t in actor['tracks'])
        names += [str(Path(request['output_source']).with_suffix('.geometry.json')),
                  str(Path(actor['frames'].removeprefix('res://')).parent)]
    for protected in ('data/combat_animation_profiles.json', 'data/pr122_palette_finish_20261019.json'):
        assert subprocess.run(['git', 'diff', '--quiet', '--', protected], cwd=root).returncode == 0
    total = sum(a['native_track_count'] for a in register['actors'].values())
    missing, missing_actions, next_target = update_authoring_queue(register, manifest)
    (root / staging.REGISTER).write_text(json.dumps(register, ensure_ascii=False, indent=2) + '\n')
    resume = root / 'docs/remake/TWILIGHT_PR122_RESUME_20261019.md'
    next_text = '이동/달리기 원화 큐 종료; 전투 동작 또는 HOLD 보완' if next_target is None else (
        f'{next_target["key"]} {next_target["direction"]} {next_target["role"]}')
    if any(hold.get('status') == 'HOLD' for hold in manifest.get('visual_quality_holds', [])):
        next_text = '유일 개체 시각 HOLD 교정 우선; 이후 ' + next_text
    latest = (f'- 최신 제작: {request["key"]} {request["direction"]} {request["role"]} {request["version"]} '
              f'{"신규6자세와 실제 Player 연결 PASS" if passed else "소스 HOLD 보존"}. '
              f'현재{total}클립/{total * 6}자세, 남은 이동{missing}블록/전용 동작{missing_actions}블록. 다음 제작: {next_text}. '
              '현재 수량은 data/pr122_native_locomotion_staging.json과 선택 소스를 우선한다.')
    lines = resume.read_text().splitlines()
    assert sum(line.startswith('- 최신 제작:') for line in lines) == 1
    resume.write_text('\n'.join(latest if line.startswith('- 최신 제작:') else line for line in lines) + '\n')
    subprocess.run(['git', 'add', '--sparse', '--', *names], cwd=root, check=True)
    staged = read_git('diff', '--cached', '--name-only').splitlines()
    assert all(any(path == name or path.startswith(name.rstrip('/') + '/') for name in names) for path in staged), \
        'Unrelated staged data preserved; inspect before committing'
    log = Path('/tmp') / ('twilight-checkpoint-' + args.request.stem + '.log')
    with log.open('w') as out:
        subprocess.run(['git', 'diff', '--cached', '--check'], cwd=root, stdout=out, stderr=subprocess.STDOUT, check=True)
        title = f'[skip ci] Author {staging.ACTORS[request["key"]]} {request["direction"]} {request["role"]} native poses' if passed else f'[skip ci] Preserve {request["key"]} {request["direction"]} {request["role"]} source HOLD'
        subprocess.run(['git', 'commit', '-m', title], cwd=root, stdout=out, stderr=subprocess.STDOUT, check=True)
        if args.local_only:
            print(json.dumps(dict(status='LOCAL_COMMITTED_NOT_PUSHED', sha=read_git('rev-parse', 'HEAD'),
                                  clips=total, poses=total * 6, approvals_added=0)))
            return
        subprocess.run(['git', 'push', 'origin', 'HEAD:refs/heads/' + BRANCH], cwd=root,
                       stdout=out, stderr=subprocess.STDOUT, check=True, timeout=60)
    sha = read_git('rev-parse', 'HEAD')
    remote = read_git('ls-remote', 'origin', 'refs/heads/' + BRANCH).split()[0]
    assert remote == sha, 'Remote changed after save; preserve and sync before the next clip'
    print(json.dumps(dict(status='PUSH_VERIFIED', sha=sha, clips=total, poses=total * 6,
                          missing_locomotion=missing, missing_dedicated_actions=missing_actions,
                          next=next_target, approvals_added=0)))


if __name__ == '__main__':
    main()
