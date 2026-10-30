#!/usr/bin/env python3
"""Save real production immediately after its bounded Godot playback check."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--revision', required=True)
    parser.add_argument('--new-direction', required=True)
    parser.add_argument('--runtime', required=True, type=Path)
    args = parser.parse_args()
    evidence = HERE / args.revision
    candidate = evidence / 'candidate.json'
    actor = json.loads(candidate.read_text())['actors']['monster:커츠']
    report = json.loads((args.runtime / 'report.json').read_text())
    process = json.loads((args.runtime / 'process.json').read_text())
    assert process['returncode'] == 0 and not process['script_errors']
    assert report['capture_enabled'] and report['speed_scale'] == 1.0
    assert all(s['status'] == 'PLAYED_AT_GAME_SCALE' for c in report['cases'] for s in c['segments'])
    images, checked = {}, 0
    for track in actor['tracks']:
        for frame in track['geometry']['frames']:
            path = ROOT / frame.get('texture', track['texture'])
            if path not in images:
                images[path] = Image.open(path).convert('RGBA')
            x, y, w, h = frame['region']
            im = images[path]
            assert x >= 0 and y >= 0 and x + w <= im.width and y + h <= im.height
            assert hashlib.sha256(im.crop((x, y, x + w, y + h)).tobytes()).hexdigest() == frame['rgba_sha256']
            checked += 1
    for path in args.runtime.rglob('*'):
        relative = path.relative_to(args.runtime)
        if relative.parts[0] in ('project', 'user') or path.is_symlink() or not path.is_file():
            continue
        output = evidence / 'playback' / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, output)
    ledger_path = ROOT / 'data/pr122_monster_boss_repair_staging.json'
    ledger = json.loads(ledger_path.read_text())
    actor['replaces_previous_staging_selection'] = True
    actor['source_candidate'] = dict(path=candidate.relative_to(ROOT).as_posix(), sha256=digest(candidate))
    ledger['actors']['monster:커츠'] = actor
    ledger['latest_authoring_session'] = HERE.relative_to(ROOT).as_posix()
    ledger_path.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + '\n')
    subprocess.run(['python3', 'tools/reclassify_pr122_monsters.py'], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    folders = [evidence, ROOT / 'assets/actors/eight_direction/monster_boss_repair/kurtz' / args.revision,
               HERE / 'references']
    folders += [HERE / ('single' if direction == 'E' else 'single-' + direction)
                for direction in args.new_direction.split(',')]
    paths = {p for folder in folders for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts
             and p.suffix not in ('.pyc', '.import')}
    paths.update(HERE / name for name in ('record_phase.py', 'build_attacks.py', 'save_revision.py'))
    paths.update([ledger_path, ROOT / 'data/pr122_monster_production_scope.json'])
    for track in actor['tracks']:
        if track['role'] == 'attack' and 'multi_source' in track:
            paths.update(ROOT / f['texture'] for f in track['geometry']['frames'])
    entries = [dict(path=p.relative_to(ROOT).as_posix(), bytes=p.stat().st_size, sha256=digest(p)) for p in sorted(paths)]
    manifest = evidence / 'file-manifest.json'
    manifest.write_text(json.dumps(dict(schema='pr122-kurtz-production-revision-v1', revision=args.revision,
                       new_direction=args.new_direction, clips=actor['native_track_count'], poses=checked,
                       missing_required_slots=len(actor['missing_required_tracks']), root_Godot_real_speed='PASS',
                       viewport_captures=sum(c['capture_count'] for c in report['cases']),
                       new_approvals=0, default_catalog_switches=0, files=entries), ensure_ascii=False, indent=2) + '\n')
    subprocess.run(['git', 'add', '--sparse', '-f', '--', *(p.relative_to(ROOT).as_posix() for p in sorted(paths)),
                    manifest.relative_to(ROOT).as_posix()], cwd=ROOT, check=True)
    subprocess.run(['git', 'diff', '--cached', '--check'], cwd=ROOT, check=True)
    subprocess.run(['git', 'commit', '--quiet', '-m', '[skip ci] Produce Kurtz ' + args.new_direction + ' attack frames and playback'], cwd=ROOT, check=True)
    print(json.dumps(dict(commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                          selected_clips=actor['native_track_count'], poses=checked,
                          missing=len(actor['missing_required_tracks']), captured=sum(c['capture_count'] for c in report['cases']))))


if __name__ == '__main__':
    main()
