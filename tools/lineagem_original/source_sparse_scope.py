"""Guarded diagnostic exceptions; absence is never synthesized into a blank frame."""
import hashlib,json
from pathlib import Path
RULES_PATH=Path(__file__).resolve().parents[2]/'data/lineagem_base508/source_sparse_attachments.json'
def load_rules():
    data=json.loads(RULES_PATH.read_text())
    if data.get('schema')!=1 or data.get('source_snapshot')!='base508':raise ValueError('unexpected sparse evidence snapshot')
    return data

def classify(actor,layer,chunk,inventory,rules,role=None):
    """Classify an indexed lookup gap without asserting M null-layer semantics."""
    assets=inventory.get(str(layer),{}).get('assets',[])
    file=f'{layer}-{chunk}.sp2'
    if any(Path(a['name']).name==file for a in assets):
        return {'classification':'indexed_file_not_materialized','file':file}
    if not assets:
        return {'classification':'entire_layer_prefix_not_located','file':file,'required_draw':'unverified'}
    matches=[]
    for item in rules.get('rules',[]):
        if int(item['actor_sprite_id'])!=int(actor['source_sprite_id']) or int(item['physical_layer_id'])!=layer or int(item['chunk'])!=chunk:continue
        if role is not None and item['role']!=role:continue
        track=actor.get('tracks',{}).get(item['role'],{})
        if (track.get('source_sprite_id')!=item['source_sprite_id'] or track.get('source_action_id')!=item['source_action_id'] or hashlib.sha256(track.get('source_raw_body','').encode()).hexdigest()!=item['source_raw_body_sha256']):continue
        if not any(int(f.get('physical_group',-1))==chunk for direction in track.get('directions',[]) for f in direction):continue
        matches.append({k:item[k] for k in ('role','source_sprite_id','source_action_id','source_raw_body_sha256','evidence')})
    return {'classification':'source_sparse_observed' if matches else 'sparse_chunk_not_located_unresolved','file':file,'required_draw':'unverified','explicit_empty':False,'evidence_matches':matches}

def reclassify_status(inputs,pack):
    import gzip,collections
    inventory=json.load(gzip.open(inputs/'full_resource_inventory/inventory/id_to_archive.json.gz','rt'));rules=load_rules();path=pack/'attachment-status.json';status=json.loads(path.read_text());cache={};byfile={}
    for issue in status['issues']:
        if issue.get('reason')!='exact_attachment_file_unavailable':continue
        sid=int(issue['actor'])
        if sid not in cache:
            actorpath=pack/'actors'/f'{sid}.json'
            if not actorpath.exists():actorpath=pack/'overlays'/f'{sid}.json'
            cache[sid]=json.loads(actorpath.read_text())
        chunk=int(issue['file'].rsplit('-',1)[1].split('.')[0]);detail=classify(cache[sid],int(issue['layer']),chunk,inventory,rules);issue['availability']=detail;byfile[issue['file']]=detail['classification']
    status['availability_by_distinct_lookup_file']=dict(collections.Counter(byfile.values()));status['availability_note']='Lookup gaps retained. source_sparse_observed is a source-supported diagnostic category, not an explicit empty frame or proven M client omission rule. Events are tracked separately.'
    path.write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n');return status
if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--inputs',type=Path,required=True);p.add_argument('--pack',type=Path,required=True);a=p.parse_args();print(json.dumps(reclassify_status(a.inputs,a.pack)['availability_by_distinct_lookup_file']))
