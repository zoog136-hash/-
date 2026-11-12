#!/usr/bin/env python3
"""Compare targeted catalog producer JSON outputs and their local receipts.

Exact producer payload SHA/digests and catalog/document bytes must match before
any speed comparison is accepted. Different code-key metadata is expected and
is not a template payload difference. Timing is observation, not a threshold.
"""
import argparse
import json
from pathlib import Path


def _strict_receipts(baseline, candidate):
    differences=[]
    for label,path in [('baseline',baseline),('candidate',candidate)]:
        path=Path(path); receipt=path.with_name(path.stem+'-receipt.json')
        if not receipt.is_file():
            differences.append(label+' lacks a strict completion receipt')
            continue
        admitted=json.loads(receipt.read_text())
        if admitted.get('passed') is not True or admitted.get('strict_errors'):
            differences.append(label+' strict completion receipt rejects the run')
        if Path(admitted.get('result','')).resolve()!=path.resolve():
            differences.append(label+' receipt names another result')
    return differences


def compare(baseline, candidate):
    before=json.loads(Path(baseline).read_text());after=json.loads(Path(candidate).read_text())
    if 'fixture' in before.get('measurements',{}):
        return _compare_equipment_replay(baseline,candidate,before,after)
    differences=[];phases={}
    differences.extend(_strict_receipts(baseline,candidate))
    if before.get('failures') or after.get('failures'):differences.append('a run reports failed assertions')
    for field in ['source','source_problem','engine']:
        if before.get(field)!=after.get(field):differences.append(field+' differs')
    b=before['measurements'];a=after['measurements']
    if b['cache_condition']!=a['cache_condition']:differences.append('cache conditions differ')
    if b['base_catalog']!=a['base_catalog']:differences.append('committed base catalog differs')
    phase_mode=before.get('phase','both')
    if phase_mode!=after.get('phase','both'):differences.append('benchmark phases differ')
    selected=['native_cold','native_warm']+(['equipment_cold','equipment_warm'] if phase_mode=='both' else [])
    for phase in selected:
        left=b[phase];right=a[phase]
        fields=['result','items','catalog_document_sha256','source_problem'] if phase.startswith('native') else ['ok','digest','data_counts','loaded_from_bake','source_problem']
        for field in fields:
            if left.get(field)!=right.get(field):differences.append(phase+'.'+field+' differs')
        # These are data file bytes; key metadata files are intentionally not
        # compared because production code digests invalidate keys safely.
        if left['artifacts']!=right['artifacts']:differences.append(phase+'.payload_file_hashes differ')
        elapsed_before=left['usec'];elapsed_after=right['usec']
        phases[phase]={'baseline_ms':elapsed_before/1000,'candidate_ms':elapsed_after/1000,
                       'change_percent':100*(elapsed_after-elapsed_before)/elapsed_before if elapsed_before else None,
                       'payloads_identical':left['artifacts']==right['artifacts']}
    return {'equivalent':not differences,'differences':differences,'phases':phases,
            'condition':b['cache_condition'],'scope':'real original definition producers; Linux headless, no Android claim',
            'timing_caveat':'one sequential observation per arm; OS cache and concurrent system load uncontrolled; replicate if result is marginal'}


def _compare_equipment_replay(baseline,candidate,before,after):
    differences=_strict_receipts(baseline,candidate);phases={}
    if before.get('failures') or after.get('failures'):differences.append('a run reports failed assertions')
    for field in ['source','source_problem','engine','scope']:
        if before.get(field)!=after.get(field):differences.append(field+' differs')
    b=before.get('measurements',{});a=after.get('measurements',{})
    if b.get('fixture')!=a.get('fixture'):differences.append('complete admitted fixture differs')
    if b.get('prepared_only') or a.get('prepared_only'):differences.append('prepare-only output is not a timed replay')
    for phase in ['cold','warm']:
        if phase not in b or phase not in a:
            differences.append(phase+' result absent');continue
        left=b[phase];right=a[phase]
        for field in ['ok','problem','digest','loaded_from_bake','artifacts','source_problem']:
            if left.get(field)!=right.get(field):differences.append(phase+'.'+field+' differs')
        phases[phase]={'baseline_ms':left['usec']/1000,'candidate_ms':right['usec']/1000,
                       'change_percent':100*(right['usec']-left['usec'])/left['usec'] if left['usec'] else None,
                       'payloads_identical':left['artifacts']==right['artifacts']}
    return {'equivalent':not differences,'differences':differences,'phases':phases,'fixture':b.get('fixture'),
            'condition':'own raw definition and auxiliary preloads prepared; equipment bakes absent for cold, same profile/new model for warm',
            'scope':before.get('scope'),'timing_caveat':'one sequential observation per arm; OS/system load uncontrolled; no Android claim'}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('baseline',type=Path);p.add_argument('candidate',type=Path);p.add_argument('--output',type=Path);args=p.parse_args()
    result=compare(args.baseline,args.candidate)
    value=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    if args.output:args.output.write_text(value)
    print(value,end='')
    if not result['equivalent']:raise SystemExit(1)
if __name__=='__main__':main()
