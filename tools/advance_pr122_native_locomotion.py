#!/usr/bin/env python3
"""Preserve one returned authoring image, connect valid poses, check the Player.

Never generates images, replaces old revisions, approves characters, changes
production catalogs, dispatches CI, commits, or pushes. A failed image is kept.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

import bind_pr122_native_locomotion_profiles as binder
import stage_pr122_native_locomotion as staging


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def preserve_action(root, source, request):
    key, direction, role = (request[field] for field in ('key', 'direction', 'role'))
    batch = request.get('source_batch', 'batch03')
    assert batch in ('batch03', 'batch04'), 'Use a dedicated preserved authoring batch'
    folder = root / 'docs/remake/evidence/pr122-mythic-detailed' / batch
    folder.mkdir(exist_ok=True)
    name = staging.ACTORS[key].rsplit('_', 1)[0]
    dest = folder / f'{name}-{direction}-{role}-{request["version"]}.png'
    assert not dest.exists(), 'Never overwrite a previously authored source'
    staging.preserve_write(dest, source.read_bytes())
    geometry = dict(status='HOLD')
    try:
        result = staging.importer.analyze(dest, rows_count=6, reference_rows=[0, 3],
                                         directions_axis='phase_grid2', canvas_size=1024,
                                         directions=[direction])
        staging.importer.require_complete_pose_regions(dest, result)
        assert result['distinct_pixel_frames'] == 6
        write_json(dest.with_suffix('.geometry.json'), result)
        geometry = dict(status='GEOMETRY_PASS', frames=6, distinct_pixel_frames=6, canvas=1024)
    except Exception as exc:
        geometry['reason'] = str(exc)
    record = dict(key=key, direction=direction, role=role, version=request['version'],
                  source=dest.relative_to(root).as_posix(), original_generated_file=str(source),
                  bytes=dest.stat().st_size, sha256=staging.digest(dest), requested_poses=6,
                  geometry=geometry, production_connected=False, detailed_completed=False)
    manifest_path = root / staging.SOURCE_MANIFEST
    manifest = json.loads(manifest_path.read_text())
    manifest['raw_images'].append(record)
    write_json(manifest_path, manifest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--request', type=Path, required=True)
    parser.add_argument('--generated', type=Path, required=True)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--godot', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    request_path = (root / args.request).resolve()
    request = json.loads(request_path.read_text())
    assert request['status'] == 'REQUESTED_NOT_APPROVED', 'Do not repeat a processed image'
    key, direction, role = (request[field] for field in ('key', 'direction', 'role'))
    assert key in staging.ACTORS and direction in staging.importer.DIRECTIONS and role in staging.NATIVE_ROLES
    source = args.generated.resolve()
    assert source.is_file() and not source.is_symlink()
    log_prefix = Path('/tmp') / ('twilight-' + staging.ACTORS[key] + '-' + args.revision)
    save_log = log_prefix.with_suffix('.save.log')
    if role in ('walk', 'run') and key in ('transform:393', 'transform:267'):
        with save_log.open('w') as out:
            subprocess.run([sys.executable, str(root / 'docs/remake/evidence/pr122-mythic-detailed/batch01/save_source.py'),
                            '--source', str(source), '--key', key, '--direction', direction,
                            '--role', role, '--version', request['version']],
                           cwd=root, stdout=out, stderr=subprocess.STDOUT, check=True)
    else:
        preserve_action(root, source, request)
    manifest_path = root / staging.SOURCE_MANIFEST
    manifest = json.loads(manifest_path.read_text())
    record = manifest['raw_images'][-1]
    assert record['key'] == key and record['direction'] == direction and record['role'] == role
    assert record['original_generated_file'] == str(source)
    request.update(output_source=record['source'], output_sha256=record['sha256'],
                   output_bytes=record['bytes'], original_generated_file=str(source),
                   status='GENERATED_' + record['geometry']['status'] + '_NOT_APPROVED')
    write_json(request_path, request)
    if record['geometry']['status'] != 'GEOMETRY_PASS':
        print(json.dumps(dict(status='SOURCE_HOLD_PRESERVED', key=key, direction=direction,
                              role=role, reason=record['geometry'].get('reason', '')[:180], approvals_added=0)))
        return
    table = 'selected_locomotion_sheets' if role in ('walk', 'run') else 'selected_detailed_action_sheets'
    manifest.setdefault(table, {})[f'{key}:{direction}:{role}'] = record['source']
    manifest['selected_locomotion_native_poses'] = 6 * len(manifest['selected_locomotion_sheets'])
    manifest['selected_detailed_action_native_poses'] = 6 * len(manifest.get('selected_detailed_action_sheets', {}))
    manifest['image_tools_forbidden'] = False
    manifest['session_stop_reason'] = None
    manifest['status'] = 'NATIVE_ANIMATION_AUTHORING_IN_PROGRESS'
    write_json(manifest_path, manifest)
    files = [record['source'], str(Path(record['source']).with_suffix('.geometry.json')),
             str(staging.SOURCE_MANIFEST), str(request_path.relative_to(root))]
    subprocess.run(['git', 'add', '--sparse', '--', *files], cwd=root, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    staging.stage(root, key, args.revision)
    binder.bind(root, key)
    env = dict(os.environ, XDG_CONFIG_HOME='/tmp/twilight-godot-config',
               XDG_CACHE_HOME='/tmp/twilight-godot-cache', XDG_DATA_HOME='/tmp/twilight-godot-native-unit',
               TWILIGHT_NATIVE_TEST_KEYS=key)
    version = subprocess.check_output([str(args.godot), '--version'], env=env, text=True).strip()
    assert version == '4.7.2.stable.official.ed1daf0bf', 'Keep the required engine version'
    cases = [('resource', 'tests/pr122_native_locomotion_resource_test.gd', 'PR122_NATIVE_RESOURCE_PASS'),
             ('player', 'tests/pr122_native_player_connection_test.gd', 'PR122_NATIVE_PLAYER_CONNECTION_PASS')]
    current = json.loads((root / staging.REGISTER).read_text())['actors'][key]
    if any(track['role'] in staging.CORE_ROLES for track in current['tracks']):
        cases.append(('action', 'tests/pr122_native_action_test.gd', 'PR122_NATIVE_ACTION_PASS'))
    for name, script, marker in cases:
        log = log_prefix.with_suffix('.' + name + '.log')
        with log.open('w') as out:
            result = subprocess.run([str(args.godot), '--headless', '--disable-render-loop', '--fixed-fps', '60',
                                     '--path', str(root), '--script', script], env=env, cwd=root,
                                    stdout=out, stderr=subprocess.STDOUT, timeout=20)
        text = log.read_text(errors='replace')
        assert result.returncode == 0 and marker in text and 'ERROR:' not in text, f'{name} failed; preserve log {log}'
    register_path = root / staging.REGISTER
    register = json.loads(register_path.read_text())
    actor = register['actors'][key]
    actor['verification'] = dict(source_sha256_and_saved_geometry='PASS',
                                distinct_native_poses=actor['native_pose_count'],
                                spriteframes_parse_and_all_frame_cycles='PASS',
                                required_engine_4_7_2='PASS', required_engine_version=version,
                                actual_Player_scene_form_api='PASS',
                                Player_position_collision_class_combat_sequence_preserved='PASS',
                                missing_locomotion_not_replaced_or_aliased='PASS',
                                actual_Main='NOT_RUN', visual_approval='NOT_RUN', completed_added=0)
    if any(track['role'] in staging.CORE_ROLES for track in actor['tracks']):
        actor['verification']['actual_Player_dedicated_actions_and_markers'] = 'PASS'
    write_json(register_path, register)
    total = sum(a['native_track_count'] for a in register['actors'].values())
    missing = sum(len(a['missing_locomotion']) for a in register['actors'].values())
    print(json.dumps(dict(status='NEW_NATIVE_CLIP_CONNECTED_PLAYER_PASS', key=key, direction=direction,
                          role=role, added_poses=6, total_clips=total, total_poses=total * 6,
                          missing_locomotion=missing, approvals_added=0)))


if __name__ == '__main__':
    main()
