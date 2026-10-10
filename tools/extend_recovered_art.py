#!/usr/bin/env python3
"""Inventory all recovered A2/JP PNG packs and extend original ID bindings.

This reads earlier resource outputs only, never installs old game code. The
original ZIP bytes remain unchanged. Monster border alpha is a separately
recorded derivative; all source IDs come from read-only A3 metadata.
"""
import argparse, collections, hashlib, json, pathlib, zipfile
from build_external_a2_pack import transparent_monster
from build_original_visual_bindings import normalize_name, verify_png

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=pathlib.Path,required=True)
    p.add_argument('--packs',type=pathlib.Path,required=True);p.add_argument('--metadata',type=pathlib.Path,required=True)
    p.add_argument('--split-images',type=pathlib.Path,help='Directly supplied image ZIP (img/item and img/monster)')
    p.add_argument('--split-patch',type=pathlib.Path,help='Directly supplied ZIP containing connector/patch/patch_1.zip')
    p.add_argument('--report',type=pathlib.Path,required=True);a=p.parse_args()
    records={};images={'items':{},'monsters':{}};dedup=collections.Counter();errors=[];unmapped=[]
    packs=[pack for pack in sorted(a.packs.rglob('*.zip'))
           if any(s in pack.name for s in ('STEP1_A2_ITEMS_','STEP1_ICONS_MONSTERS_JP','DATA_RUNTIME_VERIFIED'))]
    if a.split_images: packs.append(a.split_images)
    for pack in packs:
        with zipfile.ZipFile(pack) as z:
            bad=z.testzip()
            if bad:raise ValueError('CRC '+str(pack)+'/'+bad)
            for member in z.namelist():
                group='items' if member.startswith(('assets/l1j/a2/items/','assets/l1j/preview/a2/items/','img/item/')) else 'monsters' if member.startswith(('assets/l1j/a2/monster_portraits/','assets/l1j/preview/a2/monsters/','img/monster/')) else ''
                if not group or not member.endswith('.png'):continue
                gfx=pathlib.PurePosixPath(member).stem.lower().removeprefix('ms')
                if not gfx.isdigit():
                    unmapped.append({'pack':pack.name,'path':member,'reason':'non-numeric or negative sentinel ID; no automatic identity binding'})
                    continue
                raw=z.read(member);size=verify_png(raw);digest=hashlib.sha256(raw).hexdigest()
                key=group+':'+gfx
                if key in records:
                    if records[key]['sha256']!=digest:errors.append('conflicting source bytes '+key)
                    else:dedup[group]+=1
                    continue
                records[key]={'source_pack':pack.name,'source_member':member,'sha256':digest,'size':list(size)}
                images[group][gfx]=raw
    if a.split_patch:
        import io
        with zipfile.ZipFile(a.split_patch) as outer:
            for nested in ('connector/patch/patch_1.zip','connector/patch/patch_2.zip'):
                with zipfile.ZipFile(io.BytesIO(outer.read(nested))) as patch:
                    if patch.testzip(): raise ValueError('CRC '+nested)
                    for member in patch.namelist():
                        gfx=pathlib.PurePosixPath(member).stem
                        if not member.startswith('icon/') or not member.endswith('.png') or not gfx.isdigit(): continue
                        raw=patch.read(member);size=verify_png(raw);digest=hashlib.sha256(raw).hexdigest();key='items:'+gfx
                        if key in records:
                            if records[key]['sha256']!=digest: errors.append('conflicting patch icon bytes '+key)
                            else: dedup['items']+=1
                            continue
                        records[key]={'source_pack':a.split_patch.name,'source_member':nested+'::'+member,'sha256':digest,'size':list(size)}
                        images['items'][gfx]=raw
    if errors:raise ValueError('\n'.join(errors))
    manifest={'schema':1,'enabled':True,'match_policy':'exact normalized Korean name and one available source graphic ID',
        'source_archive':'recovered source-image ZIPs and directly supplied A2 split ZIPs; A3 read-only metadata','items':{},'monsters':{},'conflicts':{}}
    candidates={'items':collections.defaultdict(list),'monsters':collections.defaultdict(list)}
    for table in ('weapon','armor','etcitem','npc'):
        group='monsters' if table=='npc' else 'items'
        for r in json.loads((a.metadata/(table+'.json')).read_text()):
            name=normalize_name(r['desc_kr']);gfx=str(r['spriteId' if group=='monsters' else 'iconId'])
            if name and gfx in images[group]:candidates[group][name].append((gfx,str(r['npcid' if group=='monsters' else 'item_id']),table))
    for group in images:
        folder=a.root/'assets/external_l1j'/group;folder.mkdir(parents=True,exist_ok=True)
        # Original numeric resources are reusable even when a source name has
        # several variants. Name ambiguity still blocks the automatic bridge.
        for gfx,raw in images[group].items():
            target=folder/(gfx+'.png');rendered=transparent_monster(raw) if group=='monsters' else raw
            target.write_bytes(rendered);records[group+':'+gfx]['display_sha256']=hashlib.sha256(rendered).hexdigest()
        conflicts=[]
        for name,rows in candidates[group].items():
            graphics={r[0] for r in rows}
            if len(graphics)!=1:
                conflicts.append({'name':name,'graphics':sorted(graphics,key=int)});continue
            gfx=rows[0][0]
            manifest[group][name]={'path':f'res://assets/external_l1j/{group}/{gfx}.png','graphic_id':gfx,
                'source_table':rows[0][2],'source_ids':sorted({r[1] for r in rows})}
        manifest['conflicts'][group]=len(conflicts)
        a.report.mkdir(parents=True,exist_ok=True);(a.report/(group+'_name_conflicts.json')).write_text(json.dumps(conflicts,ensure_ascii=False,indent=2)+'\n')
    manifest['counts']={'item_names':len(manifest['items']),'monster_names':len(manifest['monsters']),
        'item_images':len(images['items']),'monster_images':len(images['monsters'])}
    # Candidate preview records use original bytes and explicit numeric IDs.
    # A portrait is not an animation, and an inventory PNG is not a ground PNG.
    registry_path=a.root/'data/l1j/registry/a2_visuals_normalized.json'
    registry=json.loads(registry_path.read_text()) if registry_path.exists() else []
    known={r['canonical_candidate_id'] for r in registry}
    for group in images:
        for gfx,raw in images[group].items():
            candidate='ext:a2:item:'+gfx if group=='items' else 'ext:a2:monster:ms'+gfx
            if candidate in known: continue
            rel=f'assets/l1j/preview/a2/{group}/'+('ms' if group=='monsters' else '')+gfx+'.png'
            target=a.root/rel;target.parent.mkdir(parents=True,exist_ok=True)
            if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest()!=hashlib.sha256(raw).hexdigest():
                raise ValueError('preview source collision '+rel)
            target.write_bytes(raw)
            source=records[group+':'+gfx]
            registry.append({'canonical_candidate_id':candidate,'source_member':source['source_member'],
                'source_pack':source['source_pack'],'inventory_texture' if group=='items' else 'portrait_texture':'res://'+rel,
                'sha256':source['sha256'],'dimensions':source['size'],
                'identity_status':'CANDIDATE_UNVERIFIED','gameplay_binding_applied':False})
    registry_path.parent.mkdir(parents=True,exist_ok=True)
    registry_path.write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n')
    path=a.root/'data/external_l1j/a2_bridge_v1.json';path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    (a.report/'recovered_original_images.json').write_text(json.dumps({'counts':manifest['counts'],'duplicates':dict(dedup),
        'source_records':records,'unmapped_file_ids':unmapped,'errors':errors},ensure_ascii=False,indent=2)+'\n')
    print('FULL_RECOVERED_IMAGES_OK',json.dumps(manifest['counts']),flush=True)

if __name__=='__main__':main()
