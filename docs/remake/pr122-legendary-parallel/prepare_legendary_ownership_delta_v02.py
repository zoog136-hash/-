#!/usr/bin/env python3
"""Quota execution delta: selected existing errors and two changed-source errors.

Original frozen review is immutable. No generation/corpus review is performed.
Existing semantic scale/ground registration survives integer atlas translation.
"""
import argparse
import copy
import io
import json
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import prepare_legendary_isolation_v01 as I
import deliver_legendary_isolation_batches_v01 as D

DELTA = D.DOCS / 'ownership-quota-execution-delta-v01.json'
UNSAFE = {'ALPHA_BRIDGE_BETWEEN_TEMPORAL_POSES', 'CONNECTED_OR_OPAQUE_POSE_LAYOUT',
          'DETACHED_FOREGROUND_OWNER_AMBIGUOUS', 'VISIBLE_FOREGROUND_TOUCHES_SOURCE_EDGE',
          'NO_PHYSICAL_BODY_SEED', 'SOURCE_OWNERSHIP_REVIEW_EXCEPTION'}


def active_library():
    ledger = D.read(D.REPO / D.LEDGER)
    library = D.read(D.REPO / ledger['corrections']['active_revision_library'].removeprefix('res://'))
    return ledger, library, {tuple(entry['slot']):entry for entry in library['revisions']}


def context(slot, active):
    entry = active.get(tuple(slot))
    if entry:
        relative = Path(entry['record'].removeprefix('res://'))
        record = D.read(D.REPO / relative)
        assert I.sha((D.REPO / relative).read_bytes()) == entry['record_sha256']
        parsed = I.parse_frames(I.safe_path(D.REPO, record['output_spriteframes']).read_bytes())
    else:
        relative, record, parsed = I.original_record(D.REPO, slot)
    return relative, record, parsed, entry


def safe(entry):
    codes = {finding['code'] for finding in entry['findings']}
    return 'FOREIGN_POSE_FOREGROUND_INSIDE_FRAME' in codes and not (codes & UNSAFE)


def select():
    assert not (D.WORK / DELTA).exists(), 'Never recreate the execution selection'
    ledger, _, _ = active_library()
    assert ledger['corrections']['ownership_isolation']['isolated_sources'] == 622
    assert all(D.read(D.LOGS / f'isolation-batch{batch:03d}-delivery.json')['status']=='REMOTE_SAVED' for batch in range(1,21))
    frozen_path = D.DOCS / 'whole-review-frozen-v01.json'
    technical_path = D.DOCS / 'technical-single-review-v01.json'
    targeted_path = D.DOCS / 'quality-v02/changed-source-technical-index-v01.json'
    frozen, technical, targeted = [D.read(D.WORK / path) for path in [frozen_path,technical_path,targeted_path]]
    succeeded = set()
    for batch in range(267,271):
        for entry in D.read(D.REPO / D.DOCS / f'quality-v02/batch{batch}-revision-library-v02.json')['revisions']:
            succeeded.add(D.read(I.safe_path(D.REPO,entry['record']))['previous_source'])
    assert len(succeeded)==13
    excluded = {entry['source']:entry for entry in frozen['bounded_source_correction_candidates'] if entry['source'] not in succeeded}
    assert len(excluded)==113
    selections=[]
    for entry in technical['source_findings']:
        if entry['source'] in excluded and safe(entry):
            selections.append(dict(entry, selection_kind='EXISTING_SOURCE_RETAINED_AFTER_QUOTA',
                                   source_review_path=I.resource(technical_path), source_review_sha256=I.sha((D.WORK/technical_path).read_bytes()),
                                   retained_quality_holds=excluded[entry['source']]['causes']))
    original_count=len(selections)
    for entry in targeted['source_findings']:
        if safe(entry):
            selections.append(dict(entry,selection_kind='CHANGED_SOURCE_TARGETED_FOLLOWUP',
                                   source_review_path=I.resource(targeted_path),source_review_sha256=I.sha((D.WORK/targeted_path).read_bytes()),
                                   retained_quality_holds=['camera'] if entry['correction_candidate_id']=='qc009' else []))
    assert len(selections)-original_count==2
    actors=sorted({entry['authored_slot'][0] for entry in selections})
    groups=[]
    while actors:
        size=3 if len(actors)==3 else 2
        group,actors=actors[:size],actors[size:]
        assert 2 <= len(group) <= 5
        groups.append(group)
    selection={'schema':'legendary-quota-execution-delta-v1','baseline_sha':I.BASELINE,
               'frozen_review':I.resource(frozen_path),'frozen_review_sha256':I.sha((D.WORK/frozen_path).read_bytes()),
               'quota_checkpoint':I.resource(D.DOCS/'quality-v02/tool-quota-checkpoint-v01.json'),
               'quota_checkpoint_sha256':I.sha((D.WORK/D.DOCS/'quality-v02/tool-quota-checkpoint-v01.json').read_bytes()),
               'initial_safe_sources_completed':622,'successful_replacement_sources':13,'nonreplacement_original_sources':113,
               'additional_original_safe_sources':original_count,'targeted_new_safe_sources':2,'planned_sources':len(selections),
               'generation_calls':0,'camera_identity_action_approvals_added':0,'resolves_only':['FOREIGN_POSE_FOREGROUND_INSIDE_FRAME'],
               'sources':selections,'batches':[{'batch':i+1,'actors':group} for i,group in enumerate(groups)],
               'unsafe_sources_remain_HOLD':True,'quality_status':'HOLD','final_approved':0}
    D.write_json(D.WORK/DELTA,selection,immutable=True)
    print(json.dumps({k:selection[k] for k in ['additional_original_safe_sources','targeted_new_safe_sources','planned_sources']},ensure_ascii=False))


