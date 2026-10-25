#!/usr/bin/env python3
"""Durably record the single visual pass, pinned to existing source bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parents[4]
REVIEW=HERE/'whole-review-v01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--notes',required=True);a=parser.parse_args()
    manifest=json.loads((REVIEW/'visual-pages/manifest.json').read_text())
    pages={Path(p['path']).stem:p for p in manifest['pages']}
    path=REVIEW/'visual-review-partial.json'
    records=json.loads(path.read_text()) if path.exists() else dict(schema='pr122-resume210-single-visual-pass-v1',reviewed_pages={},new_approvals=0,normal_art_changed=0)
    for note in json.loads(a.notes):
        name=note['page'];page=pages[name]
        assert name not in records['reviewed_pages'],'Already inspected; check only changed or affected parts'
        assert sha(ROOT/page['path'])==page['sha256']
        for source in page['sources']:assert sha(ROOT/source['source'])==source['sha256']
        clips={s['clip'] for s in page['sources']}
        assert all(f['clip'] in clips for f in note.get('findings',[]))
        records['reviewed_pages'][name]=dict(page=page,findings=note.get('findings',[]),observations=note.get('observations',[]),reviewer='assistant_visual_inspection',reviewed_unix=time.time(),source_phases_inspected='ALL',formal_approval_changed=False)
    records['reviewed_page_count']=len(records['reviewed_pages'])
    records['reviewed_source_sheets']=sum(len(p['page']['sources']) for p in records['reviewed_pages'].values())
    records['review_complete']=records['reviewed_page_count']==len(pages)
    temporary=path.with_suffix('.json.tmp');temporary.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n');temporary.replace(path)
    print(json.dumps(dict(reviewed_pages=records['reviewed_page_count'],reviewed_source_sheets=records['reviewed_source_sheets'],complete=records['review_complete'])))
if __name__=='__main__':main()
