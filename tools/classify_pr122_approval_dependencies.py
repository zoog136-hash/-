"""Recheck selected-track absence and classify dependencies without approving art."""
import argparse,collections,hashlib,json,re,subprocess
from pathlib import Path

def classify(root):
    evidence=root/'docs/remake/evidence/pr122-final-approval-20261025'
    prior=json.loads((evidence/'unvalidated-requests.json').read_text())
    inventory=json.loads((evidence/'exception-inventory.json').read_text())
    holds={(r['key'],r['direction'],r['role']):r for r in inventory['mythic']['source_holds']}
    connections={r['id']:r for r in json.loads((root/'data/pr122_monster_boss_runtime_connections.json').read_text())['connections']}
    tracked=set(subprocess.check_output(['git','ls-tree','-r','--name-only','HEAD'],cwd=root,text=True).splitlines())
    compass=['E','SE','S','SW','W','NW','N','NE'];rows=[];counts=collections.Counter()
    for entry in prior:
        r=entry['request'];direction=r['requested_direction'];direction=compass[direction] if isinstance(direction,int) else direction
        clip=r['requested_role']+'_'+str(compass.index(direction));file=root/entry['resource'].removeprefix('res://');raw=file.read_bytes()
        present=clip in set(re.findall(r'"name": &"([^"]+)"',raw.decode()))
        row=dict(id=entry['id'],resource=entry['resource'],clip=clip,selected_track_present=present,selected_frames_sha256=hashlib.sha256(raw).hexdigest())
        if entry['id']=='monster:얼음 여왕':
            published=connections[entry['id']];p=root/published['frames'].removeprefix('res://');b=p.read_bytes()
            assert hashlib.sha256(b).hexdigest()==published['frames_sha256']
            assert clip in set(re.findall(r'"name": &"([^"]+)"',b.decode()))
            row.update(classification='SUPERSEDED_SELECTION_ALREADY_PUBLISHED',published_frames=published['frames'],approval_added=False)
        elif entry['id'].startswith('transform:'):
            if present:
                assert entry['id']=='transform:399' and clip=='idle_2'
                row.update(classification='TRACK_PLAYABLE_PROFILE_BLOCKED',dependency='Authored WALK or RUN neutral phases 0 and 3 required by runtime_walk_reference_height; current selection has idle S only')
            elif (entry['id'],direction,r['requested_role']) in holds:
                h=holds[entry['id'],direction,r['requested_role']]
                row.update(classification='SOURCE_GEOMETRY_HOLD',source=h['source'],source_tracked=h['source'] in tracked,source_expected_sha256=h['sha256'],reason=h['geometry_error'])
            else:
                assert (entry['id'],direction,r['requested_role']) in [('transform:367','SE','hit'),('transform:399','S','death'),('transform:411','NW','hit')]
                row.update(classification='SOURCE_NOT_GENERATED',dependency='Missing primary source pose clip; image-tool restriction has not been lifted')
        elif '/boss_draft_first/' in entry['resource']:
            slug=entry['resource'].split('/boss_draft_first/')[1].split('/')[0]
            matches=[h for h in inventory['boss']['clips'] if h['slug']==slug and h['clip'].startswith(direction+'-'+r['requested_role']+'-')]
            assert len(matches)==1,(entry['id'],clip,matches)
            row.update(classification='BOSS_SOURCE_HOLD',source_hold=matches[0])
        else:
            assert entry['id'] in ['monster:놀','monster:알비노 몽크'] and not present
            row.update(classification='PARTIAL_PROPOSAL_TRACK_NOT_AUTHORED',dependency='Selected gnoll has only E run/attack; selected albino monk only SW run. Existing default runtime art remains separate.')
        counts[row['classification']]+=1;rows.append(row)
    return dict(source_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),prior_unvalidated_requests=len(prior),current_track_files_rechecked=True,counts=dict(counts),new_quality_approvals=0,rows=rows)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=classify(a.root);a.output.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(json.dumps(r['counts']))
