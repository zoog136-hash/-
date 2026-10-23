#!/usr/bin/env python3
"""Export an already completed report; never recompute findings or reopen assets."""
from pathlib import Path
import csv,hashlib,json,collections
W=Path('/workspace/legendary_work');P=W/'docs/remake/pr122-legendary-parallel'
REPORT_SHA='9fdf227783c9ac2d3d9fe67010011daf645aeb7c1cd93363366cf6bc448d9ba7'
RUNTIME_SHA='fbb0bcf777624e2e257dc93744b46deb3ed5a6b6a830aa5b9ff4a850e97d30fa'
DELTA_SHA='e79c44ec3192f1189cbf3140252a16a1c46c242e091c8b9e751e3c7319050948'
CI_SHA='0625e7737202d9f7225f002b8415c57305517eba2514f856c03599c61d85cd9c'
def read(name,sha):
 p=P/name;raw=p.read_bytes()
 if hashlib.sha256(raw).hexdigest()!=sha:raise ValueError('Exact completed evidence required: '+name)
 return json.loads(raw)
def ref(name):
 p=P/name
 return {'path':'res://'+str(p.relative_to(W)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def write_json(name,value):
 with (P/name).open('x') as f:f.write(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
def table(name,rows):
 with (P/name).open('x',newline='') as f:
  writer=csv.writer(f,delimiter='\t',lineterminator='\n');writer.writerow(['severity','actor_id','direction','role','causes'])
  for row in rows:
   key,direction,role=row['slot'];writer.writerow([row['highest_severity'],key.removeprefix('transform:'),direction,role,';'.join(row['causes'])])
def main():
 report=read('remaining-findings-final-v05.json',REPORT_SHA)
 runtime=read('final-runtime-integration-through-corrections-v02.json',RUNTIME_SHA)
 delta=read('final-correction-render-integration-v01.json',DELTA_SHA)
 ci=read('final-github-ci-receipt-v02-completed-v01.json',CI_SHA)
 if runtime['effective_results']!={'PASS':1318,'EXPECTED_BLOCKED':1,'FAIL':1} or (delta['PASS'],delta['FAIL'],delta['expected_configurations'])!=(97,1,98):raise ValueError('Preserve the actual failed runtime results')
 if ci['status']!='completed' or ci['conclusion']!='failure' or tuple(ci['summary'][k] for k in ['passed','failed','skipped'])!=(216,12,5):raise ValueError('Preserve the actual failed CI result')
 rows=report['active_residual_unique_clips'];qa=report['qa_environment_residual_unique_clips']
 if len(rows)!=972 or len({tuple(x['slot']) for x in rows})!=972 or len(qa)!=2:raise ValueError('Export only the completed deduplicated dataset')
 table('remaining-findings-active-clips-final-v05.tsv',rows);table('remaining-findings-QA-environment-clips-final-v05.tsv',qa)
 clarification={'schema':'legendary-completed-report-presentation-clarification-v06','completed_report':ref('remaining-findings-final-v05.json'),'original_MD_preserved':ref('remaining-findings-final-v05-KO.md'),'clarification_scope':'Display nested effective_results from the original receipt; export existing deduplicated clip rows. No finding or severity change.','effective_runtime':{'receipt':ref('final-runtime-integration-through-corrections-v02.json'),'json_pointer':'/effective_results','results':runtime['effective_results'],'unchanged_healthy_clips_not_replayed':runtime['unchanged_healthy_clips_not_replayed']},'changed_delta_runtime':{'receipt':ref('final-correction-render-integration-v01.json'),'PASS':97,'FAIL':1,'required':98,'fail_reclassified_as_pass':0},'CI2':{'receipt':ref('final-github-ci-receipt-v02-completed-v01.json'),'status':ci['status'],'conclusion':ci['conclusion'],'summary':ci['summary']},'exports':[dict(ref('remaining-findings-active-clips-final-v05.tsv'),rows=972,data_unit='one unique active/missing art-or-uncertainty clip; highest severity and causes already computed'),dict(ref('remaining-findings-QA-environment-clips-final-v05.tsv'),rows=2,data_unit='QA environment HOLD clips; both already overlap the972 art/uncertainty clip keys')],'precondition_attempts_preserved':[ref('remaining-findings-final-precondition-attempt1-v01.json'),ref('remaining-findings-final-precondition-attempt2-v01.json')],'completed_final_corpus_reports':1,'new_corpus_reconciliation_runs':0,'source_PNG_reads':0,'new_visual_reviews':0,'new_runtime_replays':0,'finding_classification_mutations':0,'new_approvals':0}
 body=[r for r in report['active_residual_issue_projections'] if r['cause']=='clipped_or_foreign_body' and r['severity']=='ERROR']
 states=dict(collections.Counter(r['source_activity'] for r in body))
 clarification.update(active_projection_highest_severity=report['active_residual_units']['unique_clips_by_highest_severity'],QA_environment_clips_overlap_active_projection=2,interpretation='972 combines frozen issue projections and current uncertainty; not972 newly confirmed defective clips',body_foreign_ERROR338_provenance={'unique_clips':338,'source_activity':states,'new_postfix_visual_observations':0,'projection_status':'ACTIVE_VISUAL_FINDING','meaning':'Frozen ERROR_VISUAL finding projected through current exact-source/lossless-derivative selection. Ownership proof alone does not close the combined visual clipping/shape cause; no classification change.'})
 write_json('remaining-findings-final-v05-presentation-clarification-v06.json',clarification)
 text=(P/'remaining-findings-final-v05-KO.md').read_text()
 old='최신 활성 런타임 증거는 None PASS / None FAIL / None BLOCKED입니다.'
 if text.count(old)!=1:raise ValueError('Only the known nested-result display defect may be corrected')
 text=text.replace(old,'최신 활성 런타임 증거는 1318 PASS / 1 FAIL / 1 BLOCKED입니다.')
 text+='\n이미 계산한 중복 제거 목록: [활성 잔여·불확실성972구성 TSV](remaining-findings-active-clips-final-v05.tsv), [별도 QA환경HOLD2구성 TSV](remaining-findings-QA-environment-clips-final-v05.tsv). TSV는 severity·actor ID·방향·동작·원인 목록만 내보냈고 분류를 바꾸지 않았습니다.\n\n[표시 보완 근거](remaining-findings-final-v05-presentation-clarification-v06.json)는 원본v05 보고서와 raw runtime·CI SHA를 연결합니다. 원본 JSON/MD는 보존했고 전체 대조를 다시 실행하지 않았습니다.\n'
 with (P/'remaining-findings-final-v06-KO.md').open('x') as f:f.write(text)
 print(json.dumps({'status':'PRESENTATION_EXPORT_ONLY','new_MD':ref('remaining-findings-final-v06-KO.md'),'clarification':ref('remaining-findings-final-v05-presentation-clarification-v06.json'),'main_TSV':ref('remaining-findings-active-clips-final-v05.tsv'),'QA_TSV':ref('remaining-findings-QA-environment-clips-final-v05.tsv'),'new_corpus_runs':0}))
if __name__=='__main__':main()
