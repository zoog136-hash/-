#!/usr/bin/env python3
"""Original-only on/off A/B: cold disk, restart, and 40 warm projections.

Profiles are disposable and separate for A/B; originals are only read locally.
This measures the isolated preparation/projection boundary, not full boot or FPS.
"""
import argparse
import hashlib
import json
import os
import re
import statistics
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
    parser.add_argument('--rounds', type=int, default=3)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = args.source.resolve()
    if source.stat().st_size != 25031173 or hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA:
        raise ValueError('exact original patch523 archive required; fixtures are not accepted')
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError('original archive CRC failure')
    results = {'source_sha256': SOURCE_SHA, 'scope': 'source verification + NpcClass reads + first projections; warm loops/hashes excluded; not full boot or Android', 'runs': {}}
    if args.rounds < 1:
        raise ValueError('rounds must be positive')
    with tempfile.TemporaryDirectory(prefix='twilight-npc-ab-') as folder:
        for round_index in range(args.rounds):
            for mode in (('off', 'on') if round_index % 2 == 0 else ('on', 'off')):
                profile = Path(folder) / str(round_index) / mode
                env = dict(os.environ, TWILIGHT_PATCH523_CONTENT=str(source),
                           TWILIGHT_NPC_RELATION_FAST='1' if mode == 'on' else '0',
                           XDG_DATA_HOME=str(profile / 'data'), XDG_CONFIG_HOME=str(profile / 'config'),
                           XDG_CACHE_HOME=str(profile / 'cache'))
                command = [str(args.godot.resolve()), '--headless', '--path', str(args.root.resolve()),
                           '--script', 'res://tests/current523_npc_cold_probe.gd', '--', '--npc-ids=' + args.npc_ids]
                for state in ('cold_disk', 'restart'):
                    completed = subprocess.run(command, env=env, capture_output=True, text=True, timeout=300)
                    if completed.returncode or 'SCRIPT ERROR:' in completed.stdout + completed.stderr:
                        raise RuntimeError(f'{mode}/{state}: probe failed (exit {completed.returncode}); verify local source and Godot')
                    lines = [line for line in completed.stdout.splitlines() if line.startswith('NPC_COLD_PROBE_RESULT ')]
                    if len(lines) != 1:
                        raise RuntimeError(f'{mode}/{state}: missing result')
                    result = json.loads(lines[0].split(' ', 1)[1])
                    result['table_conversion_ms'] = {table: int(ms) for table, ms in re.findall(
                        r'ev=end stage=def_table table=(\w+) ok=true ms=(\d+)', completed.stdout)}
                    results['runs'][f'{round_index}/{mode}/{state}'] = result
    results['total_stage_medians_ms'] = {
        f'{mode}/{state}': statistics.median(run['total_stage_ms'] for name, run in results['runs'].items()
                                            if name.endswith(f'/{mode}/{state}'))
        for mode in ('off', 'on') for state in ('cold_disk', 'restart')}
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
