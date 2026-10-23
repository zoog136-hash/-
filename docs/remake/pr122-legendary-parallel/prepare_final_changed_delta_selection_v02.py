#!/usr/bin/env python3
"""Pin only active clips changed after the previously rendered frozen snapshot."""
import json,subprocess
from pathlib import Path
import deliver_legendary_isolation_batches_v01 as D
import prepare_legendary_isolation_v01 as I

BASE='a2dbbb01659e562980653c8d33898d3b7d761e58'
def historical(path):
    return subprocess.check_output(['git','show',BASE+':'+str(path).removeprefix('res://')],cwd=D.REPO,stderr=subprocess.DEVNULL)
def prepare():
    assert not D.git('status','--porcelain')
    head=D.git('rev-parse','HEAD');old=json.loads(historical(D.LEDGER));new=D.read(D.REPO/D.LEDGER)
    assert (D.REPO/D.LEDGER).read_bytes()==(D.WORK/D.LEDGER).read_bytes()
    oldlib=json.loads(historical(old['corrections']['active_revision_library']))
    newpath=new['corrections']['active_revision_library'];raw=I.safe_path(D.REPO,newpath).read_bytes();assert I.sha(raw)==new['corrections']['active_revision_library_sha256']
    assert I.safe_path(D.WORK,newpath).read_bytes()==raw
    active=json.loads(raw);before={tuple(e['slot']):e for e in oldlib['revisions']};after={tuple(e['slot']):e for e in active['revisions']};assert not before.keys()-after.keys()
    keys=['record_sha256','SpriteFrames_sha256','registration_sha256']
    changed=sorted(k for k,e in after.items() if k not in before or any(e.get(f)!=before[k].get(f) for f in keys))
    assert len(changed)==98,('Unexpected changed affected set',len(changed))
    rows=[]
    for slot in changed:
        entry=after[slot];record_raw=I.safe_path(D.REPO,entry['record']).read_bytes();record=json.loads(record_raw);assert I.sha(record_raw)==entry['record_sha256']
        assert [record['key'],record['direction'],record['role']]==list(slot)
        for key in ['record','SpriteFrames','registration']:
            actual=I.safe_path(D.REPO,entry[key]).read_bytes();assert I.sha(actual)==entry[key+'_sha256'];assert I.safe_path(D.WORK,entry[key]).read_bytes()==actual
        frames=I.parse_frames(I.safe_path(D.REPO,entry['SpriteFrames']).read_bytes())['frames'];assert len(frames)==6
        declared={I.resource(s['path']):s['sha256'] for s in record['source_files']};sources=[]
        for uri in dict.fromkeys(f['source'] for f in frames):
            data=I.safe_path(D.REPO,uri).read_bytes();assert I.sha(data)==declared[uri];assert I.safe_path(D.WORK,uri).read_bytes()==data
            sources.append({'path':uri,'sha256':declared[uri],'bytes':len(data)})
        rows.append(dict(entry,active_sources=sources,active_frame_bindings=frames,baseline_entry=before.get(slot)))
    quality=new['corrections']['quality_source_corrections'];assert quality['successful_sources']==109 and quality['newly_authored_correction_poses']==604
    slot_path=D.DOCS/'final-changed-active-delta-slots-v02.json';detail_path=D.DOCS/'final-changed-active-delta-selection-v02.json'
    D.write_json(D.WORK/slot_path,[list(s) for s in changed],immutable=True)
    report={'schema':'legendary-changed-active-delta-selection-v02','frozen_asset_commit':head,'baseline_fully_rendered_assets_commit':BASE,
      'baseline_actual_full_render_asset_commit':'d8aefaeb3c47c211fa66d76d1950cbda3130ba1b','staging_sha256':I.sha((D.REPO/D.LEDGER).read_bytes()),
      'active_manifest':newpath,'active_manifest_sha256':I.sha(raw),'changed_clips':len(rows),'unchanged_healthy_clips_not_selected':1319-len(rows),
      'original_moderation_blocked_slot_not_selected':['transform:274','NE','attack'],'slots':I.resource(slot_path),'slots_sha256':I.sha((D.WORK/slot_path).read_bytes()),
      'revisions':rows,'generation_calls_added':0,'new_visual_reviews':0,'final_approved':0,'quality_status':'HOLD'}
    D.write_json(D.WORK/detail_path,report,immutable=True)
    print(json.dumps({'asset_commit':head,'delta_clips':len(rows),'slots':I.resource(slot_path),'slots_sha256':report['slots_sha256'],
         'selection':I.resource(detail_path),'selection_sha256':I.sha((D.WORK/detail_path).read_bytes()),'manifest':newpath,'manifest_sha256':I.sha(raw)}))
if __name__=='__main__':prepare()
