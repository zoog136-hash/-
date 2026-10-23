#!/usr/bin/env python3
"""Dispatch the existing whole-game workflow once on the dedicated branch.

Only GitHub workflow dispatch and read-only status calls; no checkout or git edits.
Uses the session's configured gh credentials, never prints or records secrets.
"""
import argparse
import datetime as dt
import json
from pathlib import Path
import subprocess
import time

REPO = 'zoog136-hash/-'
BRANCH = 'feature/pr122-legendary-parallel-20261023'
WORKFLOW = 'twilight-integration-validate.yml'


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def gh(args):
    result = subprocess.run(['gh', *args], text=True, capture_output=True, timeout=90)
    if result.returncode:
        raise RuntimeError(result.stderr[-2000:])
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--commit', required=True)
    parser.add_argument('--output', required=True)
    options = parser.parse_args()
    if len(options.commit) != 40 or any(c not in '0123456789abcdef' for c in options.commit):
        parser.error('A full lowercase commit SHA is required')
    output = Path(options.output)
    if output.exists():
        parser.error('Output receipt already exists; resume by reading the recorded run, never redispatch')
    output.parent.mkdir(parents=True, exist_ok=True)
    receipt = dict(schema='legendary-final-github-ci-v01', repository=REPO, branch=BRANCH,
                   workflow=WORKFLOW, commit=options.commit, started_UTC=utc(),
                   dispatch_attempts=0, status='PREFLIGHT', final_approvals_added=0)

    def save():
        receipt['updated_UTC'] = utc()
        output.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({k: receipt.get(k) for k in ('status', 'run_id', 'conclusion', 'url')}, ensure_ascii=False), flush=True)

    save()
    try:
        remote_head = gh(['api', f'repos/{REPO}/git/ref/heads/{BRANCH}', '--jq', '.object.sha']).strip()
        if remote_head != options.commit:
            raise RuntimeError('Dedicated branch remote HEAD differs from the approved integration snapshot')

        def runs():
            return json.loads(gh(['run', 'list', '--repo', REPO, '--workflow', WORKFLOW,
                                  '--branch', BRANCH, '--limit', '30', '--json',
                                  'databaseId,headSha,conclusion,status,createdAt,event,url']))

        matching = [r for r in runs() if r['headSha'] == options.commit and r['event'] == 'workflow_dispatch']
        if matching:
            run = max(matching, key=lambda r: r['createdAt'])
            receipt['existing_exact_head_run_reused'] = True
        else:
            receipt['dispatch_attempts'] = 1
            receipt['status'] = 'DISPATCH_ATTEMPT_RECORDED'
            save()
            gh(['workflow', 'run', WORKFLOW, '--repo', REPO, '--ref', BRANCH])
            receipt['status'] = 'DISPATCHED_ONCE'
            save()
            run = None
            for _ in range(12):
                matching = [r for r in runs() if r['headSha'] == options.commit and r['event'] == 'workflow_dispatch']
                if matching:
                    run = max(matching, key=lambda r: r['createdAt'])
                    break
                time.sleep(10)
            if run is None:
                raise RuntimeError('Dispatch returned but no exact-head run was discoverable; do not redispatch')
        receipt.update(run_id=run['databaseId'], url=run['url'], createdAt=run['createdAt'])
        deadline = time.monotonic() + 130 * 60
        read_errors = 0
        while True:
            try:
                current = json.loads(gh(['run', 'view', str(receipt['run_id']), '--repo', REPO,
                                         '--json', 'status,conclusion,headSha,url,jobs']))
                read_errors = 0
            except (RuntimeError, subprocess.TimeoutExpired) as exc:
                read_errors += 1
                receipt['last_status_read_error'] = str(exc)[-2000:]
                if read_errors >= 3:
                    raise RuntimeError('Three consecutive CI status reads failed; preserve the dispatched run receipt') from exc
                save()
                time.sleep(45)
                continue
            if current['headSha'] != options.commit:
                raise RuntimeError('CI run HEAD mismatch')
            receipt.update(status=current['status'], conclusion=current['conclusion'],
                           jobs=[dict(name=j['name'], status=j['status'], conclusion=j['conclusion'],
                                      steps=[dict(name=s['name'], status=s['status'], conclusion=s['conclusion'])
                                             for s in j.get('steps', [])]) for j in current['jobs']])
            save()
            if current['status'] == 'completed':
                receipt['completed_UTC'] = utc()
                save()
                return 0 if current['conclusion'] == 'success' else 1
            if time.monotonic() > deadline:
                raise RuntimeError('CI observation deadline reached; do not cancel or redispatch the existing run')
            time.sleep(45)
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        receipt.update(status='OBSERVATION_BLOCKED', error=str(exc)[-2000:])
        save()
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
