import concurrent.futures
import datetime
import json
import subprocess
from pathlib import Path

ROOT = Path('/workspace/twilight')
OUT = Path('/workspace/runtime/pr122-batch19')
REPO = 'repos/zoog136-hash/-'
BRANCH = 'feature/twilight-remaining106-20261016'

def api(path, *extra):
    run = subprocess.run(['gh', 'api', REPO + path, *extra], cwd=ROOT,
                         text=True, capture_output=True)
    if run.returncode:
        raise RuntimeError(run.stderr.strip()[:600])
    return json.loads(run.stdout) if run.stdout.strip() else None

head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
pr = api('/pulls/122')
assert pr['head']['sha'] == head and pr['head']['ref'] == BRANCH
assert pr['state'] == 'open' and not pr['merged']
workflows = json.loads((OUT/'required-workflows.json').read_text())
existing = api('/actions/runs?branch=' + BRANCH + '&head_sha=' + head + '&per_page=100')['workflow_runs']
request = OUT/'dispatch-request.json'
request.write_text(json.dumps({'ref': BRANCH}) + '\n')

def dispatch(workflow):
    prior = [r for r in existing if r['workflow_id'] == workflow['id']]
    if prior:
        latest = max(prior, key=lambda r: r['id'])
        return {**workflow, 'dispatch': 'ALREADY_PRESENT', 'run_id': latest['id'],
                'status': latest['status'], 'conclusion': latest['conclusion']}
    try:
        api('/actions/workflows/' + str(workflow['id']) + '/dispatches',
            '--method', 'POST', '--input', str(request))
        return {**workflow, 'dispatch': 'ACCEPTED'}
    except RuntimeError as exc:
        return {**workflow, 'dispatch': 'FAILED', 'error': str(exc)}

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    results = list(pool.map(dispatch, workflows))
receipt = {'observed_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'head': head, 'branch': BRANCH, 'pr': 122, 'workflows': results}
(OUT/'ci-dispatch.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({'head': head, 'required': len(results),
                  'accepted_or_present': sum(r['dispatch'] != 'FAILED' for r in results),
                  'failed_dispatches': sum(r['dispatch'] == 'FAILED' for r in results)}), flush=True)
