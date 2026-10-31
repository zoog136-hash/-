#!/usr/bin/env python3
"""Install pinned permitted SPR records as lazy native resource packs, without art conversion."""
import argparse,hashlib,json,shutil,zipfile
from pathlib import Path

def digest(data):return hashlib.sha256(data).hexdigest()
def install(inputs,root,classification):
    meta=inputs/'unpacked'
    request=json.loads((meta/'source201-next-extraction-request.json').read_text())
    assert digest((meta/'source201-next-extraction-request.json').read_bytes())=='16e17266bb3ad22b911043460744b2714449ae4fbb1db4061722c50112ad7aa1'
    rows=[json.loads(x) for x in (meta/'provenance_manifest.jsonl').read_text().splitlines()]
    assert len(rows)==36669 and all(r['extract'] for r in rows)
    by_key={r['record_key']:r for r in rows}
    blobs=json.loads((meta/'blob_index.json').read_text());by_blob={r['path']:r for r in blobs}
    assets=root/'assets/external_spx/source_effects';assets.mkdir(parents=True,exist_ok=True)
    out=root/'data/skills/source_effects';(out/'groups').mkdir(parents=True,exist_ok=True)
    packs={};seen=set()
    for a in json.loads((meta/'sprite_archive_index.json').read_text()):
        name=Path(a['path']).name;dest=assets/(Path(name).stem+'.sprpack');src=inputs/name
        existing=dest if dest.exists() else src
        assert existing.stat().st_size==a['bytes'] and digest(existing.read_bytes())==a['sha256']
        with zipfile.ZipFile(existing) as z:
            assert z.testzip() is None
            for n in z.namelist():
                assert n in by_blob and n not in seen
                b=z.read(n);r=by_blob[n]
                assert len(b)==r['size'] and digest(b)==r['sha256'] and r['archive']==name
                seen.add(n)
        if existing==src:shutil.move(src,dest)
        packs[name]={'path':'res://'+dest.relative_to(root).as_posix(),'sha256':a['sha256'],'bytes':a['bytes']}
    assert len(seen)==28330
    catalog={'schema':1,'policy':'Lazy original-grid previews. Native pixels retained; source blend, timing and attachment semantics unverified. No automatic combat activation.','request_sha256':digest((meta/'source201-next-extraction-request.json').read_bytes()),'packs':packs,'groups':{},'excluded_groups':[r['group_id'] for r in request['excluded_effect_groups']]}
    groups=[(r,'effect') for r in request['effect_groups'] if r['extract']]
    existing_ids={g['group_id'] for g,_ in groups}
    for owner in request['attachment_requests']:
        groups.extend((dict(v,source=owner['source'],model_id=owner['definition_id'],owner_definition_id=owner['owner_definition_id']),'attachment_review') for v in owner['variants'] if v['group_id'] not in existing_ids)
    catalog['attachment_requests']=request['attachment_requests']
    catalog['attachment_definitions']=request['attachment_definitions']
    for group,kind in groups:
        ident=group['group_id'];records=[]
        for key in group['record_keys']:
            assert key in by_key,key
            r=by_key[key]
            records.append({k:r[k] for k in ['record_key','source','pak','name','offset','size','sha256','frames','variant_contexts','package_blob','archive']})
        path=out/'groups'/(ident+'.json')
        value={'schema':1,'group':group,'kind':kind,'records':records}
        path.write_text(json.dumps(value,ensure_ascii=False,separators=(',',':'))+'\n')
        catalog['groups'][ident]={k:v for k,v in group.items() if k!='record_keys'}|{'kind':kind,'records':len(records),'path':'res://'+path.relative_to(root).as_posix()}
    assert sum(x['kind']=='effect' for x in catalog['groups'].values())==2719
    # Existing reviewed atlases already preserve all 91 unique SPRs of 45 groups.
    # Reuse them rather than duplicating their raw payload in the new packs.
    old=json.loads((root/'assets/external_spx/similar_skills/manifest.json').read_text())
    refs={}
    for key,e in old['effects'].items():
        for r in e['source_records']:refs.setdefault(r['record_key'],[]).append((key,e))
    representatives=json.loads(classification.read_text())['representatives']
    reused=0
    for g in representatives:
        keys={key for a in g['aliases'] for key in a.get('raw_record_keys',[])} & refs.keys()
        if not keys:continue
        assert g['id'] not in catalog['groups']
        records=[]
        for key in sorted(keys):
            for resource,e in refs[key]:records.append(dict(e,record_key=key,resource_key=resource,storage='reviewed_atlas'))
        group={'group_id':g['id'],'model_fingerprint_sha256':g['model_fingerprint_sha256'],'display_name_evidence_only':g['representative_name']}
        dest=out/'groups'/(g['id']+'.json')
        dest.write_text(json.dumps({'schema':1,'group':group,'kind':'effect','records':records},ensure_ascii=False,separators=(',',':'))+'\n')
        catalog['groups'][g['id']]=dict(group,kind='effect',records=len(records),storage='reviewed_atlas',path='res://'+dest.relative_to(root).as_posix())
        reused+=1
    assert reused==45
    catalog['summary']={'effect_groups':2764,'excluded_groups':10,'existing_reviewed_groups':45,'new_groups':2719,'additional_attachment_only_groups':3,'new_unique_raw_blobs':28330}

    (out/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'\n')
    print('SOURCE_EFFECT_INSTALL',len(catalog['groups']),'groups',len(rows),'records',len(seen),'blobs')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--inputs',type=Path,required=True);p.add_argument('--classification',type=Path,required=True);p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);a=p.parse_args();install(a.inputs,a.root,a.classification)
