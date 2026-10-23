#!/usr/bin/env python3
"""Exactly one ownership follow-up of the13 changed sources, never the corpus."""
import collections
import importlib.util
import json
from pathlib import Path

ROOT = Path('/workspace/legendary_repo')
WORK = Path('/workspace/legendary_work')
PREFIX = Path('docs/remake/pr122-legendary-parallel')
OUTPUT = WORK / PREFIX / 'quality-v02/changed-source-technical-review-v01.json'
assert not OUTPUT.exists(), 'Do not repeat a completed changed-source review'
spec = importlib.util.spec_from_file_location('first_review', WORK / PREFIX / 'audit_legendary_static_once_v01.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
rows = []
for batch in [267,268,269,270]:
    manifest = json.loads((ROOT / PREFIX / f'quality-v02/batch{batch}-revision-library-v02.json').read_text())
    for entry in manifest['revisions']:
        record = json.loads(audit.resource_path(entry['record']).read_text())
        source = audit.resource_path(record['source'])
        parsed = audit.parse_frames(audit.resource_path(record['output_spriteframes']))
        frames = [(i,frame) for i,frame in enumerate(parsed['frames']) if audit.resource_path(frame['source']) == source]
        result = audit.scan_source(source,frames,record)
        result.update(source=str(source.relative_to(ROOT)),record=entry['record'],slot=entry['slot'],
                      correction_candidate_id=entry['correction_candidate_id'],previous_source=record['previous_source'])
        assert result['sha256'] == record['source_sha256']
        rows.append(result)
assert len(rows) == 13
report = {'schema':'legendary-changed-source-ownership-followup-v1',
          'baseline_sha':'6bcd94f5a0868426ac4b5ae0ebffd93916fad1ba','whole_original_review_count':1,
          'scope':'ONLY13 successfully corrected sources after bounded correction; no healthy original source was reviewed again',
          'changed_sources_reviewed':13,'whole_corpus_rereviews':0,'generation_calls':0,'artifact_mutations':0,
          'finding_counts':dict(collections.Counter(f['code'] for row in rows for f in row['findings'])),
          'sources':rows,'quality_status':'HOLD','final_approved':0}
with OUTPUT.open('x') as handle:
    json.dump(report,handle,ensure_ascii=False,indent=2);handle.write('\n')
print(json.dumps({'changed_sources':13,'finding_counts':report['finding_counts'],'whole_corpus_rereviews':0}))
