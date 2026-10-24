#!/usr/bin/env python3
"""Prepare one frozen post-draft review before any grouped corrections.

Visual judgments stay with the reviewer. A service failure stops this worker
instead of treating missing artwork as completed or retrying generation.
"""
import json
from pathlib import Path
import subprocess
import time

HERE=Path(__file__).resolve().parent
PRODUCTION=HERE.parent
ROOT=PRODUCTION.parents[4]

def main():
    jobs=json.loads((HERE/'queue.json').read_text())['jobs']
    started=time.monotonic()
    while not all((PRODUCTION/j['slug']/(j['clip']+'-receipt.json')).exists() for j in jobs):
        if (HERE/'generation-pause.json').exists():
            print(json.dumps(dict(status='PROVIDER_PAUSE_FULL_REVIEW_NOT_STARTED')),flush=True);return
        if time.monotonic()-started>4*3600:
            print(json.dumps(dict(status='BOUNDED_WAIT_EXPIRED_FULL_REVIEW_NOT_STARTED')),flush=True);return
        time.sleep(15)
    commands=[['python3',str(PRODUCTION/'full_source_review.py'),'--resume210'],['python3',str(HERE/'contact_pages.py')]]
    print(json.dumps(dict(status='ALL_210_SAVED_SINGLE_FULL_REVIEW_STARTED')),flush=True)
    for command in commands:
        result=subprocess.run(command,cwd=ROOT,text=True,capture_output=True,timeout=900)
        log=HERE/(Path(command[1]).stem+'-result.txt');log.write_text(result.stdout+result.stderr)
        print(json.dumps(dict(step=Path(command[1]).name,returncode=result.returncode,summary=result.stdout[-1800:]),ensure_ascii=False),flush=True)
        if result.returncode:
            print(json.dumps(dict(status='POST_DRAFT_HOLD',step=Path(command[1]).name,reason=result.stderr[-1800:],automatic_retry=False)),flush=True);return
    print(json.dumps(dict(status='SINGLE_STRUCTURE_REVIEW_DONE_VISUAL_INSPECTION_AND_ERROR_FREEZE_REQUIRED_BEFORE_GROUPED_REPAIRS')),flush=True)
if __name__=='__main__':main()
