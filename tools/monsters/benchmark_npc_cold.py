#!/usr/bin/env python3
"""Four-process original-only A/B: cold disk, restart, and 40 warm projections.

Profiles are disposable and separate for A/B; originals are only read locally.
This measures the isolated preparation/projection boundary, not full boot or FPS.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

SOURCE_SHA = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--npc-ids', default='74161')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = args.source.resolve()
    if source.stat().st_size != 25031173 or hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA:
        raise ValueError('exact original patch523 archive required; fixtures are not accepted')
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError('original archive CRC failure')
    results = {'source_sha256': SOURCE_SHA, 'scope': 'isolated original projection; not full boot or Android', 'runs': {}}
    with tempfile.TemporaryDirectory(prefix='twilight-npc-ab-') as folder:
        for mode in ('unprepared', 'prepared'):
            profile = Path(folder) / mode
            env = dict(os.environ, TWILIGHT_PATCH523_CONTENT=str(source),
                       XDG_DATA_HOME=str(profile / 'data'), XDG_CONFIG_HOME=str(profile / 'config'),
                       XDG_CACHE_HOME=str(profile / 'cache'))
            command = [str(args.godot.resolve()), '--headless', '--path', str(args.root.resolve()),
                       '--script', 'res://tests/current523_npc_cold_probe.gd', '--', '--npc-ids=' + args.npc_ids]
            if mode == 'prepared':
                command.append('--npc-prepare')
            for state in ('cold_disk', 'restart'):
                completed = subprocess.run(command, env=env, capture_output=True, text=True, timeout=300)
                if completed.returncode or 'SCRIPT ERROR:' in completed.stdout + completed.stderr:
                    raise RuntimeError(f'{mode}/{state}: probe failed (exit {completed.returncode}); verify local source and Godot')
                lines = [line for line in completed.stdout.splitlines() if line.startswith('NPC_COLD_PROBE_RESULT ')]
                if len(lines) != 1:
                    raise RuntimeError(f'{mode}/{state}: missing result')
                results['runs'][mode + '/' + state] = json.loads(lines[0].split(' ', 1)[1])
    signatures = [[(npc['id'], npc['record_sha256'], npc['closure_sha256']) for npc in run['npcs']]
                  for run in results['runs'].values()]
    if any(value != signatures[0] for value in signatures[1:]):
        raise AssertionError('preparation changed projected record or complete closure')
    results['all_record_and_closure_hashes_equal'] = True
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
