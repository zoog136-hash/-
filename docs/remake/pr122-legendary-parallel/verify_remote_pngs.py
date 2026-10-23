#!/usr/bin/env python3
"""Read the exact committed PNG bytes back; this grants no visual approval."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import quote
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[3]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--commit', required=True)
    p.add_argument('--role', choices=['idle','run','attack','hit','death'], required=True)
    p.add_argument('--direction', choices=['E','SE','S','SW','W','NW','N','NE'], required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    assert re.fullmatch('[0-9a-f]{40}', args.commit)
    assert not args.output.exists(), 'Preserve earlier delivery evidence'
    files = {}
    records = list((ROOT/'assets/actors/eight_direction/legendary_parallel').glob(f'*/draft001/{args.direction}-{args.role}-record-v01.json'))
    for path in records:
        record = json.loads(path.read_text())
        assert record['direction'] == args.direction and record['role'] == args.role
        files[record['source']] = record['source_sha256']
        for source in record.get('source_files', []):
            files[source['path'].removeprefix('res://')] = source['sha256']
    assert len(records) == 40, 'Only verify a complete forty-actor phase'
    def read_one(item):
        path, expected = item
        assert path.startswith('assets/actors/eight_direction/legendary_parallel/')
        url = 'https://raw.githubusercontent.com/zoog136-hash/-/'+args.commit+'/'+quote(path)
        try:
            with urlopen(url, timeout=45) as response:
                raw = response.read()
            actual = hashlib.sha256(raw).hexdigest()
            return {'path':path,'bytes':len(raw),'expected_sha256':expected,'actual_sha256':actual,
                    'status':'PASS' if expected == actual else 'FAIL'}
        except Exception as exc:
            return {'path':path,'status':'FAIL','error':str(exc)}
    with ThreadPoolExecutor(max_workers=6) as executor:
        rows = list(executor.map(read_one, sorted(files.items())))
    failures = sum(row['status'] != 'PASS' for row in rows)
    report = {'schema':'pr122-legendary-PNG-remote-readback-v1','commit_sha':args.commit,
              'direction':args.direction,'role':args.role,'actor_count':len(records),
              'scope':'Actual committed PNG byte delivery only; no source quality or actor approval',
              'files':rows,'failures':failures,'new_final_approvals':0}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x') as handle:
        handle.write(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({'actors':len(records),'PNGs':len(rows),'bytes':sum(row.get('bytes',0) for row in rows),'failures':failures}))
    return 1 if failures else 0

if __name__ == '__main__':
    raise SystemExit(main())
