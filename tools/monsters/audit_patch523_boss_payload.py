"""Compare an authenticated 989-member M handoff with the exact boss graph.

This checks original bytes/IDs only. It never renders candidate SP2 frames or
promotes a bbox model/filename suffix into a native visual/action contract.
"""
from __future__ import annotations
import argparse,hashlib,json,struct,zipfile,zlib
from pathlib import Path,PurePosixPath

ARCHIVE_SHA='b6f665d03e84e7cd01b3dd15b60d94091b3ff762cdc58fcfd820c724aa622182'
CONTENT_SHA='d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
FIELDS=('CasterEffectSpriteID','EffectSpriteID','EffectExplosionSpriteID','SuccessEffectSpriteID','FailEffectSpriteID','CriticalEffectSpriteID','HostileEffectSpriteID')
def sha(data):return hashlib.sha256(data).hexdigest()
def png_chunks(raw):
    if raw[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('not PNG')
    position=8;count=0
    while position<len(raw):
        if position+12>len(raw):raise ValueError('truncated chunk')
        size=struct.unpack_from('>I',raw,position)[0];end=position+12+size
        if end>len(raw):raise ValueError('chunk exceeds file')
        kind=raw[position+4:position+8];body=raw[position+8:position+8+size]
        if zlib.crc32(kind+body)&0xffffffff != struct.unpack_from('>I',raw,end-4)[0]:raise ValueError('PNG chunk CRC mismatch')
        count+=1;position=end
        if kind==b'IEND':
            if size or end!=len(raw):raise ValueError('unexpected canonical PNG tail')
            return count
    raise ValueError('IEND missing')

def audit(payload: Path, content: Path, catalog_path: Path, crosscheck_path: Path) -> dict:
    if sha(payload.read_bytes())!=ARCHIVE_SHA:raise ValueError('989 payload archive SHA mismatch')
    if sha(content.read_bytes())!=CONTENT_SHA:raise ValueError('523 Content SHA mismatch')
    catalog=json.loads(catalog_path.read_bytes());tables=catalog['tables']
    if catalog['source_archive_sha256']!=CONTENT_SHA:raise ValueError('catalog source snapshot mismatch')
    verified=[];pngs=[]
    with zipfile.ZipFile(payload) as archive:
        if archive.testzip() is not None:raise ValueError('archive CRC failed')
        registry=json.loads(archive.read('results/all989_actual_current_M_SP2_registry.json'))
        actual={name for name in archive.namelist() if name.endswith('.sp2')}
        registered=set()
        for record in registry:
            member=record['canonical_package_member'];parts=PurePosixPath(member)
            if parts.is_absolute() or '..' in parts.parts or not member.startswith('selected_originals/Sprite/'):raise ValueError('unsafe member')
            if member in registered:raise ValueError('duplicate registry member')
            registered.add(member);raw=archive.read(member)
            if len(raw)!=record['bytes'] or sha(raw)!=record['sha256'] or format(zlib.crc32(raw)&0xffffffff,'08x')!=record['crc32']:raise ValueError('source member identity mismatch: '+member)
            filename_id=int(parts.stem.split('-')[0])
            if filename_id!=record['filename_ID_raw']:raise ValueError('raw filename identity mismatch')
            verified.append({'member':record['member'],'filename_id_raw':filename_id,'bytes':len(raw),'sha256':sha(raw),'container':record['container']})
        if actual!=registered or len(verified)!=989:raise ValueError('actual/registered SP2 set mismatch')
        for name in archive.namelist():
            if name.startswith('validated_PNGs/') and name.endswith('.png'):
                raw=archive.read(name);pngs.append({'member':name,'bytes':len(raw),'sha256':sha(raw),'valid_chunks':png_chunks(raw),'boss_effect_contract':False})
        qa=json.loads(archive.read('objective_decoder_checks/all989_direct_M_model_QA.json'))
    available_ids={r['filename_id_raw'] for r in verified};available_members={r['member'] for r in verified}
    references={}
    for entry in tables['SpellClass'].values():
        row=entry['row']
        for field in FIELDS:
            if row.get(field):references.setdefault(str(row[field]),[]).append({'kind':'Spell','id':row['ID'],'field':field})
    for entry in tables['InvokeOption'].values():
        row=entry['row']
        for field in ('AttackerEffectSpriteID','TargetEffectSpriteID'):
            if row.get(field):references.setdefault(str(row[field]),[]).append({'kind':'Invoke','id':row['ID'],'field':field})
    crosscheck=json.loads(crosscheck_path.read_bytes())
    exact=[]
    for identity,record in crosscheck['sprite_catalog_records'].items():
        for asset in record.get('assets',[]):
            exact.append({'sprite_id':int(identity),'expected_member':asset['name'],'expected_archive':asset['archive'],'expected_bytes':asset['size'],'in_handoff':asset['name'] in available_members})
    bodies={str(entry['row']['ID']):entry['row']['Sprite'] for entry in tables['NpcClass'].values()}
    with zipfile.ZipFile(content) as archive:
        all_attacks=json.loads(archive.read('content/NpcAttack.json').decode('utf-8-sig'))['rows']
        all_by_id={row['ID']:row for row in all_attacks}
        native_ai_tables=[name for name in archive.namelist() if 'AI' in PurePosixPath(name).name and 'FishMiniGame' not in name]
    selected=[entry['row'] for entry in tables['NpcAttack'].values()]
    edges=[]
    for row in selected:
        next_id=row.get('NextAttack',0)
        if not next_id:continue
        target=all_by_id.get(next_id)
        edges.append({'from':row['ID'],'next':next_id,'npc_id':row['NpcClassID'],'source_target_present':target is not None,'target_npc_id':target.get('NpcClassID') if target else None,'same_npc':target is not None and target['NpcClassID']==row['NpcClassID']})
    return {'kind':'patch523_boss_payload_identity_audit','payload_sha256':ARCHIVE_SHA,'payload_bytes':payload.stat().st_size,'content_sha256':CONTENT_SHA,'catalog_sha256':sha(catalog_path.read_bytes()),
        'verified_sp2_members':len(verified),'verified_sp2_bytes':sum(r['bytes'] for r in verified),'raw_filename_ids':len(available_ids),'canonical_pngs':pngs,
        'spell_invoke_effect_sprite_references':references,'direct_filename_id_matches':sorted(int(k) for k in references if int(k) in available_ids),'declared_boss_expected_members':exact,
        'npc_body_sprite_ids':bodies,'direct_body_filename_id_matches':{npc:sid for npc,sid in bodies.items() if sid in available_ids},
        'native_next_attack_edges':edges,'native_next_attack_edge_count':len(edges),'dangling_in_full_provided_content':[r for r in edges if not r['source_target_present']],
        'native_ai_ids_raw':{str(e['row']['ID']):e['row'].get('AI',0) for e in tables['NpcClass'].values()},'non_fish_AI_named_tables':native_ai_tables,
        'candidate_model_evidence':{'members_EOF':qa['candidate_grammar_EOF_success_members'],'nonempty_halfopen_extents':qa['exact_halfopen_extent_records'],'native_pixel_order_alpha_timing_approved':False},
        'boundaries':['Direct filename-ID comparison is not complete SPR alias expansion','11 declared physical members are checked separately','No ID replacement, suffix-to-direction inference or map-PNG-to-boss-VFX substitution','BBox agreement is not native pixel/color/alpha/FPS approval','Missing definitions are scoped to the pinned supplied archive, not all clients','Native AI cannot be reconstructed from an AI integer without definitions']}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--payload',type=Path,required=True);p.add_argument('--content',type=Path,required=True);p.add_argument('--catalog',type=Path,required=True);p.add_argument('--crosscheck',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();result=audit(a.payload,a.content,a.catalog,a.crosscheck);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('PATCH523_BOSS_PAYLOAD_AUDIT_OK',json.dumps({k:result[k] for k in ['verified_sp2_members','verified_sp2_bytes','raw_filename_ids','direct_filename_id_matches','direct_body_filename_id_matches','native_next_attack_edge_count','dangling_in_full_provided_content']},ensure_ascii=False))
if __name__=='__main__':main()
