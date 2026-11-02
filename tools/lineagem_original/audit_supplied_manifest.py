"""Check the supplied full category manifest against local original pixels."""
import argparse, collections, csv, gzip, json, pathlib, zlib

def run(inputs,output):
    manifest=json.load(gzip.open(inputs/'lineagem-category-source-metadata/source_manifest.json.gz','rt'))
    local=collections.defaultdict(set)
    folders=['girtas_renewal_analysis','halphas_analysis','category_samples','linm-sp2-evidence','holy_relic-001','magic_doll-001','magic_doll-002','magic_doll-003']
    folders += [p.name for p in inputs.glob('transformation-*') if p.is_dir()]
    for folder in folders:
        for p in (inputs/folder).rglob('*.sp2'):
            raw=p.read_bytes();local[p.name].add((len(raw),f'{zlib.crc32(raw):08x}'))
    rows=[]
    for a in manifest['assets']:
        if a['group'].startswith('uncertain_candidates-'):continue
        rows.append({'archive':a['archive'],'member':a['name'],'size_bytes':a['size'],'crc32':a['crc32'],'source_prefix':a['id'],'extraction_group':a['group'],'local_crc_matched':(a['size'],a['crc32']) in local[pathlib.Path(a['name']).name]})
    rows.sort(key=lambda r:(r['archive'],r['member']))
    output.mkdir(exist_ok=True,parents=True)
    for filename,selected in [('authoritative_required_sp2.csv',rows),('authoritative_missing_sp2.csv',[r for r in rows if not r['local_crc_matched']])]:
        with (output/filename).open('w',encoding='utf-8-sig',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(selected)
    summary={'manifest_library_id':'libfile_44951912853c8191936fbe5da3abd2e9','explicit_category_union_files':len(rows),'explicit_category_union_bytes':sum(r['size_bytes'] for r in rows),'locally_crc_matched_files':sum(r['local_crc_matched'] for r in rows),'missing_files':sum(not r['local_crc_matched'] for r in rows),'missing_bytes':sum(r['size_bytes'] for r in rows if not r['local_crc_matched']),'unknown_gameplay_identities_not_registered':True,'local_folders':folders,'supersedes':'Earlier narrow 27,965-file discovery request; use authoritative_missing_sp2.csv instead.'}
    (output/'authoritative_availability.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,ensure_ascii=False,indent=2))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--inputs',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();run(a.inputs,a.output)
