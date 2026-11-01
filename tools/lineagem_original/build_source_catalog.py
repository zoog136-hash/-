"""Build a source-native candidate catalog without inventing collectible identities."""
import argparse,collections,gzip,json,pathlib,re
import original_spr

def run(inputs,output):
    p=inputs/'lineagem-category-source-metadata'
    manifest=json.load(gzip.open(p/'source_manifest.json.gz','rt'))
    ds=original_spr.read((p/'original-spr').glob('*.spr'))
    referenced={t for matches in ds.values() for d in matches for r in d.references for t in r['targets']}
    bybody={};excluded=[]
    for r in manifest['root_rows']:
        for category in r['confirmed_literal_markers']:
            if category not in ['transformation','magic_doll','holy_relic']:continue
            try:body,actions=original_spr.resolve(ds,r['id'])
            except ValueError as e:
                excluded.append({'id':r['id'],'category':category,'reason':str(e)});continue
            needed=[0,3,1] if category=='transformation' else [0,3]
            if body in referenced or any(c not in actions for c in needed):
                excluded.append({'id':r['id'],'body_id':body,'category':category,'reason':'layer_dependency_or_required_actor_actions_not_present'});continue
            name=ds[body][0]
            if category=='magic_doll' and not name_is(source_name(manifest,body), 'magicdoll'):
                excluded.append({'id':r['id'],'body_id':body,'category':category,'reason':'terminal_body_not_explicit_magicdoll_prefix'});continue
            if category=='holy_relic' and not name_is(source_name(manifest,body), 'holyrelics'):
                excluded.append({'id':r['id'],'body_id':body,'category':category,'reason':'terminal_body_not_explicit_holyrelics_prefix'});continue
            key=f'{category}:{body}'
            if key not in bybody:
                bybody[key]={'source_key':key,'body_id':body,'source_file':name.source_file,'source_line':name.source_line,'source_name':source_name(manifest,body),'category':category,'gameplay_identity':'unverified','registered_in_game':False,'gameplay_grade':None,'aliases':[],'layer_references':name.references,'production_replay_ready':False,'reason':'Identity, source origin, layer attributes and native timing require explicit verification.'}
            entry=bybody[key]
            entry['aliases'].append({'id':r['id'],'source_name':r['name'],'chain':r['alias']['chain'],'actions':{str(c):actions[c] for c in needed}})
    result={'schema':1,'contract':'Source-native BODY CANDIDATES only; not a new gameplay roster. Shared terminal body groups aliases without treating variants as separate collectibles.','body_candidates':list(bybody.values()),'excluded_or_pending_roots':excluded}
    output.mkdir(parents=True,exist_ok=True)
    (output/'source_native_body_candidates.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    counts=collections.Counter(x['category'] for x in bybody.values());print(json.dumps({'body_candidates':dict(counts),'excluded_or_pending_root_rows':len(excluded),'registered_in_game':0},ensure_ascii=False))

def name_is(name,prefix):
    return isinstance(name,str) and re.match(r'^'+re.escape(prefix)+r'[_ ]',name,re.IGNORECASE) is not None

def source_name(manifest,sid):
    matches=[d['name'] for d in manifest['declarations'] if d['id']==sid]
    return matches[0] if len(matches)==1 else None

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--inputs',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();run(a.inputs,a.output)
