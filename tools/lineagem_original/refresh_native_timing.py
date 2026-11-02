"""Refresh metadata from identical source SPR copies. Never decode/write pixels.
Also emit guarded explicit-clock corrections for already-delivered old packs.
"""
import argparse, collections, hashlib, json, pathlib, zipfile
import original_spr

def sha(b): return hashlib.sha256(b).hexdigest()
def encoded(d): return (json.dumps(d,ensure_ascii=False,separators=(',',':'))+'\n').encode()
def refresh(inputs,pack,table,delta,backup):
    source=inputs/'lineagem-category-source-metadata/original-spr'
    comparison=inputs/'full_resource_inventory/motion_text'
    sources=[]
    for path in sorted(source.glob('*.spr')):
        raw=path.read_bytes()
        if raw!=(comparison/path.name).read_bytes(): raise ValueError('SPR provenance differs: '+path.name)
        sources.append({'file':path.name,'bytes':len(raw),'sha256':sha(raw),'compared_identical_to':'full_resource_inventory/motion_text'})
    if len(sources)!=30: raise ValueError('Expected30 source SPR files')
    ds=original_spr.read(source.glob('*.spr'));corrections={};changed={};previous={};counts=collections.Counter();actors=set()
    for path in sorted(list((pack/'actors').glob('*.json'))+list((pack/'overlays').glob('*.json'))):
        raw=path.read_bytes();record=json.loads(raw);dirty=False
        for role,track in record['tracks'].items():
            sid=track['source_sprite_id'];body,actions=original_spr.resolve(ds,sid);action=actions[track['source_action_id']]
            if action['raw_body']!=track['source_raw_body']: raise ValueError((path,role,'raw token declaration changed'))
            old,new=track['fps'],action['fps']
            counts['unspecified_before']+=old is None;counts['unspecified_after']+=new is None
            if old==new: continue
            if old is not None or new is None or action['errors']: raise ValueError((path,role,'unexpected non-missing clock change'))
            rate=action['fps_provenance'];assert rate is not None
            key=f'{sid}:{track["source_action_id"]}:{role}'
            correction={'fps':new,'source_sprite_id':sid,'source_body_id':body,'source_action_id':track['source_action_id'],'role':role,
                'source_raw_body_sha256':sha(action['raw_body'].encode()),'origin':'SPR_explicit_section',
                'source_rate_directive':rate,'source_file_sha256':sha((source/rate['source_file']).read_bytes())}
            corrections[key]=correction
            for direction in track['directions']:
                if len(direction)!=len(action['tokens']): raise ValueError('Frame count changed')
                for frame,(group,index,ticks) in zip(direction,action['tokens']):
                    if (frame['source_group'],frame['source_frame'],frame['source_ticks'])!=(group,index,ticks): raise ValueError('Native frame tokens changed')
                    frame['duration']=ticks/new
            track.update(fps=new,static_pending_timing=False,source_timing_provenance=rate)
            counts['corrected_tracks']+=1;actors.add(record['source_sprite_id']);dirty=True
        if dirty:
            # Recover action clock metadata through the same corrected parser.
            record['source_actions']=original_spr.resolve(ds,record['source_sprite_id'])[1]
            relative=str(path.relative_to(pack));previous[relative]=raw;changed[relative]=encoded(record)
    if not changed:
        print(json.dumps({'corrected_tracks':0,'unspecified_tracks':counts['unspecified_after'],'status':'already_refreshed; earlier correction table and receipts preserved'}))
        return
    result={'schema':1,'source_snapshot':'base508','reason':'code110 frame rate whitespace was not recognized; explicit source values, not compatibility guesses',
        'source_files':sources,'corrections':corrections,'counts':dict(counts,corrected_actors=len(actors)),
        'limits':['No image bytes, frame order, native ticks, source offsets, blend attributes or gameplay damage clocks change.','Remaining NPC/doll/effect defaults and blend formulas are not inferred.']}
    if backup.exists() or delta.exists(): raise FileExistsError('Preserve earlier metadata receipts; choose new output paths')
    backup.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(backup,'w',compression=zipfile.ZIP_DEFLATED) as z:
        for name,raw in previous.items():z.writestr(name,raw)
    table.parent.mkdir(parents=True,exist_ok=True);table.write_bytes(encoded(result))
    for name,raw in changed.items():(pack/name).write_bytes(raw)
    (pack/'source_timing_corrections.json').write_bytes(encoded(result))
    status_path=pack/'connection-status.json'
    if status_path.exists():
        status=json.loads(status_path.read_text())
        for row in status['status']:
            p=pack/'actors'/f'{row["sprite_id"]}.json'
            if not p.exists():continue
            actor=json.loads(p.read_text());row['static_pending_timing']=[k for k,v in actor['tracks'].items() if v.get('static_pending_timing')]
        status_path.write_bytes(encoded(status))
    with zipfile.ZipFile(delta,'w',compression=zipfile.ZIP_DEFLATED) as z:
        for name,raw in changed.items():z.writestr(name,raw)
        z.writestr('source_timing_corrections.json',encoded(result))
        z.writestr('README.txt','Metadata-only correction for the already-delivered base508 v2 pack. Updated game code uses the same SHA-guarded correction table automatically, including strict mode. No redownload of the 1GB pixels is required. These corrected actor JSONs are for private pack maintenance/rebuild; do not select this delta as a full install ZIP. Original v2 ZIP remains unchanged.\n')
    print(json.dumps({'counts':result['counts'],'delta':str(delta),'bytes':delta.stat().st_size,'sha256':sha(delta.read_bytes()),'old_metadata_backup':str(backup)},ensure_ascii=False))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for n in ['inputs','pack','table','delta','backup']:p.add_argument('--'+n,type=pathlib.Path,required=True)
    a=p.parse_args();refresh(a.inputs,a.pack,a.table,a.delta,a.backup)