def revised_clip(slot, active, substitutions, version):
    parent,record,parsed,entry=context(slot,active)
    parent_raw=(D.REPO/parent).read_bytes()
    previous_frames=copy.deepcopy(parsed['frames'])
    if entry and entry.get('registration'):
        metadata=D.read(I.safe_path(D.REPO,entry['registration']))
        assert I.sha(I.safe_path(D.REPO,entry['registration']).read_bytes())==entry['registration_sha256']
    else:
        metadata={'schema':'legendary-frame-registration-v1','baseline_sha':I.BASELINE,
                  'status':'RASTER_COORDINATE_PRESERVATION','scale_policy':'EXISTING_RUNTIME_CANVAS_NORMALIZATION',
                  'frames':[{'index':i,'scale':[1.0,1.0],'anchor_in_texture':[(f['region'][2]+f['margin'][2])/2,(f['region'][3]+f['margin'][3])/2],
                             'target_anchor':[0.0,0.0],'baseline_center':[(f['region'][2]+f['margin'][2])/2,(f['region'][3]+f['margin'][3])/2]} for i,f in enumerate(previous_frames)]}
    metadata=copy.deepcopy(metadata)
    used=[]
    for i,frame in enumerate(parsed['frames']):
        old=frame['source'].removeprefix('res://')
        if old not in substitutions:
            continue
        sub=substitutions[old]
        poses=[pose for pose in sub['proof']['poses'] if pose['original_region']==frame['region']]
        assert len(poses)==1
        pose=poses[0];reg=metadata['frames'][i]
        anchor=np.array(reg['anchor_in_texture'])
        if 'original_virtual_canvas' not in reg and 'baseline_center' not in reg:
            reg['original_virtual_canvas']=[frame['region'][2]+frame['margin'][2],frame['region'][3]+frame['margin'][3]]
        reg['anchor_in_texture']=(anchor-np.array(frame['margin'][:2])+np.array(frame['region'][:2])+np.array(pose['translation'])-np.array(pose['region'][:2])+np.array(pose['margin'][:2])).tolist()
        frame.update(source=I.resource(sub['atlas']),region=pose['region'],margin=pose['margin'])
        used.append(sub)
    assert used, 'Do not create a revision for an unaffected clip'
    relative=I.ASSETS/('transform_'+slot[0].split(':')[1])/'corrections'/version
    stem=slot[1]+'-'+slot[2]
    tres_path=relative/(stem+'-SpriteFrames.tres');record_path=relative/(stem+'-record.json');reg_path=relative/(stem+'-registration.json')
    tres_raw=I.render_tres(parsed)
    revised=copy.deepcopy(record)
    revised.update(schema='legendary-versioned-ownership-execution-delta-v2',status='OWNERSHIP_REPAIRED_OTHER_QUALITY_HOLD',
                   revision_parent=I.resource(parent),revision_parent_sha256=I.sha(parent_raw),
                   output_spriteframes=I.resource(tres_path),output_spriteframes_sha256=I.sha(tres_raw),
                   frame_registration=I.resource(reg_path),frame_registration_status=metadata['status'],
                   ownership_execution_delta=I.resource(DELTA),newly_authored_correction_poses_added=0,final_approved=False)
    revised['isolation_proofs']=sorted(set(record.get('isolation_proofs',[])+[I.resource(sub['proof_path']) for sub in used]))
    revised['ownership_delta_remaining_quality_holds']=sorted({hold for sub in used for hold in sub['selection'].get('retained_quality_holds',[])})
    old_main=record['source'].removeprefix('res://')
    if old_main in substitutions:
        sub=substitutions[old_main];p=sub['proof']
        revised.setdefault('raw_authored_source',record['source']);revised.setdefault('raw_authored_source_sha256',record['source_sha256'])
        revised.update(source=str(sub['atlas']),source_resource_path=I.resource(sub['atlas']),source_sha256=sub['atlas_sha256'],source_bytes=(D.WORK/sub['atlas']).stat().st_size,
                       cell_size=[p['output_canvas'][0]//p['grid'][0],p['output_canvas'][1]//p['grid'][1]])
        cw,ch=revised['cell_size'];revised['partition_edges']={'x':[i*cw for i in range(p['grid'][0]+1)],'y':[i*ch for i in range(p['grid'][1]+1)]}
    declared={I.resource(s['path']):s['sha256'] for s in record.get('source_files',[])};declared[I.resource(record['source'])]=record['source_sha256']
    revised['source_files']=[]
    for uri in dict.fromkeys(frame['source'] for frame in parsed['frames']):
        path=I.safe_path(D.WORK,uri)
        if not path.exists():path=I.safe_path(D.REPO,uri)
        digest=I.sha(path.read_bytes())
        if not any(uri==I.resource(sub['atlas']) for sub in substitutions.values()):assert digest==declared[uri]
        revised['source_files'].append({'path':uri,'sha256':digest,'bytes':path.stat().st_size})
    checks=[]
    for i,frame in enumerate(parsed['frames']):
        path=I.safe_path(D.WORK,frame['source'])
        if not path.exists():path=I.safe_path(D.REPO,frame['source'])
        pixels=I.frame_source_pixels(str(path));x,y,w,h=frame['region']
        checks.append({'index':i,'region':frame['region'],'margin':frame['margin'],'rgba_sha256':I.sha(pixels[y:y+h,x:x+w].tobytes())})
    revised['automatic_checks']=checks
    revised['revision_source_pose_sequence']=[dict(frame,phase=i) for i,frame in enumerate(parsed['frames'])]
    record_raw=I.json_bytes(revised)
    metadata.update(record_sha256=I.sha(record_raw),SpriteFrames_sha256=I.sha(tres_raw),
                    ownership_execution_delta=I.resource(DELTA),quality_status='HOLD',final_approved=0)
    metadata_raw=I.json_bytes(metadata)
    for path,raw in [(tres_path,tres_raw),(record_path,record_raw),(reg_path,metadata_raw)]:I.immutable_write(D.WORK/path,raw)
    result={'slot':slot,'record':I.resource(record_path),'record_sha256':I.sha(record_raw),'SpriteFrames':I.resource(tres_path),
            'SpriteFrames_sha256':I.sha(tres_raw),'registration':I.resource(reg_path),'registration_sha256':I.sha(metadata_raw),
            'registration_status':metadata['status']}
    if entry:
        for key in ['expected_terminal_baseline_phase','expected_terminal_source','expected_terminal_region']:
            if key in entry:result[key]=entry[key]
        if 'expected_terminal_source' in result:
            result['expected_terminal_source']=parsed['frames'][-1]['source'];result['expected_terminal_region']=parsed['frames'][-1]['region']
    return result


def apply(batch):
    delta=D.read(D.WORK/DELTA);group=delta['batches'][batch-1];assert group['batch']==batch
    version=f'ownership-delta-v{batch:02d}';manifest_path=D.DOCS/f'ownership-delta-batch{batch:03d}-library-v01.json'
    assert not (D.WORK/manifest_path).exists(), 'Resume existing manifest; never recreate derivative outputs'
    _,_,active=active_library();substitutions={};outcomes=[];slots=set()
    for entry in delta['sources']:
        if entry['authored_slot'][0] not in group['actors']:continue
        try:
            assert safe(entry)
            source=I.safe_path(D.REPO,entry['source']);source_raw=source.read_bytes();assert I.sha(source_raw)==entry['sha256']
            _,record,parsed,_=context(entry['authored_slot'],active)
            own=[dict(f,phase=i) for i,f in enumerate(parsed['frames']) if f['source']==I.resource(entry['source'])]
            own.sort(key=lambda frame:(frame['region'][1],frame['region'][0]))
            assert len(own)==entry['grid'][0]*entry['grid'][1], 'Unknown current source binding; this source stays HOLD'
            with Image.open(io.BytesIO(source_raw)) as image:assert image.mode=='RGBA';pixels=np.asarray(image).copy()
            atlas,proof=I.isolate_rgba(pixels,own,entry['grid'])
            target=I.ASSETS/('transform_'+entry['authored_slot'][0].split(':')[1])/'corrections'/version/(source.stem+'-isolated.png');proof_path=target.with_suffix('.proof.json')
            buffer=io.BytesIO();Image.fromarray(atlas).save(buffer,format='PNG');atlas_raw=buffer.getvalue()
            proof.update(schema='legendary-original-rgba-isolation-proof-v1',baseline_sha=I.BASELINE,source=entry['source'],source_sha256=entry['sha256'],
                         output=str(target),output_sha256=I.sha(atlas_raw),source_review_sha256=entry['source_review_sha256'],
                         source_review_path=entry['source_review_path'],execution_delta_sha256=I.sha((D.WORK/DELTA).read_bytes()),
                         integer_translation_verification='PASS',visible_source_coverage='EXACTLY_ONCE',quality_status='HOLD',final_approved=0)
            proof_raw=I.json_bytes(proof)
            I.immutable_write(D.WORK/target,atlas_raw);I.immutable_write(D.WORK/proof_path,proof_raw)
            assert I.sha(source.read_bytes())==entry['sha256']
            substitutions[entry['source']]={'atlas':target,'atlas_sha256':I.sha(atlas_raw),'proof':proof,'proof_path':proof_path,'selection':entry}
            slots.update(tuple(dep['slot']) for dep in entry['dependents']);slots.add(tuple(entry['authored_slot']))
            outcomes.append({'source':entry['source'],'source_sha256':entry['sha256'],'status':'INTEGER_TRANSLATION_PROOF_PASS',
                             'proof':I.resource(proof_path),'proof_sha256':I.sha(proof_raw),'atlas_sha256':I.sha(atlas_raw),'selection_kind':entry['selection_kind']})
        except Exception as exc:
            outcomes.append({'source':entry['source'],'status':'HOLD','error':repr(exc),'generation_retries':0})
    revisions=[];held=[]
    for slot in sorted(slots):
        try:
            _,_,parsed,_=context(list(slot),active)
            if any(f['source'].removeprefix('res://') in substitutions for f in parsed['frames']):
                revisions.append(revised_clip(list(slot),active,substitutions,version))
        except Exception as exc:
            held.append({'slot':list(slot),'status':'HOLD','error':repr(exc)})
    manifest={'schema':'legendary-isolation-revision-library-v1','baseline_sha':I.BASELINE,'batch':batch,'actors':group['actors'],
              'revisions':revisions,'dependency_required_slots':[entry['slot'] for entry in revisions],'excluded_slots':[],
              'source_outcomes':outcomes,'held_dependencies':held,'execution_delta':I.resource(DELTA),
              'execution_delta_sha256':I.sha((D.WORK/DELTA).read_bytes()),'newly_authored_poses_added':0,
              'camera_identity_action_approvals_added':0,'quality_status':'HOLD','final_approved':0}
    D.write_json(D.WORK/manifest_path,manifest,immutable=True)
    print(json.dumps({'batch':batch,'isolated_sources':len(substitutions),'revised_clips':len(revisions),'held_dependencies':len(held)}))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('mode',choices=['select','apply']);parser.add_argument('--batch',type=int)
    args=parser.parse_args()
    select() if args.mode=='select' else apply(args.batch)
