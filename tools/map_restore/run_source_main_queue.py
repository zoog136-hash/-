"""Sequential actual-Main source review with durable per-map checkpoints."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess


def main():
    p = argparse.ArgumentParser()
    for name in ('godot', 'project', 'assets', 'tables', 'catalog', 'graph-results', 'results', 'logs', 'xdg-root'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--timeout', type=int, default=100)
    a = p.parse_args()
    a.results.parent.mkdir(parents=True, exist_ok=True)
    lock = a.results.with_suffix('.lock').open('a')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit('This result queue is already running; do not duplicate it.')
    rows = json.loads(a.graph_results.read_text())
    completed = json.loads(a.results.read_text()) if a.results.exists() else []
    def result_key(row):
        return (str(int(row['land'])),str(row['asset']),row['entry']['kind'],int(row['entry']['id']),row.get('scope','WHOLE_GRAPH'))
    seen = {result_key(row) for row in completed}
    env = os.environ.copy()
    for key, sub in [('CONFIG', 'config'), ('CACHE', 'cache'), ('DATA', 'data')]:
        directory = a.xdg_root / sub
        directory.mkdir(parents=True, exist_ok=True)
        env['XDG_' + key + '_HOME'] = str(directory.resolve())
    a.logs.mkdir(parents=True, exist_ok=True)
    for row in rows:
        asset = str(row['asset'])
        if result_key(row) in seen or row['status'] != 'GRAPH_REVIEW_PASSED':
            continue
        entry = row['entry']
        log = a.logs / ('main-catalog-' + asset + '-land-' + str(int(row['land'])) + '-entry-' + str(int(entry['id'])) + '.log')
        command = [str(a.godot), '--headless', '--audio-driver', 'Dummy', '--path', str(a.project),
                   '--script', 'res://tools/map_restore/verify_base508_main_edges.gd', '--',
                   '--base508-source-test', '--base508-source-edge-review',
                   '--base508-tables=' + str(a.tables), '--base508-entry-catalog=' + str(a.catalog),
                   '--base508-land=' + str(int(row['land'])),
                   '--base508-pack=' + str(a.assets / ('base508_asset_' + asset)),
                   '--base508-review-entry=' + entry['kind'] + ':' + str(int(entry['id']))]
        if row.get('scope') == 'ENTRY_COMPONENT':command.append('--base508-component-review')
        try:
            with log.open('w') as output:
                code = subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=a.timeout).returncode
        except subprocess.TimeoutExpired:
            code = 124
        lines = log.read_text().splitlines()
        failures = [line for line in lines if 'MAIN_EDGE_FAIL' in line or 'SCRIPT ERROR' in line]
        if code == 0 and (failures or not any('MAIN_SOURCE_EDGE_EXIT' in line for line in lines)):
            code = 1
        result = dict(scope=row.get('scope','WHOLE_GRAPH'),asset=asset, land=row['land'], entry=entry, exit_code=code, failures=failures, log=str(log))
        completed.append(result)
        temporary = a.results.with_suffix('.pending')
        temporary.write_text(json.dumps(completed, indent=2))
        temporary.replace(a.results)
        print(json.dumps(result), flush=True)
    print(json.dumps(dict(completed=len(completed), passed=sum(r['exit_code'] == 0 for r in completed))))


if __name__ == '__main__':
    main()
